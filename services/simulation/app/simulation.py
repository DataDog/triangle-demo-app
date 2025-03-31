import random
import math
from app.models import Tower

WORLD_SIZE = 1000
PADDING = 200  # Increased padding from edges for better coverage
RADIUS = 300   # Distance from center to tower (controls triangle size)

def generate_towers():
    # Calculate center point
    center_x = WORLD_SIZE // 2
    center_y = WORLD_SIZE // 2

    # Generate three points in an equilateral triangle
    # Using angles: 90° (top), 210° (bottom left), 330° (bottom right)
    base_positions = [
        # Top center
        (center_x, center_y - RADIUS),
        # Bottom left
        (center_x - int(RADIUS * math.cos(math.radians(30))),
         center_y + int(RADIUS * math.sin(math.radians(30)))),
        # Bottom right
        (center_x + int(RADIUS * math.cos(math.radians(30))),
         center_y + int(RADIUS * math.sin(math.radians(30))))
    ]

    # Add small random jitter (much smaller than before)
    JITTER = 30  # Reduced jitter for more stable positioning
    towers = []
    for i, (base_x, base_y) in enumerate(base_positions):
        x = max(PADDING, min(WORLD_SIZE - PADDING,
                base_x + random.randint(-JITTER, JITTER)))
        y = max(PADDING, min(WORLD_SIZE - PADDING,
                base_y + random.randint(-JITTER, JITTER)))
        towers.append(Tower(id=f"tower-{i+1}", x=x, y=y))

    return towers

import asyncio

async def initialize_towers(db):
    collection = db["towers"]
    try:
        print("🔌 Connecting to MongoDB...")
        await asyncio.wait_for(collection.count_documents({}), timeout=5)
    except Exception as e:
        print(f"❌ MongoDB not reachable: {e}")
        raise

    existing = await collection.count_documents({})
    if existing == 0:
        towers = generate_towers()
        await collection.insert_many([tower.dict() for tower in towers])
        print("✅ Inserted towers into MongoDB")
    else:
        print("📡 Towers already exist in MongoDB")
