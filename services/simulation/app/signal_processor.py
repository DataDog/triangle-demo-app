import math
import os
import httpx
from app.models import Signal, Tower, TowerDetection, SignalBundle
from opentelemetry import trace
from opentelemetry.trace import Status, StatusCode
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor

# Instrument HTTPX (only once per process)
HTTPXClientInstrumentor().instrument()

tracer = trace.get_tracer(__name__)

def compute_distance(x1, y1, x2, y2):
    return math.hypot(x1 - x2, y1 - y2)

async def process_signal(signal: Signal, db):
    with tracer.start_as_current_span("process_signal") as span:
        span.set_attributes({
            "signal.x": signal.x,
            "signal.y": signal.y,
            "signal.timestamp": signal.timestamp,
        })

        print(f"[signal]  x={signal.x}  y={signal.y}  ts={signal.timestamp}")

        # Fetch towers
        try:
            with tracer.start_as_current_span("fetch_towers") as towers_span:
                towers_cursor = db["towers"].find()
                towers = [Tower(**tower) async for tower in towers_cursor]
                towers_span.set_attribute("tower.count", len(towers))
        except Exception as e:
            span.set_status(Status(StatusCode.ERROR))
            span.set_attribute("error", f"DB fetch failed: {e}")
            raise

        # Simulate detections
        detections = []
        for tower in towers:
            with tracer.start_as_current_span("process_tower") as tower_span:
                tower_span.set_attributes({
                    "tower.id": tower.id,
                    "tower.x": tower.x,
                    "tower.y": tower.y,
                })

                dist = compute_distance(signal.x, signal.y, tower.x, tower.y)
                delay_ms = (dist / 343.0) * 1000.0
                heard_at = signal.timestamp + int(delay_ms)

                tower_span.set_attributes({
                    "distance": dist,
                    "delay_ms": delay_ms,
                    "heard_at": heard_at,
                })

                print(
                    f"[tower]   id={tower.id}  x={tower.x}  y={tower.y}  "
                    f"dist={dist:.2f}m  delay={delay_ms:.1f}ms  heard_at={heard_at}"
                )

                detections.append(TowerDetection(
                    id=tower.id,
                    x=tower.x,
                    y=tower.y,
                    heard_at=heard_at
                ))

        # Compute spread
        heard_times = [d.heard_at for d in detections]
        spread = max(heard_times) - min(heard_times)
        span.set_attribute("timing.spread_ms", spread)
        print(f"[timing]  spread={spread}ms (max-min)")

        # Send to locator
        bundle = SignalBundle(
            signal_timestamp=signal.timestamp,
            towers=detections
        )
        locator_url = os.getenv("LOCATOR_URL", "http://locator:8000/bundle")

        try:
            with tracer.start_as_current_span("send_bundle") as bundle_span:
                bundle_span.set_attribute("url", locator_url)
                async with httpx.AsyncClient() as client:
                    response = await client.post(locator_url, json=bundle.dict())
                    bundle_span.set_attribute("status_code", response.status_code)
                    print(f"[bundle]  POST {locator_url}  status={response.status_code}")
                    if response.status_code != 200:
                        bundle_span.set_status(Status(StatusCode.ERROR))
                        bundle_span.set_attribute("error", f"HTTP {response.status_code}")
        except Exception as e:
            span.set_status(Status(StatusCode.ERROR))
            span.set_attribute("error", f"Locator POST failed: {e}")
            print(f"[error]   failed to send bundle: {e}")
