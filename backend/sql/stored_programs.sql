-- =====================================================================================
--  ResourceOne Capstone — Pillar 2: Database-Native Stored Programs (MySQL 8.0)
-- =====================================================================================
--  Contains, in creation order:
--    1. fn_compute_stock_urgency_score()      stored function  (health scoring)
--    2. trg_before_stock_movement_insert      BEFORE INSERT trigger (non-negative guard)
--    3. trg_after_stock_movement_insert       AFTER  INSERT trigger (stock + audit sync)
--    4. sp_dispatch_relief_aid()              stored procedure (pessimistic lock + savepoint)
--    5. sp_sweep_expired_batches()            explicit cursor procedure
--    6. v_inventory_health_summary            view
--    7. v_monthly_financial_pnl               view
--    8. v_public_masked_catalog               view
--
--  Usage:
--      mysql -u root -p resourceone < backend/sql/stored_programs.sql
--
--  IMPORTANT — engine/application handshake:
--  When `trg_after_stock_movement_insert` is installed, the database owns the
--  `inventory_items.quantity_on_hand` balance and the audit row for every ledger
--  entry. The FastAPI service detects the trigger at runtime
--  (app/services/db_programs.py::native_movement_triggers_active) and stops applying
--  the delta in Python, so the balance is never double-counted. Restart the API
--  after installing or dropping these programs.
--
--  Runs on MySQL 8.0 (InnoDB). Not portable to SQLite by design: SQLite is the
--  offline/test engine and the application keeps the equivalent rules in Python.
-- =====================================================================================

SET NAMES utf8mb4;

-- -------------------------------------------------------------------------------------
--  Idempotent teardown (safe to re-run in any order)
-- -------------------------------------------------------------------------------------
DROP VIEW IF EXISTS v_public_masked_catalog;
DROP VIEW IF EXISTS v_monthly_financial_pnl;
DROP VIEW IF EXISTS v_inventory_health_summary;

DROP TRIGGER IF EXISTS trg_before_stock_movement_insert;
DROP TRIGGER IF EXISTS trg_after_stock_movement_insert;

DROP PROCEDURE IF EXISTS sp_dispatch_relief_aid;
DROP PROCEDURE IF EXISTS sp_sweep_expired_batches;
DROP FUNCTION IF EXISTS fn_compute_stock_urgency_score;

-- =====================================================================================
--  1. STORED FUNCTION — dynamic stock health / urgency index (0 = worst, 100 = best)
-- =====================================================================================
DELIMITER //

