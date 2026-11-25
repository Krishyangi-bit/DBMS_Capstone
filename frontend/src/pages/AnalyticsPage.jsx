import { useCallback, useEffect, useMemo, useState } from "react";
import {
  Database,
  RefreshCw,
  Sigma,
  Layers,
  Network,
  Table2,
  CheckCircle2,
  XCircle,
  TrendingDown,
  ArrowDownRight,
  ArrowUpRight,
  Coins,
  ChevronDown,
  ChevronUp,
  Code2,
  Play,
  Check,
  ShieldCheck,
  Terminal,
} from "lucide-react";
import { api } from "../lib/api";
import { useAuth } from "../features/auth/useAuth";
import { formatCurrency, formatNumber, formatDate } from "../lib/format";
import Card from "../components/ui/Card";
import Badge from "../components/ui/Badge";
import Button from "../components/ui/Button";

function DataTable({ columns, rows, emptyMessage = "No rows returned by this query.", maxHeight = "" }) {
  return (
    <div className={`overflow-auto ${maxHeight}`}>
      <table className="w-full text-left text-xs">
        <thead>
          <tr className="border-b border-[var(--border-subtle)] bg-[var(--bg-surface)]/60 text-[10px] font-semibold uppercase tracking-wider text-[var(--text-dim)]">
            {columns.map((col) => (
              <th
                key={col.key}
                className={`py-2.5 px-3 whitespace-nowrap ${col.align === "right" ? "text-right" : ""}`}
              >
                {col.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-[var(--border-subtle)]">
          {rows.length === 0 ? (
            <tr>
              <td colSpan={columns.length} className="py-8 text-center text-[var(--text-dim)]">
                {emptyMessage}
              </td>
            </tr>
          ) : (
            rows.map((row, idx) => (
              <tr key={row.id ?? row.item_id ?? idx} className="hover:bg-[var(--row-hover)]">
                {columns.map((col) => (
                  <td
                    key={col.key}
                    className={`py-2.5 px-3 ${col.align === "right" ? "text-right tabular-nums" : ""} ${
                      col.className || "text-[var(--text-secondary)]"
                    }`}
                  >
                    {col.render ? col.render(row) : row[col.key] ?? "—"}
                  </td>
                ))}
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  );
}

function SectionHeader({ icon: Icon, title, caption, query }) {
  const [copied, setCopied] = useState(false);

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(query);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      setCopied(false);
    }
  };

  return (
    <div className="flex flex-wrap items-start justify-between gap-3 pb-3 border-b border-[var(--border-subtle)]">
      <div className="flex items-start gap-2.5">
        <div className="p-2 rounded-lg bg-[var(--accent-soft)] text-[var(--accent)]">
          <Icon className="w-4 h-4" />
        </div>
        <div>
          <h2 className="text-sm font-extrabold text-[var(--text-primary)]">{title}</h2>
          <p className="text-[11px] text-[var(--text-muted)] mt-0.5 max-w-2xl leading-snug">{caption}</p>
        </div>
      </div>
      {query && (
        <button
          type="button"
          onClick={copy}
          className="text-[10.5px] font-bold uppercase tracking-wider px-2.5 py-1 rounded-lg border border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--text-muted)] hover:text-[var(--text-primary)] cursor-pointer"
          title={query}
        >
          {copied ? "SQL copied" : "Copy SQL"}
        </button>
      )}
    </div>
  );
}

const urgencyBadge = (score) => {
  const value = Number(score ?? 0);
  if (value <= 0) return "danger";
  if (value <= 60) return "warning";
  return "success";
};

const STORED_PROGRAM_DATA = [
  {
    name: "trg_before_stock_movement_insert",
    object_type: "TRIGGER",
    topic: "Engine-Level Domain Constraints & Non-Negative Stock Enforcement",
    description: "Evaluates BEFORE INSERT on stock_movements. If quantity_delta < 0 would drive inventory_items.quantity_on_hand negative, the trigger aborts the transaction via SIGNAL SQLSTATE '45000'.",
    sql: `-- BEFORE INSERT Trigger: Enforces Non-Negative Stock
DELIMITER //
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
DELIMITER ;`
  },
  {
    name: "trg_after_stock_movement_insert",
    object_type: "TRIGGER",
    topic: "Automated Ledger & Immutable Audit Trail Synchronization",
    description: "Evaluates AFTER INSERT on stock_movements. Atomically applies quantity_delta to inventory_items and inserts a tamper-evident audit record into activity_logs without web app intervention.",
    sql: `-- AFTER INSERT Trigger: Auto-Stock & Audit Log Sync
DELIMITER //
CREATE TRIGGER trg_after_stock_movement_insert
AFTER INSERT ON stock_movements
FOR EACH ROW
BEGIN
    -- 1. Atomically move the physical balance
    UPDATE inventory_items
       SET quantity_on_hand = quantity_on_hand + NEW.quantity_delta,
           updated_at       = NOW()
     WHERE id = NEW.item_id;

    -- 2. Tamper-evident audit record generated by database engine
    INSERT INTO activity_logs (
        org_id, actor_user_id, action, entity_type, entity_id, summary, ip_address, created_at
    ) VALUES (
        NEW.org_id,
        NEW.actor_user_id,
        'STOCK_MUTATION',
        'inventory_items',
        NEW.item_id,
        CONCAT('Stock adjusted by ', NEW.quantity_delta, ' units (Type: ', NEW.movement_type, ', movement #', NEW.id, ')'),
        '127.0.0.1',
        NOW()
    );
END;
//
DELIMITER ;`
  },
  {
    name: "sp_dispatch_relief_aid",
    object_type: "PROCEDURE",
    topic: "ACID Concurrency Control & Pessimistic Row Locking (FOR UPDATE)",
    description: "Atomic multi-step relief dispatch procedure. Locks the inventory row with SELECT ... FOR UPDATE, sets a SAVEPOINT, inserts the movement, verifies stock balance, and commits or rolls back.",
    sql: `-- Stored Procedure: Atomic Aid Dispatch with Pessimistic Locking
DELIMITER //
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
            SAVEPOINT sv_before_movement;

            INSERT INTO stock_movements (
                org_id, item_id, movement_type, quantity_delta, unit_value, total_value,
                reference_type, note, actor_user_id, created_at
            ) VALUES (
                p_org_id, p_item_id, 'RELIEF', -p_dispatch_qty, 0.00, 0.00,
                'aid_distribution', p_destination, p_actor_id, NOW()
            );

            SET v_new_movement_id = LAST_INSERT_ID();

            SELECT quantity_on_hand INTO p_remaining_stock
              FROM inventory_items
             WHERE id = p_item_id;

            COMMIT;
            SET p_status = CONCAT('SUCCESS: Aid Dispatched (movement #', v_new_movement_id, ')');
        END IF;
    END IF;
END;
//
DELIMITER ;`
  },
  {
    name: "sp_sweep_expired_batches",
    object_type: "PROCEDURE",
    topic: "Explicit Cursor Processing (DECLARE, OPEN, FETCH, CLOSE)",
    description: "Sweeps the inventory for batches with expiry_date < CURDATE(). Uses an explicit cursor loop with CONTINUE HANDLER FOR NOT FOUND to automatically archive items and record disposal write-offs.",
    sql: `-- Stored Procedure: Cursor Sweep for Expired Batches
DELIMITER //
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
DELIMITER ;`
  },
  {
    name: "fn_compute_stock_urgency_score",
    object_type: "FUNCTION",
    topic: "Stored Functions & Reusable Deterministic Business Logic",
    description: "Computes a normalized health score (0-100) inside the engine. Penalizes items below safety reorder level (-40) and perishable batches expiring within 30 days (-35).",
    sql: `-- Stored Function: Dynamic Stock Urgency Scoring
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

    IF v_qty IS NULL OR v_qty <= 0 THEN
        SET v_score = 0;
    ELSEIF v_qty <= v_reorder THEN
        SET v_score = v_score - 40;
    END IF;

    IF v_expiry IS NOT NULL THEN
        IF v_expiry < CURDATE() THEN
            SET v_score = 0;
        ELSEIF DATEDIFF(v_expiry, CURDATE()) <= 30 THEN
            SET v_score = v_score - 35;
        END IF;
    END IF;

    RETURN GREATEST(0, v_score);
END;
//
DELIMITER ;`
  },
  {
    name: "v_inventory_health_summary",
    object_type: "VIEW",
    topic: "Database Views & Logical Data Independence",
    description: "Encapsulates inventory status (CRITICAL, LOW, IN_STOCK), expiry countdown risk, stock asset valuation, and urgency index so client applications never duplicate scoring queries.",
    sql: `-- View: Inventory Health Summary
CREATE OR REPLACE VIEW v_inventory_health_summary AS
SELECT
    ii.org_id,
    ii.id AS item_id,
    ii.sku,
    ii.name AS item_name,
    ii.category,
    ii.unit,
    ii.quantity_on_hand,
    ii.reorder_level,
    ii.unit_cost,
    ii.unit_price,
    ii.expiry_date,
    CASE
        WHEN ii.quantity_on_hand <= 0 THEN 'CRITICAL'
        WHEN ii.quantity_on_hand <= ii.reorder_level THEN 'LOW'
        ELSE 'IN_STOCK'
    END AS stock_status,
    ROUND(ii.quantity_on_hand * ii.unit_cost, 2) AS stock_value,
    fn_compute_stock_urgency_score(ii.id) AS urgency_score
FROM inventory_items ii
WHERE ii.is_archived = FALSE;`
  },
  {
    name: "v_monthly_financial_pnl",
    object_type: "VIEW",
    topic: "Views with Aggregations and UNION ALL Set Operations",
    description: "Aggregates cash inflows from donations against cash outflows from wholesale purchases and operating expenses, grouped by tenant and calendar month.",
    sql: `-- View: Monthly Financial Profit & Loss
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
        SUM(m.cash_inflow) AS cash_inflow,
        SUM(m.purchase_outflow) AS purchase_outflow,
        SUM(m.expense_outflow) AS expense_outflow
    FROM (
        SELECT org_id, DATE_FORMAT(donation_date, '%Y-%m') AS month_key, amount AS cash_inflow, 0 AS purchase_outflow, 0 AS expense_outflow FROM donations WHERE donation_type = 'cash'
        UNION ALL
        SELECT org_id, DATE_FORMAT(purchase_date, '%Y-%m'), 0, total_amount, 0 FROM purchases
        UNION ALL
        SELECT org_id, DATE_FORMAT(expense_date, '%Y-%m'), 0, 0, amount FROM expenses
    ) m GROUP BY m.org_id, m.month_key
) pnl;`
  },
  {
    name: "v_public_masked_catalog",
    object_type: "VIEW",
    topic: "Database Security & Dynamic Data Masking Projection",
    description: "Provides a public catalog projection that strips proprietary procurement costs, supplier margin figures, and internal donor notes for unauthenticated viewers.",
    sql: `-- View: Public Masked Catalog (DCL / Security Projection)
CREATE OR REPLACE VIEW v_public_masked_catalog AS
SELECT
    id,
    org_id,
    sku,
    name,
    category,
    unit,
    quantity_on_hand,
    unit_price,
    CASE WHEN quantity_on_hand > 0 THEN 'AVAILABLE' ELSE 'OUT_OF_STOCK' END AS availability
FROM inventory_items
WHERE is_archived = FALSE;`
  }
];

export default function AnalyticsPage({ showToast = () => {} }) {
  const { organization, isAuthenticated, guestOrgType } = useAuth();
  const orgType = isAuthenticated ? organization?.type || "ngo" : guestOrgType || "ngo";
  const currency = organization?.currency || "INR";

  const [activeTab, setActiveTab] = useState("window");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [health, setHealth] = useState([]);
  const [velocity, setVelocity] = useState([]);
  const [categories, setCategories] = useState([]);
  const [cashFlow, setCashFlow] = useState({ transactions: [], totals: {} });
  const [deadStock, setDeadStock] = useState([]);
  const [pnl, setPnl] = useState([]);
  const [warehouses, setWarehouses] = useState([]);
  const [donationClasses, setDonationClasses] = useState([]);
  const [programs, setPrograms] = useState(null);

  // Stored programs interactive view state
  const [expandedProgram, setExpandedProgram] = useState(null);
  const [copiedProgram, setCopiedProgram] = useState("");
  const [dispatchItemId, setDispatchItemId] = useState("1");
  const [dispatchQty, setDispatchQty] = useState("5");
  const [dispatchDest, setDispatchDest] = useState("Sector 4 Relief Camp");
  const [dispatchResult, setDispatchResult] = useState(null);
  const [dispatchLoading, setDispatchLoading] = useState(false);

  const fetchData = useCallback(
    async (showLoading = true) => {
      if (showLoading) setLoading(true);
      setError("");
      try {
        const [
          healthRes,
          velocityRes,
          categoriesRes,
          cashFlowRes,
          deadRes,
          pnlRes,
          warehouseRes,
          donationRes,
          programRes,
        ] = await Promise.all([
          api.analytics.getInventoryHealth(orgType).catch(() => []),
          api.analytics.getStockVelocity(orgType, 120).catch(() => []),
          api.analytics.getCategoryVelocity(orgType).catch(() => []),
          api.analytics.getCashFlow(orgType).catch(() => ({ transactions: [], totals: {} })),
          api.analytics.getDeadStock(orgType).catch(() => []),
          api.analytics.getPnl(orgType).catch(() => []),
          api.analytics.getWarehouses(orgType).catch(() => []),
          api.analytics.getDonationSpecialization(orgType).catch(() => []),
          api.analytics.getDbPrograms().catch(() => null),
        ]);

        setHealth(Array.isArray(healthRes) ? healthRes : []);
        setVelocity(Array.isArray(velocityRes) ? velocityRes : []);
        setCategories(Array.isArray(categoriesRes) ? categoriesRes : []);
        setCashFlow(cashFlowRes || { transactions: [], totals: {} });
        setDeadStock(Array.isArray(deadRes) ? deadRes : []);
        setPnl(Array.isArray(pnlRes) ? pnlRes : []);
        setWarehouses(Array.isArray(warehouseRes) ? warehouseRes : []);
        setDonationClasses(Array.isArray(donationRes) ? donationRes : []);
        setPrograms(programRes);
      } catch (err) {
        setError(err.message || "Unable to execute the analytical query suite.");
        showToast(err.message || "Unable to load analytics.", "error");
      } finally {
        setLoading(false);
      }
    },
    [orgType, showToast]
  );

  useEffect(() => {
    (async () => {
      await fetchData(false);
    })();
  }, [fetchData]);

  const loadAll = useCallback(() => {
    fetchData(true);
  }, [fetchData]);

  const installedPrograms = useMemo(
    () => (programs?.programs || []).filter((p) => p.installed).length,
    [programs]
  );

  const velocityColumns = [
    {
      key: "created_at",
      label: "Timestamp",
      render: (r) => (
        <span className="text-[var(--text-muted)] whitespace-nowrap">{formatDate(r.created_at, true)}</span>
      ),
    },
    {
      key: "item_name",
      label: "Item",
      render: (r) => (
        <div>
          <div className="font-bold text-[var(--text-primary)]">{r.item_name}</div>
          <div className="text-[10px] font-mono text-[var(--text-dim)]">{r.sku}</div>
        </div>
      ),
    },
    {
      key: "movement_type",
      label: "Type",
      render: (r) => (
        <Badge variant={r.movement_type === "RESTOCK" ? "success" : "neutral"} size="sm">
          {r.movement_type}
        </Badge>
      ),
    },
    {
      key: "previous_delta",
      label: "LAG (prev)",
      align: "right",
      render: (r) => (r.previous_delta === null ? "—" : formatNumber(Number(r.previous_delta), 2)),
    },
    {
      key: "quantity_delta",
      label: "Delta",
      align: "right",
      render: (r) => (
        <span
          className={
            Number(r.quantity_delta) >= 0
              ? "font-bold text-emerald-600 dark:text-emerald-400"
              : "font-bold text-rose-600 dark:text-rose-400"
          }
        >
          {Number(r.quantity_delta) > 0 ? "+" : ""}
          {formatNumber(Number(r.quantity_delta), 2)}
        </span>
      ),
    },
    {
      key: "running_balance",
      label: "Running balance",
      align: "right",
      render: (r) => (
        <span className="font-extrabold text-[var(--text-primary)]">
          {formatNumber(Number(r.running_balance), 2)}
        </span>
      ),
    },
  ];

  const categoryColumns = [
    {
      key: "category_velocity_rank",
      label: "Rank",
      render: (r) => (
        <Badge variant={Number(r.category_velocity_rank) === 1 ? "primary" : "neutral"} size="sm">
          #{r.category_velocity_rank}
        </Badge>
      ),
    },
    { key: "category", label: "Category" },
    {
      key: "item_name",
      label: "Item",
      render: (r) => <span className="font-semibold text-[var(--text-primary)]">{r.item_name}</span>,
    },
    {
      key: "total_outflow",
      label: "30-day outflow",
      align: "right",
      render: (r) => formatNumber(Number(r.total_outflow), 2),
    },
  ];

  const cashFlowColumns = [
    {
      key: "transaction_type",
      label: "Transaction",
      render: (r) => (
        <Badge variant={r.direction === "INFLOW" ? "success" : "danger"} size="sm">
          {r.transaction_type}
        </Badge>
      ),
    },
    {
      key: "voucher_ref",
      label: "Voucher",
      render: (r) => <span className="font-mono text-[11px]">{r.voucher_ref}</span>,
    },
    { key: "counterparty", label: "Counterparty" },
    { key: "payment_channel", label: "Channel" },
    {
      key: "amount",
      label: "Amount",
      align: "right",
      render: (r) => (
        <span
          className={
            r.direction === "INFLOW"
              ? "font-bold text-emerald-600 dark:text-emerald-400"
              : "font-bold text-rose-600 dark:text-rose-400"
          }
        >
          {r.direction === "INFLOW" ? "+" : "−"}
          {formatCurrency(Number(r.amount), currency)}
        </span>
      ),
    },
    {
      key: "txn_date",
      label: "Date",
      align: "right",
      render: (r) => <span className="whitespace-nowrap">{formatDate(r.txn_date)}</span>,
    },
  ];

  const deadStockColumns = [
    {
      key: "item_name",
      label: "Item",
      render: (r) => (
        <div>
          <div className="font-bold text-[var(--text-primary)]">{r.item_name}</div>
          <div className="text-[10px] font-mono text-[var(--text-dim)]">{r.sku}</div>
        </div>
      ),
    },
    { key: "category", label: "Category" },
    {
      key: "quantity_on_hand",
      label: "On hand",
      align: "right",
      render: (r) => formatNumber(Number(r.quantity_on_hand), 2),
    },
    {
      key: "locked_capital",
      label: "Locked capital",
      align: "right",
      render: (r) => formatCurrency(Number(r.locked_capital), currency),
    },
  ];

  const healthColumns = [
    {
      key: "item_name",
      label: "Item",
      render: (r) => (
        <div>
          <div className="font-bold text-[var(--text-primary)]">{r.item_name}</div>
          <div className="text-[10px] font-mono text-[var(--text-dim)]">{r.sku}</div>
        </div>
      ),
    },
    { key: "category", label: "Category" },
    {
      key: "quantity_on_hand",
      label: "On hand",
      align: "right",
      render: (r) => formatNumber(Number(r.quantity_on_hand), 2),
    },
    {
      key: "stock_status",
      label: "Status",
      render: (r) => (
        <Badge
          variant={r.stock_status === "CRITICAL" ? "danger" : r.stock_status === "LOW" ? "warning" : "success"}
          size="sm"
        >
          {r.stock_status}
        </Badge>
      ),
    },
    {
      key: "expiry_status",
      label: "Shelf life",
      render: (r) => (
        <span className="text-[11px] text-[var(--text-muted)]">{r.expiry_status}</span>
      ),
    },
    {
      key: "stock_value",
      label: "Valuation",
      align: "right",
      render: (r) => formatCurrency(Number(r.stock_value), currency),
    },
    {
      key: "urgency_score",
      label: "Urgency",
      align: "right",
      render: (r) => (
        <Badge variant={urgencyBadge(r.urgency_score)} size="sm">
          {r.urgency_score}/100
        </Badge>
      ),
    },
  ];

  const pnlColumns = [
    { key: "month_key", label: "Month", render: (r) => <span className="font-mono">{r.month_key}</span> },
    {
      key: "total_inflow",
      label: "Inflow",
      align: "right",
      render: (r) => formatCurrency(Number(r.total_inflow), currency),
    },
    {
      key: "total_outflow",
      label: "Outflow",
      align: "right",
      render: (r) => formatCurrency(Number(r.total_outflow), currency),
    },
    {
      key: "net_cash",
      label: "Net",
      align: "right",
      render: (r) => (
        <span className={Number(r.net_cash) >= 0 ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"}>
          {formatCurrency(Number(r.net_cash), currency)}
        </span>
      ),
    },
    {
      key: "cumulative_net_cash",
      label: "Cumulative",
      align: "right",
      render: (r) => (
        <span className="font-bold text-[var(--text-primary)]">
          {formatCurrency(Number(r.cumulative_net_cash), currency)}
        </span>
      ),
    },
  ];

  const warehouseColumns = [
    { key: "warehouse_code", label: "Code", render: (r) => <span className="font-mono">{r.warehouse_code}</span> },
    {
      key: "warehouse_name",
      label: "Facility",
      render: (r) => (
        <div>
          <div className="font-bold text-[var(--text-primary)]">{r.warehouse_name}</div>
          <div className="text-[10px] text-[var(--text-dim)]">{r.city}</div>
        </div>
      ),
    },
    { key: "stocked_item_count", label: "SKUs", align: "right" },
    {
      key: "total_units_stored",
      label: "Units stored",
      align: "right",
      render: (r) => formatNumber(Number(r.total_units_stored), 2),
    },
    {
      key: "stored_asset_value",
      label: "Stored value",
      align: "right",
      render: (r) => formatCurrency(Number(r.stored_asset_value), currency),
    },
    {
      key: "is_active",
      label: "State",
      render: (r) => (
        <Badge variant={r.is_active ? "success" : "neutral"} size="sm">
          {r.is_active ? "ACTIVE" : "INACTIVE"}
        </Badge>
      ),
    },
  ];

  const totals = cashFlow?.totals || {};

  const tabs = [
    { id: "window", label: "Window Functions", icon: Sigma },
    { id: "sets", label: "Set Operations & Joins", icon: Network },
    { id: "views", label: "Views & Health", icon: Table2 },
    { id: "programs", label: "DB Programs", icon: Database },
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-2 border-b border-[var(--border-subtle)]">
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <h1 className="text-xl sm:text-2xl font-extrabold tracking-tight text-[var(--text-primary)] flex items-center gap-2">
              <Database className="w-6 h-6 text-[var(--accent)]" />
              <span>Database Analytics Engine</span>
            </h1>
            <Badge variant="primary" size="sm">
              DBMS Capstone
            </Badge>
          </div>
          <p className="text-xs sm:text-sm text-[var(--text-muted)]">
            Window functions, set operations, anti-joins, indexed views and engine-native stored programs
          </p>
        </div>

        <Button variant="secondary" size="sm" onClick={loadAll} disabled={loading}>
          <RefreshCw className={`w-3.5 h-3.5 mr-1 ${loading ? "animate-spin text-[var(--accent)]" : ""}`} />
          <span>Re-run queries</span>
        </Button>
      </div>

      {error && (
        <div className="p-3 rounded-xl border border-rose-300/50 bg-rose-500/10 text-xs font-semibold text-rose-600 dark:text-rose-300">
          {error}
        </div>
      )}

      {programs && (
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <Card className="p-4">
            <p className="text-[10px] font-bold uppercase tracking-wider text-[var(--text-dim)]">Query Engine</p>
            <p className="text-lg font-extrabold text-[var(--text-primary)] mt-1 uppercase">
              {programs.engine}
            </p>
            <p className="text-[11px] text-[var(--text-muted)] mt-0.5">
              {programs.native_programs_supported
                ? "Stored programs executed by the engine"
                : "Portable SQL mode (SQLite)"}
            </p>
          </Card>

          <Card className="p-4">
            <p className="text-[10px] font-bold uppercase tracking-wider text-[var(--text-dim)]">Programs installed</p>
            <p className="text-lg font-extrabold text-[var(--text-primary)] mt-1">
              {installedPrograms}/{programs.expected_count}
            </p>
            <p className="text-[11px] text-[var(--text-muted)] mt-0.5">triggers · procedures · functions · views</p>
          </Card>

          <Card className="p-4">
            <p className="text-[10px] font-bold uppercase tracking-wider text-[var(--text-dim)]">Stock trigger authority</p>
            <p className="text-lg font-extrabold mt-1">
              {programs.native_movement_triggers_active ? (
                <span className="text-emerald-600 dark:text-emerald-400">DATABASE</span>
              ) : (
                <span className="text-amber-600 dark:text-amber-400">APPLICATION</span>
              )}
            </p>
            <p className="text-[11px] text-[var(--text-muted)] mt-0.5">
              Who owns quantity_on_hand and the audit row
            </p>
          </Card>
        </div>
      )}

      <div className="flex flex-wrap items-center gap-2 border-b border-[var(--border-subtle)] pb-2">
        {tabs.map((tab) => {
          const Icon = tab.icon;
          const active = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              type="button"
              onClick={() => setActiveTab(tab.id)}
              className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                active
                  ? "bg-[var(--accent-solid)] text-white shadow-[0_5px_16px_-5px_rgba(124,58,237,0.7)]"
                  : "text-[var(--text-secondary)] dark:text-[var(--text-dim)] hover:bg-[var(--row-hover)]"
              }`}
            >
              <Icon className="w-4 h-4" />
              <span>{tab.label}</span>
            </button>
          );
        })}
      </div>

      {activeTab === "window" && (
        <div className="space-y-6">
          <Card className="p-5">
            <SectionHeader
              icon={Sigma}
              title="Cumulative running stock balance"
              caption="SUM(quantity_delta) OVER (PARTITION BY item ORDER BY created_at ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) with LAG()/LEAD() for delivery velocity. GROUP BY would collapse the ledger; the window keeps every row."
              query="SUM(sm.quantity_delta) OVER (PARTITION BY sm.item_id ORDER BY sm.created_at, sm.id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_balance"
            />
            <div className="pt-3">
              <DataTable
                columns={velocityColumns}
                rows={velocity}
                emptyMessage="No stock movements recorded for this organization yet."
                maxHeight="max-h-[420px]"
              />
            </div>
          </Card>

          <Card className="p-5">
            <SectionHeader
              icon={Layers}
              title="Top-N fastest outflow items per category"
              caption="DENSE_RANK() OVER (PARTITION BY category ORDER BY total_outflow DESC) inside a CTE, filtered to rank ≤ 3. Ties share a rank instead of skipping numbers."
              query="DENSE_RANK() OVER (PARTITION BY category ORDER BY total_outflow DESC) AS category_velocity_rank"
            />
            <div className="pt-3">
              <DataTable
                columns={categoryColumns}
                rows={categories}
                emptyMessage="No outflow movements in the last 30 days."
              />
            </div>
          </Card>
        </div>
      )}

      {activeTab === "sets" && (
        <div className="space-y-6">
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <Card className="p-4">
              <div className="flex items-center justify-between">
                <p className="text-[10px] font-bold uppercase tracking-wider text-[var(--text-dim)]">Total inflow</p>
                <ArrowUpRight className="w-4 h-4 text-emerald-500" />
              </div>
              <p className="text-xl font-extrabold text-emerald-600 dark:text-emerald-400 mt-1 tabular-nums">
                {formatCurrency(Number(totals.inflow || 0), currency)}
              </p>
            </Card>
            <Card className="p-4">
              <div className="flex items-center justify-between">
                <p className="text-[10px] font-bold uppercase tracking-wider text-[var(--text-dim)]">Total outflow</p>
                <ArrowDownRight className="w-4 h-4 text-rose-500" />
              </div>
              <p className="text-xl font-extrabold text-rose-600 dark:text-rose-400 mt-1 tabular-nums">
                {formatCurrency(Number(totals.outflow || 0), currency)}
              </p>
            </Card>
            <Card className="p-4">
              <div className="flex items-center justify-between">
                <p className="text-[10px] font-bold uppercase tracking-wider text-[var(--text-dim)]">Net position</p>
                <Coins className="w-4 h-4 text-[var(--accent)]" />
              </div>
              <p className="text-xl font-extrabold text-[var(--text-primary)] mt-1 tabular-nums">
                {formatCurrency(Number(totals.net || 0), currency)}
              </p>
            </Card>
          </div>

          <Card className="p-5">
            <SectionHeader
              icon={Network}
              title="Consolidated cash flow (UNION ALL)"
              caption="Cash donations JOINed to their cash_donations subclass, supplier purchases and operating expenses merged with UNION ALL — duplicates are semantically meaningful here, so UNION would silently drop vouchers."
              query="SELECT ... FROM donations d JOIN cash_donations cd ON d.id = cd.donation_id UNION ALL SELECT ... FROM purchases UNION ALL SELECT ... FROM expenses"
            />
            <div className="pt-3">
              <DataTable
                columns={cashFlowColumns}
                rows={cashFlow?.transactions || []}
                emptyMessage="No financial vouchers recorded for this organization."
                maxHeight="max-h-[420px]"
              />
            </div>
          </Card>

          <Card className="p-5">
            <SectionHeader
              icon={TrendingDown}
              title="Dead stock detector (left anti-join + correlated subquery)"
              caption="Items with no movement in 60 days whose on-hand quantity exceeds the average for their own category. The subquery is correlated: it is re-evaluated per outer row and scoped to the same tenant."
              query="LEFT JOIN stock_movements sm ON ii.id = sm.item_id AND sm.created_at >= :cutoff WHERE sm.id IS NULL AND ii.quantity_on_hand > (SELECT AVG(sub.quantity_on_hand) FROM inventory_items sub WHERE sub.category = ii.category)"
            />
            <div className="pt-3">
              <DataTable
                columns={deadStockColumns}
                rows={deadStock}
                emptyMessage="No dead stock detected — every above-average item moved within 60 days."
              />
            </div>
          </Card>
        </div>
      )}

      {activeTab === "views" && (
        <div className="space-y-6">
          <Card className="p-5">
            <SectionHeader
              icon={Table2}
              title="v_inventory_health_summary"
              caption="Status, expiry risk, asset valuation and a 0–100 urgency score computed by the engine so no consumer re-implements the rule (mirrors fn_compute_stock_urgency_score)."
              query="SELECT stock_status, expiry_status, ROUND(quantity_on_hand * unit_cost, 2) AS stock_value FROM v_inventory_health_summary"
            />
            <div className="pt-3">
              <DataTable
                columns={healthColumns}
                rows={health}
                emptyMessage="No active catalog items."
                maxHeight="max-h-[420px]"
              />
            </div>
          </Card>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <Card className="p-5">
              <SectionHeader
                icon={Coins}
                title="v_monthly_financial_pnl"
                caption="Monthly inflow vs outflow with a cumulative net-cash window column."
                query="SELECT * FROM v_monthly_financial_pnl WHERE org_id = :org_id"
              />
              <div className="pt-3" />
              <DataTable columns={pnlColumns} rows={pnl} emptyMessage="No financial months recorded." />
            </Card>

            <Card className="p-5">
              <SectionHeader
                icon={Database}
                title="Warehouse aggregation (warehouse_stock)"
                caption="EER aggregation entity: stock only exists in the context of a (warehouse, item) pair, unique on (warehouse_id, item_id)."
                query="SELECT w.*, SUM(ws.quantity_stored) FROM warehouses w LEFT JOIN warehouse_stock ws ON ws.warehouse_id = w.id GROUP BY w.id"
              />
              <div className="pt-3" />
              <DataTable
                columns={warehouseColumns}
                rows={warehouses}
                emptyMessage="No facilities registered for this organization."
              />
            </Card>
          </div>

          <Card className="p-5">
            <SectionHeader
              icon={Layers}
              title="Donation specialization (d, t)"
              caption="Every donations row participates totally in exactly one subclass: cash_donations for money, in_kind_donations for goods. Counts below are read through each subclass relation."
            />
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-3">
              {donationClasses.length === 0 ? (
                <p className="text-xs text-[var(--text-dim)]">No donation subclass rows recorded.</p>
              ) : (
                donationClasses.map((row) => (
                  <div
                    key={row.donation_class}
                    className="rounded-xl border border-[var(--border-subtle)] bg-[var(--bg-surface)] p-4"
                  >
                    <div className="flex items-center justify-between">
                      <Badge variant={row.donation_class === "CASH" ? "success" : "info"} size="sm">
                        {row.donation_class === "CASH" ? "cash_donations" : "in_kind_donations"}
                      </Badge>
                      <span className="text-[11px] font-bold text-[var(--text-muted)]">
                        {row.donation_count} rows
                      </span>
                    </div>
                    <p className="text-lg font-extrabold text-[var(--text-primary)] mt-2 tabular-nums">
                      {formatCurrency(Number(row.declared_value), currency)}
                    </p>
                    <p className="text-[11px] text-[var(--text-muted)] mt-0.5">
                      {row.donation_class === "CASH"
                        ? `${row.tax_exempt_count} receipts flagged 80G`
                        : "Declared fair value of donated goods"}
                    </p>
                  </div>
                ))
              )}
            </div>
          </Card>
        </div>
      )}

      {activeTab === "programs" && (
        <Card className="p-5">
          <SectionHeader
            icon={Database}
            title="Engine-native stored programs"
            caption="Install with backend/sql/stored_programs.sql on MySQL 8. When the audit trigger is present the database owns the on-hand balance, so the service layer stops applying the delta in Python."
            query="mysql -u root -p resourceone < backend/sql/stored_programs.sql"
          />
          <div className="pt-4 space-y-2">
            {(programs?.programs || []).map((program) => (
              <div
                key={program.name}
                className="flex items-center justify-between gap-3 rounded-xl border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3.5 py-2.5"
              >
                <div className="flex items-center gap-2.5 min-w-0">
                  {program.installed ? (
                    <CheckCircle2 className="w-4 h-4 text-emerald-500 shrink-0" />
                  ) : (
                    <XCircle className="w-4 h-4 text-[var(--text-dim)] shrink-0" />
                  )}
                  <span className="font-mono text-[11.5px] text-[var(--text-primary)] truncate">
                    {program.name}
                  </span>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <Badge variant="neutral" size="sm">
                    {program.object_type}
                  </Badge>
                  <Badge variant={program.installed ? "success" : "warning"} size="sm">
                    {program.installed ? "INSTALLED" : "NOT INSTALLED"}
                  </Badge>
                </div>
              </div>
            ))}
            {!programs && (
              <p className="text-xs text-[var(--text-dim)]">
                Program introspection is unavailable because the backend is offline.
              </p>
            )}
            {programs?.error && (
              <p className="text-[11px] text-amber-600 dark:text-amber-400">{programs.error}</p>
            )}
            {programs && !programs.native_programs_supported && (
              <p className="text-[11px] text-[var(--text-muted)] pt-1">
                Running on {programs.engine}: the analytical queries above execute as portable SQL. Install the
                procedures, triggers and views on MySQL 8 to satisfy the stored-program pillar.
              </p>
            )}
          </div>
        </Card>
      )}
    </div>
  );
}
