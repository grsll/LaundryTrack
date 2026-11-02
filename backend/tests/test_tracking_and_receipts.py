from decimal import Decimal
import secrets
import pytest


def register_and_get_auth(client):
    """Helper to register a fresh business and return headers and auth data."""
    rand_suffix = secrets.token_hex(4)
    data = {
        "full_name": f"Owner {rand_suffix}",
        "email": f"owner_{rand_suffix}@laundrytest.com",
        "phone": f"0812{secrets.randbelow(100000000):08d}",
        "password": "SecurePassword123!",
        "business_name": f"Laundry {rand_suffix}",
        "outlet_name": "Outlet Pusat",
    }
    res = client.post("/api/v1/auth/register", json=data)
    assert res.status_code == 201
    auth_data = res.json()["data"]
    headers = {"Authorization": f"Bearer {auth_data['tokens']['access_token']}"}
    return headers, auth_data


def create_sample_order(client, headers):
    """Creates a sample customer, service, and order with items."""
    c_res = client.post(
        "/api/v1/customers",
        headers=headers,
        json={
            "name": "Budi Santoso",
            "phone": "081234567890",
            "address": "Jl. Mawar No. 45",
        },
    )
    assert c_res.status_code == 201
    customer = c_res.json()["data"]

    s_res = client.post(
        "/api/v1/services",
        headers=headers,
        json={
            "name": "Cuci Komplit Reguler",
            "price_type": "per_kg",
            "unit": "kg",
            "price": "10000.00",
        },
    )
    assert s_res.status_code == 201
    service = s_res.json()["data"]

    order_payload = {
        "customer_id": customer["id"],
        "items": [
            {
                "service_id": service["id"],
                "quantity": "2.50",
            }
        ],
        "discount_amount": "0.00",
        "notes": "Jangan pakai pewangi melati",
    }
    o_res = client.post("/api/v1/orders", headers=headers, json=order_payload)
    assert o_res.status_code == 201
    order = o_res.json()["data"]
    return customer, service, order


def test_public_tracking_success_and_privacy_masking(client):
    """
    Test public tracking endpoint:
    - Accessible without authorization headers.
    - Masks customer name and phone.
    - Exposes order status, items, subtotal, and timeline.
    - Does NOT expose internal database IDs (tenant_id, customer_id, outlet_id).
    """
    headers, _ = register_and_get_auth(client)
    customer, service, order = create_sample_order(client, headers)

    token = order["tracking_token"]
    assert token is not None
    assert len(token) > 20

    # Request tracking WITHOUT auth header
    res = client.get(f"/api/v1/tracking/{token}")
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    data = body["data"]

    # Verify order metadata
    assert data["order_number"] == order["order_number"]
    assert data["status"] == "received"
    assert data["payment_status"] == "unpaid"
    assert Decimal(data["total_amount"]) == Decimal("25000.00")

    # Privacy masking verification
    assert data["customer_name_masked"] == "Budi S*****"
    assert data["customer_phone_masked"] == "0812****7890"
    assert "Budi Santoso" not in data.values()
    assert "081234567890" not in data.values()

    # Zero internal database IDs leaked in root response
    assert "tenant_id" not in data
    assert "customer_id" not in data
    assert "outlet_id" not in data
    assert "created_by_id" not in data

    # Verify items and timeline
    assert len(data["items"]) == 1
    assert data["items"][0]["service_name"] == "Cuci Komplit Reguler"
    assert len(data["timeline"]) >= 1


def test_public_tracking_invalid_token_returns_404(client):
    """Non-existent or forged token must return 404."""
    res = client.get("/api/v1/tracking/non_existent_token_123456789")
    assert res.status_code == 404
    body = res.json()
    assert body["success"] is False
    assert body["error"]["code"] == "TRACKING_NOT_FOUND"


def test_tracking_link_and_regeneration(client):
    """
    Test retrieving tracking link and regenerating the token.
    Regeneration invalidates the old public tracking token.
    """
    headers, _ = register_and_get_auth(client)
    customer, service, order = create_sample_order(client, headers)
    order_id = order["id"]

    # 1. Get tracking link
    res = client.get(f"/api/v1/orders/{order_id}/tracking-link", headers=headers)
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    link_data = body["data"]

    old_token = link_data["tracking_token"]
    assert old_token == order["tracking_token"]
    assert old_token in link_data["tracking_url"]
    assert "whatsapp_share_text" in link_data
    assert order["order_number"] in link_data["whatsapp_share_text"]

    # Verify old token works publicly
    pub_old = client.get(f"/api/v1/tracking/{old_token}")
    assert pub_old.status_code == 200

    # 2. Regenerate tracking token
    regen_res = client.post(
        f"/api/v1/orders/{order_id}/tracking-link/regenerate",
        headers=headers,
    )
    assert regen_res.status_code == 200
    regen_data = regen_res.json()["data"]
    new_token = regen_data["tracking_token"]
    assert new_token != old_token

    # Verify old token is now invalidated (returns 404)
    old_check = client.get(f"/api/v1/tracking/{old_token}")
    assert old_check.status_code == 404

    # Verify new token works publicly
    new_check = client.get(f"/api/v1/tracking/{new_token}")
    assert new_check.status_code == 200


