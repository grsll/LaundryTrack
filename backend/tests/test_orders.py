from decimal import Decimal
import re
import secrets
import pytest
from app.modules.orders.models import OrderStatus


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


def create_sample_customer_and_services(client, headers):
    """Helper to seed customer and services for order testing."""
    # Create customer
    c_res = client.post(
        "/api/v1/customers",
        headers=headers,
        json={
            "name": f"Budi Santoso {secrets.token_hex(2)}",
            "phone": f"0856{secrets.randbelow(100000000):08d}",
            "address": "Jl. Sudirman No. 45",
        },
    )
    assert c_res.status_code == 201
    customer = c_res.json()["data"]

    # Create Kiloan Service
    s1_res = client.post(
        "/api/v1/services",
        headers=headers,
        json={
            "name": "Cuci Komplit Reguler",
            "price_type": "per_kg",
            "unit": "kg",
            "price": "7000.00",
            "estimated_duration_hours": 48,
        },
    )
    assert s1_res.status_code == 201
    svc_kiloan = s1_res.json()["data"]

    # Create Satuan Service
    s2_res = client.post(
        "/api/v1/services",
        headers=headers,
        json={
            "name": "Bedcover Besar",
            "price_type": "per_item",
            "unit": "pcs",
            "price": "25000.00",
            "estimated_duration_hours": 72,
        },
    )
    assert s2_res.status_code == 201
    svc_satuan = s2_res.json()["data"]

    return customer, svc_kiloan, svc_satuan


def test_create_order_with_kiloan_and_satuan_calculations(client):
    """
    Verify creating an order with kiloan and satuan items computes Decimal
    totals correctly and snapshots service data.
    """
    headers, _ = register_and_get_auth(client)
    customer, svc_kiloan, svc_satuan = create_sample_customer_and_services(client, headers)

    order_payload = {
        "customer_id": customer["id"],
        "items": [
            {
                "service_id": svc_kiloan["id"],
                "quantity": "3.50",
                "notes": "Pewangi lavender",
            },
            {
                "service_id": svc_satuan["id"],
                "quantity": "2.00",
                "notes": "Noda teh di sudut",
            },
        ],
        "discount_amount": "5000.00",
        "notes": "Pelanggan minta selesai tepat waktu",
    }

    res = client.post("/api/v1/orders", json=order_payload, headers=headers)
    assert res.status_code == 201
    order = res.json()["data"]

    # Check order number pattern
    assert re.match(r"^LDR-\d{8}-\d{4}$", order["order_number"])

    # Calculations:
    # 3.50 * 7000 = 24500.00
    # 2.00 * 25000 = 50000.00
    # subtotal = 74500.00
    # discount = 5000.00
    # total = 69500.00
    assert Decimal(order["subtotal"]) == Decimal("74500.00")
    assert Decimal(order["discount_amount"]) == Decimal("5000.00")
    assert Decimal(order["total_amount"]) == Decimal("69500.00")
    assert Decimal(order["paid_amount"]) == Decimal("0.00")
    assert Decimal(order["remaining_amount"]) == Decimal("69500.00")
    assert order["status"] == OrderStatus.RECEIVED.value
    assert order["payment_status"] == "unpaid"
    assert order["customer_name"] == customer["name"]

    # Check items snapshot
    items = order["items"]
    assert len(items) == 2

    kiloan_item = next(it for it in items if it["service_id"] == svc_kiloan["id"])
    assert kiloan_item["service_name_snapshot"] == "Cuci Komplit Reguler"
    assert kiloan_item["price_type_snapshot"] == "per_kg"
    assert kiloan_item["unit_snapshot"] == "kg"
    assert Decimal(kiloan_item["unit_price_snapshot"]) == Decimal("7000.00")
    assert Decimal(kiloan_item["quantity"]) == Decimal("3.50")
    assert Decimal(kiloan_item["subtotal"]) == Decimal("24500.00")

    satuan_item = next(it for it in items if it["service_id"] == svc_satuan["id"])
    assert satuan_item["service_name_snapshot"] == "Bedcover Besar"
    assert satuan_item["price_type_snapshot"] == "per_item"
    assert satuan_item["unit_snapshot"] == "pcs"
    assert Decimal(satuan_item["unit_price_snapshot"]) == Decimal("25000.00")
    assert Decimal(satuan_item["quantity"]) == Decimal("2.00")
    assert Decimal(satuan_item["subtotal"]) == Decimal("50000.00")

    # Check initial status log
    assert len(order["status_logs"]) == 1
    assert order["status_logs"][0]["previous_status"] is None
    assert order["status_logs"][0]["new_status"] == OrderStatus.RECEIVED.value


