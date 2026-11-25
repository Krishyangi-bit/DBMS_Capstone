-- =====================================================================================
--  ResourceOne Capstone — Pillar 3 & 5: Analytical SQL Suite + Query Optimisation
--  Target: MySQL 8.0 (InnoDB). Every query is tenant-scoped through @org_id.
-- =====================================================================================
--  1. Window function  — cumulative running stock balance (SUM ... OVER)
--  2. Window function  — category velocity ranking (DENSE_RANK + LAG/LEAD)
--  3. Set operations   — consolidated cash flow (UNION ALL)
--  4. Anti-join        — dead stock detector (LEFT JOIN ... IS NULL)
--  5. Correlated subquery — items above their category average
--  6. Self-join        — restock followed by a larger dispatch (shrinkage check)
--  7. Window function  — monthly P&L with cumulative net cash
--  8. EXPLAIN ANALYZE  — B-Tree index optimisation before/after
--  9. TCL              — SAVEPOINT / ROLLBACK TO / explicit transactions
-- 10. Concurrency      — SELECT ... FOR UPDATE lost-update prevention
-- =====================================================================================

SET @org_id = 1;   -- switch to 2 for the retail tenant

-- =====================================================================================
--  1. RUNNING CUMULATIVE STOCK BALANCE (window function, no self-join)
--     GROUP BY would collapse the ledger into one row per item; the window function
--     keeps every movement row while still producing the partition-level running total.
-- =====================================================================================
SELECT
    sm.id                                        AS movement_id,
    sm.created_at,
    ii.name                                      AS item_name,
    sm.movement_type,
    sm.quantity_delta,
    SUM(sm.quantity_delta) OVER (
        PARTITION BY sm.item_id
        ORDER BY sm.created_at, sm.id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                            AS running_balance,
    LAG(sm.quantity_delta) OVER (
        PARTITION BY sm.item_id
        ORDER BY sm.created_at, sm.id
    )                                            AS previous_delta,
    LEAD(sm.quantity_delta) OVER (
        PARTITION BY sm.item_id
        ORDER BY sm.created_at, sm.id
    )                                            AS next_delta
FROM stock_movements sm
JOIN inventory_items ii ON sm.item_id = ii.id
WHERE sm.org_id = @org_id
ORDER BY sm.item_id, sm.created_at, sm.id;

-- =====================================================================================
--  2. TOP-N FASTEST OUTFLOW ITEMS PER CATEGORY (DENSE_RANK, 30-day window)
-- =====================================================================================
WITH category_outflows AS (
    SELECT
        ii.category,
        ii.id                                  AS item_id,
        ii.name                                AS item_name,
        COALESCE(ABS(SUM(sm.quantity_delta)), 0) AS total_outflow
    FROM inventory_items ii
    LEFT JOIN stock_movements sm
           ON ii.id = sm.item_id
          AND sm.quantity_delta < 0
          AND sm.created_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
    WHERE ii.org_id = @org_id
      AND ii.is_archived = FALSE
    GROUP BY ii.category, ii.id, ii.name
),
ranked AS (
    SELECT
        category,
        item_id,
        item_name,
        total_outflow,
        DENSE_RANK() OVER (
            PARTITION BY category
            ORDER BY total_outflow DESC
        ) AS category_velocity_rank
    FROM category_outflows
)
SELECT *
FROM ranked
WHERE category_velocity_rank <= 3      -- top-3 movers per category
ORDER BY category, category_velocity_rank;

-- =====================================================================================
--  3. CONSOLIDATED CASH FLOW (set operation: UNION ALL keeps duplicates)
--     UNION would de-duplicate identical vouchers and silently drop rows.
-- =====================================================================================
SELECT * FROM (
    SELECT
        'INFLOW: Cash Donation'            AS transaction_type,
        d.receipt_no                       AS voucher_ref,
        d.donor_name                       AS counterparty,
        COALESCE(cd.payment_mode, 'CASH')  AS payment_channel,
        d.amount                           AS amount,
        d.donation_date                    AS txn_date,
        'INFLOW'                           AS direction
    FROM donations d
    JOIN cash_donations cd ON d.id = cd.donation_id
    WHERE d.org_id = @org_id

    UNION ALL

    SELECT
        'OUTFLOW: Supplier Purchase',
        p.invoice_no,
        p.supplier_name,
        p.payment_status,
        p.total_amount,
        p.purchase_date,
        'OUTFLOW'
    FROM purchases p
    WHERE p.org_id = @org_id

    UNION ALL

    SELECT
        'OUTFLOW: Expense',
        COALESCE(e.receipt_no, 'VOUCHER-N/A'),
        e.description,
        e.category,
        e.amount,
        e.expense_date,
        'OUTFLOW'
    FROM expenses e
    WHERE e.org_id = @org_id
) cf
ORDER BY cf.txn_date DESC, cf.voucher_ref
LIMIT 200;

-- Net position of the same set, proving the UNION ALL reconciles with the finance API
SELECT
    cf.direction,
    SUM(cf.amount) AS total_amount
FROM (
    SELECT 'INFLOW' AS direction, d.amount AS amount
      FROM donations d
     WHERE d.org_id = @org_id AND d.donation_type = 'cash'
    UNION ALL
    SELECT 'OUTFLOW', p.total_amount FROM purchases p WHERE p.org_id = @org_id
    UNION ALL
    SELECT 'OUTFLOW', e.amount       FROM expenses  e WHERE e.org_id = @org_id
) cf
GROUP BY cf.direction;

-- =====================================================================================
--  4. DEAD STOCK DETECTOR (left anti-join + correlated subquery)
--     No movement in 60 days AND holding more than the category average on hand.
-- =====================================================================================
SELECT
    ii.id,
    ii.name,
    ii.category,
    ii.quantity_on_hand,
    ii.unit_cost,
    ROUND(ii.quantity_on_hand * ii.unit_cost, 2) AS locked_capital
FROM inventory_items ii
LEFT JOIN stock_movements sm
       ON ii.id = sm.item_id
      AND sm.created_at >= DATE_SUB(CURDATE(), INTERVAL 60 DAY)
WHERE ii.org_id = @org_id
  AND ii.is_archived = FALSE
  AND sm.id IS NULL                                  -- anti-join: zero recent movement
  AND ii.quantity_on_hand > (
        -- correlated subquery: re-evaluated per outer row, scoped to its category
        SELECT AVG(sub.quantity_on_hand)
          FROM inventory_items sub
         WHERE sub.category = ii.category
           AND sub.org_id   = ii.org_id
           AND sub.is_archived = FALSE
      )
ORDER BY locked_capital DESC;

-- =====================================================================================
--  5. SELF-JOIN — restock immediately followed by a larger dispatch (shrinkage / leakage)
-- =====================================================================================
SELECT
    restock.id           AS restock_id,
    restock.created_at   AS restocked_at,
    relief.id            AS dispatch_id,
    relief.created_at    AS dispatched_at,
    ii.name              AS item_name,
    restock.quantity_delta AS units_in,
    relief.quantity_delta  AS units_out
FROM stock_movements restock
JOIN stock_movements relief
      ON relief.item_id = restock.item_id
     AND relief.org_id  = restock.org_id
     AND relief.id      > restock.id
     AND relief.quantity_delta < 0
     AND relief.created_at <= DATE_ADD(restock.created_at, INTERVAL 7 DAY)
JOIN inventory_items ii ON ii.id = restock.item_id
WHERE restock.org_id = @org_id
  AND restock.quantity_delta > 0
  AND ABS(relief.quantity_delta) > restock.quantity_delta
ORDER BY restock.created_at DESC;

-- =====================================================================================
--  6. MONTHLY P&L WITH CUMULATIVE NET CASH (aggregation + window function)
-- =====================================================================================
SELECT
    pnl.month_key,
    pnl.total_inflow,
    pnl.total_outflow,
    pnl.net_cash,
    SUM(pnl.net_cash) OVER (
        ORDER BY pnl.month_key
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_net_cash
FROM (
    SELECT
        m.month_key,
        SUM(m.inflow)  AS total_inflow,
        SUM(m.outflow) AS total_outflow,
        SUM(m.inflow) - SUM(m.outflow) AS net_cash
    FROM (
        SELECT DATE_FORMAT(d.donation_date, '%Y-%m') AS month_key,
               d.amount AS inflow, 0 AS outflow
          FROM donations d
         WHERE d.org_id = @org_id AND d.donation_type = 'cash'
        UNION ALL
        SELECT DATE_FORMAT(p.purchase_date, '%Y-%m'), 0, p.total_amount
          FROM purchases p WHERE p.org_id = @org_id
        UNION ALL
        SELECT DATE_FORMAT(e.expense_date, '%Y-%m'), 0, e.amount
          FROM expenses e WHERE e.org_id = @org_id
    ) m
    GROUP BY m.month_key
) pnl
ORDER BY pnl.month_key;

-- =====================================================================================
--  7. INDEXING OPTIMISATION WITH EXPLAIN ANALYZE
-- =====================================================================================
--  The composite B-Tree `ix_movements_org_created_at (org_id, created_at)` lets the
--  engine range-scan the tenant's time window instead of scanning every movement row.
--  The item filter additionally uses `ix_stock_movements_item_id (item_id)`.
--
--  Baseline (no composite index): type=ALL, rows = full table, high filtered %.
--  Optimised:                     type=range, rows ~ time window, using index condition.
-- -------------------------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT sm.item_id, SUM(sm.quantity_delta) AS net_movement
  FROM stock_movements sm
 WHERE sm.org_id = @org_id
   AND sm.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
 GROUP BY sm.item_id;

-- Force the optimizer to reveal the alternative plan (cost comparison for the viva)
EXPLAIN ANALYZE
SELECT STRAIGHT_JOIN sm.item_id, SUM(sm.quantity_delta) AS net_movement
  FROM stock_movements sm IGNORE INDEX (ix_movements_org_created_at)
 WHERE sm.org_id = @org_id
   AND sm.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
 GROUP BY sm.item_id;

-- Covering-index demonstration on the tenant catalog lookup
EXPLAIN ANALYZE
SELECT ii.id, ii.name, ii.category
  FROM inventory_items ii
 WHERE ii.org_id = @org_id AND ii.category = 'Medical Relief';

-- =====================================================================================
--  8. TCL — explicit transaction with SAVEPOINT and partial rollback
--     Scenario from Pillar 5: record an in-kind donation header, try to restock,
--     and if the restock is invalid keep the donation but discard only the restock.
-- =====================================================================================
START TRANSACTION;

    INSERT INTO donations (
        org_id, donor_name, donation_type, amount, item_id, quantity,
        declared_value, purpose, receipt_no, donation_date, recorded_by, created_at
    ) VALUES (
        @org_id, 'Savepoint Demo Trust', 'goods', 0.00, 1, 25.00,
        3000.00, 'Viva demonstration of partial rollback', 'DON-SAVEPOINT-DEMO', CURDATE(), 1, NOW()
    );
    SET @demo_donation_id = LAST_INSERT_ID();

    INSERT INTO in_kind_donations (
        donation_id, item_id, quantity_donated, unit_fair_value,
        storage_requirement, condition_grade
    ) VALUES (@demo_donation_id, 1, 25.00, 120.00, 'AMBIENT', 'NEW');

    SAVEPOINT sp_before_restock;

    -- Deliberately invalid: -999999 units would drive stock negative
    INSERT INTO stock_movements (
        org_id, item_id, movement_type, quantity_delta, unit_value, total_value,
        reference_type, note, actor_user_id, created_at
    ) VALUES (
        @org_id, 1, 'ADJUSTMENT', -999999, 0.00, 0.00,
        'savepoint_demo', 'This row must never survive', 1, NOW()
    );

    -- If control reaches here the guard did not fire; discard only the bad leg
    ROLLBACK TO SAVEPOINT sp_before_restock;

COMMIT;   -- donation header + subclass row survive, the bad movement does not

-- Verify the partial rollback
SELECT d.id, d.receipt_no, d.donation_type, ik.quantity_donated
  FROM donations d
  JOIN in_kind_donations ik ON ik.donation_id = d.id
 WHERE d.receipt_no = 'DON-SAVEPOINT-DEMO';

-- Clean up the demonstration rows (children cascade from the superclass)
DELETE FROM donations WHERE receipt_no = 'DON-SAVEPOINT-DEMO';

-- =====================================================================================
--  9. CONCURRENCY CONTROL — lost-update prevention with SELECT ... FOR UPDATE
-- =====================================================================================
--  Session A                                   | Session B
--  --------------------------------------------|------------------------------------------
--  START TRANSACTION;                          | START TRANSACTION;
--  SELECT quantity_on_hand INTO @q             | SELECT quantity_on_hand INTO @q
--    FROM inventory_items                      |   FROM inventory_items
--   WHERE id = 1 FOR UPDATE;   -- X-Lock held   |  WHERE id = 1 FOR UPDATE;  -- BLOCKS
--  UPDATE inventory_items SET qty = qty - 30;  |  -- waits on row lock
--  COMMIT;                                     |  -- lock released, B reads 10
--                                              |  -- B's 30-unit dispatch fails
--
--  Without FOR UPDATE both sessions read 40 and both write 10: 60 units dispatched
--  from a 40-unit balance (the classic lost update).
-- -------------------------------------------------------------------------------------
START TRANSACTION;
    SELECT quantity_on_hand INTO @locked_qty
      FROM inventory_items
     WHERE id = 1 AND org_id = @org_id
       FOR UPDATE;
    SELECT @locked_qty AS locked_quantity_visible_to_this_session;
ROLLBACK;

-- The procedure form used by the application (atomic, with OUT parameters)
-- CALL sp_dispatch_relief_aid(@org_id, 1, 5.00, 1, 'Demo Camp 4', @status, @remaining);
-- SELECT @status AS dispatch_status, @remaining AS remaining_stock;

-- Cursor sweep of expired batches
-- CALL sp_sweep_expired_batches(@org_id, @archived);
-- SELECT @archived AS archived_items;
