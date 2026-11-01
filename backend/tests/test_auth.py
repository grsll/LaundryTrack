import secrets
import pytest


def generate_unique_registration_data():
    rand_suffix = secrets.token_hex(4)
    return {
        "full_name": f"Owner {rand_suffix}",
        "email": f"owner_{rand_suffix}@laundrytest.com",
        "phone": f"0812{secrets.randbelow(100000000):08d}",
        "password": "SecurePassword123!",
        "business_name": f"Laundry Barokah {rand_suffix}",
        "outlet_name": "Outlet Utama",
        "outlet_address": "Jl. Merdeka No. 1",
        "outlet_phone": "081299990000",
    }


def test_register_business_success(client):
    """Verify that business registration creates all entities atomically and issues tokens."""
    data = generate_unique_registration_data()
    response = client.post("/api/v1/auth/register", json=data)
    assert response.status_code == 201
    res = response.json()
    assert res["success"] is True

    auth_data = res["data"]
    # Verify User
    assert auth_data["user"]["email"] == data["email"]
    assert auth_data["user"]["full_name"] == data["full_name"]
    assert auth_data["user"]["role"] == "owner"

    # Verify Tenant & Outlet
    assert auth_data["tenant"]["name"] == data["business_name"]
    assert "slug" in auth_data["tenant"]
    assert auth_data["outlet"]["name"] == "Outlet Utama"

    # Verify Subscription
    assert auth_data["subscription"]["plan"] == "free"
    assert auth_data["subscription"]["status"] == "active"

    # Verify Tokens
    tokens = auth_data["tokens"]
    assert tokens["access_token"]
    assert tokens["refresh_token"]
    assert tokens["token_type"] == "bearer"
    assert tokens["expires_in"] > 0


def test_register_business_duplicate_email(client):
    """Verify that registering with an existing email returns 409 Conflict."""
    data = generate_unique_registration_data()
    # First registration
    res1 = client.post("/api/v1/auth/register", json=data)
    assert res1.status_code == 201

    # Second registration with same email but different phone
    dup_data = data.copy()
    dup_data["phone"] = f"0813{secrets.randbelow(100000000):08d}"
    dup_data["business_name"] = "Different Business"
    res2 = client.post("/api/v1/auth/register", json=dup_data)
    assert res2.status_code == 409
    err = res2.json()
    assert err["error"]["code"] == "EMAIL_ALREADY_EXISTS"


def test_register_business_duplicate_phone(client):
    """Verify that registering with an existing phone returns 409 Conflict."""
    data = generate_unique_registration_data()
    res1 = client.post("/api/v1/auth/register", json=data)
    assert res1.status_code == 201

    dup_data = data.copy()
    dup_data["email"] = f"diff_{secrets.token_hex(4)}@laundrytest.com"
    dup_data["business_name"] = "Different Business"
    res2 = client.post("/api/v1/auth/register", json=dup_data)
    assert res2.status_code == 409
    err = res2.json()
    assert err["error"]["code"] == "PHONE_ALREADY_EXISTS"


def test_login_success_with_email_and_phone(client):
    """Verify login works interchangeably with email or phone number."""
    data = generate_unique_registration_data()
    reg_res = client.post("/api/v1/auth/register", json=data)
    assert reg_res.status_code == 201

    # Login via Email
    login_email_res = client.post(
        "/api/v1/auth/login",
        json={"email_or_phone": data["email"], "password": data["password"]},
    )
    assert login_email_res.status_code == 200
    assert login_email_res.json()["data"]["tokens"]["access_token"]

    # Login via Phone
    login_phone_res = client.post(
        "/api/v1/auth/login",
        json={"email_or_phone": data["phone"], "password": data["password"]},
    )
    assert login_phone_res.status_code == 200
    assert login_phone_res.json()["data"]["tokens"]["access_token"]


def test_login_invalid_credentials(client):
    """Verify that incorrect password returns 401 Unauthorized."""
    data = generate_unique_registration_data()
    client.post("/api/v1/auth/register", json=data)

    res = client.post(
        "/api/v1/auth/login",
        json={"email_or_phone": data["email"], "password": "WrongPassword!"},
    )
    assert res.status_code == 401
    assert res.json()["error"]["code"] == "INVALID_CREDENTIALS"


