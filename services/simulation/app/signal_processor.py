import math
import os
import httpx
from app.models import Signal, Tower, TowerDetection, SignalBundle

def compute_distance(x1, y1, x2, y2):
    return math.hypot(x1 - x2, y1 - y2)

async def process_signal(signal: Signal, db):
    print(f"[signal]  x={signal.x}  y={signal.y}  ts={signal.timestamp}")

    towers_cursor = db["towers"].find()
    towers = [Tower(**tower) async for tower in towers_cursor]

    detections = []
    for tower in towers:
        dist = compute_distance(signal.x, signal.y, tower.x, tower.y)
        delay_s = dist / 343.0
        delay_ms = delay_s * 1000.0
        heard_at = signal.timestamp + int(delay_ms)

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

    heard_times = [d.heard_at for d in detections]
    spread = max(heard_times) - min(heard_times)
    print(f"[timing]  spread={spread}ms (max-min)")

    bundle = SignalBundle(
        signal_timestamp=signal.timestamp,
        towers=detections
    )

    locator_url = os.getenv("LOCATOR_URL", "http://locator:8000/bundle")
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(locator_url, json=bundle.dict())
            print(f"[bundle]  POST {locator_url}  status={response.status_code}")
    except Exception as e:
        print(f"[error]   failed to send bundle: {e}")
