from fastapi import FastAPI, Request
from app.db import get_db
from app.simulation import initialize_towers
from app.models import Signal, Tower
from app.signal_processor import process_signal
import os

app = FastAPI()

@app.on_event("startup")
async def on_startup():
    db = get_db()
    await initialize_towers(db)

@app.post("/signal")
async def receive_signal(signal: Signal):
    db = get_db()
    await process_signal(signal, db)
    return {"status": "received"}

@app.get("/api/simulation/towers")
async def get_towers(request: Request):
    print(f"📥 Simulation received request: {request.url.path}")
    db = get_db()
    towers_cursor = db["towers"].find()
    towers = [Tower(**tower) async for tower in towers_cursor]
    return towers

# Health check, make sure that mongodb is working before startup
@app.get("/healthz")
async def healthz():
    try:
        db = get_db()
        await db["towers"].find_one()
        return {"status": "ok"}
    except Exception:
        return JSONResponse(status_code=503, content={"status": "unhealthy"})
