from motor.motor_asyncio import AsyncIOMotorClient
import os

_mongo_client = None

def get_db():
    global _mongo_client
    if _mongo_client is None:
        mongo_uri = os.getenv("MONGO_URI", "mongodb://localhost:27017")
        mongo_db = os.getenv("MONGO_DB", "triangle")
        _mongo_client = AsyncIOMotorClient(mongo_uri)
    return _mongo_client[os.getenv("MONGO_DB", "triangle")]