def test_refresh_token_rotation_and_revocation(client):
    """Verify refresh token rotation: old token is revoked and cannot be replayed."""
    data = generate_unique_registration_data()
    reg_res = client.post("/api/v1/auth/register", json=data)
    initial_refresh = reg_res.json()["data"]["tokens"]["refresh_token"]

    # Rotate Refresh Token
    refresh_res = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": initial_refresh},
    )
    assert refresh_res.status_code == 200
    new_tokens = refresh_res.json()
    assert new_tokens["access_token"]
    assert new_tokens["refresh_token"]
    assert new_tokens["refresh_token"] != initial_refresh

    # Replay Old Refresh Token -> Must Fail
    replay_res = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": initial_refresh},
    )
    assert replay_res.status_code == 401
    assert replay_res.json()["error"]["code"] == "INVALID_REFRESH_TOKEN"


def test_logout_revokes_session(client):
    """Verify that logout revokes active refresh token."""
    data = generate_unique_registration_data()
    reg_res = client.post("/api/v1/auth/register", json=data)
    refresh_token = reg_res.json()["data"]["tokens"]["refresh_token"]

    # Logout
    logout_res = client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": refresh_token},
    )
    assert logout_res.status_code == 200
    assert logout_res.json()["success"] is True

    # Attempting to refresh with logged-out token must fail
    refresh_res = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert refresh_res.status_code == 401


def test_get_me_authenticated_endpoint(client):
    """Verify GET /api/v1/auth/me resolves active user, tenant, and outlet context."""
    data = generate_unique_registration_data()
    reg_res = client.post("/api/v1/auth/register", json=data)
    access_token = reg_res.json()["data"]["tokens"]["access_token"]

    headers = {"Authorization": f"Bearer {access_token}"}
    me_res = client.get("/api/v1/auth/me", headers=headers)
    assert me_res.status_code == 200
    profile = me_res.json()["data"]

    assert profile["user"]["email"] == data["email"]
    assert profile["user"]["role"] == "owner"
    assert profile["tenant"]["name"] == data["business_name"]
    assert profile["outlet"]["name"] == "Outlet Utama"
    assert profile["subscription"]["plan"] == "free"


def test_tenant_slug_collision_deduplication(client):
    """Verify that colliding business names produce unique, deduplicated slugs."""
    shared_name = f"Barokah Laundry {secrets.token_hex(3)}"
    data1 = generate_unique_registration_data()
    data1["business_name"] = shared_name
    res1 = client.post("/api/v1/auth/register", json=data1)
    assert res1.status_code == 201
    slug1 = res1.json()["data"]["tenant"]["slug"]

    data2 = generate_unique_registration_data()
    data2["business_name"] = shared_name
    res2 = client.post("/api/v1/auth/register", json=data2)
    assert res2.status_code == 201
    slug2 = res2.json()["data"]["tenant"]["slug"]

    assert slug1 != slug2
    assert slug1 in slug2 or slug2.startswith(slug1)


@pytest.mark.asyncio
async def test_inactive_user_login_rejected():
    """Verify that AuthService strictly rejects inactive users with 403 ACCOUNT_INACTIVE."""
    from unittest.mock import AsyncMock, MagicMock
    from app.modules.auth.service import AuthService
    from app.modules.auth.schemas import LoginRequest
    from app.core.exceptions import AppException
    from app.core.security import hash_password

    mock_db = AsyncMock()
    mock_user = MagicMock()
    mock_user.email = "inactive@test.com"
    mock_user.phone = "081234567890"
    mock_user.hashed_password = hash_password("ValidPassword123!")
    mock_user.is_active = False

    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = mock_user
    mock_db.execute.return_value = mock_result

    service = AuthService(mock_db)
    payload = LoginRequest(email_or_phone="inactive@test.com", password="ValidPassword123!")

    with pytest.raises(AppException) as exc_info:
        await service.authenticate_user(payload)

    assert exc_info.value.status_code == 403
    assert exc_info.value.code == "ACCOUNT_INACTIVE"

