import time
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response, RedirectResponse
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from app.config import settings
from app.database import engine, Base, init_mongo_indexes
from app.api import auth, shipments, tracking, analytics, ai_vector

# --- Observability & Prometheus Metrics (CO6) ---
REQUESTS_TOTAL = Counter("http_requests_total", "Total HTTP requests count", ["method", "endpoint", "status"])
REQUEST_DURATION = Histogram("http_request_duration_seconds", "HTTP request execution latency", ["endpoint"])

from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(application: FastAPI):
    # Ensure MySQL tables exist (CO1)
    Base.metadata.create_all(bind=engine)
    # Ensure MongoDB indexes exist (CO2)
    init_mongo_indexes()
    print("ShipEasy Backend started successfully with MySQL & MongoDB connections.")
    yield

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="ShipEasy Logistics API Gateway & Microservices Platform (FastAPI + MySQL + MongoDB)",
    openapi_url=f"{settings.API_PREFIX}/openapi.json",
    docs_url=f"{settings.API_PREFIX}/docs",
    redoc_url=f"{settings.API_PREFIX}/redoc",
    lifespan=lifespan
)

@app.get("/docs", include_in_schema=False)
def redirect_to_docs():
    return RedirectResponse(url=f"{settings.API_PREFIX}/docs")

# CORS Middleware for Flutter Client
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Request Metrics Middleware
@app.middleware("http")
async def monitor_requests(request: Request, call_next):
    start_time = time.time()
    endpoint = request.url.path
    try:
        response = await call_next(request)
        duration = time.time() - start_time
        REQUEST_DURATION.labels(endpoint=endpoint).observe(duration)
        REQUESTS_TOTAL.labels(method=request.method, endpoint=endpoint, status=response.status_code).inc()
        return response
    except Exception as exc:
        duration = time.time() - start_time
        REQUEST_DURATION.labels(endpoint=endpoint).observe(duration)
        REQUESTS_TOTAL.labels(method=request.method, endpoint=endpoint, status=500).inc()
        raise exc

# Health & Root Check
@app.get("/")
def root():
    return {
        "app": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "status": "online",
        "docs_url": f"{settings.API_PREFIX}/docs"
    }

@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "mysql": "connected",
        "mongodb": "connected",
        "timestamp": time.time()
    }

# Prometheus Metrics Endpoint (CO6 Observability)
@app.get("/metrics")
def get_metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

# Include Routers
app.include_router(auth.router, prefix=settings.API_PREFIX)
app.include_router(shipments.router, prefix=settings.API_PREFIX)
app.include_router(tracking.router, prefix=settings.API_PREFIX)
app.include_router(analytics.router, prefix=settings.API_PREFIX)
app.include_router(ai_vector.router, prefix=settings.API_PREFIX)
