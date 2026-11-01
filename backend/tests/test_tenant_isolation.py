import secrets
from jose import jwt
from app.core.config import settings
from app.core.security import create_access_token
from tests.test_auth import generate_unique_registration_data


def test_tenant_context_isolation_between_separate_tenants(client):
    """Verify that multiple tenants are strictly isolated and resolve their own context."""
    # Register Business A
    data_a = generate_unique_registration_data()
    res_a = client.post("/api/v1/auth/register", json=data_a)
    assert res_a.status_code == 201
    auth_a = res_a.json()["data"]
    token_a = auth_a["tokens"]["access_token"]
    tenant_id_a = auth_a["tenant"]["id"]

    # Register Business B
    data_b = generate_unique_registration_data()
    res_b = client.post("/api/v1/auth/register", json=data_b)
    assert res_b.status_code == 201
    auth_b = res_b.json()["data"]
    token_b = auth_b["tokens"]["access_token"]
    tenant_id_b = auth_b["tenant"]["id"]

    # Assert tenants have distinct IDs and slugs
    assert tenant_id_a != tenant_id_b

    # Request /auth/me as Tenant A
    me_a = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token_a}"})
    assert me_a.status_code == 200
    assert me_a.json()["data"]["tenant"]["id"] == tenant_id_a
    assert me_a.json()["data"]["tenant"]["name"] == data_a["business_name"]

    # Request /auth/me as Tenant B
    me_b = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token_b}"})
    assert me_b.status_code == 200
    assert me_b.json()["data"]["tenant"]["id"] == tenant_id_b
    assert me_b.json()["data"]["tenant"]["name"] == data_b["business_name"]


def test_forged_or_tampered_jwt_rejected(client):
    """Verify that tokens signed with an arbitrary secret or tampered claims are rejected."""
    tampered_claims = {
        "sub": "00000000-0000-0000-0000-000000000001",
        "tenant_id": "00000000-0000-0000-0000-000000000002",
        "outlet_id": "00000000-0000-0000-0000-000000000003",
        "role": "owner",
        "type": "access",
    }
    # Signed with wrong secret
    fake_token = jwt.encode(tampered_claims, "attacker_secret_key_1234567890123456", algorithm="HS256")

    response = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {fake_token}"})
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "INVALID_TOKEN"


def test_unauthenticated_request_rejected(client):
    """Verify that accessing protected endpoints without authorization returns 403/401."""
    response = client.get("/api/v1/auth/me")
    assert response.status_code == 401 or response.status_code == 403
