import secrets
import pytest


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


def test_create_and_get_customer_success(client):
    """Verify that an authenticated user can create and retrieve a customer record."""
    headers, _ = register_and_get_auth(client)

    customer_payload = {
        "name": "Ibu Siti Aisyah",
        "phone": "081234567891",
        "email": "siti.aisyah@gmail.com",
        "address": "Jl. Melati No. 15, RT 02/05",
        "notes": "Alergi deterjen wangi menyengat, gunakan pewangi lavender lembut.",
    }
    create_res = client.post("/api/v1/customers", json=customer_payload, headers=headers)
    assert create_res.status_code == 201
    created = create_res.json()["data"]
    assert created["name"] == customer_payload["name"]
    assert created["phone"] == customer_payload["phone"]
    assert created["is_active"] is True
    customer_id = created["id"]

    # Retrieve customer
    get_res = client.get(f"/api/v1/customers/{customer_id}", headers=headers)
    assert get_res.status_code == 200
    retrieved = get_res.json()["data"]
    assert retrieved["id"] == customer_id
    assert retrieved["notes"] == customer_payload["notes"]


def test_list_and_search_customers(client):
    """Verify customer listing, pagination, and keyword search by name or phone."""
    headers, _ = register_and_get_auth(client)

    # Create 3 distinct customers
    c1 = {"name": "Budi Santoso", "phone": "081211112222", "address": "Jl. Mawar"}
    c2 = {"name": "Budi Haryanto", "phone": "081233334444", "address": "Jl. Anggrek"}
    c3 = {"name": "Dewi Sartika", "phone": "081255556666", "address": "Jl. Cempaka"}

    for c in [c1, c2, c3]:
        res = client.post("/api/v1/customers", json=c, headers=headers)
        assert res.status_code == 201

    # List all
    list_res = client.get("/api/v1/customers", headers=headers)
    assert list_res.status_code == 200
    meta = list_res.json()["meta"]
    assert meta["total"] >= 3

    # Search by name "Budi"
    search_name_res = client.get("/api/v1/customers?q=Budi", headers=headers)
    assert search_name_res.status_code == 200
    results_name = search_name_res.json()["data"]
    assert len(results_name) == 2
    for r in results_name:
        assert "Budi" in r["name"]

    # Search by phone "5555"
    search_phone_res = client.get("/api/v1/customers?q=5555", headers=headers)
    assert search_phone_res.status_code == 200
    results_phone = search_phone_res.json()["data"]
    assert len(results_phone) == 1
    assert results_phone[0]["name"] == "Dewi Sartika"


def test_update_and_archive_customer(client):
    """Verify partial updating and soft-deleting/archiving customer."""
    headers, _ = register_and_get_auth(client)

    create_res = client.post(
        "/api/v1/customers",
        json={"name": "Ahmad Dani", "phone": "081987654321"},
        headers=headers,
    )
    customer_id = create_res.json()["data"]["id"]

    # Update phone and address
    update_res = client.patch(
        f"/api/v1/customers/{customer_id}",
        json={"phone": "081999888777", "address": "Jl. Baru No. 8"},
        headers=headers,
    )
    assert update_res.status_code == 200
    updated = update_res.json()["data"]
    assert updated["phone"] == "081999888777"
    assert updated["address"] == "Jl. Baru No. 8"

    # Soft delete / archive
    archive_res = client.delete(f"/api/v1/customers/{customer_id}", headers=headers)
    assert archive_res.status_code == 200
    assert archive_res.json()["data"]["is_active"] is False

    # Verify customer still exists for audit trail but marked inactive
    get_res = client.get(f"/api/v1/customers/{customer_id}", headers=headers)
    assert get_res.status_code == 200
    assert get_res.json()["data"]["is_active"] is False


def test_customer_summary_and_orders_baseline(client):
    """Verify customer summary metrics and historical orders endpoint."""
    headers, _ = register_and_get_auth(client)

    create_res = client.post(
        "/api/v1/customers",
        json={"name": "Rina Gunawan", "phone": "081777888999"},
        headers=headers,
    )
    customer_id = create_res.json()["data"]["id"]

    # Summary
    summary_res = client.get(f"/api/v1/customers/{customer_id}/summary", headers=headers)
    assert summary_res.status_code == 200
    summary = summary_res.json()["data"]
    assert summary["customer_name"] == "Rina Gunawan"
    assert summary["total_orders"] == 0

    # Orders baseline
    orders_res = client.get(f"/api/v1/customers/{customer_id}/orders", headers=headers)
    assert orders_res.status_code == 200
    assert orders_res.json()["data"] == []


def test_customer_cross_tenant_isolation_idor_prevention(client):
    """Verify strict tenant isolation: Tenant B cannot view, update, or archive Tenant A's customer."""
    headers_a, _ = register_and_get_auth(client)
    headers_b, _ = register_and_get_auth(client)

    # Tenant A creates customer
    res_a = client.post(
        "/api/v1/customers",
        json={"name": "Pelanggan Rahasia Tenant A", "phone": "081299991111"},
        headers=headers_a,
    )
    customer_a_id = res_a.json()["data"]["id"]

    # Tenant B attempts to read Tenant A's customer -> Must be 404
    probe_get = client.get(f"/api/v1/customers/{customer_a_id}", headers=headers_b)
    assert probe_get.status_code == 404
    assert probe_get.json()["error"]["code"] == "CUSTOMER_NOT_FOUND"

    # Tenant B attempts to update Tenant A's customer -> Must be 404
    probe_update = client.patch(
        f"/api/v1/customers/{customer_a_id}",
        json={"name": "Hacked Name"},
        headers=headers_b,
    )
    assert probe_update.status_code == 404
    assert probe_update.json()["error"]["code"] == "CUSTOMER_NOT_FOUND"

    # Tenant B attempts to archive Tenant A's customer -> Must be 404
    probe_delete = client.delete(f"/api/v1/customers/{customer_a_id}", headers=headers_b)
    assert probe_delete.status_code == 404
    assert probe_delete.json()["error"]["code"] == "CUSTOMER_NOT_FOUND"


