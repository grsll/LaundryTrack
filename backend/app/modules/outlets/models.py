import uuid
from typing import Optional
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.shared.models import Base, UUIDMixin, TimestampMixin


class Outlet(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "outlets"

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("tenants.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    name: Mapped[str] = mapped_column(sa.String(150), nullable=False)
    address: Mapped[Optional[str]] = mapped_column(sa.Text, nullable=True)
    phone: Mapped[Optional[str]] = mapped_column(sa.String(30), nullable=True)
    is_active: Mapped[bool] = mapped_column(
        sa.Boolean,
        default=True,
        server_default=sa.text("true"),
        nullable=False,
    )

    # Relationships
    tenant = relationship("Tenant", back_populates="outlets")
    outlet_users = relationship("OutletUser", back_populates="outlet", cascade="all, delete-orphan")
