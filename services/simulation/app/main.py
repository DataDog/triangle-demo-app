import os
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from app.db import get_db
from app.simulation import initialize_towers
from app.models import Signal, Tower
from app.signal_processor import process_signal
import logging

# Configure Python logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI()

@app.on_event("startup")
async def on_startup():
    try:
        # Initialize database
        db = await get_db()
        await initialize_towers(db)
        logger.info("Simulation service started successfully")
    except Exception as e:
        logger.error(f"Failed to start simulation service: {str(e)}")
        raise

@app.post("/signal")
async def receive_signal(signal: Signal):
    logger.info(f"Received signal: x={signal.x}, y={signal.y}")
    db = await get_db()
    await process_signal(signal, db)
    return {"status": "received"}

@app.get("/api/simulation/towers")
async def get_towers(request: Request):
    logger.info(f"📥 Simulation received request: {request.url.path}")
    db = await get_db()
    towers_cursor = db["towers"].find()
    towers = [Tower(**tower) async for tower in towers_cursor]
    logger.info(f"Returning {len(towers)} towers")
    return towers

@app.get("/healthz")
async def healthz():
    try:
        db = await get_db()
        # Check if towers collection exists and has documents
        towers_count = await db["towers"].count_documents({})
        if towers_count == 0:
            logger.warning("Towers collection is empty")
            return JSONResponse(status_code=503, content={"status": "unhealthy", "reason": "towers_empty"})
        logger.info("Health check passed")
        return {"status": "ok", "towers_count": towers_count}
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return JSONResponse(status_code=503, content={"status": "unhealthy", "reason": str(e)})

@app.get("/signal/healthz")
async def signal_healthz():
    """Health check endpoint for the signal processing service."""
    try:
        db = await get_db()
        # Check if towers collection exists and has documents
        towers_count = await db["towers"].count_documents({})
        if towers_count == 0:
            logger.warning("Towers collection is empty")
            return JSONResponse(status_code=503, content={"status": "unhealthy", "reason": "towers_empty"})
        logger.info("Signal health check passed")
        return {"status": "ok", "towers_count": towers_count}
    except Exception as e:
        logger.error(f"Signal health check failed: {str(e)}")
        return JSONResponse(status_code=503, content={"status": "unhealthy", "reason": str(e)})
