"""Pillars 3 & 4 — analytical SQL executed through the application.

Every query is written to be portable between MySQL 8 (production capstone demo)
and SQLite 3.35+ (offline/test engine), so the Analytics screen works either way:

* window functions  -> ``SUM() OVER``, ``DENSE_RANK()``, ``LAG()``/``LEAD()``
* set operations    -> ``UNION ALL`` consolidated cash flow
* anti-join         -> dead stock detector with a correlated subquery
* views            -> ``v_inventory_health_summary`` / ``v_monthly_financial_pnl``
                      equivalents, computed with the same rules at query time

The canonical MySQL view/procedure definitions live in ``backend/sql/*.sql``.
"""
from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

from sqlalchemy import text
from sqlalchemy.orm import Session


def _rows(db: Session, sql: str, params: Dict[str, Any]) -> List[Dict[str, Any]]:
    return [dict(row) for row in db.execute(text(sql), params).mappings().all()]


# -------------------------------------------------------------------------------------
# Pillar 4.1 — inventory health view (status, expiry, valuation, urgency score)
# -------------------------------------------------------------------------------------
def inventory_health(db: Session, org_id: int) -> List[Dict[str, Any]]:
    today = date.today().isoformat()
    expiry_window = (date.today() + timedelta(days=30)).isoformat()

    sql = """
        SELECT
            ii.id AS item_id,
            ii.sku,
            ii.name AS item_name,
            ii.category,
            ii.unit,
            ii.quantity_on_hand,
            ii.reorder_level,
            ii.unit_cost,
            ii.expiry_date,
            CASE
                WHEN ii.quantity_on_hand <= 0 THEN 'CRITICAL'
                WHEN ii.quantity_on_hand <= ii.reorder_level THEN 'LOW'
                ELSE 'IN_STOCK'
            END AS stock_status,
            CASE
                WHEN ii.expiry_date IS NULL THEN 'NONE'
                WHEN ii.expiry_date < :today THEN 'EXPIRED'
                WHEN ii.expiry_date <= :expiry_window THEN 'EXPIRING_30D'
                ELSE 'OK'
            END AS expiry_status,
            ROUND(ii.quantity_on_hand * ii.unit_cost, 2) AS stock_value,
            CASE
                WHEN ii.quantity_on_hand <= 0 THEN 0
                WHEN ii.expiry_date IS NOT NULL AND ii.expiry_date < :today THEN 0
                ELSE
                    -- 100 - (40 low-stock) - (35 expiring) never drops below 25,
                    -- so plain arithmetic is equivalent to GREATEST(0, x)
                    -- and stays portable across MySQL and SQLite.
                    100
                    - CASE WHEN ii.quantity_on_hand <= ii.reorder_level THEN 40 ELSE 0 END
                    - CASE
                        WHEN ii.expiry_date IS NOT NULL AND ii.expiry_date <= :expiry_window THEN 35
                        ELSE 0
                      END
            END AS urgency_score
        FROM inventory_items ii
        WHERE ii.org_id = :org_id
          AND ii.is_archived = 0
        ORDER BY urgency_score ASC, ii.name
    """
    return _rows(db, sql, {"org_id": org_id, "today": today, "expiry_window": expiry_window})


# -------------------------------------------------------------------------------------
# Pillar 3.1 — running cumulative balance per item (window function)
# -------------------------------------------------------------------------------------
def stock_velocity(
    db: Session,
    org_id: int,
    item_id: Optional[int] = None,
    limit: int = 100,
) -> List[Dict[str, Any]]:
    filters = ["sm.org_id = :org_id"]
    params: Dict[str, Any] = {"org_id": org_id, "limit": limit}
    if item_id:
        filters.append("sm.item_id = :item_id")
        params["item_id"] = item_id

    sql = f"""
        SELECT
            sm.id AS movement_id,
            sm.created_at,
            sm.item_id,
            ii.name AS item_name,
            ii.sku,
            sm.movement_type,
            sm.quantity_delta,
            SUM(sm.quantity_delta) OVER (
                PARTITION BY sm.item_id
                ORDER BY sm.created_at, sm.id
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS running_balance,
            LAG(sm.quantity_delta) OVER (
                PARTITION BY sm.item_id
                ORDER BY sm.created_at, sm.id
            ) AS previous_delta,
            LEAD(sm.quantity_delta) OVER (
                PARTITION BY sm.item_id
                ORDER BY sm.created_at, sm.id
            ) AS next_delta
        FROM stock_movements sm
        JOIN inventory_items ii ON sm.item_id = ii.id
        WHERE {' AND '.join(filters)}
        ORDER BY sm.created_at DESC, sm.id DESC
        LIMIT :limit
    """
    return _rows(db, sql, params)


