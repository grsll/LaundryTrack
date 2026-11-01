from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.dependencies import get_current_outlet, get_current_tenant, get_current_user
from app.modules.auth.schemas import (
    AuthResponse,
    LoginRequest,
    RefreshTokenRequest,
    RegisterBusinessRequest,
    SimpleMessageResponse,
    TokenResponse,
    UserProfileResponse,
)
from app.modules.auth.service import AuthService
from app.modules.outlets.models import Outlet
from app.modules.tenants.models import Tenant
from app.modules.users.models import User

router = APIRouter(prefix="/auth", tags=["Authentication & Multi-Tenancy"])


@router.post(
    "/register",
    response_model=AuthResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Daftar Bisnis Baru (Atomic Onboarding)",
    description="Mendaftarkan pemilik laundry, tenant bisnis, outlet pertama, dan paket langganan Free secara atomik.",
)
async def register(
    payload: RegisterBusinessRequest,
    db: AsyncSession = Depends(get_db),
):
    service = AuthService(db)
    auth_data = await service.register_business(payload)
    return AuthResponse(success=True, data=auth_data)


@router.post(
    "/login",
    response_model=AuthResponse,
    status_code=status.HTTP_200_OK,
    summary="Login Staf Bisnis",
    description="Masuk menggunakan email atau nomor telepon dan kata sandi.",
)
async def login(
    payload: LoginRequest,
    db: AsyncSession = Depends(get_db),
):
    service = AuthService(db)
    auth_data = await service.authenticate_user(payload)
    return AuthResponse(success=True, data=auth_data)


@router.post(
    "/refresh",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
    summary="Perbarui Access Token (Token Rotation)",
    description="Menukarkan refresh token aktif dengan access token baru dan refresh token baru.",
)
async def refresh_tokens(
    payload: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db),
):
    service = AuthService(db)
    token_response = await service.refresh_tokens(payload.refresh_token)
    return token_response


@router.post(
    "/logout",
    response_model=SimpleMessageResponse,
    status_code=status.HTTP_200_OK,
    summary="Logout & Revoke Sesi",
    description="Mencabut status aktif dari refresh token.",
)
async def logout(
    payload: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db),
):
    service = AuthService(db)
    await service.logout_user(payload.refresh_token)
    return SimpleMessageResponse(success=True, message="Berhasil logout.")


@router.get(
    "/me",
    response_model=UserProfileResponse,
    status_code=status.HTTP_200_OK,
    summary="Profil Pengguna & Tenant Aktif",
    description="Mengembalikan informasi pengguna aktif, peran, bisnis, dan outlet yang terotorisasi.",
)
async def get_me(
    current_user: User = Depends(get_current_user),
    tenant: Tenant = Depends(get_current_tenant),
    outlet: Outlet = Depends(get_current_outlet),
    db: AsyncSession = Depends(get_db),
):
    service = AuthService(db)
    profile_data = await service.get_user_profile(current_user, tenant, outlet)
    return UserProfileResponse(success=True, data=profile_data)
