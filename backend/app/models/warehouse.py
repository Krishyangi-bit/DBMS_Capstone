"""Pillar 1.2 — EER Aggregation: multi-facility warehouse distribution.

`WarehouseStock` is the *aggregation* entity: it exists only in the context of a
(Warehouse, InventoryItem) relationship pair, exactly as required by the EER
aggregation construct from the syllabus. The composite candidate key
`(warehouse_id, item_id)` guarantees a single stock row per item per facility.
"""
from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from app.database import Base


class Warehouse(Base):
    __tablename__ = "warehouses"

    id = Column(Integer, primary_key=True, index=True)
    org_id = Column(Integer, ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    warehouse_code = Column(String(30), nullable=False)
    name = Column(String(150), nullable=False)
    city = Column(String(100), nullable=False)
    capacity_sqft = Column(Integer, nullable=False, default=0)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    __table_args__ = (
        # Candidate key: a facility code is unique inside a tenant only.
        UniqueConstraint("org_id", "warehouse_code", name="uq_warehouses_org_code"),
        CheckConstraint("capacity_sqft >= 0", name="chk_warehouses_capacity_non_negative"),
        Index("ix_warehouses_org_city", "org_id", "city"),
    )

    organization = relationship("Organization", back_populates="warehouses")
    stock_entries = relationship(
        "WarehouseStock", back_populates="warehouse", cascade="all, delete-orphan"
    )

    @property
    def total_units_stored(self) -> Decimal:
        return sum(
            (Decimal(str(s.quantity_stored or 0)) for s in self.stock_entries),
            Decimal("0.00"),
        )


class WarehouseStock(Base):
    __tablename__ = "warehouse_stock"

    id = Column(Integer, primary_key=True, index=True)
    warehouse_id = Column(
        Integer, ForeignKey("warehouses.id", ondelete="CASCADE"), nullable=False, index=True
    )
    item_id = Column(
        Integer, ForeignKey("inventory_items.id", ondelete="CASCADE"), nullable=False, index=True
    )
    quantity_stored = Column(Numeric(12, 2), nullable=False, default=Decimal("0.00"))
    bin_location = Column(String(50), nullable=True)
    last_counted_at = Column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        UniqueConstraint("warehouse_id", "item_id", name="uq_warehouse_stock_wh_item"),
        CheckConstraint("quantity_stored >= 0", name="chk_warehouse_stock_non_negative"),
        Index("ix_warehouse_stock_item", "item_id"),
    )

    warehouse = relationship("Warehouse", back_populates="stock_entries")
    item = relationship("InventoryItem")
