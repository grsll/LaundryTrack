import uuid
from typing import Optional
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.shared.models import Base, UUIDMixin, TimestampMixin


class Customer(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "customers"

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("tenants.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    name: Mapped[str] = mapped_column(sa.String(255), index=True, nullable=False)
    phone: Mapped[Optional[str]] = mapped_column(sa.String(32), index=True, nullable=True)
    email: Mapped[Optional[str]] = mapped_column(sa.String(255), nullable=True)
    address: Mapped[Optional[str]] = mapped_column(sa.Text, nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(sa.Text, nullable=True)
    is_active: Mapped[bool] = mapped_column(
        sa.Boolean,
        default=True,
        server_default=sa.text("true"),
        index=True,
        nullable=False,
    )

    # Table arguments: composite index for fast tenant filtering
    __table_args__ = (
        sa.Index("ix_customers_tenant_active", "tenant_id", "is_active"),
        sa.Index("ix_customers_tenant_phone", "tenant_id", "phone"),
    )

    # Relationships
    tenant = relationship("Tenant", back_populates="customers")
    orders = relationship("Order", back_populates="customer")
