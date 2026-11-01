from datetime import datetime, timedelta, timezone
import re
import secrets
import uuid
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import status
from app.core.config import settings
from app.core.exceptions import AppException
from app.core.security import (
    create_access_token,
    generate_random_token,
    hash_password,
    hash_token,
    verify_password,
)
from app.modules.auth.models import RefreshToken
from app.modules.auth.schemas import (
    AuthData,
    LoginRequest,
    OutletSummary,
    RegisterBusinessRequest,
    SubscriptionSummary,
    TenantSummary,
    TokenResponse,
    UserProfileData,
    UserSummary,
)
from app.modules.outlets.models import Outlet
from app.modules.subscriptions.models import Subscription
from app.modules.tenants.models import Tenant
from app.modules.users.models import OutletUser, TenantUser, User, UserRole, UserType

# Pre-computed dummy Argon2id hash for constant-time comparison on user lookup miss
DUMMY_ARGON2_HASH = "$argon2id$v=19$m=65536,t=3,p=4$ZHVtbXlzYWx0MTIzNDU2Nw$qUfS1sIeN0FjQ8fWnL0X4O3fP+zT5V2Y7Z1W6M9E"


def slugify(text: str) -> str:
    """Generates a URL-friendly slug from a text string."""
    text = text.lower().strip()
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"[\s_-]+", "-", text)
    text = re.sub(r"^-+|-+$", "", text)
    return text or "tenant"


