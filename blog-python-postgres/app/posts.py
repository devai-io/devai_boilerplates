"""Post CRUD. Reads are public; writes require a Bearer token and ownership."""

import re
import secrets

import asyncpg
from fastapi import APIRouter, Depends, HTTPException, Request, Response
from pydantic import BaseModel, Field

from .auth import current_user_id

router = APIRouter(prefix="/posts")

EXCERPT_CHARS = 200


class PostCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    body: str


class PostUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    body: str | None = None
    published: bool | None = None


def slugify(title: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    return slug or "post"


@router.get("")
async def list_posts(request: Request) -> list[dict]:
    rows = await request.app.state.pool.fetch(
        "SELECT id, title, slug, left(body, $1) AS excerpt, created_at AS published_at"
        " FROM posts WHERE published ORDER BY created_at DESC",
        EXCERPT_CHARS,
    )
    return [dict(r) for r in rows]


@router.get("/{slug}")
async def get_post(slug: str, request: Request) -> dict:
    row = await request.app.state.pool.fetchrow(
        "SELECT * FROM posts WHERE slug = $1 AND published", slug
    )
    if row is None:
        raise HTTPException(404, "post not found")
    return dict(row)


@router.post("", status_code=201)
async def create_post(
    post: PostCreate, request: Request, user_id: int = Depends(current_user_id)
) -> dict:
    base = slugify(post.title)
    slug = base
    for _ in range(3):  # retry with a random suffix if the slug is taken
        try:
            row = await request.app.state.pool.fetchrow(
                "INSERT INTO posts (title, slug, body, author_id)"
                " VALUES ($1, $2, $3, $4) RETURNING *",
                post.title,
                slug,
                post.body,
                user_id,
            )
            return dict(row)
        except asyncpg.UniqueViolationError:
            slug = f"{base}-{secrets.token_hex(3)}"
    raise HTTPException(409, "could not generate a unique slug")


async def _owned_post(pool: asyncpg.Pool, post_id: int, user_id: int) -> None:
    author_id = await pool.fetchval("SELECT author_id FROM posts WHERE id = $1", post_id)
    if author_id is None:
        raise HTTPException(404, "post not found")
    if author_id != user_id:
        raise HTTPException(403, "not your post")


@router.put("/{post_id}")
async def update_post(
    post_id: int, patch: PostUpdate, request: Request, user_id: int = Depends(current_user_id)
) -> dict:
    pool = request.app.state.pool
    await _owned_post(pool, post_id, user_id)
    updates = {k: v for k, v in patch.model_dump(exclude_unset=True).items() if v is not None}
    if not updates:
        return dict(await pool.fetchrow("SELECT * FROM posts WHERE id = $1", post_id))
    # Column names come from PostUpdate's fixed field set, so interpolating them is
    # safe. The slug is intentionally left alone: permalinks survive retitles.
    columns = ", ".join(f"{col} = ${i}" for i, col in enumerate(updates, start=2))
    row = await pool.fetchrow(
        f"UPDATE posts SET {columns}, updated_at = now() WHERE id = $1 RETURNING *",
        post_id,
        *updates.values(),
    )
    return dict(row)


@router.delete("/{post_id}", status_code=204)
async def delete_post(
    post_id: int, request: Request, user_id: int = Depends(current_user_id)
) -> Response:
    pool = request.app.state.pool
    await _owned_post(pool, post_id, user_id)
    await pool.execute("DELETE FROM posts WHERE id = $1", post_id)
    return Response(status_code=204)
