import random
import math
from app.models import Tower

WORLD_SIZE = 1000
MIN_DISTANCE = 200


def distance(a, b):
    return math.sqrt((a.x - b.x) ** 2 + (a.y - b.y) ** 2)

def generate_towers(n=3):
    towers = []
    attempts = 0

    while len(towers) < n and attempts < 1000:
        x = random.randint(0, WORLD_SIZE)
        y = random.randint(0, WORLD_SIZE)
        new_tower = Tower(id=f"tower-{len(towers)+1}", x=x, y=y)

        if all(distance(new_tower, existing) >= MIN_DISTANCE for existing in towers):
            towers.append(new_tower)
        attempts += 1

    if len(towers) < n:
        raise Exception("Could not place all towers with required distance constraint")

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
