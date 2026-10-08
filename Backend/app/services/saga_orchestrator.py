from datetime import datetime
from typing import Dict, Any
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.models.sql_models import Shipment, TrackingEvent, Invoice
from app.services.shipment_service import evaluate_cancellation_eligibility
from app.database import audit_collection

class SagaOrchestrator:
    """
    Implements CO5 Microservices Saga Pattern with Compensating Transactions.
    Coordinates across Relational Database (MySQL) and Document Audit Store (MongoDB).
    """

    @staticmethod
    def execute_cancellation_saga(db: Session, shipment: Shipment, shipper_id: int) -> Dict[str, Any]:
        # 1. Validation Phase
        can_cancel, reason, deadline, remaining = evaluate_cancellation_eligibility(shipment)
        if not can_cancel:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=reason
            )

        try:
            # 2. Transaction Phase 1: Update Shipment Status
            shipment.status = "cancelled"

            # 3. Transaction Phase 2: Add Tracking Event
            cancel_event = TrackingEvent(
                shipment_id=shipment.shipment_id,
                status="cancelled",
                location=shipment.origin_city or "Origin Hub",
                notes="Shipment cancelled by shipper within 5-hour booking window.",
                event_time=datetime.utcnow()
            )
            db.add(cancel_event)

            # 4. Compensating Action (Saga Pattern): Refund Invoice
            invoice_refunded = False
            invoice = db.query(Invoice).filter(Invoice.shipment_id == shipment.shipment_id).first()
            if invoice:
                invoice.payment_status = "refunded"
                invoice_refunded = True

            # Commit relational transaction (ACID guarantees in MySQL)
            db.commit()
            db.refresh(shipment)

            # 5. Distributed Event Publishing: Write to MongoDB Audit Stream (CO2 & CO5)
            try:
                audit_collection.insert_one({
                    "action": "SHIPMENT_CANCELLED",
                    "service": "shipment_cancellation_service",
                    "shipment_id": shipment.shipment_id,
                    "shipper_id": shipper_id,
                    "details": {
                        "previous_status": "booked",
                        "new_status": "cancelled",
                        "invoice_refunded": invoice_refunded,
                        "cancellation_timestamp": datetime.utcnow().isoformat()
                    },
                    "created_at": datetime.utcnow()
                })
            except Exception as e:
                # MongoDB audit logging non-blocking for core transaction
                pass

            return {
                "success": True,
                "message": f"Shipment #{shipment.shipment_id} has been cancelled successfully. Any pending charges have been refunded.",
                "shipment_id": shipment.shipment_id,
                "status": "cancelled",
                "invoice_refund_status": "refunded" if invoice_refunded else "none"
            }

        except HTTPException:
            db.rollback()
            raise
        except Exception as e:
            db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to cancel shipment due to internal error: {str(e)}"
            )
