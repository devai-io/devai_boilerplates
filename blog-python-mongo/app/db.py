"""Mongo connection + startup index creation (the indexes are the whole schema)."""

from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase


async def connect(mongo_url: str, db_name: str) -> tuple[AsyncIOMotorClient, AsyncIOMotorDatabase]:
    client = AsyncIOMotorClient(mongo_url)
    db = client[db_name]
    await db.users.create_index("email", unique=True)
    await db.posts.create_index("slug", unique=True)
    await db.posts.create_index([("published", 1), ("created_at", -1)])
    return client, db
