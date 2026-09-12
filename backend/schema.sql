DROP DATABASE IF EXISTS logistics_app;
CREATE DATABASE logistics_app;
USE logistics_app;

CREATE TABLE Shippers (
    shipper_id      INT AUTO_INCREMENT PRIMARY KEY,
    full_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(120) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    phone           VARCHAR(20),
    company_name    VARCHAR(120),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Carriers (
    carrier_id      INT AUTO_INCREMENT PRIMARY KEY,
    carrier_name    VARCHAR(100) NOT NULL,
    contact_email   VARCHAR(120),
    contact_phone   VARCHAR(20)
);

CREATE TABLE Vehicles (
    vehicle_id      INT AUTO_INCREMENT PRIMARY KEY,
    carrier_id      INT NOT NULL,
    vehicle_number  VARCHAR(30) NOT NULL UNIQUE,
    vehicle_type    ENUM('truck','van','bike','container') NOT NULL,
    capacity_kg     DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (carrier_id) REFERENCES Carriers(carrier_id) ON DELETE CASCADE
);

CREATE TABLE Drivers (
    driver_id       INT AUTO_INCREMENT PRIMARY KEY,
    carrier_id      INT NOT NULL,
    full_name       VARCHAR(100) NOT NULL,
    license_number  VARCHAR(50) NOT NULL UNIQUE,
    phone           VARCHAR(20),
    FOREIGN KEY (carrier_id) REFERENCES Carriers(carrier_id) ON DELETE CASCADE
);

CREATE TABLE Warehouses (
    warehouse_id    INT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    city            VARCHAR(80) NOT NULL,
    address         VARCHAR(200)
);

CREATE TABLE Shipments (
    shipment_id      INT AUTO_INCREMENT PRIMARY KEY,
    shipper_id       INT NOT NULL,
    carrier_id       INT,
    vehicle_id       INT,
    driver_id        INT,
    origin_address   VARCHAR(200) NOT NULL,
    origin_city      VARCHAR(80) NOT NULL,
    destination_address VARCHAR(200) NOT NULL,
    destination_city VARCHAR(80) NOT NULL,
    weight_kg        DECIMAL(10,2) NOT NULL CHECK (weight_kg > 0),
    length_cm        DECIMAL(8,2),
    width_cm         DECIMAL(8,2),
    height_cm        DECIMAL(8,2),
    status           ENUM('booked','picked_up','in_transit','out_for_delivery','delivered','cancelled')
                      NOT NULL DEFAULT 'booked',
    estimated_cost   DECIMAL(10,2),
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    picked_up_at     TIMESTAMP NULL,
    delivered_at     TIMESTAMP NULL,
    FOREIGN KEY (shipper_id) REFERENCES Shippers(shipper_id) ON DELETE CASCADE,
    FOREIGN KEY (carrier_id) REFERENCES Carriers(carrier_id) ON DELETE SET NULL,
    FOREIGN KEY (vehicle_id) REFERENCES Vehicles(vehicle_id) ON DELETE SET NULL,
    FOREIGN KEY (driver_id) REFERENCES Drivers(driver_id) ON DELETE SET NULL,
    INDEX idx_shipper_status (shipper_id, status),
    INDEX idx_created_at (created_at)
);

CREATE TABLE TrackingEvents (
    event_id        INT AUTO_INCREMENT PRIMARY KEY,
    shipment_id     INT NOT NULL,
    status          ENUM('booked','picked_up','in_transit','out_for_delivery','delivered','cancelled') NOT NULL,
    location        VARCHAR(150),
    notes           VARCHAR(255),
    event_time      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (shipment_id) REFERENCES Shipments(shipment_id) ON DELETE CASCADE,
    INDEX idx_shipment_time (shipment_id, event_time)
);

CREATE TABLE Invoices (
    invoice_id      INT AUTO_INCREMENT PRIMARY KEY,
    shipment_id     INT NOT NULL UNIQUE,
    amount          DECIMAL(10,2) NOT NULL,
    payment_status  ENUM('pending','paid','failed','refunded') NOT NULL DEFAULT 'pending',
    payment_method  VARCHAR(40),
    issued_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    paid_at         TIMESTAMP NULL,
    FOREIGN KEY (shipment_id) REFERENCES Shipments(shipment_id) ON DELETE CASCADE
);

DELIMITER $$
CREATE TRIGGER trg_sync_shipment_status
AFTER INSERT ON TrackingEvents
FOR EACH ROW
BEGIN
    UPDATE Shipments
    SET status = NEW.status,
        picked_up_at = CASE WHEN NEW.status = 'picked_up' THEN NEW.event_time ELSE picked_up_at END,
        delivered_at = CASE WHEN NEW.status = 'delivered' THEN NEW.event_time ELSE delivered_at END
    WHERE shipment_id = NEW.shipment_id;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_estimate_cost(
    IN p_weight_kg DECIMAL(10,2),
    IN p_same_city BOOLEAN,
    OUT p_cost DECIMAL(10,2)
)
BEGIN
    DECLARE base_rate DECIMAL(10,2) DEFAULT 50.00;
    DECLARE per_kg_rate DECIMAL(10,2);
    SET per_kg_rate = IF(p_same_city, 8.00, 15.00);
    SET p_cost = base_rate + (p_weight_kg * per_kg_rate);
END$$
DELIMITER ;