def test_order_snapshot_immutability(client):
    """
    Modifying or updating a service price in catalog must NOT alter existing historical orders.
    """
    headers, _ = register_and_get_auth(client)
    customer, svc_kiloan, _ = create_sample_customer_and_services(client, headers)

    order_payload = {
        "customer_id": customer["id"],
        "items": [
            {
                "service_id": svc_kiloan["id"],
                "quantity": "5.00",
            }
        ],
    }
    create_res = client.post("/api/v1/orders", json=order_payload, headers=headers)
    assert create_res.status_code == 201
    order_id = create_res.json()["data"]["id"]

    # Verify initial calculation (5 * 7000 = 35000)
    assert Decimal(create_res.json()["data"]["subtotal"]) == Decimal("35000.00")

    # Update service price from 7000 to 15000
    update_svc_res = client.patch(
        f"/api/v1/services/{svc_kiloan['id']}",
        json={"price": "15000.00"},
        headers=headers,
    )
    assert update_svc_res.status_code == 200

    # Retrieve order: price and subtotal MUST remain unchanged
    get_res = client.get(f"/api/v1/orders/{order_id}", headers=headers)
    assert get_res.status_code == 200
    persisted_order = get_res.json()["data"]
    assert Decimal(persisted_order["subtotal"]) == Decimal("35000.00")
    assert Decimal(persisted_order["items"][0]["unit_price_snapshot"]) == Decimal("7000.00")


def test_order_sequential_numbering(client):
    """
    Consecutive order creations within the same outlet must increment sequence suffix.
    """
    headers, _ = register_and_get_auth(client)
    customer, svc_kiloan, _ = create_sample_customer_and_services(client, headers)

    order_nums = []
    for _ in range(3):
        res = client.post(
            "/api/v1/orders",
            json={
                "customer_id": customer["id"],
                "items": [{"service_id": svc_kiloan["id"], "quantity": "1.00"}],
            },
            headers=headers,
        )
        assert res.status_code == 201
        order_nums.append(res.json()["data"]["order_number"])

    assert len(order_nums) == 3
    # Check suffixes are consecutive
    suf1 = int(order_nums[0].split("-")[-1])
    suf2 = int(order_nums[1].split("-")[-1])
    suf3 = int(order_nums[2].split("-")[-1])
    assert suf2 == suf1 + 1
    assert suf3 == suf2 + 1


def test_order_tenant_isolation_and_idor_protection(client):
    """
    Orders must be strictly isolated:
    1. Cross-tenant customer/service rejected on creation (IDOR).
    2. Tenant B cannot retrieve or alter Tenant A's orders.
    """
    headers_a, _ = register_and_get_auth(client)
    cust_a, svc_a, _ = create_sample_customer_and_services(client, headers_a)

    headers_b, _ = register_and_get_auth(client)
    cust_b, svc_b, _ = create_sample_customer_and_services(client, headers_b)

    # Tenant A attempts to use Tenant B's customer
    res_bad_cust = client.post(
        "/api/v1/orders",
        json={"customer_id": cust_b["id"], "items": [{"service_id": svc_a["id"], "quantity": "1.00"}]},
        headers=headers_a,
    )
    assert res_bad_cust.status_code == 400

    # Tenant A attempts to use Tenant B's service
    res_bad_svc = client.post(
        "/api/v1/orders",
        json={"customer_id": cust_a["id"], "items": [{"service_id": svc_b["id"], "quantity": "1.00"}]},
        headers=headers_a,
    )
    assert res_bad_svc.status_code == 400

    # Tenant A creates valid order
    order_res = client.post(
        "/api/v1/orders",
        json={"customer_id": cust_a["id"], "items": [{"service_id": svc_a["id"], "quantity": "2.00"}]},
        headers=headers_a,
    )
    assert order_res.status_code == 201
    order_a_id = order_res.json()["data"]["id"]

    # Tenant B tries to get Tenant A's order -> 404
    get_res = client.get(f"/api/v1/orders/{order_a_id}", headers=headers_b)
    assert get_res.status_code == 404

    # Tenant B tries to change status of Tenant A's order -> 404
    status_res = client.post(
        f"/api/v1/orders/{order_a_id}/status",
        json={"status": "washing"},
        headers=headers_b,
    )
    assert status_res.status_code == 404

    # Tenant B tries to cancel Tenant A's order -> 404
    cancel_res = client.post(
        f"/api/v1/orders/{order_a_id}/cancel",
        json={"reason": "Hacking attempt"},
        headers=headers_b,
    )
    assert cancel_res.status_code == 404