def test_get_receipt_digital_details(client):
    """Test full digital receipt detail retrieval with staff authorization."""
    headers, _ = register_and_get_auth(client)
    customer, service, order = create_sample_order(client, headers)
    order_id = order["id"]

    res = client.get(f"/api/v1/orders/{order_id}/receipt", headers=headers)
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    receipt = body["data"]

    assert receipt["order_number"] == order["order_number"]
    assert receipt["customer_name"] == "Budi Santoso"
    assert receipt["customer_phone"] == "081234567890"
    assert receipt["outlet_name"] == "Outlet Pusat"
    assert len(receipt["items"]) == 1
    assert Decimal(receipt["total_amount"]) == Decimal("25000.00")
    assert receipt["reprint_count"] == 0


def test_generate_receipt_pdf(client):
    """Test binary PDF stream generation."""
    headers, _ = register_and_get_auth(client)
    customer, service, order = create_sample_order(client, headers)
    order_id = order["id"]

    res = client.get(f"/api/v1/orders/{order_id}/receipt/pdf", headers=headers)
    assert res.status_code == 200
    assert res.headers["content-type"] == "application/pdf"
    assert res.content.startswith(b"%PDF-")
    assert len(res.content) > 1000


def test_generate_thermal_html(client):
    """Test 58mm/80mm thermal receipt HTML generation."""
    headers, _ = register_and_get_auth(client)
    customer, service, order = create_sample_order(client, headers)
    order_id = order["id"]

    res = client.get(
        f"/api/v1/orders/{order_id}/receipt/thermal?width=58",
        headers=headers,
    )
    assert res.status_code == 200
    assert "text/html" in res.headers["content-type"]
    html_text = res.text
    assert order["order_number"] in html_text
    assert "OUTLET PUSAT" in html_text
    assert "58mm" in html_text
    assert "data:image/png;base64," in html_text


def test_receipt_reprint_audit_logging(client):
    """Test recording receipt reprint increments counter and logs audit."""
    headers, _ = register_and_get_auth(client)
    customer, service, order = create_sample_order(client, headers)
    order_id = order["id"]

    # Initial check
    rec1 = client.get(f"/api/v1/orders/{order_id}/receipt", headers=headers).json()["data"]
    assert rec1["reprint_count"] == 0

    # 1st reprint record
    p1 = client.post(
        f"/api/v1/orders/{order_id}/receipt/reprint",
        headers=headers,
        json={"print_type": "thermal", "notes": "Kertas macet di kasir"},
    )
    assert p1.status_code == 200
    p1_data = p1.json()["data"]
    assert p1_data["reprint_count"] == 1
    assert p1_data["print_type"] == "thermal"

    # 2nd reprint record
    p2 = client.post(
        f"/api/v1/orders/{order_id}/receipt/reprint",
        headers=headers,
        json={"print_type": "pdf", "notes": "Pelanggan minta cetak ulang"},
    )
    assert p2.status_code == 200
    assert p2.json()["data"]["reprint_count"] == 2

    # Verify receipt detail reflects 2 reprints
    rec2 = client.get(f"/api/v1/orders/{order_id}/receipt", headers=headers).json()["data"]
    assert rec2["reprint_count"] == 2
    assert rec2["receipt_printed_at"] is not None


def test_tenant_isolation_on_receipt_and_tracking_admin(client):
    """Ensure tenant A cannot access or reprint receipts belonging to tenant B."""
    headers_a, _ = register_and_get_auth(client)
    headers_b, _ = register_and_get_auth(client)

    _, _, order_b = create_sample_order(client, headers_b)
    order_b_id = order_b["id"]

    # Tenant A attempts to view Tenant B's receipt
    res = client.get(f"/api/v1/orders/{order_b_id}/receipt", headers=headers_a)
    assert res.status_code == 404

    # Tenant A attempts to regenerate Tenant B's tracking token
    res = client.post(
        f"/api/v1/orders/{order_b_id}/tracking-link/regenerate",
        headers=headers_a,
    )
    assert res.status_code == 404

    # Tenant A attempts to record reprint on Tenant B's receipt
    res = client.post(
        f"/api/v1/orders/{order_b_id}/receipt/reprint",
        headers=headers_a,
        json={"print_type": "thermal"},
    )
    assert res.status_code == 404


