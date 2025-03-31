import os
from motor.motor_asyncio import AsyncIOMotorClient
from opentelemetry.instrumentation.pymongo import PymongoInstrumentor

# Initialize MongoDB instrumentation
PymongoInstrumentor().instrument()

def get_db():
    print("🔌 Connecting to MongoDB...")
    mongo_uri = os.getenv("MONGO_URI", "mongodb://localhost:27017")
    mongo_db = os.getenv("MONGO_DB", "simulation")
    client = AsyncIOMotorClient(mongo_uri)
    db = client[mongo_db]
    return db

