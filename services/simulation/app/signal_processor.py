import math
import os
import httpx
from app.models import Signal, Tower, TowerDetection, SignalBundle

def compute_distance(x1, y1, x2, y2):
    return math.sqrt((x1 - x2) ** 2 + (y1 - y2) ** 2)

async def process_signal(signal: Signal, db):
    print(f"📡 Received signal: {signal}")

    towers_cursor = db["towers"].find()
    towers = [Tower(**tower) async for tower in towers_cursor]

    detections = []
    for tower in towers:
        dist = compute_distance(signal.x, signal.y, tower.x, tower.y)
        delay_seconds = dist / 343.0  # speed of sound
        heard_at = signal.timestamp + int(delay_seconds * 1000)  # ms
        detections.append(TowerDetection(
            id=tower.id,
            x=tower.x,
            y=tower.y,
            heard_at=heard_at
        ))

    bundle = SignalBundle(
        signal_timestamp=signal.timestamp,
        towers=detections
    )

    locator_url = os.getenv("LOCATOR_URL", "http://locator:8000/bundle")
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(locator_url, json=bundle.dict())
            print(f"✅ Sent bundle to locator: {response.status_code}")
        except Exception as e:
            print(f"❌ Failed to send to locator: {e}")
