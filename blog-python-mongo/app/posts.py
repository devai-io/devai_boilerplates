import re
import secrets
from datetime import datetime, timezone
from typing import Annotated

from bson import ObjectId
from bson.errors import InvalidId
from fastapi import APIRouter, Depends, HTTPException, Request, Response
from pydantic import BaseModel, StringConstraints
from pymongo import ReturnDocument
from pymongo.asynchronous.database import AsyncDatabase
from pymongo.errors import DuplicateKeyError

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


def now() -> datetime:
    # MongoDB stores milliseconds; trim so a response matches what later reads return.
    t = datetime.now(timezone.utc)
    return t.replace(microsecond=t.microsecond // 1000 * 1000)


async def with_unique_slug(title: str, write):
    """Run write(slug); while the slug is taken, retry with a random suffix."""
    base = slug = slugify(title)
    for _ in range(3):
        try:
            return await write(slug)
        except DuplicateKeyError:
            slug = f"{base}-{secrets.token_hex(3)}"
    raise HTTPException(409, "could not generate a unique slug")


def public(doc: dict) -> dict:
    doc["id"] = str(doc.pop("_id"))
    return doc


def object_id(post_id: str) -> ObjectId:
    try:
        return ObjectId(post_id)
    except InvalidId:
        raise HTTPException(404, "post not found")


async def owned_post(db: AsyncDatabase, post_id: str, user_id: str) -> dict:
    doc = await db.posts.find_one({"_id": object_id(post_id)})
    if doc is None:
        raise HTTPException(404, "post not found")
    if doc["author_id"] != user_id:
        raise HTTPException(403, "not your post")
    return doc


@router.get("")
async def list_posts(request: Request) -> list[dict]:
    cursor = request.app.state.db.posts.find({"published": True}).sort("created_at", -1)
    return [
        {
            "id": str(doc["_id"]),
            "title": doc["title"],
            "slug": doc["slug"],
            "excerpt": doc["body"][:200],
            "published_at": doc["created_at"],
        }
        async for doc in cursor
    ]


@router.get("/{slug}")
async def get_post(slug: str, request: Request) -> dict:
    doc = await request.app.state.db.posts.find_one({"slug": slug, "published": True})
    if doc is None:
        raise HTTPException(404, "post not found")
    return public(doc)


@router.post("", status_code=201)
async def create_post(post: PostCreate, request: Request, user_id: str = Depends(current_user_id)) -> dict:
    created = now()
    doc = {
        "title": post.title,
        "body": post.body,
        "published": False,
        "author_id": user_id,
        "created_at": created,
        "updated_at": created,
    }

    async def insert(slug: str) -> dict:
        new = doc | {"slug": slug}  # a fresh dict each try: insert_one sets its _id
        await request.app.state.db.posts.insert_one(new)
        return new

    return public(await with_unique_slug(post.title, insert))


@router.put("/{post_id}")
async def update_post(
    post_id: str, patch: PostUpdate, request: Request, user_id: str = Depends(current_user_id)
) -> dict:
    db = request.app.state.db
    current = await owned_post(db, post_id, user_id)
    changes = patch.model_dump(exclude_none=True) | {"updated_at": now()}

    async def save(slug: str) -> dict:
        return await db.posts.find_one_and_update(
            {"_id": current["_id"]}, {"$set": changes | {"slug": slug}}, return_document=ReturnDocument.AFTER
        )

    title = changes.get("title", current["title"])
    if title == current["title"]:
        return public(await save(current["slug"]))
    return public(await with_unique_slug(title, save))  # the slug follows the title


@router.delete("/{post_id}", status_code=204)
async def delete_post(post_id: str, request: Request, user_id: str = Depends(current_user_id)) -> Response:
    db = request.app.state.db
    current = await owned_post(db, post_id, user_id)
    await db.posts.delete_one({"_id": current["_id"]})
    return Response(status_code=204)
