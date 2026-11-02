from datetime import datetime, timezone
from decimal import Decimal
import enum
from typing import List, Optional
import uuid
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.shared.models import Base, TimestampMixin, UUIDMixin


class PaymentMethod(str, enum.Enum):
    CASH = "cash"
    QRIS = "qris"
    BANK_TRANSFER = "bank_transfer"
    DEBIT = "debit"


class PaymentRecordStatus(str, enum.Enum):
    PAID = "paid"
    PARTIALLY_REFUNDED = "partially_refunded"
    REFUNDED = "refunded"


class Payment(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "payments"

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("tenants.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    outlet_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("outlets.id", ondelete="RESTRICT"),
        index=True,
        nullable=False,
    )
    order_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("orders.id", ondelete="RESTRICT"),
        index=True,
        nullable=False,
    )
    received_by_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )

    amount: Mapped[Decimal] = mapped_column(
        sa.Numeric(precision=12, scale=2),
        nullable=False,
    )
    payment_method: Mapped[str] = mapped_column(
        sa.String(32),
        default=PaymentMethod.CASH.value,
        server_default=PaymentMethod.CASH.value,
        nullable=False,
    )
    reference_number: Mapped[Optional[str]] = mapped_column(
        sa.String(64),
        nullable=True,
    )
    status: Mapped[str] = mapped_column(
        sa.String(32),
        default=PaymentRecordStatus.PAID.value,
        server_default=PaymentRecordStatus.PAID.value,
        index=True,
        nullable=False,
    )
    paid_at: Mapped[datetime] = mapped_column(
        sa.DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=sa.text("now()"),
        nullable=False,
    )
    notes: Mapped[Optional[str]] = mapped_column(
        sa.Text,
        nullable=True,
    )

    # Composite indexes
    __table_args__ = (
        sa.Index("ix_payments_tenant_order", "tenant_id", "order_id"),
        sa.Index("ix_payments_tenant_outlet", "tenant_id", "outlet_id"),
        sa.Index("ix_payments_tenant_paid_at", "tenant_id", "paid_at"),
    )

    # Relationships
    tenant = relationship("Tenant", foreign_keys=[tenant_id])
    outlet = relationship("Outlet", foreign_keys=[outlet_id])
    order = relationship("Order", back_populates="payments")
    received_by = relationship("User", foreign_keys=[received_by_id])
    refunds: Mapped[List["Refund"]] = relationship(
        "Refund",
        back_populates="payment",
        cascade="all, delete-orphan",
        order_by="Refund.refunded_at",
    )


class Refund(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "refunds"

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("tenants.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    outlet_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("outlets.id", ondelete="RESTRICT"),
        index=True,
        nullable=False,
    )
    payment_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("payments.id", ondelete="RESTRICT"),
        index=True,
        nullable=False,
    )
    order_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("orders.id", ondelete="RESTRICT"),
        index=True,
        nullable=False,
    )
    refunded_by_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )

    amount: Mapped[Decimal] = mapped_column(
        sa.Numeric(precision=12, scale=2),
        nullable=False,
    )
    reason: Mapped[str] = mapped_column(
        sa.Text,
        nullable=False,
    )
    refunded_at: Mapped[datetime] = mapped_column(
        sa.DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=sa.text("now()"),
        nullable=False,
    )

    # Composite indexes
    __table_args__ = (
        sa.Index("ix_refunds_tenant_payment", "tenant_id", "payment_id"),
        sa.Index("ix_refunds_tenant_order", "tenant_id", "order_id"),
        sa.Index("ix_refunds_tenant_refunded_at", "tenant_id", "refunded_at"),
    )

    # Relationships
    tenant = relationship("Tenant", foreign_keys=[tenant_id])
    outlet = relationship("Outlet", foreign_keys=[outlet_id])
    payment = relationship("Payment", back_populates="refunds")
    order = relationship("Order", back_populates="refunds")
    refunded_by = relationship("User", foreign_keys=[refunded_by_id])
