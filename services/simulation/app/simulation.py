import random
import math
import asyncio
from app.models import Tower

WORLD_SIZE = 1000
PADDING = 200
RADIUS = 300  # Distance from center to tower (triangle size)
JITTER = 30   # Small position noise for realism

def generate_towers():
    center_x = WORLD_SIZE // 2
    center_y = WORLD_SIZE // 2

    # Equilateral triangle: angles 90°, 210°, 330°
    base_positions = [
        (center_x, center_y - RADIUS),  # Top
        (center_x - int(RADIUS * math.cos(math.radians(30))),
         center_y + int(RADIUS * math.sin(math.radians(30)))),  # Bottom left
        (center_x + int(RADIUS * math.cos(math.radians(30))),
         center_y + int(RADIUS * math.sin(math.radians(30))))   # Bottom right
    ]

    towers = []
    for i, (base_x, base_y) in enumerate(base_positions):
        x = max(PADDING, min(WORLD_SIZE - PADDING,
                base_x + random.randint(-JITTER, JITTER)))
        y = max(PADDING, min(WORLD_SIZE - PADDING,
                base_y + random.randint(-JITTER, JITTER)))
        towers.append(Tower(id=f"tower-{i+1}", x=x, y=y))

    return towers

async def initialize_towers(db):
    collection = db["towers"]
    try:
        print("🔌 Checking MongoDB connection...")
        # First try a simple ping
        await db.command("ping")
        print("✅ MongoDB connection verified")

        # Then check if we can access the collection
        print("📊 Checking towers collection...")
        existing = await collection.count_documents({})
        print(f"📡 Found {existing} existing towers")

        if existing == 0:
            print("🎯 Generating new towers...")
            towers = generate_towers()
            print(f"📦 Inserting {len(towers)} towers...")
            await collection.insert_many([tower.dict() for tower in towers])
            print("✅ Successfully inserted towers")
        else:
            print(f"📡 {existing} towers already exist in MongoDB")

    except Exception as e:
        print(f"❌ Error initializing towers: {str(e)}")
        raise RuntimeError(f"Failed to initialize towers: {str(e)}") from e
