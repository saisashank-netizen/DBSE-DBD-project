from datetime import datetime, timezone
from typing import List, Dict, Any, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from app.models.pydantic_schemas import TelemetryPingRequest, TelemetryPingResponse
from app.database import telemetry_collection, async_mongo_db

router = APIRouter(prefix="/tracking", tags=["Live Tracking & Telemetry (MongoDB)"])

@router.post("/ping", response_model=TelemetryPingResponse)
def record_telemetry_ping(ping: TelemetryPingRequest):
    """
    Ingests high-frequency IoT GPS pings into MongoDB (CO2 Document Engineering).
    This handles write-heavy IoT streaming data without locking relational tables.
    """
    doc = {
        "shipment_id": ping.shipment_id,
        "lat": ping.lat,
        "lng": ping.lng,
        "speed_kmh": ping.speed_kmh or 0.0,
        "notes": ping.notes or "Live GPS ping",
        "timestamp": datetime.now(timezone.utc)
    }
    telemetry_collection.insert_one(doc)

    return TelemetryPingResponse(
        success=True,
        shipment_id=ping.shipment_id,
        lat=ping.lat,
        lng=ping.lng,
        recorded_at=doc["timestamp"]
    )

@router.get("/{shipment_id}/pings")
def get_shipment_pings(shipment_id: int):
    """
    Fetches raw GPS coordinate history from MongoDB.
    """
    cursor = telemetry_collection.find(
        {"shipment_id": shipment_id},
        {"_id": 0}
    ).sort("timestamp", 1)

    pings = list(cursor)
    return {"shipment_id": shipment_id, "count": len(pings), "pings": pings}

@router.get("/{shipment_id}/analytics")
def get_telemetry_aggregation(shipment_id: int):
    """
    Executes a MongoDB Aggregation Pipeline (CO2 syllabus requirement)
    to calculate max speed, average speed, waypoint count, and duration.
    """
    pipeline = [
        {"$match": {"shipment_id": shipment_id}},
        {
            "$group": {
                "_id": "$shipment_id",
                "total_pings": {"$sum": 1},
                "avg_speed": {"$avg": "$speed_kmh"},
                "max_speed": {"$max": "$speed_kmh"},
                "first_ping": {"$min": "$timestamp"},
                "last_ping": {"$max": "$timestamp"}
            }
        },
        {
            "$project": {
                "_id": 0,
                "shipment_id": "$_id",
                "total_pings": 1,
                "avg_speed_kmh": {"$round": ["$avg_speed", 2]},
                "max_speed_kmh": {"$round": ["$max_speed", 2]},
                "duration_minutes": {
                    "$round": [
                        {"$divide": [{"$subtract": ["$last_ping", "$first_ping"]}, 60000]},
                        2
                    ]
                }
            }
        }
    ]

    result = list(telemetry_collection.aggregate(pipeline))
    if not result:
        return {
            "shipment_id": shipment_id,
            "total_pings": 0,
            "avg_speed_kmh": 0.0,
            "max_speed_kmh": 0.0,
            "duration_minutes": 0.0
        }
    return result[0]
