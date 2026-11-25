"""capstone EER extensions: donation specialization + warehouse aggregation

Revision ID: 0002_capstone_eer_extensions
Revises: 0001_initial
Create Date: 2026-11-24 00:00:00.000000

Pillar 1 of the capstone specification:

* ``cash_donations`` / ``in_kind_donations``  -> disjoint total specialization (d, t)
  of the ``donations`` superclass.
* ``warehouses`` / ``warehouse_stock``         -> EER aggregation entity with the
  composite candidate key ``(warehouse_id, item_id)``.
* Engine-level ``CHECK`` constraints and secondary indexes on the new relations.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0002_capstone_eer_extensions"
down_revision: Union[str, None] = "0001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ------------------------------------------------------------------ #
    # EER Aggregation: Warehouse / WarehouseStock
    # ------------------------------------------------------------------ #
    op.create_table(
        "warehouses",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column(
            "org_id",
            sa.Integer(),
            sa.ForeignKey("organizations.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("warehouse_code", sa.String(30), nullable=False),
        sa.Column("name", sa.String(150), nullable=False),
        sa.Column("city", sa.String(100), nullable=False),
        sa.Column("capacity_sqft", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("org_id", "warehouse_code", name="uq_warehouses_org_code"),
        sa.CheckConstraint("capacity_sqft >= 0", name="chk_warehouses_capacity_non_negative"),
    )
    op.create_index("ix_warehouses_org_city", "warehouses", ["org_id", "city"])

    op.create_table(
        "warehouse_stock",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column(
            "warehouse_id",
            sa.Integer(),
            sa.ForeignKey("warehouses.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "item_id",
            sa.Integer(),
            sa.ForeignKey("inventory_items.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("quantity_stored", sa.Numeric(12, 2), nullable=False, server_default="0.00"),
        sa.Column("bin_location", sa.String(50), nullable=True),
        sa.Column("last_counted_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("warehouse_id", "item_id", name="uq_warehouse_stock_wh_item"),
        sa.CheckConstraint("quantity_stored >= 0", name="chk_warehouse_stock_non_negative"),
    )
    op.create_index("ix_warehouse_stock_item", "warehouse_stock", ["item_id"])

    # ------------------------------------------------------------------ #
    # EER Specialization: Donation -> CashDonation | InKindDonation
    # ------------------------------------------------------------------ #
    op.create_table(
        "cash_donations",
        sa.Column(
            "donation_id",
            sa.Integer(),
            sa.ForeignKey("donations.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("payment_mode", sa.String(20), nullable=False, server_default="NEFT"),
        sa.Column("transaction_reference", sa.String(100), nullable=True, unique=True),
        sa.Column("bank_name", sa.String(100), nullable=True),
        sa.Column("is_tax_exempt_80g", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.CheckConstraint(
            "payment_mode IN ('NEFT', 'RTGS', 'CHEQUE', 'UPI', 'CARD', 'CASH')",
            name="chk_cash_donations_payment_mode",
        ),
    )

    op.create_table(
        "in_kind_donations",
        sa.Column(
            "donation_id",
            sa.Integer(),
            sa.ForeignKey("donations.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column(
            "item_id",
            sa.Integer(),
            sa.ForeignKey("inventory_items.id", ondelete="RESTRICT"),
            nullable=False,
            index=True,
        ),
        sa.Column("quantity_donated", sa.Numeric(12, 2), nullable=False),
        sa.Column("unit_fair_value", sa.Numeric(12, 2), nullable=False, server_default="0.00"),
        sa.Column("storage_requirement", sa.String(20), nullable=False, server_default="AMBIENT"),
        sa.Column("condition_grade", sa.String(20), nullable=False, server_default="NEW"),
        sa.CheckConstraint("quantity_donated > 0", name="chk_in_kind_quantity_positive"),
        sa.CheckConstraint("unit_fair_value >= 0", name="chk_in_kind_fair_value_non_negative"),
        sa.CheckConstraint(
            "storage_requirement IN ('COLD', 'AMBIENT', 'DRY')",
            name="chk_in_kind_storage_domain",
        ),
        sa.CheckConstraint(
            "condition_grade IN ('NEW', 'REFURBISHED', 'USED')",
            name="chk_in_kind_condition_domain",
        ),
    )

    # ------------------------------------------------------------------ #
    # Domain constraint on the specialization discriminator.
    # SQLite cannot ALTER TABLE ADD CONSTRAINT; batch rebuilds there are risky
    # once child tables reference `donations`, so it is MySQL-only.
    # ------------------------------------------------------------------ #
    if op.get_bind().dialect.name != "sqlite":
        op.create_check_constraint(
            "chk_donations_type_domain",
            "donations",
            "donation_type IN ('cash', 'goods')",
        )


def downgrade() -> None:
    if op.get_bind().dialect.name != "sqlite":
        op.drop_constraint("chk_donations_type_domain", "donations", type_="check")

    op.drop_index("ix_warehouse_stock_item", table_name="warehouse_stock")
    op.drop_table("in_kind_donations")
    op.drop_table("cash_donations")
    op.drop_table("warehouse_stock")
    op.drop_index("ix_warehouses_org_city", table_name="warehouses")
    op.drop_table("warehouses")
