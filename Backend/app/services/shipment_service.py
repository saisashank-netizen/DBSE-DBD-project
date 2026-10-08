from datetime import datetime, timedelta
from typing import Tuple, Optional, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy import text
from fastapi import HTTPException, status
from app.config import settings
from app.models.sql_models import Shipment, TrackingEvent, Invoice, Carrier, Vehicle, Driver
from app.database import get_raw_mysql_connection, audit_collection, telemetry_collection

def estimate_cost_sp(weight_kg: float, same_city: bool) -> float:
    """
    Invokes the MySQL stored procedure `sp_estimate_cost` (CO1).
    Falls back to Python calculation if procedure unavailable.
    """
    try:
        conn = get_raw_mysql_connection()
        with conn.cursor() as cur:
            cur.execute("CALL sp_estimate_cost(%s, %s, @p_cost);", (weight_kg, same_city))
            cur.execute("SELECT @p_cost AS cost;")
            res = cur.fetchone()
            if res and res.get("cost") is not None:
                cost = float(res["cost"])
                conn.close()
                return cost
        conn.close()
    except Exception as e:
        # Fallback pricing calculation
        pass

    per_kg = 8.00 if same_city else 15.00
    return round(50.00 + (weight_kg * per_kg), 2)

def evaluate_cancellation_eligibility(shipment: Shipment) -> Tuple[bool, str, Optional[datetime], Optional[str]]:
    """
    Evaluates whether a shipment can be cancelled based on:
    1. Status MUST be 'booked' (once picked_up, in_transit, etc., cancellation is strictly rejected).
    2. Must be within the 5-hour cancellation window from booking time.
    """
    if shipment.status == "cancelled":
        return False, "This shipment is already cancelled.", None, "0h 0m"

    if shipment.status in ["picked_up", "in_transit", "out_for_delivery", "delivered"]:
        status_readable = shipment.status.replace("_", " ")
        return False, f"This shipment has already been {status_readable} and cannot be cancelled.", None, "0h 0m"

    if shipment.status != "booked":
        return False, f"Shipments in '{shipment.status}' status cannot be cancelled.", None, "0h 0m"

    # Evaluate 5-hour cutoff
    created_at = shipment.created_at or datetime.utcnow()
    deadline = created_at + timedelta(hours=settings.CANCELLATION_WINDOW_HOURS)
    now = datetime.utcnow()

    if now > deadline:
        return (
            False,
            f"The {int(settings.CANCELLATION_WINDOW_HOURS)}-hour cancellation window has expired. "
            f"Booked at {created_at.strftime('%Y-%m-%d %H:%M:%S UTC')}.",
            deadline,
            "0h 0m"
        )

    # Time remaining
    remaining = deadline - now
    hours = int(remaining.total_seconds() // 3600)
    minutes = int((remaining.total_seconds() % 3600) // 60)
    time_remaining_str = f"{hours}h {minutes}m"

    return True, "Shipment can be cancelled within the 5-hour window.", deadline, time_remaining_str

def auto_assign_logistics(db: Session, weight_kg: float) -> Tuple[Optional[Carrier], Optional[Vehicle], Optional[Driver]]:
    """
    Finds a suitable carrier, vehicle with capacity, and driver (CO1 relational joins).
    """
    # Prefer vehicle that can handle weight
    vehicle = db.query(Vehicle).filter(Vehicle.capacity_kg >= weight_kg).first()
    if vehicle:
        carrier = db.query(Carrier).filter(Carrier.carrier_id == vehicle.carrier_id).first()
        driver = db.query(Driver).filter(Driver.carrier_id == vehicle.carrier_id).first()
        return carrier, vehicle, driver

    # Fallback to any carrier
    carrier = db.query(Carrier).first()
    driver = db.query(Driver).filter(Driver.carrier_id == carrier.carrier_id).first() if carrier else None
    vehicle = db.query(Vehicle).filter(Vehicle.carrier_id == carrier.carrier_id).first() if carrier else None
    return carrier, vehicle, driver