def test_customer_search_with_wildcards_and_whitespace_trimming(client):
    """Verify search handles wildcard characters safely and trims phone inputs."""
    headers, _ = register_and_get_auth(client)

    # Create customer with padded whitespace in phone
    res = client.post(
        "/api/v1/customers",
        json={"name": "Wildcard Customer 100%", "phone": "  081298761234  "},
        headers=headers,
    )
    assert res.status_code == 201
    assert res.json()["data"]["phone"] == "081298761234"

    # Search with literal "%"
    search_res = client.get("/api/v1/customers?q=%", headers=headers)
    assert search_res.status_code == 200
    assert any(c["name"] == "Wildcard Customer 100%" for c in search_res.json()["data"])


def test_customer_duplicate_phone_in_same_and_different_tenants(client):
    """Verify phone collision isolation across tenants and duplicate phone handling in same tenant."""
    headers_a, _ = register_and_get_auth(client)
    headers_b, _ = register_and_get_auth(client)
    shared_phone = f"0819{secrets.randbelow(100000000):08d}"

    # Tenant A creates customer with shared_phone
    res_a1 = client.post("/api/v1/customers", json={"name": "Customer A1", "phone": shared_phone}, headers=headers_a)
    assert res_a1.status_code == 201

    # Tenant B creates customer with the SAME phone -> Allowed & strictly isolated
    res_b = client.post("/api/v1/customers", json={"name": "Customer B1", "phone": shared_phone}, headers=headers_b)
    assert res_b.status_code == 201

    # Querying by phone in Tenant A returns ONLY Tenant A's customer
    search_a = client.get(f"/api/v1/customers?q={shared_phone}", headers=headers_a)
    assert search_a.status_code == 200
    assert len(search_a.json()["data"]) == 1
    assert search_a.json()["data"][0]["name"] == "Customer A1"


def test_customer_active_inactive_filters_and_reactivation(client):
    """Verify filtering by is_active status and reactivating an archived customer."""
    headers, _ = register_and_get_auth(client)

    c1 = client.post("/api/v1/customers", json={"name": "Active One", "phone": "081111111"}, headers=headers).json()["data"]
    c2 = client.post("/api/v1/customers", json={"name": "To Archive", "phone": "082222222"}, headers=headers).json()["data"]

    # Archive c2
    client.delete(f"/api/v1/customers/{c2['id']}", headers=headers)

    # Filter is_active=true
    res_active = client.get("/api/v1/customers?is_active=true", headers=headers)
    assert res_active.status_code == 200
    active_ids = [c["id"] for c in res_active.json()["data"]]
    assert c1["id"] in active_ids
    assert c2["id"] not in active_ids

    # Filter is_active=false
    res_inactive = client.get("/api/v1/customers?is_active=false", headers=headers)
    assert res_inactive.status_code == 200
    inactive_ids = [c["id"] for c in res_inactive.json()["data"]]
    assert c2["id"] in inactive_ids
    assert c1["id"] not in inactive_ids

    # Reactivate c2 via PATCH
    patch_res = client.patch(f"/api/v1/customers/{c2['id']}", json={"is_active": True}, headers=headers)
    assert patch_res.status_code == 200
    assert patch_res.json()["data"]["is_active"] is True


def test_customer_idor_subresources_and_list_isolation(client):
    """Ensure Tenant B cannot access Tenant A's customer sub-resources or list."""
    headers_a, _ = register_and_get_auth(client)
    headers_b, _ = register_and_get_auth(client)

    res_a = client.post("/api/v1/customers", json={"name": "Secret Customer A", "phone": "0819999000"}, headers=headers_a)
    cust_a_id = res_a.json()["data"]["id"]

    # 1. Tenant B listing must NOT leak Tenant A's customer
    list_b = client.get("/api/v1/customers", headers=headers_b)
    assert list_b.status_code == 200
    assert cust_a_id not in [c["id"] for c in list_b.json()["data"]]

    # 2. Tenant B searching must NOT leak Tenant A's customer
    search_b = client.get("/api/v1/customers?q=Secret", headers=headers_b)
    assert search_b.status_code == 200
    assert len(search_b.json()["data"]) == 0

    # 3. Tenant B probing sub-resources must return 404
    summary_b = client.get(f"/api/v1/customers/{cust_a_id}/summary", headers=headers_b)
    assert summary_b.status_code == 404
    assert summary_b.json()["error"]["code"] == "CUSTOMER_NOT_FOUND"

    orders_b = client.get(f"/api/v1/customers/{cust_a_id}/orders", headers=headers_b)
    assert orders_b.status_code == 404
    assert orders_b.json()["error"]["code"] == "CUSTOMER_NOT_FOUND"


