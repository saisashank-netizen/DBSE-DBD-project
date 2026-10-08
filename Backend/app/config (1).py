import os
from pydantic import BaseModel

class Settings(BaseModel):
    PROJECT_NAME: str = "ShipEasy Logistics Microservices API"
    VERSION: str = "2.0.0"
    API_PREFIX: str = "/api"

    # MySQL Configuration (CO1 Relational Engineering)
    MYSQL_HOST: str = os.getenv("MYSQL_HOST", "127.0.0.1")
    MYSQL_PORT: int = int(os.getenv("MYSQL_PORT", 3306))
    MYSQL_USER: str = os.getenv("MYSQL_USER", "root")
    MYSQL_PASSWORD: str = os.getenv("MYSQL_PASSWORD", "Iamchaitanya@13542")
    MYSQL_DB: str = os.getenv("MYSQL_DB", "logistics_app")

    @property
    def MYSQL_URL(self) -> str:
        from urllib.parse import quote_plus
        encoded_password = quote_plus(self.MYSQL_PASSWORD)
        return f"mysql+pymysql://{self.MYSQL_USER}:{encoded_password}@{self.MYSQL_HOST}:{self.MYSQL_PORT}/{self.MYSQL_DB}"

    # MongoDB Configuration (CO2 Document Store & Real-Time Telemetry)
    MONGODB_URI: str = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
    MONGODB_DB: str = os.getenv("MONGODB_DB", "logistics_app_mongo")

    # JWT Authentication & Tokens (CO3 Security)
    JWT_SECRET: str = os.getenv("JWT_SECRET", "shipeasy_super_secret_jwt_key_2026_dbms_co3_co5")
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 24 hours

    # Cancellation Policy (User requirement: within 5 hours & before picked_up)
    CANCELLATION_WINDOW_HOURS: float = float(os.getenv("CANCELLATION_WINDOW_HOURS", "5.0"))

settings = Settings()