def test_order_status_pipeline_transitions_and_timeline(client):
    """
    Test standard execution pipeline:
    received -> washing -> drying -> ironing -> packaging -> ready -> completed.
    And verify chronological timeline.
    """
    headers, _ = register_and_get_auth(client)
    customer, svc_kiloan, _ = create_sample_customer_and_services(client, headers)

    create_res = client.post(
        "/api/v1/orders",
        json={"customer_id": customer["id"], "items": [{"service_id": svc_kiloan["id"], "quantity": "4.00"}]},
        headers=headers,
    )
    order_id = create_res.json()["data"]["id"]

    steps = [
        ("washing", "Memulai proses perendaman dan pencucian"),
        ("drying", "Pencucian selesai, masuk mesin pengering"),
        ("ironing", "Pengeringan tuntas, proses setrika uap"),
        ("packaging", "Selesai setrika, pengemasan plastik kedap"),
        ("ready", "Pesanan rapi dan siap diambil pelanggan"),
        ("completed", "Pelanggan sudah mengambil cucian di outlet"),
    ]

    for next_status, note in steps:
        res = client.post(
            f"/api/v1/orders/{order_id}/status",
            json={"status": next_status, "notes": note},
            headers=headers,
        )
        assert res.status_code == 200
        assert res.json()["data"]["status"] == next_status

    # Check terminal completed order cannot transition further
    res_invalid = client.post(
        f"/api/v1/orders/{order_id}/status",
        json={"status": "washing"},
        headers=headers,
    )
    assert res_invalid.status_code == 400

    # Completed order cannot be cancelled
    res_cancel_completed = client.post(
        f"/api/v1/orders/{order_id}/cancel",
        json={"reason": "Cancel after done"},
        headers=headers,
    )
    assert res_cancel_completed.status_code == 400

    # Check timeline
    timeline_res = client.get(f"/api/v1/orders/{order_id}/timeline", headers=headers)
    assert timeline_res.status_code == 200
    timeline = timeline_res.json()["data"]
    # 1 initial + 6 steps = 7 logs
    assert len(timeline) == 7
    assert timeline[0]["new_status"] == "received"
    assert timeline[-1]["new_status"] == "completed"


def test_invalid_status_transition_rejected(client):
    """
    Illegal status transitions (e.g. jumping directly from received to ready) must be rejected.
    """
    headers, _ = register_and_get_auth(client)
    customer, svc_kiloan, _ = create_sample_customer_and_services(client, headers)

    create_res = client.post(
        "/api/v1/orders",
        json={"customer_id": customer["id"], "items": [{"service_id": svc_kiloan["id"], "quantity": "2.00"}]},
        headers=headers,
    )
    order_id = create_res.json()["data"]["id"]

    # Direct jump received -> ready is prohibited
    res = client.post(
        f"/api/v1/orders/{order_id}/status",
        json={"status": "ready"},
        headers=headers,
    )
    assert res.status_code == 400
    assert "tidak diizinkan" in res.json()["error"]["message"]


def test_order_cancellation_flow(client):
    """
    Active orders can be cancelled with a mandatory reason.
    Subsequent status updates are blocked.
    """
    headers, _ = register_and_get_auth(client)
    customer, svc_kiloan, _ = create_sample_customer_and_services(client, headers)

    create_res = client.post(
        "/api/v1/orders",
        json={"customer_id": customer["id"], "items": [{"service_id": svc_kiloan["id"], "quantity": "1.50"}]},
        headers=headers,
    )
    order_id = create_res.json()["data"]["id"]

    # Cancel with reason
    reason_text = "Pelanggan membatalkan pesanan karena akan dinas luar kota mendadak."
    cancel_res = client.post(
        f"/api/v1/orders/{order_id}/cancel",
        json={"reason": reason_text},
        headers=headers,
    )
    assert cancel_res.status_code == 200
    cancelled_order = cancel_res.json()["data"]
    assert cancelled_order["status"] == "cancelled"
    assert cancelled_order["cancellation_reason"] == reason_text
    assert cancelled_order["cancelled_at"] is not None

    # Cancel again -> 400
    res_cancel_again = client.post(
        f"/api/v1/orders/{order_id}/cancel",
        json={"reason": "Cancel again"},
        headers=headers,
    )
    assert res_cancel_again.status_code == 400

    # Transition cancelled order -> 400
    res_trans = client.post(
        f"/api/v1/orders/{order_id}/status",
        json={"status": "washing"},
        headers=headers,
    )
    assert res_trans.status_code == 400


def test_order_cancellation_requires_reason(client):
    """Cancellation without reason or with empty string must fail validation."""
    headers, _ = register_and_get_auth(client)
    customer, svc_kiloan, _ = create_sample_customer_and_services(client, headers)

    create_res = client.post(
        "/api/v1/orders",
        json={"customer_id": customer["id"], "items": [{"service_id": svc_kiloan["id"], "quantity": "1.00"}]},
        headers=headers,
    )
    order_id = create_res.json()["data"]["id"]

    res_empty = client.post(
        f"/api/v1/orders/{order_id}/cancel",
        json={"reason": "  "},
        headers=headers,
    )
    # Pydantic min_length=3 or service validation fails
    assert res_empty.status_code in (400, 422)


