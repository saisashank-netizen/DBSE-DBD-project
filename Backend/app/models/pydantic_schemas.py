from pydantic import BaseModel, EmailStr, Field, ConfigDict
from typing import Optional, List, Any
from datetime import datetime
from decimal import Decimal

# --- Auth & Token Schemas (CO3) ---
class ShipperRegisterRequest(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=100)
    email: EmailStr
    password: str = Field(..., min_length=4, max_length=100)
    phone: Optional[str] = Field(None, max_length=20)
    company_name: Optional[str] = Field(None, max_length=120)

class LoginRequest(BaseModel):
    username_or_email: Optional[str] = None
    email: Optional[str] = None
    username: Optional[str] = None
    password: str

class ShipperProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    shipper_id: int
    full_name: str
    email: str
    phone: Optional[str] = None
    company_name: Optional[str] = None
    created_at: Optional[datetime] = None

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in_minutes: int
    shipper: ShipperProfileResponse


# --- Shipment & Tracking Schemas (CO1, CO3) ---
class CostEstimateRequest(BaseModel):
    weight_kg: float = Field(..., gt=0, description="Package weight in kg")
    origin_city: str
    destination_city: str

class CostEstimateResponse(BaseModel):
    weight_kg: float
    same_city: bool
    estimated_cost: float
    rate_per_kg: float
    base_rate: float

class ShipmentCreateRequest(BaseModel):
    origin_address: str = Field(..., min_length=3, max_length=200)
    origin_city: str = Field(..., min_length=2, max_length=80)
    destination_address: str = Field(..., min_length=3, max_length=200)
    destination_city: str = Field(..., min_length=2, max_length=80)
    weight_kg: float = Field(..., gt=0)
    length_cm: Optional[float] = None
    width_cm: Optional[float] = None
    height_cm: Optional[float] = None
    # Optional coordinates from Flutter Map
    origin_lat: Optional[float] = None
    origin_lng: Optional[float] = None
    destination_lat: Optional[float] = None
    destination_lng: Optional[float] = None

class TrackingEventResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    event_id: int
    status: str
    location: Optional[str] = None
    notes: Optional[str] = None
    event_time: datetime
    lat: Optional[float] = None
    lng: Optional[float] = None

class ShipmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    shipper_id: int
    origin: str
    origin_city: str
    destination: str
    destination_city: str
    weight: float
    status: str
    cost: float
    date: str
    created_at: datetime
    carrier: str
    carrier_id: Optional[int] = None
    vehicle_number: Optional[str] = None
    driver_name: Optional[str] = None
    can_cancel: bool
    cancellation_deadline: Optional[datetime] = None
    time_remaining_for_cancellation: Optional[str] = None
    timeline: List[TrackingEventResponse] = []
    latest_lat: Optional[float] = None
    latest_lng: Optional[float] = None

class ShipmentCancelResponse(BaseModel):
    success: bool
    message: str
    shipment_id: int
    status: str
    invoice_refund_status: Optional[str] = None


# --- MongoDB Telemetry Schemas (CO2) ---
class TelemetryPingRequest(BaseModel):
    shipment_id: int
    lat: float
    lng: float
    speed_kmh: Optional[float] = 0.0
    notes: Optional[str] = "Live GPS ping"

class TelemetryPingResponse(BaseModel):
    success: bool
    shipment_id: int
    lat: float
    lng: float
    recorded_at: datetime


# --- Advanced Analytics Schemas (CO1 SQL Advanced) ---
class CarrierAnalytics(BaseModel):
    carrier_name: str
    total_shipments: int
    delivered_shipments: int
    avg_weight_kg: float
    total_revenue: float
    efficiency_rank: int

class MonthlyRevenueCTE(BaseModel):
    month_year: str
    shipment_count: int
    gross_revenue: float
    avg_order_value: float


# --- AI Vector & Cargo Categorization (CO2) ---
class CargoClassifyRequest(BaseModel):
    cargo_description: str
    declared_weight_kg: float

class CargoClassifyResponse(BaseModel):
    category: str
    similarity_score: float
    recommended_vehicle: str
    special_handling_instructions: str
