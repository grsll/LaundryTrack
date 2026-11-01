from decimal import Decimal
import secrets
import pytest
from app.modules.services.schemas import PriceType


def register_and_get_auth(client):
    """Helper to register a fresh business and return access token and auth data."""
    rand_suffix = secrets.token_hex(4)
    data = {
        "full_name": f"Owner {rand_suffix}",
        "email": f"owner_{rand_suffix}@laundrytest.com",
        "phone": f"0812{secrets.randbelow(100000000):08d}",
        "password": "SecurePassword123!",
        "business_name": f"Laundry {rand_suffix}",
        "outlet_name": "Outlet Utama",
    }
    res = client.post("/api/v1/auth/register", json=data)
    assert res.status_code == 201
    auth_data = res.json()["data"]
    headers = {"Authorization": f"Bearer {auth_data['tokens']['access_token']}"}
    return headers, auth_data


def test_create_and_get_service_kiloan_and_satuan(client):
    """Verify creating and retrieving services with per_kg and per_item price models."""
    headers, _ = register_and_get_auth(client)

    # 1. Create per_kg service
    kg_payload = {
        "name": "Cuci Komplit Reguler",
        "description": "Cuci bersih, pengeringan, setrika rapi, dan kemasan plastik",
        "price_type": "per_kg",
        "unit": "kg",
        "price": "8000.00",
        "estimated_duration_hours": 48,
    }
    kg_res = client.post("/api/v1/services", json=kg_payload, headers=headers)
    assert kg_res.status_code == 201
    kg_service = kg_res.json()["data"]
    assert kg_service["name"] == kg_payload["name"]
    assert kg_service["price_type"] == "per_kg"
    assert Decimal(kg_service["price"]) == Decimal("8000.00")
    assert kg_service["estimated_duration_hours"] == 48
    kg_id = kg_service["id"]

    # 2. Create per_item service
    item_payload = {
        "name": "Bed Cover King Size",
        "description": "Pencucian khusus selimut besar",
        "price_type": "per_item",
        "unit": "pcs",
        "price": "35000.00",
        "estimated_duration_hours": 72,
    }
    item_res = client.post("/api/v1/services", json=item_payload, headers=headers)
    assert item_res.status_code == 201
    item_service = item_res.json()["data"]
    assert item_service["name"] == item_payload["name"]
    assert item_service["price_type"] == "per_item"
    assert Decimal(item_service["price"]) == Decimal("35000.00")

    # 3. Retrieve per_kg service
    get_res = client.get(f"/api/v1/services/{kg_id}", headers=headers)
    assert get_res.status_code == 200
    assert get_res.json()["data"]["id"] == kg_id


def test_service_price_validation_must_be_positive(client):
    """Verify that zero or negative service pricing is rejected with 422 Unprocessable Entity."""
    headers, _ = register_and_get_auth(client)

    zero_payload = {
        "name": "Layanan Gratis Ilegal",
        "price_type": "per_kg",
        "unit": "kg",
        "price": "0.00",
    }
    res = client.post("/api/v1/services", json=zero_payload, headers=headers)
    assert res.status_code == 422


def test_list_and_filter_services(client):
    """Verify listing services with search and price_type filter."""
    headers, _ = register_and_get_auth(client)

    # Add services
    s1 = {"name": "Cuci Kering Saja", "price_type": "per_kg", "unit": "kg", "price": "6000.00"}
    s2 = {"name": "Setrika Kilat 6 Jam", "price_type": "per_kg", "unit": "kg", "price": "10000.00"}
    s3 = {"name": "Jaket Kulit Premium", "price_type": "per_item", "unit": "pcs", "price": "45000.00"}

    for s in [s1, s2, s3]:
        r = client.post("/api/v1/services", json=s, headers=headers)
        assert r.status_code == 201

    # Filter by price_type=per_kg
    res_kg = client.get("/api/v1/services?price_type=per_kg", headers=headers)
    assert res_kg.status_code == 200
    kg_items = res_kg.json()["data"]
    assert len(kg_items) == 2
    for item in kg_items:
        assert item["price_type"] == "per_kg"

    # Search keyword "Jaket"
    res_search = client.get("/api/v1/services?q=Jaket", headers=headers)
    assert res_search.status_code == 200
    search_items = res_search.json()["data"]
    assert len(search_items) == 1
    assert search_items[0]["name"] == "Jaket Kulit Premium"


def test_update_and_archive_service(client):
    """Verify updating service price and soft-deactivating service."""
    headers, _ = register_and_get_auth(client)

    create_res = client.post(
        "/api/v1/services",
        json={"name": "Dry Clean Jas", "price_type": "per_item", "unit": "pcs", "price": "50000.00"},
        headers=headers,
    )
    service_id = create_res.json()["data"]["id"]

    # Update price to 55,000.00
    update_res = client.patch(
        f"/api/v1/services/{service_id}",
        json={"price": "55000.00", "description": "Termasuk hanger dan cover pakaian"},
        headers=headers,
    )
    assert update_res.status_code == 200
    assert Decimal(update_res.json()["data"]["price"]) == Decimal("55000.00")
    assert update_res.json()["data"]["description"] == "Termasuk hanger dan cover pakaian"

    # Deactivate / archive service
    archive_res = client.delete(f"/api/v1/services/{service_id}", headers=headers)
    assert archive_res.status_code == 200
    assert archive_res.json()["data"]["is_active"] is False

    # Check that inactive service is marked inactive
    get_res = client.get(f"/api/v1/services/{service_id}", headers=headers)
    assert get_res.status_code == 200
    assert get_res.json()["data"]["is_active"] is False


