import enum
from typing import Optional
import uuid
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.shared.models import Base, TimestampMixin, UUIDMixin


class ReceiptPrintType(str, enum.Enum):
    THERMAL = "thermal"
    PDF = "pdf"
    DIGITAL = "digital"


class ReceiptLog(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "receipt_logs"

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
        sa.ForeignKey("orders.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    printed_by_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )

    print_type: Mapped[str] = mapped_column(
        sa.String(32),
        default=ReceiptPrintType.THERMAL.value,
        server_default=ReceiptPrintType.THERMAL.value,
        nullable=False,
    )
    notes: Mapped[Optional[str]] = mapped_column(
        sa.String(255),
        nullable=True,
    )

    # Composite indexes
    __table_args__ = (
        sa.Index("ix_receipt_logs_tenant_order", "tenant_id", "order_id"),
        sa.Index("ix_receipt_logs_tenant_created", "tenant_id", "created_at"),
    )

    # Relationships
    tenant = relationship("Tenant", foreign_keys=[tenant_id])
    outlet = relationship("Outlet", foreign_keys=[outlet_id])
    order = relationship("Order", back_populates="receipt_logs")
    printed_by = relationship("User", foreign_keys=[printed_by_id])
