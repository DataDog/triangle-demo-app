import os
from motor.motor_asyncio import AsyncIOMotorClient

# Keep a single MongoDB client instance
_client = None

async def get_db():
    global _client
    if _client is None:
        print("🔌 Connecting to MongoDB...")

        # Try to get the full URI first
        mongo_uri = os.getenv("MONGO_URI")
        if not mongo_uri:
            # If no URI, construct it from individual components
            mongo_user = os.getenv("MONGO_USERNAME")
            mongo_pass = os.getenv("MONGO_PASSWORD")
            mongo_host = os.getenv("MONGO_HOST")
            mongo_port = os.getenv("MONGO_PORT")
            mongo_db = os.getenv("MONGO_DB")
            mongo_auth_source = os.getenv("MONGO_AUTH_SOURCE")

            # Ensure all required variables are present
            if not all([mongo_user, mongo_pass, mongo_host, mongo_port, mongo_db, mongo_auth_source]):
                raise ValueError("Missing required MongoDB environment variables")

            # Connect directly to the target database
            mongo_uri = f"mongodb://{mongo_user}:{mongo_pass}@{mongo_host}:{mongo_port}/{mongo_db}?authSource={mongo_auth_source}"

        print(f"🔗 Using MongoDB URI: {mongo_uri}")
        _client = AsyncIOMotorClient(mongo_uri)

        # Test the connection
        try:
            # Try to ping the server
            await _client.admin.command('ping')
            print("✅ MongoDB connection successful")
        except Exception as e:
            print(f"❌ MongoDB not reachable: {str(e)}")
            raise

    # Get the database name from environment or default to 'triangle'
    db_name = os.getenv("MONGO_DB", "triangle")
    print(f"📚 Using database: {db_name}")
    return _client[db_name]
