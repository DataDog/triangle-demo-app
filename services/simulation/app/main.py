import os
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from app.db import get_db
from app.simulation import initialize_towers
from app.models import Signal, Tower
from app.signal_processor import process_signal
import logging

# OpenTelemetry imports
from opentelemetry import trace, metrics
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.logging import LoggingInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader

# Configure OpenTelemetry Tracing
trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)

# Configure OpenTelemetry Metrics
metric_reader = PeriodicExportingMetricReader(
    OTLPMetricExporter()
)
metrics.set_meter_provider(MeterProvider(metric_readers=[metric_reader]))
meter = metrics.get_meter(__name__)

# Create metrics
request_counter = meter.create_counter(
    name="simulation_requests",
    description="Number of requests processed",
    unit="1",
)

tower_gauge = meter.create_up_down_counter(
    name="simulation_towers",
    description="Number of towers in the simulation",
    unit="1",
)

# Configure OTLP exporters
otlp_span_exporter = OTLPSpanExporter()
span_processor = BatchSpanProcessor(otlp_span_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

# Configure Python logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s [%(name)s] [%(filename)s:%(lineno)d] [trace_id=%(otelTraceID)s span_id=%(otelSpanID)s] - %(message)s'
)
logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI()

# Initialize auto-instrumentation
FastAPIInstrumentor.instrument_app(app)
LoggingInstrumentor().instrument()
HTTPXClientInstrumentor().instrument()

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
    with tracer.start_as_current_span("process_signal") as span:
        request_counter.add(1, {"endpoint": "/signal"})
        span.set_attribute("signal.x", signal.x)
        span.set_attribute("signal.y", signal.y)
        logger.info(f"Received signal: x={signal.x}, y={signal.y}")
        db = await get_db()
        await process_signal(signal, db)
        return {"status": "received"}

@app.get("/api/simulation/towers")
async def get_towers(request: Request):
    with tracer.start_as_current_span("get_towers") as span:
        request_counter.add(1, {"endpoint": "/api/simulation/towers"})
        logger.info(f"📥 Simulation received request: {request.url.path}")
        db = await get_db()
        towers_cursor = db["towers"].find()
        towers = [Tower(**tower) async for tower in towers_cursor]
        tower_count = len(towers)
        tower_gauge.add(tower_count)
        span.set_attribute("towers.count", tower_count)
        logger.info(f"Returning {tower_count} towers")
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
