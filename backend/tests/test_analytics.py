from decimal import Decimal
from tests.conftest import get_auth_headers
from app.models.warehouse import Warehouse, WarehouseStock


def test_analytics_endpoints_and_specialization(client, db_session):
    headers = get_auth_headers(user_id=1, org_id=1, role="admin")

    # 1. Seed warehouse and warehouse_stock for test
    wh = Warehouse(org_id=1, warehouse_code="WH-TEST", name="Test Warehouse", city="Delhi", capacity_sqft=5000, is_active=True)
    db_session.add(wh)
    db_session.flush()

    ws = WarehouseStock(warehouse_id=wh.id, item_id=1, quantity_stored=Decimal("10.00"), bin_location="BIN-A1")
    db_session.add(ws)
    db_session.commit()

    # 2. Test analytics GET endpoints
    assert client.get("/api/v1/analytics/inventory-health?org_type=ngo").status_code == 200
    assert client.get("/api/v1/analytics/stock-velocity?org_type=ngo&limit=5").status_code == 200
    assert client.get("/api/v1/analytics/category-velocity?org_type=ngo").status_code == 200
    assert client.get("/api/v1/analytics/cash-flow?org_type=ngo").status_code == 200
    assert client.get("/api/v1/analytics/dead-stock?org_type=ngo").status_code == 200
    assert client.get("/api/v1/analytics/pnl?org_type=ngo").status_code == 200
    assert client.get("/api/v1/analytics/warehouses?org_type=ngo").status_code == 200
    assert client.get("/api/v1/analytics/donation-specialization?org_type=ngo").status_code == 200
    assert client.get("/api/v1/analytics/db-programs").status_code == 200

    # 3. Create cash donation (EER Specialization)
    cash_res = client.post(
        "/api/v1/donations",
        headers=headers,
        json={
            "donor_name": "Relief Trust",
            "donation_type": "cash",
            "amount": 10000.00,
            "payment_mode": "RTGS",
            "transaction_reference": "TXN-TEST-9999",
            "bank_name": "SBI",
            "is_tax_exempt_80g": True
        }
    )
    assert cash_res.status_code == 201
    c_data = cash_res.json()
    assert c_data["payment_mode"] == "RTGS"
    assert c_data["receipt_no"].startswith("DON-")

    # 4. Create in-kind goods donation (EER Specialization)
    goods_res = client.post(
        "/api/v1/donations",
        headers=headers,
        json={
            "donor_name": "Medical Aid Foundation",
            "donation_type": "goods",
            "item_id": 1,
            "quantity": 5,
            "storage_requirement": "COLD",
            "condition_grade": "NEW"
        }
    )
    assert goods_res.status_code == 201
    g_data = goods_res.json()
    assert g_data["storage_requirement"] == "COLD"
    assert float(g_data["quantity"]) == 5

    # 5. Dispatch relief aid via analytics endpoint (proves service fallback on SQLite)
    dispatch_res = client.post(
        "/api/v1/analytics/dispatch-aid",
        headers=headers,
        json={
            "item_id": 1,
            "quantity": 3,
            "destination": "Test Camp North",
            "note": "Field distribution"
        }
    )
    assert dispatch_res.status_code == 201
    assert dispatch_res.json()["quantity_dispatched"] == 3

    # 6. Verify over-dispatch rejection
    over_res = client.post(
        "/api/v1/analytics/dispatch-aid",
        headers=headers,
        json={
            "item_id": 1,
            "quantity": 99999,
            "destination": "Test Camp North"
        }
    )
    assert over_res.status_code == 409
