from pathlib import Path

import asyncpg

SCHEMA = (Path(__file__).parent.parent / "schema.sql").read_text()


async def create_pool(database_url: str) -> asyncpg.Pool:
    pool = await asyncpg.create_pool(database_url, min_size=1, max_size=10)
    await pool.execute(SCHEMA)
    return pool
