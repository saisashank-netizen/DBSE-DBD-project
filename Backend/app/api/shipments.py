from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from app.api.deps import get_db, get_current_shipper, get_optional_shipper
from app.models.sql_models import Shipment, TrackingEvent, Invoice, Carrier, Vehicle, Driver, Shipper
from app.models.pydantic_schemas import (
    ShipmentCreateRequest, ShipmentResponse, ShipmentCancelResponse,
    TrackingEventResponse, CostEstimateRequest, CostEstimateResponse
)
from app.services.shipment_service import (
    estimate_cost_sp, evaluate_cancellation_eligibility, auto_assign_logistics
)
from app.services.saga_orchestrator import SagaOrchestrator
from app.database import telemetry_collection

router = APIRouter(prefix="/shipments", tags=["Shipments"])

def _format_shipment_dict(s: Shipment, db: Session) -> dict:
    carrier_name = s.carrier.carrier_name if s.carrier else "Swift Logistics"
    vehicle_num = s.vehicle.vehicle_number if s.vehicle else None
    driver_name = s.driver.full_name if s.driver else None

    # Check live GPS from MongoDB or fallback to event locations
    latest_mongo = telemetry_collection.find_one(
        {"shipment_id": s.shipment_id},
        sort=[("timestamp", -1)]
    )

    timeline_list = []
    for ev in s.events:
        lat = 17.3850
        lng = 78.4867
        if "Bangalore" in (ev.location or ""):
            lat, lng = 12.9716, 77.5946
        elif "Chennai" in (ev.location or ""):
            lat, lng = 13.0827, 80.2707
        elif "Vijayawada" in (ev.location or ""):
            lat, lng = 16.5062, 80.6480
        elif "Kurnool" in (ev.location or ""):
            lat, lng = 15.8281, 78.0373
        elif "Nellore" in (ev.location or ""):
            lat, lng = 14.4426, 79.9865

        timeline_list.append({
            "event_id": ev.event_id,
            "status": ev.status.replace("_", " ").title(),
            "location": ev.location or f"{s.origin_city} Hub",
            "notes": ev.notes or "",
            "event_time": ev.event_time or datetime.utcnow(),
            "lat": lat,
            "lng": lng
        })

    # Default coordinates for latest position
    latest_lat = latest_mongo.get("lat") if latest_mongo else (timeline_list[-1]["lat"] if timeline_list else 17.3850)
    latest_lng = latest_mongo.get("lng") if latest_mongo else (timeline_list[-1]["lng"] if timeline_list else 78.4867)

    can_cancel, _, deadline, time_rem = evaluate_cancellation_eligibility(s)

    return {
        "id": s.shipment_id,
        "shipper_id": s.shipper_id,
        "origin": s.origin_city or s.origin_address,
        "origin_city": s.origin_city,
        "destination": s.destination_city or s.destination_address,
        "destination_city": s.destination_city,
        "weight": float(s.weight_kg),
        "status": s.status,
        "cost": float(s.estimated_cost or 0.0),
        "date": (s.created_at or datetime.utcnow()).strftime("%d %b %Y"),
        "created_at": s.created_at or datetime.utcnow(),
        "carrier": carrier_name,
        "carrier_id": s.carrier_id,
        "vehicle_number": vehicle_num,
        "driver_name": driver_name,
        "can_cancel": can_cancel,
        "cancellation_deadline": deadline,
        "time_remaining_for_cancellation": time_rem,
        "timeline": timeline_list,
        "latest_lat": latest_lat,
        "latest_lng": latest_lng
    }

@router.get("", response_model=List[ShipmentResponse])
def get_shipments(
    current_shipper: Optional[Shipper] = Depends(get_optional_shipper),
    db: Session = Depends(get_db)
):
    """
    Fetches shipments for the authenticated shipper.
    If unauthenticated or if shipper has 0 shipments, shows recent sample shipments
    from MySQL so the dashboard remains interactive.
    """
    if current_shipper:
        my_shipments = db.query(Shipment).filter(Shipment.shipper_id == current_shipper.shipper_id).order_by(Shipment.created_at.desc()).all()
        if my_shipments:
            return [_format_shipment_dict(s, db) for s in my_shipments]

    # Provide recent shipments directly from MySQL database
    sample_shipments = db.query(Shipment).order_by(Shipment.created_at.desc()).limit(10).all()
    return [_format_shipment_dict(s, db) for s in sample_shipments]

