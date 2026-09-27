import re
from typing import Annotated

import asyncpg
from fastapi import APIRouter, Depends, HTTPException, Request, Response
from pydantic import BaseModel, StringConstraints

from .auth import current_user_id

router = APIRouter(prefix="/posts")

Title = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]


class PostCreate(BaseModel):
    title: Title
    body: str


class PostUpdate(BaseModel):
    title: Title | None = None
    body: str | None = None
    published: bool | None = None


def slugify(title: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-") or "post"


async def with_unique_slug(title: str, write):
    """Run write(slug) with the title's slug, then slug-2, slug-3, ... while it is taken."""
    base = slugify(title)
    for n in range(1, 51):
        try:
            return await write(base if n == 1 else f"{base}-{n}")
        except asyncpg.UniqueViolationError:
            pass
    raise HTTPException(409, "could not generate a unique slug")


async def owned_post(pool: asyncpg.Pool, post_id: int, user_id: int) -> dict:
    row = await pool.fetchrow("SELECT * FROM posts WHERE id = $1", post_id)
    if row is None:
        raise HTTPException(404, "post not found")
    if row["author_id"] != user_id:
        raise HTTPException(403, "not your post")
    return dict(row)


@router.get("")
async def list_posts(request: Request) -> list[dict]:
    rows = await request.app.state.pool.fetch(
        "SELECT id, title, slug, left(body, 200) AS excerpt, published_at"
        " FROM posts WHERE published ORDER BY published_at DESC"
    )
    return [dict(r) for r in rows]


@router.get("/{slug}")
async def get_post(slug: str, request: Request) -> dict:
    row = await request.app.state.pool.fetchrow("SELECT * FROM posts WHERE slug = $1 AND published", slug)
    if row is None:
        raise HTTPException(404, "post not found")
    return dict(row)


@router.post("", status_code=201)
async def create_post(post: PostCreate, request: Request, user_id: int = Depends(current_user_id)) -> dict:
    pool = request.app.state.pool

    async def insert(slug: str):
        return await pool.fetchrow(
            "INSERT INTO posts (title, slug, body, author_id) VALUES ($1, $2, $3, $4) RETURNING *",
            post.title,
            slug,
            post.body,
            user_id,
        )

    return dict(await with_unique_slug(post.title, insert))


@router.put("/{post_id}")
async def update_post(
    post_id: int, patch: PostUpdate, request: Request, user_id: int = Depends(current_user_id)
) -> dict:
    pool = request.app.state.pool
    current = await owned_post(pool, post_id, user_id)
    post = current | patch.model_dump(exclude_none=True)

    # published_at is stamped the first time the post is published, then kept.
    async def save(slug: str):
        return await pool.fetchrow(
            "UPDATE posts SET title = $2, slug = $3, body = $4, published = $5,"
            " published_at = coalesce(published_at, CASE WHEN $5 THEN now() END), updated_at = now()"
            " WHERE id = $1 RETURNING *",
            post_id,
            post["title"],
            slug,
            post["body"],
            post["published"],
        )

    if post["title"] == current["title"]:
        return dict(await save(current["slug"]))
    return dict(await with_unique_slug(post["title"], save))  # the slug follows the title


@router.delete("/{post_id}", status_code=204)
async def delete_post(post_id: int, request: Request, user_id: int = Depends(current_user_id)) -> Response:
    pool = request.app.state.pool
    await owned_post(pool, post_id, user_id)
    await pool.execute("DELETE FROM posts WHERE id = $1", post_id)
    return Response(status_code=204)
