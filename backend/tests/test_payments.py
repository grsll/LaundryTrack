from decimal import Decimal
import secrets
import pytest
from app.core.security import create_access_token


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


def create_order_helper(client, headers, total_amount="50000.00"):
    """Creates a sample customer, service, and order with fixed amount."""
    c_res = client.post(
        "/api/v1/customers",
        headers=headers,
        json={
            "name": f"Pelanggan {secrets.token_hex(2)}",
            "phone": f"0813{secrets.randbelow(100000000):08d}",
        },
    )
    assert c_res.status_code == 201
    customer = c_res.json()["data"]

    s_res = client.post(
        "/api/v1/services",
        headers=headers,
        json={
            "name": "Cuci Standar",
            "price_type": "per_item",
            "unit": "pcs",
            "price": total_amount,
        },
    )
    assert s_res.status_code == 201
    service = s_res.json()["data"]

    order_payload = {
        "customer_id": customer["id"],
        "items": [
            {
                "service_id": service["id"],
                "quantity": "1.00",
            }
        ],
        "discount_amount": "0.00",
    }
    o_res = client.post("/api/v1/orders", json=order_payload, headers=headers)
    assert o_res.status_code == 201
    return o_res.json()["data"]


def test_full_payment_flow(client):
    """Test full payment recording changes order status to paid and remaining amount to zero."""
    headers, auth = register_and_get_auth(client)
    order = create_order_helper(client, headers, total_amount="40000.00")
    order_id = order["id"]

    assert order["payment_status"] == "unpaid"
    assert Decimal(order["remaining_amount"]) == Decimal("40000.00")
    assert Decimal(order["paid_amount"]) == Decimal("0.00")

    pay_res = client.post(
        f"/api/v1/orders/{order_id}/payments",
        headers=headers,
        json={
            "amount": "40000.00",
            "payment_method": "cash",
            "notes": "Pembayaran lunas tunai",
        },
    )
    assert pay_res.status_code == 201
    payment = pay_res.json()["data"]
    assert payment["order_id"] == order_id
    assert payment["amount"] == "40000.00"
    assert payment["payment_method"] == "cash"
    assert payment["status"] == "paid"
    assert payment["total_refunded"] == "0.00"
    assert payment["net_amount"] == "40000.00"

    # Verify order state
    o_get = client.get(f"/api/v1/orders/{order_id}", headers=headers)
    assert o_get.status_code == 200
    updated_order = o_get.json()["data"]
    assert updated_order["payment_status"] == "paid"
    assert Decimal(updated_order["paid_amount"]) == Decimal("40000.00")
    assert Decimal(updated_order["remaining_amount"]) == Decimal("0.00")


def test_partial_payment_flow(client):
    """Test multiple partial payments advance status from unpaid -> partial -> paid."""
    headers, auth = register_and_get_auth(client)
    order = create_order_helper(client, headers, total_amount="60000.00")
    order_id = order["id"]

    # 1st Payment: 25,000 (QRIS)
    p1_res = client.post(
        f"/api/v1/orders/{order_id}/payments",
        headers=headers,
        json={
            "amount": "25000.00",
            "payment_method": "qris",
            "reference_number": "QRIS-88991122",
            "notes": "DP cucian",
        },
    )
    assert p1_res.status_code == 201

    o_get1 = client.get(f"/api/v1/orders/{order_id}", headers=headers)
    order1 = o_get1.json()["data"]
    assert order1["payment_status"] == "partial"
    assert Decimal(order1["paid_amount"]) == Decimal("25000.00")
    assert Decimal(order1["remaining_amount"]) == Decimal("35000.00")

    # 2nd Payment: 35,000 (Bank Transfer)
    p2_res = client.post(
        f"/api/v1/orders/{order_id}/payments",
        headers=headers,
        json={
            "amount": "35000.00",
            "payment_method": "bank_transfer",
            "reference_number": "BCA-TRF-00129",
            "notes": "Pelunasan transfer",
        },
    )
    assert p2_res.status_code == 201

    o_get2 = client.get(f"/api/v1/orders/{order_id}", headers=headers)
    order2 = o_get2.json()["data"]
    assert order2["payment_status"] == "paid"
    assert Decimal(order2["paid_amount"]) == Decimal("60000.00")
    assert Decimal(order2["remaining_amount"]) == Decimal("0.00")

    # List payments for order
    list_res = client.get(f"/api/v1/orders/{order_id}/payments", headers=headers)
    assert list_res.status_code == 200
    payments = list_res.json()["data"]
    assert len(payments) == 2


