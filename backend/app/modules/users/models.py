import enum
import uuid
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.shared.models import Base, UUIDMixin, TimestampMixin


class UserType(str, enum.Enum):
    STAFF = "staff"
    CUSTOMER = "customer"


class UserRole(str, enum.Enum):
    OWNER = "owner"
    ADMIN = "admin"
    CASHIER = "cashier"
    OPERATOR = "operator"


class User(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "users"

    email: Mapped[str] = mapped_column(sa.String(255), unique=True, index=True, nullable=False)
    phone: Mapped[str] = mapped_column(sa.String(50), unique=True, index=True, nullable=False)
    full_name: Mapped[str] = mapped_column(sa.String(150), nullable=False)
    hashed_password: Mapped[str] = mapped_column(sa.String(255), nullable=False)
    user_type: Mapped[str] = mapped_column(
        sa.String(20),
        default=UserType.STAFF.value,
        server_default=sa.text("'staff'"),
        nullable=False,
    )
    is_active: Mapped[bool] = mapped_column(
        sa.Boolean,
        default=True,
        server_default=sa.text("true"),
        nullable=False,
    )
    is_verified: Mapped[bool] = mapped_column(
        sa.Boolean,
        default=False,
        server_default=sa.text("false"),
        nullable=False,
    )

    # Relationships
    tenant_memberships = relationship("TenantUser", back_populates="user", cascade="all, delete-orphan")
    outlet_assignments = relationship("OutletUser", back_populates="user", cascade="all, delete-orphan")
    refresh_tokens = relationship("RefreshToken", back_populates="user", cascade="all, delete-orphan")


class TenantUser(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "tenant_users"

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("tenants.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    role: Mapped[str] = mapped_column(
        sa.String(30),
        default=UserRole.OWNER.value,
        server_default=sa.text("'owner'"),
        nullable=False,
    )
    is_active: Mapped[bool] = mapped_column(
        sa.Boolean,
        default=True,
        server_default=sa.text("true"),
        nullable=False,
    )

    __table_args__ = (
        sa.UniqueConstraint("tenant_id", "user_id", name="uq_tenant_user"),
    )

    # Relationships
    tenant = relationship("Tenant", back_populates="tenant_users")
    user = relationship("User", back_populates="tenant_memberships")


class OutletUser(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "outlet_users"

    outlet_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("outlets.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )

    __table_args__ = (
        sa.UniqueConstraint("outlet_id", "user_id", name="uq_outlet_user"),
    )

    # Relationships
    outlet = relationship("Outlet", back_populates="outlet_users")
    user = relationship("User", back_populates="outlet_assignments")
