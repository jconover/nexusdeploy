"""API Gateway Service - Entry point for all client requests."""
import logging
import time
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, Request, Response
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

START_TIME = time.time()


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("API Gateway starting up")
    yield
    logger.info("API Gateway shutting down")


app = FastAPI(title="API Gateway", version="1.0.0", lifespan=lifespan)


class HealthResponse(BaseModel):
    status: str
    uptime_seconds: float


class StatusResponse(BaseModel):
    service: str
    version: str
    environment: str
    dependencies: dict


@app.get("/health", response_model=HealthResponse)
async def health():
    """Liveness probe endpoint."""
    return HealthResponse(
        status="healthy",
        uptime_seconds=round(time.time() - START_TIME, 2),
    )


@app.get("/ready")
async def ready():
    """Readiness probe endpoint."""
    return {"status": "ready"}


@app.get("/api/v1/status", response_model=StatusResponse)
async def status():
    """Service status and dependency overview."""
    import os

    return StatusResponse(
        service="api-gateway",
        version="1.0.0",
        environment=os.getenv("ENVIRONMENT", "development"),
        dependencies={
            "auth-service": os.getenv("AUTH_SERVICE_URL", "http://auth-service:8081"),
            "worker-service": os.getenv("WORKER_SERVICE_URL", "http://worker-service:8082"),
        },
    )


@app.get("/api/v1/ping")
async def ping():
    return {"message": "pong", "timestamp": time.time()}