def test_public_tracking_invalid_token_404_and_validation(client):
    """Test public tracking endpoint handles invalid tokens and parameter length bounds."""
    # Non-existent valid-length token -> 404
    non_existent = "a" * 43
    res = client.get(f"/api/v1/tracking/{non_existent}")
    assert res.status_code == 404

    # Too short token (< 20 chars) -> 422
    res_short = client.get("/api/v1/tracking/short_token")
    assert res_short.status_code == 422


def test_mask_name_and_phone_edge_cases():
    """Unit test for mask_name and mask_phone on diverse edge cases."""
    from app.modules.tracking.service import mask_name, mask_phone

    # mask_name edge cases
    assert mask_name(None) == "***"
    assert mask_name("") == "***"
    assert mask_name("   ") == "***"
    assert mask_name("Al") == "A*"
    assert mask_name("Bob") == "Bo*"
    assert mask_name("Budi Santoso") == "Budi S*****"
    assert mask_name("Muhammad Rizki Pratama") == "Muhammad R**** P*****"

    # mask_phone edge cases
    assert mask_phone(None) == ""
    assert mask_phone("") == ""
    assert mask_phone("   ") == ""
    assert mask_phone("123") == "12****"
    assert mask_phone("081234567890") == "0812****7890"


def test_thermal_width_and_reprint_validation(client):
    """Test thermal receipt width validation and reprint_type enum validation."""
    headers, _ = register_and_get_auth(client)
    _, _, order = create_sample_order(client, headers)
    order_id = order["id"]

    # Valid widths (58, 80)
    res_80 = client.get(f"/api/v1/orders/{order_id}/receipt/thermal?width=80", headers=headers)
    assert res_80.status_code == 200
    assert "80mm" in res_80.text

    # Invalid width < 40 or > 120 -> 422
    res_invalid_width = client.get(f"/api/v1/orders/{order_id}/receipt/thermal?width=20", headers=headers)
    assert res_invalid_width.status_code == 422

    # Invalid print_type enum in reprint -> 422
    res_invalid_type = client.post(
        f"/api/v1/orders/{order_id}/receipt/reprint",
        headers=headers,
        json={"print_type": "fax"},
    )
    assert res_invalid_type.status_code == 422


def test_special_characters_xss_and_xml_escaping(client):
    """Test that customer names with HTML tags or XML characters do not crash PDF and are escaped in thermal HTML."""
    headers, _ = register_and_get_auth(client)

    # Customer with potential XSS / XML markup payload
    c_res = client.post(
        "/api/v1/customers",
        headers=headers,
        json={
            "name": "<script>alert('xss')</script> & \"Budi\"",
            "phone": "081999888777",
            "address": "Jl. Gajah <Utama> & No. 1",
        },
    )
    assert c_res.status_code == 201
    customer = c_res.json()["data"]

    s_res = client.post(
        "/api/v1/services",
        headers=headers,
        json={
            "name": "Cuci <Express> & Setrika",
            "price_type": "per_kg",
            "unit": "kg",
            "price": "15000.00",
        },
    )
    assert s_res.status_code == 201
    service = s_res.json()["data"]

    o_res = client.post(
        "/api/v1/orders",
        headers=headers,
        json={
            "customer_id": customer["id"],
            "items": [{"service_id": service["id"], "quantity": "1.0"}],
        },
    )
    assert o_res.status_code == 201
    order = o_res.json()["data"]
    order_id = order["id"]

    # 1. Thermal HTML must escape the <script> and XML tags
    res_thermal = client.get(f"/api/v1/orders/{order_id}/receipt/thermal", headers=headers)
    assert res_thermal.status_code == 200
    html_content = res_thermal.text
    assert "<script>" not in html_content
    assert "&lt;script&gt;alert(&#x27;xss&#x27;)&lt;/script&gt;" in html_content
    assert "&amp; &quot;Budi&quot;" in html_content or "&amp;" in html_content

    # 2. PDF generation must succeed without SAX / XML parse exceptions
    res_pdf = client.get(f"/api/v1/orders/{order_id}/receipt/pdf", headers=headers)
    assert res_pdf.status_code == 200
    assert res_pdf.content.startswith(b"%PDF")


def test_resolve_base_url_anti_phishing(client):
    """Test resolve_base_url ignores untrusted origins and falls back to safe origin."""
    headers, _ = register_and_get_auth(client)
    _, _, order = create_sample_order(client, headers)
    order_id = order["id"]

    # Client sends malicious Origin header
    malicious_origin = "https://evil-phishing-laundry.com"
    res = client.get(
        f"/api/v1/orders/{order_id}/tracking-link",
        headers={**headers, "Origin": malicious_origin},
    )
    assert res.status_code == 200
    data = res.json()["data"]
    # Malicious origin MUST NOT be reflected in tracking URL or WhatsApp message
    assert "evil-phishing-laundry.com" not in data["tracking_url"]
    assert "evil-phishing-laundry.com" not in data["whatsapp_share_text"]