def test_list_and_search_orders(client):
    """
    Search and filter orders by status and keyword.
    """
    headers, _ = register_and_get_auth(client)
    customer, svc_kiloan, _ = create_sample_customer_and_services(client, headers)

    # Create 2 orders
    res1 = client.post(
        "/api/v1/orders",
        json={"customer_id": customer["id"], "items": [{"service_id": svc_kiloan["id"], "quantity": "2.00"}]},
        headers=headers,
    )
    order1 = res1.json()["data"]

    res2 = client.post(
        "/api/v1/orders",
        json={"customer_id": customer["id"], "items": [{"service_id": svc_kiloan["id"], "quantity": "3.00"}]},
        headers=headers,
    )
    order2 = res2.json()["data"]

    # Advance order 2 to washing
    client.post(
        f"/api/v1/orders/{order2['id']}/status",
        json={"status": "washing"},
        headers=headers,
    )

    # Filter status=received -> should include order1, exclude order2
    list_rec = client.get("/api/v1/orders?status=received", headers=headers)
    assert list_rec.status_code == 200
    data_rec = list_rec.json()["data"]
    order_ids_rec = [o["id"] for o in data_rec]
    assert order1["id"] in order_ids_rec
    assert order2["id"] not in order_ids_rec

    # Search by order_number
    search_res = client.get(f"/api/v1/orders?q={order1['order_number']}", headers=headers)
    assert search_res.status_code == 200
    search_data = search_res.json()["data"]
    assert len(search_data) == 1
    assert search_data[0]["id"] == order1["id"]


def test_order_discount_capped_at_subtotal(client):
    """
    Verify providing a discount larger than subtotal caps discount to subtotal,
    so total amount cannot become negative.
    """
    headers, _ = register_and_get_auth(client)
    customer, svc_kiloan, _ = create_sample_customer_and_services(client, headers)

    # 2.00 kg * 7000 = 14000 subtotal, with discount 50000
    res = client.post(
        "/api/v1/orders",
        json={
            "customer_id": customer["id"],
            "items": [{"service_id": svc_kiloan["id"], "quantity": "2.00"}],
            "discount_amount": "50000.00",
        },
        headers=headers,
    )
    assert res.status_code == 201
    order = res.json()["data"]
    assert Decimal(order["subtotal"]) == Decimal("14000.00")
    assert Decimal(order["discount_amount"]) == Decimal("14000.00")
    assert Decimal(order["total_amount"]) == Decimal("0.00")
    assert Decimal(order["remaining_amount"]) == Decimal("0.00")


def test_order_list_and_timeline_tenant_isolation(client):
    """
    Verify Tenant B's order list never leaks Tenant A's orders,
    and probing Tenant A's timeline from Tenant B returns 404.
    """
    headers_a, _ = register_and_get_auth(client)
    cust_a, svc_a, _ = create_sample_customer_and_services(client, headers_a)

    headers_b, _ = register_and_get_auth(client)

    order_res = client.post(
        "/api/v1/orders",
        json={
            "customer_id": cust_a["id"],
            "items": [{"service_id": svc_a["id"], "quantity": "1.00"}],
        },
        headers=headers_a,
    )
    assert order_res.status_code == 201
    order_a = order_res.json()["data"]

    # Tenant B list must not include order A
    list_b = client.get("/api/v1/orders", headers=headers_b)
    assert list_b.status_code == 200
    b_order_ids = [o["id"] for o in list_b.json()["data"]]
    assert order_a["id"] not in b_order_ids

    # Tenant B timeline probing must 404
    probe_timeline = client.get(f"/api/v1/orders/{order_a['id']}/timeline", headers=headers_b)
    assert probe_timeline.status_code == 404


def test_order_validation_invalid_quantity_and_empty_items(client):
    """
    Verify empty items array or non-positive quantities fail Pydantic validation (422).
    """
    headers, _ = register_and_get_auth(client)
    customer, svc_kiloan, _ = create_sample_customer_and_services(client, headers)

    # Empty items array
    res_empty = client.post(
        "/api/v1/orders",
        json={"customer_id": customer["id"], "items": []},
        headers=headers,
    )
    assert res_empty.status_code == 422

    # Zero quantity
    res_zero_qty = client.post(
        "/api/v1/orders",
        json={
            "customer_id": customer["id"],
            "items": [{"service_id": svc_kiloan["id"], "quantity": "0.00"}],
        },
        headers=headers,
    )
    assert res_zero_qty.status_code == 422

