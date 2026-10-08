"""
generate_seed_data.py
Generates seed_data.sql with 50+ rows in every table for the
Logistics & Supply Chain Mobile App database (matches schema.sql).

Run: python3 generate_seed_data.py
Output: seed_data.sql  (import this AFTER schema.sql in MySQL Workbench)
"""

import random
from datetime import datetime, timedelta

random.seed(42)  # reproducible output

FIRST_NAMES = ["Ravi","Priya","Arjun","Sneha","Kiran","Divya","Manoj","Anitha","Suresh","Lakshmi",
               "Vijay","Pooja","Naveen","Swathi","Rahul","Meena","Sanjay","Deepa","Karthik","Anusha",
               "Vikram","Nisha","Ajay","Shreya","Prakash","Kavya","Ramesh","Sindhu","Gopal","Radhika",
               "Harish","Sowmya","Dinesh","Padma","Srinivas","Bhavana","Mahesh","Jyothi","Anil","Roja",
               "Krishna","Sunitha","Venkat","Aparna","Sathish","Madhavi","Ganesh","Vani","Praveen","Latha"]

LAST_NAMES = ["Kumar","Reddy","Sharma","Rao","Naidu","Chowdary","Verma","Iyer","Nair","Gupta"]

COMPANIES = ["Fresh Mart Grocery","QuickBasket Online","Daily Needs Store","GreenLeaf Grocers",
             "UrbanCart","MiniMart Express","ValueBazaar","LocalPantry","EasyBuy Store","CityGrocers",
             "SmartShop Online","BudgetBasket","HomeNeeds Store","QuickShop","FreshPick Grocery"]

CITIES = ["Hyderabad","Bangalore","Chennai","Vijayawada","Visakhapatnam","Warangal","Guntur",
          "Nellore","Kurnool","Tirupati","Mysore","Coimbatore"]

STREETS = ["Main Road","Gandhi Nagar","MG Road","Jubilee Hills","Ameerpet","Kukatpally",
           "Madhapur","Banjara Hills","LB Nagar","Dilsukhnagar","Secunderabad Rd","Kondapur"]

STATUSES_ORDER = ["booked","picked_up","in_transit","out_for_delivery","delivered"]

sql = []
sql.append("USE logistics_app;\n")
sql.append("SET FOREIGN_KEY_CHECKS = 0;\n")
sql.append("DELETE FROM Invoices; DELETE FROM TrackingEvents; DELETE FROM Shipments;")
sql.append("DELETE FROM Drivers; DELETE FROM Vehicles; DELETE FROM Warehouses; DELETE FROM Carriers; DELETE FROM Shippers;")
sql.append("SET FOREIGN_KEY_CHECKS = 1;\n")

# ---------- Shippers (50) ----------
sql.append("-- 50 Shippers")
shipper_rows = []
for i in range(1, 51):
    name = f"{random.choice(FIRST_NAMES)} {random.choice(LAST_NAMES)}"
    email = f"shipper{i}@example.com"
    phone = f"9{random.randint(100000000,999999999)}"
    company = random.choice(COMPANIES)
    shipper_rows.append(f"('{name}','{email}','$2b$10$hashplaceholder{i:02d}','{phone}','{company}')")
sql.append("INSERT INTO Shippers (full_name, email, password_hash, phone, company_name) VALUES\n" + ",\n".join(shipper_rows) + ";\n")

# ---------- Carriers (50) ----------
sql.append("-- 50 Carriers")
carrier_names = ["Swift Freight","BlueLine Logistics","Rapid Cargo","MetroTrans","EastWest Movers",
                  "CityLink Transport","Prime Haulers","SafeRoute Logistics","QuickShip Carriers","TransLine Co"]
carrier_rows = []
for i in range(1, 51):
    name = f"{random.choice(carrier_names)} {i}"
    email = f"ops{i}@carrier{i}.com"
    phone = f"9{random.randint(100000000,999999999)}"
    carrier_rows.append(f"('{name}','{email}','{phone}')")
sql.append("INSERT INTO Carriers (carrier_name, contact_email, contact_phone) VALUES\n" + ",\n".join(carrier_rows) + ";\n")

# ---------- Vehicles (50) ----------
sql.append("-- 50 Vehicles")
vehicle_types = ["truck","van","bike","container"]
vehicle_rows = []
for i in range(1, 51):
    carrier_id = random.randint(1, 50)
    plate = f"TS{random.randint(10,99)}{random.choice('ABCDEFGH')}{random.randint(1000,9999)}"
    vtype = random.choice(vehicle_types)
    capacity = {"truck": 5000, "van": 1200, "bike": 30, "container": 15000}[vtype]
    vehicle_rows.append(f"({carrier_id},'{plate}','{vtype}',{capacity})")
sql.append("INSERT INTO Vehicles (carrier_id, vehicle_number, vehicle_type, capacity_kg) VALUES\n" + ",\n".join(vehicle_rows) + ";\n")

# ---------- Drivers (50) ----------
sql.append("-- 50 Drivers")
driver_rows = []
for i in range(1, 51):
    carrier_id = random.randint(1, 50)
    name = f"{random.choice(FIRST_NAMES)} {random.choice(LAST_NAMES)}"
    license_no = f"DL{random.randint(10000000,99999999)}"
    phone = f"9{random.randint(100000000,999999999)}"
    driver_rows.append(f"({carrier_id},'{name}','{license_no}','{phone}')")
sql.append("INSERT INTO Drivers (carrier_id, full_name, license_number, phone) VALUES\n" + ",\n".join(driver_rows) + ";\n")

