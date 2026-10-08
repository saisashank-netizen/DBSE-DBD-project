from datetime import datetime, timezone
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field

class TelemetryDocument(BaseModel):
    shipment_id: int
    lat: float
    lng: float
    speed_kmh: float = 0.0
    notes: Optional[str] = None
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    def to_mongo(self) -> Dict[str, Any]:
        return {
            "shipment_id": self.shipment_id,
            "lat": self.lat,
            "lng": self.lng,
            "speed_kmh": self.speed_kmh,
            "notes": self.notes,
            "timestamp": self.timestamp
        }


class AuditLogDocument(BaseModel):
    action: str
    service: str
    shipment_id: Optional[int] = None
    shipper_id: Optional[int] = None
    details: Dict[str, Any] = {}
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    def to_mongo(self) -> Dict[str, Any]:
        return {
            "action": self.action,
            "service": self.service,
            "shipment_id": self.shipment_id,
            "shipper_id": self.shipper_id,
            "details": self.details,
            "created_at": self.created_at
        }