def test_overpayment_rejected(client):
    """Test paying more than remaining amount is rejected with 400 Bad Request."""
    headers, auth = register_and_get_auth(client)
    order = create_order_helper(client, headers, total_amount="50000.00")
    order_id = order["id"]

    res = client.post(
        f"/api/v1/orders/{order_id}/payments",
        headers=headers,
        json={
            "amount": "50000.01",
            "payment_method": "cash",
        },
    )
    assert res.status_code == 400
    assert "melebihi sisa tagihan" in res.json()["error"]["message"]


def test_zero_or_negative_payment_rejected(client):
    """Test payment with zero or negative amounts is rejected."""
    headers, auth = register_and_get_auth(client)
    order = create_order_helper(client, headers, total_amount="50000.00")
    order_id = order["id"]

    res_zero = client.post(
        f"/api/v1/orders/{order_id}/payments",
        headers=headers,
        json={"amount": "0.00", "payment_method": "cash"},
    )
    assert res_zero.status_code in (400, 422)

    res_neg = client.post(
        f"/api/v1/orders/{order_id}/payments",
        headers=headers,
        json={"amount": "-15000.00", "payment_method": "cash"},
    )
    assert res_neg.status_code in (400, 422)


def test_payment_on_cancelled_order_rejected(client):
    """Test recording payment on a cancelled order is rejected."""
    headers, auth = register_and_get_auth(client)
    order = create_order_helper(client, headers, total_amount="50000.00")
    order_id = order["id"]

    # Cancel order
    c_res = client.post(
        f"/api/v1/orders/{order_id}/cancel",
        headers=headers,
        json={"reason": "Pelanggan berubah pikiran"},
    )
    assert c_res.status_code == 200

    # Attempt payment
    pay_res = client.post(
        f"/api/v1/orders/{order_id}/payments",
        headers=headers,
        json={"amount": "20000.00", "payment_method": "cash"},
    )
    assert pay_res.status_code == 400
    assert "dibatalkan" in pay_res.json()["error"]["message"]


