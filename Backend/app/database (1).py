import pymysql
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from pymongo import MongoClient
import motor.motor_asyncio
from app.config import settings

# --- SQLAlchemy MySQL Setup (CO1 Relational Core) ---
engine = create_engine(
    settings.MYSQL_URL,
    pool_pre_ping=True,
    pool_recycle=3600,
    echo=False
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_raw_mysql_connection():
    """Provides a direct PyMySQL connection for calling stored procedures and CTEs."""
    return pymysql.connect(
        host=settings.MYSQL_HOST,
        port=settings.MYSQL_PORT,
        user=settings.MYSQL_USER,
        password=settings.MYSQL_PASSWORD,
        database=settings.MYSQL_DB,
        cursorclass=pymysql.cursors.DictCursor
    )

# --- MongoDB Setup (CO2 Document Store & High-Speed Telemetry) ---
mongo_client = MongoClient(settings.MONGODB_URI)
mongo_db = mongo_client[settings.MONGODB_DB]

# Async motor client for async FastAPI endpoints
async_mongo_client = motor.motor_asyncio.AsyncIOMotorClient(settings.MONGODB_URI)
async_mongo_db = async_mongo_client[settings.MONGODB_DB]

# MongoDB Collections
telemetry_collection = mongo_db["telemetry_pings"]
audit_collection = mongo_db["audit_logs"]
geo_routes_collection = mongo_db["geo_routes"]

def init_mongo_indexes():
    """Ensures indexes for fast geospatial and timeline querying."""
    try:
        telemetry_collection.create_index([("shipment_id", 1), ("timestamp", -1)])
        audit_collection.create_index([("shipment_id", 1), ("created_at", -1)])
        geo_routes_collection.create_index([("shipment_id", 1)])
    except Exception as e:
        print(f"Warning: Failed to create mongo indexes: {e}")