# -------------------------------------------------------------------------------------
# Pillar 3.2 — DENSE_RANK top-N fastest movers per category
# -------------------------------------------------------------------------------------
def category_velocity(
    db: Session,
    org_id: int,
    days: int = 30,
    top_n: int = 3,
) -> List[Dict[str, Any]]:
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)

    sql = """
        WITH category_outflows AS (
            SELECT
                ii.category,
                ii.id AS item_id,
                ii.name AS item_name,
                COALESCE(ABS(SUM(sm.quantity_delta)), 0) AS total_outflow
            FROM inventory_items ii
            LEFT JOIN stock_movements sm
                   ON ii.id = sm.item_id
                  AND sm.quantity_delta < 0
                  AND sm.created_at >= :cutoff
            WHERE ii.org_id = :org_id
              AND ii.is_archived = 0
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
        SELECT category, item_id, item_name, total_outflow, category_velocity_rank
        FROM ranked
        WHERE category_velocity_rank <= :top_n
        ORDER BY category, category_velocity_rank
    """
    return _rows(db, sql, {"org_id": org_id, "cutoff": cutoff, "top_n": top_n})


# -------------------------------------------------------------------------------------
# Pillar 3.3 — consolidated cash flow (UNION ALL set operation)
# -------------------------------------------------------------------------------------
def cash_flow(db: Session, org_id: int, limit: int = 200) -> List[Dict[str, Any]]:
    sql = """
        SELECT * FROM (
            SELECT
                'INFLOW: Cash Donation' AS transaction_type,
                d.receipt_no AS voucher_ref,
                d.donor_name AS counterparty,
                COALESCE(cd.payment_mode, 'CASH') AS payment_channel,
                d.amount AS amount,
                d.donation_date AS txn_date,
                'INFLOW' AS direction
            FROM donations d
            LEFT JOIN cash_donations cd ON d.id = cd.donation_id
            WHERE d.org_id = :org_id
              AND d.donation_type = 'cash'

            UNION ALL

            SELECT
                'OUTFLOW: Supplier Purchase' AS transaction_type,
                p.invoice_no AS voucher_ref,
                p.supplier_name AS counterparty,
                p.payment_status AS payment_channel,
                p.total_amount AS amount,
                p.purchase_date AS txn_date,
                'OUTFLOW' AS direction
            FROM purchases p
            WHERE p.org_id = :org_id

            UNION ALL

            SELECT
                'OUTFLOW: Expense' AS transaction_type,
                COALESCE(e.receipt_no, 'VOUCHER-N/A') AS voucher_ref,
                e.description AS counterparty,
                e.category AS payment_channel,
                e.amount AS amount,
                e.expense_date AS txn_date,
                'OUTFLOW' AS direction
            FROM expenses e
            WHERE e.org_id = :org_id
        ) cf
        ORDER BY cf.txn_date DESC, cf.voucher_ref
        LIMIT :limit
    """
    return _rows(db, sql, {"org_id": org_id, "limit": limit})


# -------------------------------------------------------------------------------------
# Pillar 3.4 — dead stock: left anti-join + correlated average subquery
# -------------------------------------------------------------------------------------
def dead_stock(db: Session, org_id: int, days: int = 60) -> List[Dict[str, Any]]:
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)

    sql = """
        SELECT
            ii.id AS item_id,
            ii.name AS item_name,
            ii.sku,
            ii.category,
            ii.quantity_on_hand,
            ii.unit_cost,
            ROUND(ii.quantity_on_hand * ii.unit_cost, 2) AS locked_capital
        FROM inventory_items ii
        LEFT JOIN stock_movements sm
               ON ii.id = sm.item_id
              AND sm.created_at >= :cutoff
        WHERE ii.org_id = :org_id
          AND ii.is_archived = 0
          AND sm.id IS NULL
          AND ii.quantity_on_hand > (
                SELECT AVG(sub.quantity_on_hand)
                  FROM inventory_items sub
                 WHERE sub.category = ii.category
                   AND sub.org_id = ii.org_id
                   AND sub.is_archived = 0
              )
        ORDER BY locked_capital DESC
    """
    return _rows(db, sql, {"org_id": org_id, "cutoff": cutoff})


