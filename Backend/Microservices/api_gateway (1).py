"""
CO5 Microservices Engineering: API Gateway
Acts as the single point of entry for clients, routing traffic,
validating JWT authentication tokens, and centralizing error handling.
"""

from fastapi import FastAPI, Request, HTTPException, status
from fastapi.responses import JSONResponse
import httpx
from app.config import settings
from app.security import decode_access_token

gateway_app = FastAPI(
    title="ShipEasy API Gateway",
    description="Microservice API Gateway providing centralized token validation and request forwarding"
)

# Downstream service addresses in microservice architecture
SERVICES = {
    "auth": "http://127.0.0.1:8001",
    "shipments": "http://127.0.0.1:8002",
    "telemetry": "http://127.0.0.1:8003"
}

@gateway_app.middleware("http")
async def token_gateway_middleware(request: Request, call_next):
    # Allow public endpoints
    path = request.url.path
    if path.startswith("/api/auth/login") or path.startswith("/api/auth/register") or path == "/health" or path == "/":
        return await call_next(request)

    # Validate Authorization token
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return JSONResponse(
            status_code=status.HTTP_401_UNAUTHORIZED,
            content={"detail": "API Gateway: Missing or invalid Bearer token"}
        )

    token = auth_header.split(" ")[1]
    payload = decode_access_token(token)
    if not payload:
        return JSONResponse(
            status_code=status.HTTP_401_UNAUTHORIZED,
            content={"detail": "API Gateway: Token expired or signature invalid"}
        )

    return await call_next(request)

@gateway_app.get("/health")
def gateway_health():
    return {"gateway": "healthy", "architecture": "microservices", "services": SERVICES}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("api_gateway:gateway_app", host="0.0.0.0", port=8000, reload=True)
