import pytest
from datetime import datetime, timedelta
from fastapi.testclient import TestClient
from app.main import app
from app.database import SessionLocal
from app.models.sql_models import Shipper, Shipment, TrackingEvent, Invoice
from app.security import create_access_token

client = TestClient(app)

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"

def test_auth_and_token_flow():
    # 1. Register a new shipper
    email = f"test_shipper_{int(datetime.utcnow().timestamp())}@test.com"
    reg_payload = {
        "full_name": "Test Shipper",
        "email": email,
        "password": "Password123!",
        "phone": "9998887776",
        "company_name": "Test Corp"
    }
    reg_res = client.post("/api/auth/register", json=reg_payload)
    assert reg_res.status_code == 201
    data = reg_res.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    token = data["access_token"]

    # 2. Access protected /me endpoint with token
    me_res = client.get("/api/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me_res.status_code == 200
    assert me_res.json()["email"] == email

    # 3. Access protected endpoint WITHOUT token (should be 401)
    unauth_res = client.get("/api/auth/me")
    assert unauth_res.status_code == 401

def test_shipment_booking_and_cancellation_policy():
    db = SessionLocal()
    # Find or create a test shipper
    shipper = db.query(Shipper).first()
    if not shipper:
        shipper = Shipper(full_name="Seed Shipper", email="seed@test.com", password_hash="hash")
        db.add(shipper)
        db.commit()
        db.refresh(shipper)
    db.close()

    token = create_access_token({"sub": shipper.email, "shipper_id": shipper.shipper_id})
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Book a new shipment
    book_payload = {
        "origin_address": "Banjara Hills, Road 1",
        "origin_city": "Hyderabad",
        "destination_address": "Indiranagar 100ft Rd",
        "destination_city": "Bangalore",
        "weight_kg": 5.5,
        "origin_lat": 17.4156,
        "origin_lng": 78.4357,
        "destination_lat": 12.9784,
        "destination_lng": 77.6408
    }
    book_res = client.post("/api/shipments", json=book_payload, headers=headers)
    assert book_res.status_code == 201
    shipment_data = book_res.json()
    shipment_id = shipment_data["id"]
    assert shipment_data["status"] == "booked"
    assert shipment_data["can_cancel"] is True

    # 2. Successfully cancel within the 5-hour window
    cancel_res = client.post(f"/api/shipments/{shipment_id}/cancel", headers=headers)
    assert cancel_res.status_code == 200
    cancel_data = cancel_res.json()
    assert cancel_data["success"] is True
    assert cancel_data["status"] == "cancelled"

    # 3. Test: Cannot cancel an already picked-up shipment
    db = SessionLocal()
    picked_up_shipment = Shipment(
        shipper_id=shipper.shipper_id,
        origin_address="Madhapur",
        origin_city="Hyderabad",
        destination_address="Koramangala",
        destination_city="Bangalore",
        weight_kg=10.0,
        status="picked_up",
        created_at=datetime.utcnow()
    )
    db.add(picked_up_shipment)
    db.commit()
    db.refresh(picked_up_shipment)
    db.close()

    cant_cancel_res = client.post(f"/api/shipments/{picked_up_shipment.shipment_id}/cancel", headers=headers)
    assert cant_cancel_res.status_code == 400
    assert "picked up" in cant_cancel_res.json()["detail"].lower()

    # 4. Test: Cannot cancel if 5-hour window has expired
    db = SessionLocal()
    old_shipment = Shipment(
        shipper_id=shipper.shipper_id,
        origin_address="Ameerpet",
        origin_city="Hyderabad",
        destination_address="Adyar",
        destination_city="Chennai",
        weight_kg=4.0,
        status="booked",
        created_at=datetime.utcnow() - timedelta(hours=6)  # 6 hours ago
    )
    db.add(old_shipment)
    db.commit()
    db.refresh(old_shipment)
    db.close()

    expired_cancel_res = client.post(f"/api/shipments/{old_shipment.shipment_id}/cancel", headers=headers)
    assert expired_cancel_res.status_code == 400
    assert "expired" in expired_cancel_res.json()["detail"].lower()

def test_mongodb_telemetry_pipeline():
    ping_payload = {
        "shipment_id": 9999,
        "lat": 17.3850,
        "lng": 78.4867,
        "speed_kmh": 45.5,
        "notes": "Highway transit"
    }
    ping_res = client.post("/api/tracking/ping", json=ping_payload)
    assert ping_res.status_code == 200
    assert ping_res.json()["success"] is True

    # Test MongoDB Aggregation Pipeline endpoint
    analytics_res = client.get("/api/tracking/9999/analytics")
    assert analytics_res.status_code == 200
    data = analytics_res.json()
    assert data["shipment_id"] == 9999
    assert data["total_pings"] >= 1

def test_sql_advanced_analytics():
    rank_res = client.get("/api/analytics/carrier-rankings")
    assert rank_res.status_code == 200
    assert "carrier_rankings" in rank_res.json()

    cte_res = client.get("/api/analytics/monthly-revenue-cte")
    assert cte_res.status_code == 200
    assert "monthly_financials" in cte_res.json()

def test_ai_vector_classification():
    payload = {
        "cargo_description": "Frozen vaccines and cold milk cartons",
        "declared_weight_kg": 25.0
    }
    res = client.post("/api/ai/classify-cargo", json=payload)
    assert res.status_code == 200
    data = res.json()
    assert "Perishable" in data["category"]
    assert "Refrigerated" in data["recommended_vehicle"]