# ---------- Warehouses (50) ----------
sql.append("-- 50 Warehouses")
warehouse_rows = []
for i in range(1, 51):
    city = random.choice(CITIES)
    name = f"{city} Hub {i}"
    address = f"{random.choice(STREETS)}, {city}"
    warehouse_rows.append(f"('{name}','{city}','{address}')")
sql.append("INSERT INTO Warehouses (name, city, address) VALUES\n" + ",\n".join(warehouse_rows) + ";\n")

# ---------- Shipments (60) ----------
sql.append("-- 60 Shipments")
shipment_rows = []
NUM_SHIPMENTS = 60
base_date = datetime(2026, 6, 1)
shipment_final_status = []  # track chosen final status per shipment for tracking events later
for i in range(1, NUM_SHIPMENTS + 1):
    shipper_id = random.randint(1, 50)
    carrier_id = random.randint(1, 50)
    vehicle_id = random.randint(1, 50)
    driver_id = random.randint(1, 50)
    origin_city = random.choice(CITIES)
    dest_city = random.choice([c for c in CITIES if c != origin_city])
    origin_addr = f"{random.randint(1,200)}, {random.choice(STREETS)}"
    dest_addr = f"{random.randint(1,200)}, {random.choice(STREETS)}"
    weight = round(random.uniform(0.5, 500), 2)
    length = round(random.uniform(10, 150), 1)
    width = round(random.uniform(10, 100), 1)
    height = round(random.uniform(5, 100), 1)
    final_status = random.choices(STATUSES_ORDER + ["cancelled"], weights=[5,10,10,10,55,10])[0]
    shipment_final_status.append(final_status)
    same_city = origin_city == dest_city
    cost = round(50 + weight * (8 if same_city else 15), 2)
    created_offset = random.randint(0, 89)
    created_at = base_date + timedelta(days=created_offset, hours=random.randint(0,23))
    shipment_rows.append(
        f"({shipper_id},{carrier_id},{vehicle_id},{driver_id},"
        f"'{origin_addr}','{origin_city}','{dest_addr}','{dest_city}',"
        f"{weight},{length},{width},{height},'{final_status}',{cost},'{created_at.strftime('%Y-%m-%d %H:%M:%S')}')"
    )
sql.append(
    "INSERT INTO Shipments (shipper_id, carrier_id, vehicle_id, driver_id, origin_address, origin_city, "
    "destination_address, destination_city, weight_kg, length_cm, width_cm, height_cm, status, estimated_cost, created_at) VALUES\n"
    + ",\n".join(shipment_rows) + ";\n"
)

# ---------- TrackingEvents (one per lifecycle stage reached, ~200+ rows) ----------
sql.append("-- Tracking events (progressive history per shipment)")
event_rows = []
LOCATIONS = [f"{c} Hub" for c in CITIES]
for shipment_id in range(1, NUM_SHIPMENTS + 1):
    final_status = shipment_final_status[shipment_id - 1]
    if final_status == "cancelled":
        stages = ["booked", "cancelled"]
    else:
        idx = STATUSES_ORDER.index(final_status)
        stages = STATUSES_ORDER[:idx + 1]
    event_time = base_date + timedelta(days=random.randint(0, 85))
    for stage in stages:
        event_time += timedelta(hours=random.randint(2, 20))
        location = random.choice(LOCATIONS)
        notes = f"Status updated to {stage.replace('_',' ')}"
        event_rows.append(f"({shipment_id},'{stage}','{location}','{notes}','{event_time.strftime('%Y-%m-%d %H:%M:%S')}')")
sql.append("INSERT INTO TrackingEvents (shipment_id, status, location, notes, event_time) VALUES\n" + ",\n".join(event_rows) + ";\n")
sql.append(f"-- total tracking events generated: {len(event_rows)}\n")

# ---------- Invoices (one per delivered shipment; pad to ensure >=50) ----------
sql.append("-- Invoices for delivered shipments")
invoice_rows = []
delivered_ids = [i+1 for i, s in enumerate(shipment_final_status) if s == "delivered"]
# If fewer than 50 delivered shipments, invoices will naturally be < 50 (invoices only make
# sense for delivered/paid shipments) -- but we also add 'pending' invoices for in_transit/out_for_delivery
# ones so the Invoices table itself clears 50 rows, since every table needs 50+.
eligible_ids = [i+1 for i, s in enumerate(shipment_final_status) if s != "cancelled"]
for sid in eligible_ids:
    status_for_shipment = shipment_final_status[sid-1]
    amount = round(random.uniform(100, 4000), 2)
    if status_for_shipment == "delivered":
        pay_status = random.choices(["paid","pending","failed"], weights=[80,15,5])[0]
    else:
        pay_status = "pending"
    method = random.choice(["UPI","Card","NetBanking","Cash on Delivery"])
    invoice_rows.append(f"({sid},{amount},'{pay_status}','{method}')")
sql.append("INSERT INTO Invoices (shipment_id, amount, payment_status, payment_method) VALUES\n" + ",\n".join(invoice_rows) + ";\n")
sql.append(f"-- total invoices generated: {len(invoice_rows)}\n")

with open("seed_data.sql", "w") as f:
    f.write("\n".join(sql))

print("seed_data.sql generated.")
print("Row counts -> Shippers: 50, Carriers: 50, Vehicles: 50, Drivers: 50, Warehouses: 50,")
print(f"Shipments: {NUM_SHIPMENTS}, TrackingEvents: {len(event_rows)}, Invoices: {len(invoice_rows)}")
