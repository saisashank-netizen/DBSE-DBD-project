from datetime import datetime
from sqlalchemy import (
    Column, Integer, String, Numeric, DateTime, ForeignKey, Enum as SQLEnum, Text
)
from sqlalchemy.orm import relationship
from app.database import Base

class Shipper(Base):
    __tablename__ = "shippers"

    shipper_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    full_name = Column(String(100), nullable=False)
    email = Column(String(120), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    phone = Column(String(20))
    company_name = Column(String(120))
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    shipments = relationship("Shipment", back_populates="shipper", cascade="all, delete-orphan")


class Carrier(Base):
    __tablename__ = "carriers"

    carrier_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    carrier_name = Column(String(100), nullable=False)
    contact_email = Column(String(120))
    contact_phone = Column(String(20))

    # Relationships
    vehicles = relationship("Vehicle", back_populates="carrier", cascade="all, delete-orphan")
    drivers = relationship("Driver", back_populates="carrier", cascade="all, delete-orphan")
    shipments = relationship("Shipment", back_populates="carrier")


class Vehicle(Base):
    __tablename__ = "vehicles"

    vehicle_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    carrier_id = Column(Integer, ForeignKey("carriers.carrier_id", ondelete="CASCADE"), nullable=False)
    vehicle_number = Column(String(30), unique=True, nullable=False)
    vehicle_type = Column(SQLEnum('truck', 'van', 'bike', 'container', name="vehicle_type_enum"), nullable=False)
    capacity_kg = Column(Numeric(10, 2), nullable=False)

    carrier = relationship("Carrier", back_populates="vehicles")
    shipments = relationship("Shipment", back_populates="vehicle")


class Driver(Base):
    __tablename__ = "drivers"

    driver_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    carrier_id = Column(Integer, ForeignKey("carriers.carrier_id", ondelete="CASCADE"), nullable=False)
    full_name = Column(String(100), nullable=False)
    license_number = Column(String(50), unique=True, nullable=False)
    phone = Column(String(20))

    carrier = relationship("Carrier", back_populates="drivers")
    shipments = relationship("Shipment", back_populates="driver")


class Warehouse(Base):
    __tablename__ = "warehouses"

    warehouse_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    name = Column(String(100), nullable=False)
    city = Column(String(80), nullable=False)
    address = Column(String(200))


class Shipment(Base):
    __tablename__ = "shipments"

    shipment_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    shipper_id = Column(Integer, ForeignKey("shippers.shipper_id", ondelete="CASCADE"), nullable=False, index=True)
    carrier_id = Column(Integer, ForeignKey("carriers.carrier_id", ondelete="SET NULL"), nullable=True)
    vehicle_id = Column(Integer, ForeignKey("vehicles.vehicle_id", ondelete="SET NULL"), nullable=True)
    driver_id = Column(Integer, ForeignKey("drivers.driver_id", ondelete="SET NULL"), nullable=True)

    origin_address = Column(String(200), nullable=False)
    origin_city = Column(String(80), nullable=False)
    destination_address = Column(String(200), nullable=False)
    destination_city = Column(String(80), nullable=False)

    weight_kg = Column(Numeric(10, 2), nullable=False)
    length_cm = Column(Numeric(8, 2), nullable=True)
    width_cm = Column(Numeric(8, 2), nullable=True)
    height_cm = Column(Numeric(8, 2), nullable=True)

    status = Column(
        SQLEnum('booked', 'picked_up', 'in_transit', 'out_for_delivery', 'delivered', 'cancelled', name="shipment_status_enum"),
        nullable=False,
        default='booked'
    )
    estimated_cost = Column(Numeric(10, 2), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    picked_up_at = Column(DateTime, nullable=True)
    delivered_at = Column(DateTime, nullable=True)

    # Relationships
    shipper = relationship("Shipper", back_populates="shipments")
    carrier = relationship("Carrier", back_populates="shipments")
    vehicle = relationship("Vehicle", back_populates="shipments")
    driver = relationship("Driver", back_populates="shipments")
    events = relationship("TrackingEvent", back_populates="shipment", cascade="all, delete-orphan", order_by="TrackingEvent.event_time.asc()")
    invoice = relationship("Invoice", back_populates="shipment", uselist=False, cascade="all, delete-orphan")


class TrackingEvent(Base):
    __tablename__ = "trackingevents"

    event_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    shipment_id = Column(Integer, ForeignKey("shipments.shipment_id", ondelete="CASCADE"), nullable=False, index=True)
    status = Column(
        SQLEnum('booked', 'picked_up', 'in_transit', 'out_for_delivery', 'delivered', 'cancelled', name="event_status_enum"),
        nullable=False
    )
    location = Column(String(150), nullable=True)
    notes = Column(String(255), nullable=True)
    event_time = Column(DateTime, default=datetime.utcnow, index=True)

    shipment = relationship("Shipment", back_populates="events")


class Invoice(Base):
    __tablename__ = "invoices"

    invoice_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    shipment_id = Column(Integer, ForeignKey("shipments.shipment_id", ondelete="CASCADE"), nullable=False, unique=True)
    amount = Column(Numeric(10, 2), nullable=False)
    payment_status = Column(
        SQLEnum('pending', 'paid', 'failed', 'refunded', name="payment_status_enum"),
        nullable=False,
        default='pending'
    )
    payment_method = Column(String(40), nullable=True)
    issued_at = Column(DateTime, default=datetime.utcnow)
    paid_at = Column(DateTime, nullable=True)

    shipment = relationship("Shipment", back_populates="invoice")