# -------------------------------------------------------------------------------------
# Pillar 4.2 — monthly P&L with cumulative net cash (view + window function)
# -------------------------------------------------------------------------------------
def monthly_pnl(db: Session, org_id: int) -> List[Dict[str, Any]]:
    sql = """
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
                m.month_key AS month_key,
                SUM(m.inflow) AS total_inflow,
                SUM(m.outflow) AS total_outflow,
                SUM(m.inflow) - SUM(m.outflow) AS net_cash
            FROM (
                SELECT SUBSTR(CAST(d.donation_date AS CHAR), 1, 7) AS month_key,
                       d.amount AS inflow,
                       0 AS outflow
                  FROM donations d
                 WHERE d.org_id = :org_id AND d.donation_type = 'cash'

                UNION ALL

                SELECT SUBSTR(CAST(p.purchase_date AS CHAR), 1, 7),
                       0,
                       p.total_amount
                  FROM purchases p
                 WHERE p.org_id = :org_id

                UNION ALL

                SELECT SUBSTR(CAST(e.expense_date AS CHAR), 1, 7),
                       0,
                       e.amount
                  FROM expenses e
                 WHERE e.org_id = :org_id
            ) m
            GROUP BY m.month_key
        ) pnl
        ORDER BY pnl.month_key
    """
    return _rows(db, sql, {"org_id": org_id})


def cash_flow_totals(db: Session, org_id: int) -> Dict[str, Any]:
    sql = """
        SELECT cf.direction, SUM(cf.amount) AS total_amount
        FROM (
            SELECT 'INFLOW' AS direction, d.amount AS amount
              FROM donations d
             WHERE d.org_id = :org_id AND d.donation_type = 'cash'
            UNION ALL
            SELECT 'OUTFLOW', p.total_amount FROM purchases p WHERE p.org_id = :org_id
            UNION ALL
            SELECT 'OUTFLOW', e.amount FROM expenses e WHERE e.org_id = :org_id
        ) cf
        GROUP BY cf.direction
    """
    rows = _rows(db, sql, {"org_id": org_id})
    totals = {str(r["direction"]).lower(): r["total_amount"] for r in rows}
    inflow = totals.get("inflow") or 0
    outflow = totals.get("outflow") or 0
    try:
        net = inflow - outflow
    except TypeError:  # pragma: no cover - defensive
        net = 0
    return {"inflow": inflow, "outflow": outflow, "net": net}


# -------------------------------------------------------------------------------------
# Pillar 1.2 — aggregation: warehouse distribution (EER aggregation entity)
# -------------------------------------------------------------------------------------
def warehouse_distribution(db: Session, org_id: int) -> List[Dict[str, Any]]:
    sql = """
        SELECT
            w.id AS warehouse_id,
            w.warehouse_code,
            w.name AS warehouse_name,
            w.city,
            w.capacity_sqft,
            w.is_active,
            COUNT(ws.id) AS stocked_item_count,
            COALESCE(SUM(ws.quantity_stored), 0) AS total_units_stored,
            COALESCE(ROUND(SUM(ws.quantity_stored * ii.unit_cost), 2), 0) AS stored_asset_value
        FROM warehouses w
        LEFT JOIN warehouse_stock ws ON ws.warehouse_id = w.id
        LEFT JOIN inventory_items ii ON ii.id = ws.item_id
        WHERE w.org_id = :org_id
        GROUP BY w.id, w.warehouse_code, w.name, w.city, w.capacity_sqft, w.is_active
        ORDER BY w.warehouse_code
    """
    return _rows(db, sql, {"org_id": org_id})


def donation_specialization_breakdown(db: Session, org_id: int) -> List[Dict[str, Any]]:
    """EER proof: count/value of each donation subclass through its own relation."""
    sql = """
        SELECT 'CASH' AS donation_class,
               COUNT(cd.donation_id) AS donation_count,
               COALESCE(SUM(d.declared_value), 0) AS declared_value,
               COUNT(CASE WHEN cd.is_tax_exempt_80g = 1 THEN 1 END) AS tax_exempt_count
          FROM cash_donations cd
          JOIN donations d ON d.id = cd.donation_id
         WHERE d.org_id = :org_id

        UNION ALL

        SELECT 'GOODS' AS donation_class,
               COUNT(ik.donation_id) AS donation_count,
               COALESCE(SUM(d.declared_value), 0) AS declared_value,
               0 AS tax_exempt_count
          FROM in_kind_donations ik
          JOIN donations d ON d.id = ik.donation_id
         WHERE d.org_id = :org_id
    """
    return _rows(db, sql, {"org_id": org_id})
