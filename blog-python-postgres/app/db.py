"""Connection pool + first-run schema setup."""

from pathlib import Path

import asyncpg

_SCHEMA = Path(__file__).resolve().parent.parent / "schema.sql"


async def create_pool(database_url: str) -> asyncpg.Pool:
    pool = await asyncpg.create_pool(database_url, min_size=1, max_size=10)
    async with pool.acquire() as conn:
        if not await conn.fetchval("SELECT to_regclass('public.posts') IS NOT NULL"):
            await conn.execute(_SCHEMA.read_text())
    return pool
