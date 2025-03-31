import os
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from app.db import get_db
from app.simulation import initialize_towers
from app.models import Signal, Tower
from app.signal_processor import process_signal

# Initialize OpenTelemetry
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

print("🔧 Initializing OpenTelemetry...")
tracer_provider = TracerProvider()
otlp_exporter = OTLPSpanExporter()
tracer_provider.add_span_processor(BatchSpanProcessor(otlp_exporter))
trace.set_tracer_provider(tracer_provider)

# Create FastAPI app
app = FastAPI()

# Instrument FastAPI
print("🔧 Instrumenting FastAPI...")
FastAPIInstrumentor.instrument_app(app)
print("✅ FastAPI instrumented")

@app.on_event("startup")
async def on_startup():
    # Initialize database
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

@app.get("/healthz")
async def healthz():
    try:
        db = get_db()
        await db["towers"].find_one()
        return {"status": "ok"}
    except Exception:
        return JSONResponse(status_code=503, content={"status": "unhealthy"})

@app.get("/signal/healthz")
async def signal_healthz():
    """Health check endpoint for the signal processing service."""
    try:
        db = get_db()
        await db["towers"].find_one()
        return {"status": "ok"}
    except Exception:
        return JSONResponse(status_code=503, content={"status": "unhealthy"})