def test_service_cross_tenant_isolation_idor_prevention(client):
    """Verify strict tenant isolation: Tenant B cannot access or modify Tenant A's services."""
    headers_a, _ = register_and_get_auth(client)
    headers_b, _ = register_and_get_auth(client)

    # Tenant A creates service
    create_a = client.post(
        "/api/v1/services",
        json={"name": "Layanan Rahasia Tenant A", "price_type": "per_kg", "unit": "kg", "price": "12000.00"},
        headers=headers_a,
    )
    service_a_id = create_a.json()["data"]["id"]

    # Tenant B tries to get Tenant A's service -> 404
    probe_get = client.get(f"/api/v1/services/{service_a_id}", headers=headers_b)
    assert probe_get.status_code == 404
    assert probe_get.json()["error"]["code"] == "SERVICE_NOT_FOUND"

    # Tenant B tries to update Tenant A's service -> 404
    probe_patch = client.patch(
        f"/api/v1/services/{service_a_id}",
        json={"price": "1000.00"},
        headers=headers_b,
    )
    assert probe_patch.status_code == 404
    assert probe_patch.json()["error"]["code"] == "SERVICE_NOT_FOUND"

    # Tenant B tries to delete Tenant A's service -> 404
    probe_del = client.delete(f"/api/v1/services/{service_a_id}", headers=headers_b)
    assert probe_del.status_code == 404
    assert probe_del.json()["error"]["code"] == "SERVICE_NOT_FOUND"


def test_service_price_validation_negative_price(client):
    """Verify that negative service pricing is rejected with 422 Unprocessable Entity."""
    headers, _ = register_and_get_auth(client)

    negative_payload = {
        "name": "Layanan Harga Negatif",
        "price_type": "per_kg",
        "unit": "kg",
        "price": "-5000.00",
    }
    res = client.post("/api/v1/services", json=negative_payload, headers=headers)
    assert res.status_code == 422


def test_service_creation_restricted_to_owner_and_admin(client):
    """Verify that a user without owner/admin role (e.g. cashier) cannot create services."""
    from app.core.security import create_access_token

    headers_owner, auth_data = register_and_get_auth(client)
    user_id = auth_data["user"]["id"]
    tenant_id = auth_data["tenant"]["id"]
    outlet_id = auth_data["outlet"]["id"]

    # Cashier JWT claim
    cashier_token = create_access_token({
        "sub": user_id,
        "tenant_id": tenant_id,
        "outlet_id": outlet_id,
        "role": "cashier",
    })
    headers_cashier = {"Authorization": f"Bearer {cashier_token}"}

    res = client.post(
        "/api/v1/services",
        json={"name": "Layanan Ilegal Kasir", "price_type": "per_kg", "unit": "kg", "price": "10000.00"},
        headers=headers_cashier,
    )
    assert res.status_code == 403
    assert res.json()["error"]["code"] == "INSUFFICIENT_PERMISSIONS"


def test_service_filter_per_item_and_invalid_price_type(client):
    """Verify filter price_type=per_item, invalid enum rejection, and combined filters."""
    headers, _ = register_and_get_auth(client)

    client.post("/api/v1/services", json={"name": "Kiloan A", "price_type": "per_kg", "unit": "kg", "price": "7000.00"}, headers=headers)
    client.post("/api/v1/services", json={"name": "Satuan Boneka", "price_type": "per_item", "unit": "pcs", "price": "25000.00"}, headers=headers)

    # 1. Filter per_item
    res_item = client.get("/api/v1/services?price_type=per_item", headers=headers)
    assert res_item.status_code == 200
    items = res_item.json()["data"]
    assert len(items) == 1
    assert items[0]["name"] == "Satuan Boneka"
    assert items[0]["price_type"] == "per_item"

    # 2. Invalid price_type rejected with 422
    res_invalid = client.get("/api/v1/services?price_type=meteran", headers=headers)
    assert res_invalid.status_code == 422

    # 3. Combined filter (price_type=per_item & q=Kiloan -> 0 results)
    res_combo = client.get("/api/v1/services?price_type=per_item&q=Kiloan", headers=headers)
    assert res_combo.status_code == 200
    assert len(res_combo.json()["data"]) == 0


def test_service_list_and_search_tenant_isolation(client):
    """Verify that Tenant B cannot see Tenant A's services in list or search queries."""
    headers_a, _ = register_and_get_auth(client)
    headers_b, _ = register_and_get_auth(client)

    client.post("/api/v1/services", json={
        "name": "Paket Eksklusif Tenant A", "price_type": "per_kg", "unit": "kg", "price": "20000.00"
    }, headers=headers_a)

    # Tenant B list must be empty
    list_b = client.get("/api/v1/services", headers=headers_b)
    assert list_b.status_code == 200
    assert len(list_b.json()["data"]) == 0

    # Tenant B search must be empty
    search_b = client.get("/api/v1/services?q=Eksklusif", headers=headers_b)
    assert search_b.status_code == 200
    assert len(search_b.json()["data"]) == 0