def test_partial_and_full_refund_flow(client):
    """Test partial and full refunds update payment status and order remaining/paid amounts."""
    headers, auth = register_and_get_auth(client)
    order = create_order_helper(client, headers, total_amount="50000.00")
    order_id = order["id"]

    # Pay 50,000 full
    pay_res = client.post(
        f"/api/v1/orders/{order_id}/payments",
        headers=headers,
        json={"amount": "50000.00", "payment_method": "cash"},
    )
    assert pay_res.status_code == 201
    payment_id = pay_res.json()["data"]["id"]

    # 1st Refund: 20,000
    ref1_res = client.post(
        f"/api/v1/payments/{payment_id}/refunds",
        headers=headers,
        json={"amount": "20000.00", "reason": "Pakaian rusak karena luntur"},
    )
    assert ref1_res.status_code == 201
    ref1 = ref1_res.json()["data"]
    assert ref1["amount"] == "20000.00"
    assert ref1["payment_id"] == payment_id
    assert ref1["reason"] == "Pakaian rusak karena luntur"

    # Check payment detail
    p_get1 = client.get(f"/api/v1/payments/{payment_id}", headers=headers)
    assert p_get1.status_code == 200
    payment1 = p_get1.json()["data"]
    assert payment1["status"] == "partially_refunded"
    assert payment1["total_refunded"] == "20000.00"
    assert payment1["net_amount"] == "30000.00"

    # Check order state
    o_get1 = client.get(f"/api/v1/orders/{order_id}", headers=headers)
    order1 = o_get1.json()["data"]
    assert order1["payment_status"] == "partial"
    assert Decimal(order1["paid_amount"]) == Decimal("30000.00")
    assert Decimal(order1["remaining_amount"]) == Decimal("20000.00")

    # 2nd Refund: remaining 30,000
    ref2_res = client.post(
        f"/api/v1/payments/{payment_id}/refunds",
        headers=headers,
        json={"amount": "30000.00", "reason": "Pengembalian dana penuh cucian"},
    )
    assert ref2_res.status_code == 201

    # Check payment detail
    p_get2 = client.get(f"/api/v1/payments/{payment_id}", headers=headers)
    payment2 = p_get2.json()["data"]
    assert payment2["status"] == "refunded"
    assert payment2["total_refunded"] == "50000.00"
    assert payment2["net_amount"] == "0.00"

    # Check order state
    o_get2 = client.get(f"/api/v1/orders/{order_id}", headers=headers)
    order2 = o_get2.json()["data"]
    assert order2["payment_status"] == "refunded"
    assert Decimal(order2["paid_amount"]) == Decimal("0.00")
    assert Decimal(order2["remaining_amount"]) == Decimal("50000.00")


def test_refund_exceeding_payment_amount_rejected(client):
    """Test refunding more than the net payment amount is rejected with 400 Bad Request."""
    headers, auth = register_and_get_auth(client)
    order = create_order_helper(client, headers, total_amount="30000.00")
    order_id = order["id"]

    pay_res = client.post(
        f"/api/v1/orders/{order_id}/payments",
        headers=headers,
        json={"amount": "30000.00", "payment_method": "cash"},
    )
    payment_id = pay_res.json()["data"]["id"]

    # Attempt to refund 30,000.01
    ref_res = client.post(
        f"/api/v1/payments/{payment_id}/refunds",
        headers=headers,
        json={"amount": "30000.01", "reason": "Kelebihan refund ilegal"},
    )
    assert ref_res.status_code == 400
    assert "melebihi sisa dana pembayaran" in ref_res.json()["error"]["message"]


def test_refund_requires_valid_reason(client):
    """Test refund without reason or too short reason is rejected."""
    headers, auth = register_and_get_auth(client)
    order = create_order_helper(client, headers, total_amount="20000.00")
    order_id = order["id"]

    pay_res = client.post(
        f"/api/v1/orders/{order_id}/payments",
        headers=headers,
        json={"amount": "20000.00", "payment_method": "cash"},
    )
    payment_id = pay_res.json()["data"]["id"]

    res_empty = client.post(
        f"/api/v1/payments/{payment_id}/refunds",
        headers=headers,
        json={"amount": "10000.00", "reason": "  "},
    )
    assert res_empty.status_code in (400, 422)


def test_refund_rbac_cashier_forbidden(client):
    """Verify cashier can record payments but is strictly forbidden from issuing refunds."""
    headers_owner, auth = register_and_get_auth(client)
    user_id = auth["user"]["id"]
    tenant_id = auth["tenant"]["id"]
    outlet_id = auth["outlet"]["id"]

    # Generate cashier token
    cashier_token = create_access_token({
        "sub": user_id,
        "tenant_id": tenant_id,
        "outlet_id": outlet_id,
        "role": "cashier",
    })
    headers_cashier = {"Authorization": f"Bearer {cashier_token}"}

    order = create_order_helper(client, headers_owner, total_amount="40000.00")
    order_id = order["id"]

    # Cashier can record payment
    pay_res = client.post(
        f"/api/v1/orders/{order_id}/payments",
        headers=headers_cashier,
        json={"amount": "40000.00", "payment_method": "cash"},
    )
    assert pay_res.status_code == 201
    payment_id = pay_res.json()["data"]["id"]

    # Cashier cannot refund
    ref_cashier = client.post(
        f"/api/v1/payments/{payment_id}/refunds",
        headers=headers_cashier,
        json={"amount": "10000.00", "reason": "Refund kasir"},
    )
    assert ref_cashier.status_code == 403
    assert ref_cashier.json()["error"]["code"] == "INSUFFICIENT_PERMISSIONS"

    # Owner can refund
    ref_owner = client.post(
        f"/api/v1/payments/{payment_id}/refunds",
        headers=headers_owner,
        json={"amount": "10000.00", "reason": "Otorisasi refund oleh owner"},
    )
    assert ref_owner.status_code == 201


