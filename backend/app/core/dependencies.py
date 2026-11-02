from typing import Any, AsyncGenerator, Callable, List
import uuid
from fastapi import Depends, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.exceptions import AppException
from app.core.security import decode_access_token
from app.modules.tenants.models import Tenant
from app.modules.outlets.models import Outlet
from app.modules.users.models import User, TenantUser

# Bearer Token Scheme
security_bearer = HTTPBearer(auto_error=True)

# Re-export database dependency
DatabaseSession = Depends(get_db)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security_bearer),
    db: AsyncSession = DatabaseSession,
) -> User:
    """Validates JWT access token and returns authenticated active user."""
    token = credentials.credentials
    try:
        payload = decode_access_token(token)
    except ValueError as e:
        raise AppException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            code="INVALID_TOKEN",
            message=str(e),
        )

    user_id_str = payload.get("sub")
    if not user_id_str:
        raise AppException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            code="INVALID_TOKEN",
            message="Token payload is missing subject claim.",
        )

    try:
        user_uuid = uuid.UUID(user_id_str)
    except ValueError:
        raise AppException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            code="INVALID_TOKEN",
            message="Invalid user identifier in token.",
        )

    stmt = select(User).where(User.id == user_uuid)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user or not user.is_active:
        raise AppException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            code="USER_INACTIVE",
            message="Pengguna tidak ditemukan atau berstatus nonaktif.",
        )

    # Attach decoded token context onto user object for downstream use
    user._token_payload = payload
    return user


async def get_current_tenant(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = DatabaseSession,
) -> Tenant:
    """Resolves and verifies active tenant context strictly from authenticated user's token claim."""
    payload = getattr(current_user, "_token_payload", {})
    tenant_id_str = payload.get("tenant_id")
    if not tenant_id_str:
        raise AppException(
            status_code=status.HTTP_403_FORBIDDEN,
            code="NO_TENANT_CONTEXT",
            message="Konteks bisnis/tenant tidak ditemukan pada sesi pengguna.",
        )

    try:
        tenant_uuid = uuid.UUID(tenant_id_str)
    except ValueError:
        raise AppException(
            status_code=status.HTTP_400_BAD_REQUEST,
            code="INVALID_TENANT_ID",
            message="Identifier tenant tidak valid.",
        )

    # Verify active tenant membership
    stmt = (
        select(Tenant)
        .join(TenantUser, TenantUser.tenant_id == Tenant.id)
        .where(
            Tenant.id == tenant_uuid,
            Tenant.is_active.is_(True),
            TenantUser.user_id == current_user.id,
            TenantUser.is_active.is_(True),
        )
    )
    result = await db.execute(stmt)
    tenant = result.scalar_one_or_none()

    if not tenant:
        raise AppException(
            status_code=status.HTTP_403_FORBIDDEN,
            code="FORBIDDEN_TENANT_ACCESS",
            message="Akses ditolak: Anda bukan anggota aktif dari bisnis ini.",
        )

    return tenant


async def get_current_outlet(
    current_user: User = Depends(get_current_user),
    tenant: Tenant = Depends(get_current_tenant),
    db: AsyncSession = DatabaseSession,
) -> Outlet:
    """Resolves and verifies active operational outlet."""
    payload = getattr(current_user, "_token_payload", {})
    outlet_id_str = payload.get("outlet_id")

    if not outlet_id_str:
        raise AppException(
            status_code=status.HTTP_400_BAD_REQUEST,
            code="NO_OUTLET_CONTEXT",
            message="Konteks outlet tidak ditemukan pada sesi aktif.",
        )

    try:
        outlet_uuid = uuid.UUID(outlet_id_str)
    except ValueError:
        raise AppException(
            status_code=status.HTTP_400_BAD_REQUEST,
            code="INVALID_OUTLET_ID",
            message="Identifier outlet tidak valid.",
        )

    stmt = select(Outlet).where(
        Outlet.id == outlet_uuid,
        Outlet.tenant_id == tenant.id,
        Outlet.is_active.is_(True),
    )
    result = await db.execute(stmt)
    outlet = result.scalar_one_or_none()

    if not outlet:
        raise AppException(
            status_code=status.HTTP_403_FORBIDDEN,
            code="FORBIDDEN_OUTLET_ACCESS",
            message="Outlet tidak ditemukan atau bukan milik bisnis ini.",
        )

    return outlet


def require_roles(*roles: Any) -> Callable:
    """Dependency factory checking if current user holds one of the required roles."""
    allowed_roles: List[str] = []
    for r in roles:
        if isinstance(r, (list, tuple, set)):
            allowed_roles.extend(str(item) for item in r)
        else:
            allowed_roles.append(str(r))

    async def role_checker(current_user: User = Depends(get_current_user)) -> User:
        payload = getattr(current_user, "_token_payload", {})
        user_role = payload.get("role")
        if user_role not in allowed_roles:
            raise AppException(
                status_code=status.HTTP_403_FORBIDDEN,
                code="INSUFFICIENT_PERMISSIONS",
                message=f"Izin tidak mencukupi. Peran yang dibutuhkan: {', '.join(allowed_roles)}.",
            )
        return current_user

    return role_checker