@router.post("", response_model=ShipmentResponse, status_code=status.HTTP_201_CREATED)
def create_shipment(
    req: ShipmentCreateRequest,
    current_shipper: Shipper = Depends(get_current_shipper),
    db: Session = Depends(get_db)
):
    """
    Books a new shipment:
    1. Calculates cost using stored procedure `sp_estimate_cost`.
    2. Auto-assigns logistics carrier, vehicle, and driver.
    3. Persists shipment with 'booked' status.
    4. Creates initial tracking event.
    5. Issues pending invoice.
    6. Stores initial coordinates in MongoDB.
    """
    same_city = req.origin_city.strip().lower() == req.destination_city.strip().lower()
    cost = estimate_cost_sp(req.weight_kg, same_city)

    carrier, vehicle, driver = auto_assign_logistics(db, req.weight_kg)

    new_shipment = Shipment(
        shipper_id=current_shipper.shipper_id,
        carrier_id=carrier.carrier_id if carrier else None,
        vehicle_id=vehicle.vehicle_id if vehicle else None,
        driver_id=driver.driver_id if driver else None,
        origin_address=req.origin_address,
        origin_city=req.origin_city,
        destination_address=req.destination_address,
        destination_city=req.destination_city,
        weight_kg=req.weight_kg,
        length_cm=req.length_cm,
        width_cm=req.width_cm,
        height_cm=req.height_cm,
        status="booked",
        estimated_cost=cost,
        created_at=datetime.utcnow()
    )
    db.add(new_shipment)
    db.flush()

    # Initial tracking event
    initial_event = TrackingEvent(
        shipment_id=new_shipment.shipment_id,
        status="booked",
        location=f"{req.origin_city} Hub",
        notes="Shipment successfully booked. Carrier assigned automatically.",
        event_time=datetime.utcnow()
    )
    db.add(initial_event)

    # Invoice generation
    invoice = Invoice(
        shipment_id=new_shipment.shipment_id,
        amount=cost,
        payment_status="pending",
        payment_method="UPI / Card",
        issued_at=datetime.utcnow()
    )
    db.add(invoice)

    db.commit()
    db.refresh(new_shipment)

    # Ingest coordinates into MongoDB if provided
    if req.origin_lat and req.origin_lng:
        try:
            telemetry_collection.insert_one({
                "shipment_id": new_shipment.shipment_id,
                "lat": req.origin_lat,
                "lng": req.origin_lng,
                "speed_kmh": 0.0,
                "notes": f"Origin coordinate ({req.origin_city})",
                "timestamp": datetime.utcnow()
            })
        except Exception:
            pass

    return _format_shipment_dict(new_shipment, db)

@router.get("/{shipment_id}", response_model=ShipmentResponse)
def get_shipment_by_id(
    shipment_id: int,
    current_shipper: Shipper = Depends(get_current_shipper),
    db: Session = Depends(get_db)
):
    """Fetches details for a specific shipment."""
    shipment = db.query(Shipment).filter(Shipment.shipment_id == shipment_id).first()
    if not shipment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Shipment #{shipment_id} not found.")

    return _format_shipment_dict(shipment, db)

@router.post("/{shipment_id}/cancel", response_model=ShipmentCancelResponse)
def cancel_shipment(
    shipment_id: int,
    current_shipper: Shipper = Depends(get_current_shipper),
    db: Session = Depends(get_db)
):
    """
    Cancels a booked shipment.
    STRICT POLICY:
    - Cancellation is only allowed within 5 hours of booking.
    - If status has transitioned to 'picked_up', 'in_transit', etc., cancellation is REJECTED.
    - Executes Saga compensating transaction: refunds invoice & records audit event.
    """
    shipment = db.query(Shipment).filter(Shipment.shipment_id == shipment_id).first()
    if not shipment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Shipment #{shipment_id} does not exist."
        )

    # Execute Saga
    result = SagaOrchestrator.execute_cancellation_saga(db, shipment, current_shipper.shipper_id)
    return ShipmentCancelResponse(**result)

@router.post("/estimate-cost", response_model=CostEstimateResponse)
def estimate_cost_endpoint(req: CostEstimateRequest):
    """
    Standalone cost estimation endpoint invoking MySQL stored procedure `sp_estimate_cost`.
    """
    same_city = req.origin_city.strip().lower() == req.destination_city.strip().lower()
    cost = estimate_cost_sp(req.weight_kg, same_city)
    rate = 8.00 if same_city else 15.00
    return CostEstimateResponse(
        weight_kg=req.weight_kg,
        same_city=same_city,
        estimated_cost=cost,
        rate_per_kg=rate,
        base_rate=50.00
    )
