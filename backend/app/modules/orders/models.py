from datetime import datetime, timezone
from decimal import Decimal
import enum
from typing import List, Optional
import uuid
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.shared.models import Base, TimestampMixin, UUIDMixin


class OrderStatus(str, enum.Enum):
    RECEIVED = "received"
    WASHING = "washing"
    DRYING = "drying"
    IRONING = "ironing"
    PACKAGING = "packaging"
    READY = "ready"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class PaymentStatus(str, enum.Enum):
    UNPAID = "unpaid"
    PARTIAL = "partial"
    PAID = "paid"
    REFUNDED = "refunded"


class Order(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "orders"

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
    customer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("customers.id", ondelete="RESTRICT"),
        index=True,
        nullable=False,
    )
    created_by_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )

    order_number: Mapped[str] = mapped_column(
        sa.String(64),
        index=True,
        nullable=False,
    )
    status: Mapped[str] = mapped_column(
        sa.String(32),
        default=OrderStatus.RECEIVED.value,
        server_default=OrderStatus.RECEIVED.value,
        index=True,
        nullable=False,
    )
    payment_status: Mapped[str] = mapped_column(
        sa.String(32),
        default=PaymentStatus.UNPAID.value,
        server_default=PaymentStatus.UNPAID.value,
        index=True,
        nullable=False,
    )

    received_at: Mapped[datetime] = mapped_column(
        sa.DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=sa.text("now()"),
        nullable=False,
    )
    estimated_completion_at: Mapped[Optional[datetime]] = mapped_column(
        sa.DateTime(timezone=True),
        nullable=True,
    )

    subtotal: Mapped[Decimal] = mapped_column(
        sa.Numeric(precision=12, scale=2),
        nullable=False,
    )
    discount_amount: Mapped[Decimal] = mapped_column(
        sa.Numeric(precision=12, scale=2),
        default=Decimal("0.00"),
        server_default=sa.text("0.00"),
        nullable=False,
    )
    total_amount: Mapped[Decimal] = mapped_column(
        sa.Numeric(precision=12, scale=2),
        nullable=False,
    )
    paid_amount: Mapped[Decimal] = mapped_column(
        sa.Numeric(precision=12, scale=2),
        default=Decimal("0.00"),
        server_default=sa.text("0.00"),
        nullable=False,
    )
    remaining_amount: Mapped[Decimal] = mapped_column(
        sa.Numeric(precision=12, scale=2),
        nullable=False,
    )

    notes: Mapped[Optional[str]] = mapped_column(
        sa.Text,
        nullable=True,
    )
    cancellation_reason: Mapped[Optional[str]] = mapped_column(
        sa.Text,
        nullable=True,
    )
    cancelled_at: Mapped[Optional[datetime]] = mapped_column(
        sa.DateTime(timezone=True),
        nullable=True,
    )

    # Composite indexes
    __table_args__ = (
        sa.UniqueConstraint("tenant_id", "order_number", name="uq_orders_tenant_order_number"),
        sa.Index("ix_orders_tenant_outlet", "tenant_id", "outlet_id"),
        sa.Index("ix_orders_tenant_status", "tenant_id", "status"),
        sa.Index("ix_orders_tenant_customer", "tenant_id", "customer_id"),
    )

    # Relationships
    tenant = relationship("Tenant", back_populates="orders")
    outlet = relationship("Outlet", back_populates="orders")
    customer = relationship("Customer", back_populates="orders")
    creator = relationship("User", foreign_keys=[created_by_id])
    items: Mapped[List["OrderItem"]] = relationship(
        "OrderItem",
        back_populates="order",
        cascade="all, delete-orphan",
        order_by="OrderItem.created_at",
    )
    status_logs: Mapped[List["OrderStatusLog"]] = relationship(
        "OrderStatusLog",
        back_populates="order",
        cascade="all, delete-orphan",
        order_by="OrderStatusLog.created_at",
    )


class OrderItem(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "order_items"

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("tenants.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    order_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("orders.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    service_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("services.id", ondelete="SET NULL"),
        index=True,
        nullable=True,
    )

    # Snapshots (Immutable historic audit trail)
    service_name_snapshot: Mapped[str] = mapped_column(
        sa.String(255),
        nullable=False,
    )
    price_type_snapshot: Mapped[str] = mapped_column(
        sa.String(32),
        nullable=False,
    )
    unit_snapshot: Mapped[str] = mapped_column(
        sa.String(32),
        nullable=False,
    )
    unit_price_snapshot: Mapped[Decimal] = mapped_column(
        sa.Numeric(precision=12, scale=2),
        nullable=False,
    )

    quantity: Mapped[Decimal] = mapped_column(
        sa.Numeric(precision=12, scale=2),
        nullable=False,
    )
    subtotal: Mapped[Decimal] = mapped_column(
        sa.Numeric(precision=12, scale=2),
        nullable=False,
    )
    notes: Mapped[Optional[str]] = mapped_column(
        sa.Text,
        nullable=True,
    )

    # Relationships
    order: Mapped["Order"] = relationship("Order", back_populates="items")
    service = relationship("Service")


class OrderStatusLog(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "order_status_logs"

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("tenants.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    order_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("orders.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    changed_by_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )

    previous_status: Mapped[Optional[str]] = mapped_column(
        sa.String(32),
        nullable=True,
    )
    new_status: Mapped[str] = mapped_column(
        sa.String(32),
        nullable=False,
    )
    notes: Mapped[Optional[str]] = mapped_column(
        sa.Text,
        nullable=True,
    )

    # Relationships
    order: Mapped["Order"] = relationship("Order", back_populates="status_logs")
    changed_by = relationship("User")


class OrderSequence(Base, UUIDMixin):
    __tablename__ = "order_sequences"

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("tenants.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    outlet_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("outlets.id", ondelete="SET NULL"),
        index=True,
        nullable=True,
    )
    date_str: Mapped[str] = mapped_column(
        sa.String(8),
        nullable=False,
    )
    last_sequence: Mapped[int] = mapped_column(
        sa.Integer,
        default=0,
        server_default=sa.text("0"),
        nullable=False,
    )

    __table_args__ = (
        sa.UniqueConstraint("tenant_id", "date_str", name="uq_order_sequences_tenant_date"),
    )