CREATE FUNCTION fn_compute_stock_urgency_score(p_item_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_qty     DECIMAL(12, 2);
    DECLARE v_reorder INT;
    DECLARE v_expiry  DATE;
    DECLARE v_score   INT DEFAULT 100;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_score = 0;

    SELECT quantity_on_hand, reorder_level, expiry_date
      INTO v_qty, v_reorder, v_expiry
      FROM inventory_items
     WHERE id = p_item_id;

    -- Stock depletion penalty
    IF v_qty IS NULL OR v_qty <= 0 THEN
        SET v_score = 0;                       -- out of stock / unknown item
    ELSEIF v_qty <= v_reorder THEN
        SET v_score = v_score - 40;            -- below safety threshold
    END IF;

    -- Perishable expiry penalty
    IF v_expiry IS NOT NULL THEN
        IF v_expiry < CURDATE() THEN
            SET v_score = 0;                               -- already expired
        ELSEIF DATEDIFF(v_expiry, CURDATE()) <= 30 THEN
            SET v_score = v_score - 35;                    -- expiring within 30 days
        END IF;
    END IF;

    RETURN GREATEST(0, v_score);
END;
//

-- =====================================================================================
--  2. TRIGGER — reject any ledger row that would drive physical stock negative
-- =====================================================================================
CREATE TRIGGER trg_before_stock_movement_insert
BEFORE INSERT ON stock_movements
FOR EACH ROW
BEGIN
    DECLARE v_current_qty DECIMAL(12, 2);

    SELECT quantity_on_hand INTO v_current_qty
      FROM inventory_items
     WHERE id = NEW.item_id AND org_id = NEW.org_id;

    IF NEW.quantity_delta = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Integrity Violation: movement quantity_delta must not be zero.';
    END IF;

    IF NEW.quantity_delta < 0 AND (v_current_qty + NEW.quantity_delta) < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Integrity Violation: Physical stock cannot drop below zero.';
    END IF;
END;
//

-- =====================================================================================
--  3. TRIGGER — single source of truth for the on-hand balance and the audit trail
-- =====================================================================================
CREATE TRIGGER trg_after_stock_movement_insert
AFTER INSERT ON stock_movements
FOR EACH ROW
BEGIN
    -- 3.1 Atomically move the physical balance
    UPDATE inventory_items
       SET quantity_on_hand = quantity_on_hand + NEW.quantity_delta,
           updated_at       = NOW()
     WHERE id = NEW.item_id;

    -- 3.2 Tamper-evident audit record produced by the engine, not by the web tier
    INSERT INTO activity_logs (
        org_id, actor_user_id, action, entity_type, entity_id, summary, ip_address, created_at
    ) VALUES (
        NEW.org_id,
        NEW.actor_user_id,
        'STOCK_MUTATION',
        'inventory_items',
        NEW.item_id,
        CONCAT('Stock adjusted by ', NEW.quantity_delta,
               ' units (Type: ', NEW.movement_type,
               ', movement #', NEW.id, ')'),
        '127.0.0.1',
        NOW()
    );
END;
//

-- =====================================================================================
--  4. STORED PROCEDURE — atomic relief dispatch: X-Lock + SAVEPOINT + TCL
-- =====================================================================================
--  Concurrency proof: two coordinators dispatching from 40 units of stock.
--  Without the `FOR UPDATE` lock both read 40 and both subtract 30 (lost update).
--  With it, InnoDB queues the second session on the row's exclusive lock until the
--  first transaction commits, so the second sees the true remaining balance.
-- =====================================================================================
CREATE PROCEDURE sp_dispatch_relief_aid(
    IN  p_org_id        INT,
    IN  p_item_id       INT,
    IN  p_dispatch_qty  DECIMAL(12, 2),
    IN  p_actor_id      INT,
    IN  p_destination   VARCHAR(255),
    OUT p_status        VARCHAR(50),
    OUT p_remaining_stock DECIMAL(12, 2)
)
BEGIN
    DECLARE v_available_stock DECIMAL(12, 2);
    DECLARE v_new_movement_id BIGINT;

    -- Unexpected engine error -> undo everything and report through OUT params
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status = 'ERROR: Transaction Rolled Back';
        SET p_remaining_stock = -1;
    END;

    IF p_dispatch_qty IS NULL OR p_dispatch_qty <= 0 THEN
        SET p_status = 'FAILED: Invalid Quantity';
        SET p_remaining_stock = -1;
    ELSE
        START TRANSACTION;

        -- PESSIMISTIC LOCK: exclusive row lock blocks concurrent dispatchers
        SELECT quantity_on_hand INTO v_available_stock
          FROM inventory_items
         WHERE id = p_item_id AND org_id = p_org_id
           FOR UPDATE;

        IF v_available_stock < p_dispatch_qty THEN
            SET p_status = 'FAILED: Insufficient Stock';
            SET p_remaining_stock = v_available_stock;
            ROLLBACK;
        ELSE
            -- Partial-rollback boundary: the movement ledger stays recoverable
            SAVEPOINT sv_before_movement;

            INSERT INTO stock_movements (
                org_id, item_id, movement_type, quantity_delta, unit_value, total_value,
                reference_type, note, actor_user_id, created_at
            ) VALUES (
                p_org_id, p_item_id, 'RELIEF', -p_dispatch_qty, 0.00, 0.00,
                'aid_distribution', p_destination, p_actor_id, NOW()
            );

            SET v_new_movement_id = LAST_INSERT_ID();

            -- trg_after_stock_movement_insert has already moved the balance;
            -- read the authoritative post-trigger value back.
            SELECT quantity_on_hand INTO p_remaining_stock
              FROM inventory_items
             WHERE id = p_item_id;

            COMMIT;
            SET p_status = CONCAT('SUCCESS: Aid Dispatched (movement #', v_new_movement_id, ')');
        END IF;
    END IF;
END;
//

-- =====================================================================================
--  5. EXPLICIT CURSOR — perishable batch expiry sweep
--     Demonstrates DECLARE CURSOR / OPEN / FETCH / CONTINUE HANDLER / CLOSE / LOOP
-- =====================================================================================
CREATE PROCEDURE sp_sweep_expired_batches(
    IN  p_org_id          INT,
    OUT p_archived_count  INT
)
BEGIN
    DECLARE v_done       INT DEFAULT FALSE;
    DECLARE v_item_id    INT;
    DECLARE v_item_name  VARCHAR(200);
    DECLARE v_item_qty   DECIMAL(12, 2);

    DECLARE cur_expired CURSOR FOR
        SELECT id, name, quantity_on_hand
          FROM inventory_items
         WHERE org_id = p_org_id
           AND expiry_date < CURDATE()
           AND is_archived = FALSE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    SET p_archived_count = 0;
    OPEN cur_expired;

    sweep_loop: LOOP
        FETCH cur_expired INTO v_item_id, v_item_name, v_item_qty;
        IF v_done THEN
            LEAVE sweep_loop;
        END IF;

        UPDATE inventory_items
           SET is_archived = TRUE, updated_at = NOW()
         WHERE id = v_item_id;

        INSERT INTO activity_logs (
            org_id, actor_user_id, action, entity_type, entity_id, summary, ip_address, created_at
        ) VALUES (
            p_org_id, NULL, 'SYSTEM_ARCHIVE', 'inventory_items', v_item_id,
            CONCAT('Auto-archived expired item: ', v_item_name, ' (', v_item_qty, ' units written off)'),
            '127.0.0.1', NOW()
        );

        SET p_archived_count = p_archived_count + 1;
    END LOOP;

    CLOSE cur_expired;
END;
//

DELIMITER ;

-- =====================================================================================
--  6. VIEW v_inventory_health_summary — logical data independence + valuation
--     Status and urgency are computed by the engine; consumers never re-implement
--     the business rule. `fn_compute_stock_urgency_score()` is the reusable form.
-- =====================================================================================
CREATE OR REPLACE VIEW v_inventory_health_summary AS
SELECT
    ii.org_id,
    ii.id                                   AS item_id,
    ii.sku,
    ii.name                                 AS item_name,
    ii.category,
    ii.unit,
    ii.quantity_on_hand,
    ii.reorder_level,
    ii.unit_cost,
    ii.unit_price,
    ii.expiry_date,
    CASE
        WHEN ii.quantity_on_hand <= 0                THEN 'CRITICAL'
        WHEN ii.quantity_on_hand <= ii.reorder_level THEN 'LOW'
        ELSE 'IN_STOCK'
    END                                     AS stock_status,
    CASE
        WHEN ii.expiry_date IS NULL                              THEN 'NONE'
        WHEN ii.expiry_date < CURDATE()                          THEN 'EXPIRED'
        WHEN ii.expiry_date <= DATE_ADD(CURDATE(), INTERVAL 30 DAY) THEN 'EXPIRING_30D'
        ELSE 'OK'
    END                                     AS expiry_status,
    ROUND(ii.quantity_on_hand * ii.unit_cost, 2) AS stock_value,
    GREATEST(0,
        100
        - CASE WHEN ii.quantity_on_hand <= 0 THEN 100
               WHEN ii.quantity_on_hand <= ii.reorder_level THEN 40
               ELSE 0 END
        - CASE WHEN ii.expiry_date IS NOT NULL
                AND ii.expiry_date < CURDATE() THEN 100
               WHEN ii.expiry_date IS NOT NULL
                AND ii.expiry_date <= DATE_ADD(CURDATE(), INTERVAL 30 DAY) THEN 35
               ELSE 0 END
    )                                       AS urgency_score
FROM inventory_items ii
WHERE ii.is_archived = FALSE;

-- =====================================================================================
--  7. VIEW v_monthly_financial_pnl — monthly inflows vs outflows per organization
-- =====================================================================================
CREATE OR REPLACE VIEW v_monthly_financial_pnl AS
SELECT
    pnl.org_id,
    pnl.month_key,
    pnl.cash_inflow,
    pnl.purchase_outflow,
    pnl.expense_outflow,
    (pnl.cash_inflow - pnl.purchase_outflow - pnl.expense_outflow) AS net_cash_movement
FROM (
    SELECT
        m.org_id,
        m.month_key,
        SUM(m.cash_inflow)      AS cash_inflow,
        SUM(m.purchase_outflow) AS purchase_outflow,
        SUM(m.expense_outflow)  AS expense_outflow
    FROM (
        SELECT d.org_id,
               DATE_FORMAT(d.donation_date, '%Y-%m') AS month_key,
               d.amount AS cash_inflow, 0 AS purchase_outflow, 0 AS expense_outflow
          FROM donations d
         WHERE d.donation_type = 'cash'

        UNION ALL

        SELECT p.org_id,
               DATE_FORMAT(p.purchase_date, '%Y-%m'),
               0, p.total_amount, 0
          FROM purchases p

        UNION ALL

        SELECT e.org_id,
               DATE_FORMAT(e.expense_date, '%Y-%m'),
               0, 0, e.amount
          FROM expenses e
    ) m
    GROUP BY m.org_id, m.month_key
) pnl;

-- =====================================================================================
--  8. VIEW v_public_masked_catalog — least-privilege projection for guest/auditor roles
--     Deliberately omits unit_cost, supplier margins and free-text notes.
-- =====================================================================================
CREATE OR REPLACE VIEW v_public_masked_catalog AS
SELECT
    ii.org_id,
    ii.id       AS item_id,
    ii.sku,
    ii.name     AS item_name,
    ii.category,
    ii.unit,
    CASE
        WHEN ii.quantity_on_hand <= 0                THEN 'OUT_OF_STOCK'
        WHEN ii.quantity_on_hand <= ii.reorder_level THEN 'LIMITED'
        ELSE 'AVAILABLE'
    END         AS availability,
    CASE
        WHEN ii.expiry_date IS NULL     THEN 'NOT_APPLICABLE'
        WHEN ii.expiry_date < CURDATE() THEN 'EXPIRED'
        ELSE 'WITHIN_SHELF_LIFE'
    END         AS shelf_life
FROM inventory_items ii
WHERE ii.is_archived = FALSE;

-- =====================================================================================
--  Post-install verification (expected: 2 triggers, 2 procedures, 1 function, 3 views)
-- =====================================================================================
SELECT 'TRIGGER' AS object_type, TRIGGER_NAME AS object_name
  FROM information_schema.TRIGGERS
 WHERE TRIGGER_SCHEMA = DATABASE()
UNION ALL
SELECT ROUTINE_TYPE, ROUTINE_NAME
  FROM information_schema.ROUTINES
 WHERE ROUTINE_SCHEMA = DATABASE()
UNION ALL
SELECT 'VIEW', TABLE_NAME
  FROM information_schema.VIEWS
 WHERE TABLE_SCHEMA = DATABASE()
ORDER BY object_type, object_name;
