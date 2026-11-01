from datetime import datetime
from typing import Optional
import uuid
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.shared.models import Base, UUIDMixin, TimestampMixin


class Subscription(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "subscriptions"

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("tenants.id", ondelete="CASCADE"),
        unique=True,
        index=True,
        nullable=False,
    )
    plan: Mapped[str] = mapped_column(
        sa.String(30),
        default="free",
        server_default=sa.text("'free'"),
        nullable=False,
    )
    status: Mapped[str] = mapped_column(
        sa.String(30),
        default="active",
        server_default=sa.text("'active'"),
        nullable=False,
    )
    expires_at: Mapped[Optional[datetime]] = mapped_column(
        sa.DateTime(timezone=True),
        nullable=True,
    )

    # Relationships
    tenant = relationship("Tenant", back_populates="subscription")