class AuthService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def register_business(self, payload: RegisterBusinessRequest) -> AuthData:
        """Atomically registers a business owner, tenant, default outlet, and free subscription."""
        clean_email = payload.email.strip().lower()
        clean_phone = payload.phone.strip()

        # 1. Check duplicate email or phone
        existing_stmt = select(User).where(
            or_(User.email == clean_email, User.phone == clean_phone)
        )
        existing_res = await self.db.execute(existing_stmt)
        existing_user = existing_res.scalar_one_or_none()
        if existing_user:
            if existing_user.email == clean_email:
                raise AppException(
                    status_code=status.HTTP_409_CONFLICT,
                    code="EMAIL_ALREADY_EXISTS",
                    message="Email sudah terdaftar. Silakan gunakan email lain atau login.",
                )
            else:
                raise AppException(
                    status_code=status.HTTP_409_CONFLICT,
                    code="PHONE_ALREADY_EXISTS",
                    message="Nomor telepon sudah terdaftar. Silakan gunakan nomor lain.",
                )

        # 2. Generate unique slug for tenant
        base_slug = slugify(payload.business_name)
        slug = base_slug
        slug_stmt = select(Tenant).where(Tenant.slug == slug)
        slug_res = await self.db.execute(slug_stmt)
        if slug_res.scalar_one_or_none():
            slug = f"{base_slug}-{secrets.token_hex(3)}"

        # 3. Create Entities atomically
        user = User(
            email=clean_email,
            phone=clean_phone,
            full_name=payload.full_name.strip(),
            hashed_password=hash_password(payload.password),
            user_type=UserType.STAFF.value,
            is_active=True,
            is_verified=True,
        )
        self.db.add(user)
        await self.db.flush()

        tenant = Tenant(
            name=payload.business_name.strip(),
            slug=slug,
            is_active=True,
        )
        self.db.add(tenant)
        await self.db.flush()

        outlet = Outlet(
            tenant_id=tenant.id,
            name=payload.outlet_name.strip() if payload.outlet_name else "Outlet Utama",
            address=payload.outlet_address.strip() if payload.outlet_address else None,
            phone=payload.outlet_phone.strip() if payload.outlet_phone else clean_phone,
            is_active=True,
        )
        self.db.add(outlet)
        await self.db.flush()

        tenant_user = TenantUser(
            tenant_id=tenant.id,
            user_id=user.id,
            role=UserRole.OWNER.value,
            is_active=True,
        )
        self.db.add(tenant_user)

        outlet_user = OutletUser(
            outlet_id=outlet.id,
            user_id=user.id,
        )
        self.db.add(outlet_user)

        subscription = Subscription(
            tenant_id=tenant.id,
            plan="free",
            status="active",
        )
        self.db.add(subscription)

        # 4. Issue Refresh Token bound to user and tenant
        raw_refresh_token = generate_random_token()
        refresh_token = RefreshToken(
            user_id=user.id,
            tenant_id=tenant.id,
            token_hash=hash_token(raw_refresh_token),
            is_revoked=False,
            expires_at=datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        )
        self.db.add(refresh_token)

        # Commit atomic transaction
        await self.db.commit()

        # 5. Issue Access Token
        access_token_claims = {
            "sub": str(user.id),
            "tenant_id": str(tenant.id),
            "outlet_id": str(outlet.id),
            "role": UserRole.OWNER.value,
        }
        access_token = create_access_token(access_token_claims)

        return AuthData(
            user=UserSummary(
                id=user.id,
                full_name=user.full_name,
                email=user.email,
                phone=user.phone,
                user_type=user.user_type,
                role=UserRole.OWNER.value,
            ),
            tenant=TenantSummary(
                id=tenant.id,
                name=tenant.name,
                slug=tenant.slug,
            ),
            outlet=OutletSummary(
                id=outlet.id,
                name=outlet.name,
            ),
            subscription=SubscriptionSummary(
                plan=subscription.plan,
                status=subscription.status,
            ),
            tokens=TokenResponse(
                access_token=access_token,
                refresh_token=raw_refresh_token,
                token_type="bearer",
                expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            ),
        )

    async def authenticate_user(self, payload: LoginRequest) -> AuthData:
        """Authenticates a staff member using email or phone and password with constant-time resistance."""
        identifier = payload.email_or_phone.strip()
        stmt = select(User).where(
            or_(User.email == identifier.lower(), User.phone == identifier)
        )
        res = await self.db.execute(stmt)
        user = res.scalar_one_or_none()

        # Constant-time dummy verification prevents timing side-channel on user enumeration
        target_hash = user.hashed_password if user else DUMMY_ARGON2_HASH
        password_ok = verify_password(payload.password, target_hash)

        if not user or not password_ok:
            raise AppException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                code="INVALID_CREDENTIALS",
                message="Email/nomor telepon atau kata sandi tidak cocok.",
            )

        if not user.is_active:
            raise AppException(
                status_code=status.HTTP_403_FORBIDDEN,
                code="ACCOUNT_INACTIVE",
                message="Akun Anda berstatus nonaktif. Silakan hubungi pemilik bisnis.",
            )

        # Fetch active tenant membership
        tu_stmt = (
            select(TenantUser, Tenant)
            .join(Tenant, Tenant.id == TenantUser.tenant_id)
            .where(
                TenantUser.user_id == user.id,
                TenantUser.is_active.is_(True),
                Tenant.is_active.is_(True),
            )
        )
        tu_res = await self.db.execute(tu_stmt)
        tu_row = tu_res.first()

        if not tu_row:
            raise AppException(
                status_code=status.HTTP_403_FORBIDDEN,
                code="NO_ACTIVE_TENANT",
                message="Pengguna belum terhubung dengan bisnis aktif manapun.",
            )

        tenant_user, tenant = tu_row

        # Fetch primary outlet
        outlet_stmt = (
            select(Outlet)
            .join(OutletUser, OutletUser.outlet_id == Outlet.id)
            .where(
                OutletUser.user_id == user.id,
                Outlet.tenant_id == tenant.id,
                Outlet.is_active.is_(True),
            )
        )
        outlet_res = await self.db.execute(outlet_stmt)
        outlet = outlet_res.scalar_one_or_none()

        if not outlet:
            fallback_stmt = select(Outlet).where(
                Outlet.tenant_id == tenant.id,
                Outlet.is_active.is_(True),
            )
            fallback_res = await self.db.execute(fallback_stmt)
            outlet = fallback_res.scalar_one_or_none()

        outlet_id_str = str(outlet.id) if outlet else ""
        outlet_name_str = outlet.name if outlet else "Semua Outlet"

        # Fetch subscription
        sub_stmt = select(Subscription).where(Subscription.tenant_id == tenant.id)
        sub_res = await self.db.execute(sub_stmt)
        subscription = sub_res.scalar_one_or_none()
        plan_str = subscription.plan if subscription else "free"
        status_str = subscription.status if subscription else "active"

        # Issue Refresh Token bound to user and tenant
        raw_refresh_token = generate_random_token()
        refresh_token = RefreshToken(
            user_id=user.id,
            tenant_id=tenant.id,
            token_hash=hash_token(raw_refresh_token),
            is_revoked=False,
            expires_at=datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        )
        self.db.add(refresh_token)
        await self.db.commit()

        # Issue Access Token
        access_token_claims = {
            "sub": str(user.id),
            "tenant_id": str(tenant.id),
            "outlet_id": outlet_id_str,
            "role": tenant_user.role,
        }
        access_token = create_access_token(access_token_claims)

        return AuthData(
            user=UserSummary(
                id=user.id,
                full_name=user.full_name,
                email=user.email,
                phone=user.phone,
                user_type=user.user_type,
                role=tenant_user.role,
            ),
            tenant=TenantSummary(
                id=tenant.id,
                name=tenant.name,
                slug=tenant.slug,
            ),
            outlet=OutletSummary(
                id=outlet.id if outlet else uuid.uuid4(),
                name=outlet_name_str,
            ),
            subscription=SubscriptionSummary(
                plan=plan_str,
                status=status_str,
            ),
            tokens=TokenResponse(
                access_token=access_token,
                refresh_token=raw_refresh_token,
                token_type="bearer",
                expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            ),
        )

    async def refresh_tokens(self, raw_refresh_token: str) -> TokenResponse:
        """Rotates refresh token and issues a new access token with row-locking and tenant binding."""
        input_hash = hash_token(raw_refresh_token)
        now = datetime.now(timezone.utc)

        # Use with_for_update() to prevent race conditions during concurrent rotation
        stmt = (
            select(RefreshToken)
            .where(
                RefreshToken.token_hash == input_hash,
                RefreshToken.is_revoked.is_(False),
                RefreshToken.expires_at > now,
            )
            .with_for_update()
        )
        res = await self.db.execute(stmt)
        stored_token = res.scalar_one_or_none()

        if not stored_token:
            raise AppException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                code="INVALID_REFRESH_TOKEN",
                message="Refresh token tidak valid atau telah kedaluwarsa.",
            )

        # Revoke used refresh token (Token Rotation)
        stored_token.is_revoked = True

        # Fetch user
        user_stmt = select(User).where(User.id == stored_token.user_id, User.is_active.is_(True))
        user_res = await self.db.execute(user_stmt)
        user = user_res.scalar_one_or_none()

        if not user:
            raise AppException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                code="USER_INACTIVE",
                message="Pengguna tidak aktif.",
            )

        # Resolve specific tenant context bound to the refresh token session
        tu_stmt = (
            select(TenantUser)
            .join(Tenant, Tenant.id == TenantUser.tenant_id)
            .where(
                TenantUser.user_id == user.id,
                TenantUser.is_active.is_(True),
                Tenant.is_active.is_(True),
            )
        )
        if stored_token.tenant_id:
            tu_stmt = tu_stmt.where(TenantUser.tenant_id == stored_token.tenant_id)

        tu_res = await self.db.execute(tu_stmt)
        tenant_user = tu_res.scalars().first()

        tenant_id_str = str(tenant_user.tenant_id) if tenant_user else ""
        role_str = tenant_user.role if tenant_user else "owner"

        # Resolve outlet
        ou_stmt = (
            select(OutletUser)
            .join(Outlet, Outlet.id == OutletUser.outlet_id)
            .where(
                OutletUser.user_id == user.id,
                Outlet.is_active.is_(True),
            )
        )
        if stored_token.tenant_id:
            ou_stmt = ou_stmt.where(Outlet.tenant_id == stored_token.tenant_id)

        ou_res = await self.db.execute(ou_stmt)
        outlet_user = ou_res.scalars().first()
        outlet_id_str = str(outlet_user.outlet_id) if outlet_user else ""

        # Issue new pair bound to the same tenant
        new_raw_refresh = generate_random_token()
        new_refresh_token = RefreshToken(
            user_id=user.id,
            tenant_id=stored_token.tenant_id,
            token_hash=hash_token(new_raw_refresh),
            is_revoked=False,
            expires_at=now + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        )
        self.db.add(new_refresh_token)
        await self.db.commit()

        new_access_token = create_access_token({
            "sub": str(user.id),
            "tenant_id": tenant_id_str,
            "outlet_id": outlet_id_str,
            "role": role_str,
        })

        return TokenResponse(
            access_token=new_access_token,
            refresh_token=new_raw_refresh,
            token_type="bearer",
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        )

    async def logout_user(self, raw_refresh_token: str) -> bool:
        """Revokes active refresh token."""
        input_hash = hash_token(raw_refresh_token)
        stmt = select(RefreshToken).where(RefreshToken.token_hash == input_hash)
        res = await self.db.execute(stmt)
        stored_token = res.scalar_one_or_none()
        if stored_token:
            stored_token.is_revoked = True
            await self.db.commit()
            return True
        return False

    async def get_user_profile(self, user: User, tenant: Tenant, outlet: Outlet | None) -> UserProfileData:
        """Constructs profile summary with active tenant context."""
        tu_stmt = select(TenantUser).where(
            TenantUser.tenant_id == tenant.id,
            TenantUser.user_id == user.id,
        )
        tu_res = await self.db.execute(tu_stmt)
        tu = tu_res.scalar_one_or_none()
        role = tu.role if tu else "owner"

        sub_stmt = select(Subscription).where(Subscription.tenant_id == tenant.id)
        sub_res = await self.db.execute(sub_stmt)
        sub = sub_res.scalar_one_or_none()

        return UserProfileData(
            user=UserSummary(
                id=user.id,
                full_name=user.full_name,
                email=user.email,
                phone=user.phone,
                user_type=user.user_type,
                role=role,
            ),
            tenant=TenantSummary(
                id=tenant.id,
                name=tenant.name,
                slug=tenant.slug,
            ),
            outlet=OutletSummary(id=outlet.id, name=outlet.name) if outlet else None,
            subscription=SubscriptionSummary(
                plan=sub.plan if sub else "free",
                status=sub.status if sub else "active",
            ),
        )
