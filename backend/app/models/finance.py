from datetime import datetime, date, timezone
from decimal import Decimal
from sqlalchemy import (
    Boolean, Column, Integer, String, Numeric, Date, DateTime,
    ForeignKey, UniqueConstraint, CheckConstraint
)
from sqlalchemy.orm import relationship
from app.database import Base


class Purchase(Base):
    __tablename__ = "purchases"

    id = Column(Integer, primary_key=True, index=True)
    org_id = Column(Integer, ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    item_id = Column(Integer, ForeignKey("inventory_items.id", ondelete="RESTRICT"), nullable=False, index=True)
    invoice_no = Column(String(100), nullable=False)
    supplier_name = Column(String(150), nullable=False)
    quantity = Column(Numeric(12, 2), nullable=False)
    unit_cost = Column(Numeric(12, 2), nullable=False)
    total_amount = Column(Numeric(12, 2), nullable=False)
    payment_status = Column(String(20), nullable=False, default="unpaid")  # paid, unpaid
    purchase_date = Column(Date, nullable=False, default=date.today)
    created_by = Column(Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    organization = relationship("Organization", back_populates="purchases")
    item = relationship("InventoryItem")
    creator = relationship("User")


class Donation(Base):
    __tablename__ = "donations"

    id = Column(Integer, primary_key=True, index=True)
    org_id = Column(Integer, ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    donor_name = Column(String(150), nullable=False)
    donation_type = Column(String(20), nullable=False)  # cash, goods
    amount = Column(Numeric(12, 2), nullable=False, default=Decimal("0.00"))
    item_id = Column(Integer, ForeignKey("inventory_items.id", ondelete="SET NULL"), nullable=True, index=True)
    quantity = Column(Numeric(12, 2), nullable=True)
    declared_value = Column(Numeric(12, 2), nullable=False, default=Decimal("0.00"))
    purpose = Column(String(255), nullable=True)
    receipt_no = Column(String(100), nullable=False)
    donation_date = Column(Date, nullable=False, default=date.today)
    recorded_by = Column(Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    __table_args__ = (
        UniqueConstraint("org_id", "receipt_no", name="uq_donations_org_receipt"),
        CheckConstraint("donation_type IN ('cash', 'goods')", name="chk_donations_type_domain"),
    )

    organization = relationship("Organization", back_populates="donations")
    item = relationship("InventoryItem")
    recorder = relationship("User")

    # EER disjoint-total specialization (d, t): every donation row owns exactly
    # one subclass row — `cash_donations` for money, `in_kind_donations` for goods.
    # `declared_value` on the superclass is the textbook `total_declared_value`.
    cash_detail = relationship(
        "CashDonation",
        back_populates="donation",
        uselist=False,
        cascade="all, delete-orphan",
        single_parent=True,
    )
    in_kind_detail = relationship(
        "InKindDonation",
        back_populates="donation",
        uselist=False,
        cascade="all, delete-orphan",
        single_parent=True,
    )


class CashDonation(Base):
    """EER subclass: monetary donations (payment rails + statutory 80G flag)."""

    __tablename__ = "cash_donations"

    donation_id = Column(
        Integer,
        ForeignKey("donations.id", ondelete="CASCADE"),
        primary_key=True,
    )
    payment_mode = Column(String(20), nullable=False, default="NEFT")
    transaction_reference = Column(String(100), nullable=True, unique=True)
    bank_name = Column(String(100), nullable=True)
    is_tax_exempt_80g = Column(Boolean, nullable=False, default=True)

    __table_args__ = (
        CheckConstraint(
            "payment_mode IN ('NEFT', 'RTGS', 'CHEQUE', 'UPI', 'CARD', 'CASH')",
            name="chk_cash_donations_payment_mode",
        ),
    )

    donation = relationship("Donation", back_populates="cash_detail")


class InKindDonation(Base):
    """EER subclass: physical goods donations tied to a catalog item."""

    __tablename__ = "in_kind_donations"

    donation_id = Column(
        Integer,
        ForeignKey("donations.id", ondelete="CASCADE"),
        primary_key=True,
    )
    item_id = Column(
        Integer, ForeignKey("inventory_items.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    quantity_donated = Column(Numeric(12, 2), nullable=False)
    unit_fair_value = Column(Numeric(12, 2), nullable=False, default=Decimal("0.00"))
    storage_requirement = Column(String(20), nullable=False, default="AMBIENT")
    condition_grade = Column(String(20), nullable=False, default="NEW")

    __table_args__ = (
        CheckConstraint("quantity_donated > 0", name="chk_in_kind_quantity_positive"),
        CheckConstraint("unit_fair_value >= 0", name="chk_in_kind_fair_value_non_negative"),
        CheckConstraint(
            "storage_requirement IN ('COLD', 'AMBIENT', 'DRY')",
            name="chk_in_kind_storage_domain",
        ),
        CheckConstraint(
            "condition_grade IN ('NEW', 'REFURBISHED', 'USED')",
            name="chk_in_kind_condition_domain",
        ),
    )

    donation = relationship("Donation", back_populates="in_kind_detail")
    item = relationship("InventoryItem")


class Expense(Base):
    __tablename__ = "expenses"

    id = Column(Integer, primary_key=True, index=True)
    org_id = Column(Integer, ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    category = Column(String(50), nullable=False)  # rent, utilities, salaries, transport, supplies, maintenance, other
    amount = Column(Numeric(12, 2), nullable=False)
    description = Column(String(255), nullable=False)
    expense_date = Column(Date, nullable=False, default=date.today)
    receipt_no = Column(String(100), nullable=True)
    recorded_by = Column(Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    __table_args__ = (
        CheckConstraint("amount >= 0", name="chk_expenses_amount_non_negative"),
    )

    organization = relationship("Organization", back_populates="expenses")
    recorder = relationship("User")


__all__ = [
    "Purchase",
    "Donation",
    "CashDonation",
    "InKindDonation",
    "Expense",
]