def test_payments_tenant_isolation_and_idor(client):
    """Verify Tenant B cannot view, pay, or refund orders and payments of Tenant A."""
    headers_a, _ = register_and_get_auth(client)
    headers_b, _ = register_and_get_auth(client)

    order_a = create_order_helper(client, headers_a, total_amount="50000.00")
    order_a_id = order_a["id"]

    # Tenant B tries to record payment on Tenant A's order
    idor_pay = client.post(
        f"/api/v1/orders/{order_a_id}/payments",
        headers=headers_b,
        json={"amount": "50000.00", "payment_method": "cash"},
    )
    assert idor_pay.status_code == 404

    # Tenant A records legitimate payment
    legit_pay = client.post(
        f"/api/v1/orders/{order_a_id}/payments",
        headers=headers_a,
        json={"amount": "50000.00", "payment_method": "cash"},
    )
    assert legit_pay.status_code == 201
    payment_a_id = legit_pay.json()["data"]["id"]

    # Tenant B tries to view payments of Tenant A's order
    idor_list = client.get(f"/api/v1/orders/{order_a_id}/payments", headers=headers_b)
    assert idor_list.status_code == 404

    # Tenant B tries to get Tenant A's payment detail
    idor_detail = client.get(f"/api/v1/payments/{payment_a_id}", headers=headers_b)
    assert idor_detail.status_code == 404

    # Tenant B tries to refund Tenant A's payment
    idor_refund = client.post(
        f"/api/v1/payments/{payment_a_id}/refunds",
        headers=headers_b,
        json={"amount": "10000.00", "reason": "IDOR refund attempt"},
    )
    assert idor_refund.status_code == 404


def test_order_cancellation_blocked_if_active_payment(client):
    """
    Verify an order with active payment cannot be cancelled without refunding first.
    Once refunded completely, cancellation succeeds.
    """
    headers, _ = register_and_get_auth(client)
    order = create_order_helper(client, headers, total_amount="50000.00")
    order_id = order["id"]

    # Record payment of 20,000
    pay_res = client.post(
        f"/api/v1/orders/{order_id}/payments",
        headers=headers,
        json={"amount": "20000.00", "payment_method": "cash"},
    )
    assert pay_res.status_code == 201
    payment_id = pay_res.json()["data"]["id"]

    # Attempt to cancel order with active payment -> should fail
    cancel_fail = client.post(
        f"/api/v1/orders/{order_id}/cancel",
        headers=headers,
        json={"reason": "Mau batalkan tapi sudah ada DP"},
    )
    assert cancel_fail.status_code == 400
    assert "saldo pembayaran aktif" in cancel_fail.json()["error"]["message"]

    # Refund the 20,000 payment
    refund_res = client.post(
        f"/api/v1/payments/{payment_id}/refunds",
        headers=headers,
        json={"amount": "20000.00", "reason": "Pengembalian DP untuk pembatalan pesanan"},
    )
    assert refund_res.status_code == 201

    # Now cancellation succeeds
    cancel_success = client.post(
        f"/api/v1/orders/{order_id}/cancel",
        headers=headers,
        json={"reason": "Pembatalan disetujui setelah refund tuntas"},
    )
    assert cancel_success.status_code == 200
    assert cancel_success.json()["data"]["status"] == "cancelled"
