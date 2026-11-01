import enum
import uuid
from decimal import Decimal
from typing import Optional
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.shared.models import Base, UUIDMixin, TimestampMixin


class PriceType(str, enum.Enum):
    PER_KG = "per_kg"
    PER_ITEM = "per_item"


class Service(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "services"

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("tenants.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    name: Mapped[str] = mapped_column(sa.String(255), index=True, nullable=False)
    description: Mapped[Optional[str]] = mapped_column(sa.Text, nullable=True)
    price_type: Mapped[str] = mapped_column(
        sa.String(32),
        default=PriceType.PER_KG.value,
        nullable=False,
    )
    unit: Mapped[str] = mapped_column(
        sa.String(32),
        default="kg",
        nullable=False,
    )
    price: Mapped[Decimal] = mapped_column(
        sa.Numeric(precision=12, scale=2),
        nullable=False,
    )
    estimated_duration_hours: Mapped[Optional[int]] = mapped_column(
        sa.Integer,
        nullable=True,
    )
    is_active: Mapped[bool] = mapped_column(
        sa.Boolean,
        default=True,
        server_default=sa.text("true"),
        index=True,
        nullable=False,
    )

    # Table arguments: composite index for fast tenant filtering
    __table_args__ = (
        sa.Index("ix_services_tenant_active", "tenant_id", "is_active"),
    )

    # Relationships
    tenant = relationship("Tenant", back_populates="services")
