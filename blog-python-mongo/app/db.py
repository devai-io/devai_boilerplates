from pymongo import AsyncMongoClient
from pymongo.asynchronous.database import AsyncDatabase


async def connect(mongo_url: str, db_name: str) -> tuple[AsyncMongoClient, AsyncDatabase]:
    client = AsyncMongoClient(mongo_url, tz_aware=True)
    db = client[db_name]
    await db.users.create_index("email", unique=True)
    await db.posts.create_index("slug", unique=True)
    await db.posts.create_index([("published", 1), ("created_at", -1)])
    return client, db
