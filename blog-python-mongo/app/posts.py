"""Post CRUD. Reads are public; writes require a Bearer token and ownership."""

import re
import secrets
from datetime import datetime, timezone

from bson import ObjectId
from bson.errors import InvalidId
from fastapi import APIRouter, Depends, HTTPException, Request, Response
from motor.motor_asyncio import AsyncIOMotorDatabase
from pydantic import BaseModel, Field
from pymongo import ReturnDocument
from pymongo.errors import DuplicateKeyError

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


def _public(doc: dict) -> dict:
    doc["id"] = str(doc.pop("_id"))
    return doc


def _oid(post_id: str) -> ObjectId:
    try:
        return ObjectId(post_id)
    except InvalidId:
        raise HTTPException(404, "post not found")


@router.get("")
async def list_posts(request: Request) -> list[dict]:
    cursor = request.app.state.db.posts.find(
        {"published": True}, {"title": 1, "slug": 1, "body": 1, "created_at": 1}
    ).sort("created_at", -1)
    return [
        {
            "id": str(doc["_id"]),
            "title": doc["title"],
            "slug": doc["slug"],
            "excerpt": doc["body"][:EXCERPT_CHARS],
            "published_at": doc["created_at"],
        }
        async for doc in cursor
    ]


@router.get("/{slug}")
async def get_post(slug: str, request: Request) -> dict:
    doc = await request.app.state.db.posts.find_one({"slug": slug, "published": True})
    if doc is None:
        raise HTTPException(404, "post not found")
    return _public(doc)


@router.post("", status_code=201)
async def create_post(
    post: PostCreate, request: Request, user_id: str = Depends(current_user_id)
) -> dict:
    now = datetime.now(timezone.utc)
    base = slugify(post.title)
    doc = {
        "title": post.title,
        "slug": base,
        "body": post.body,
        "published": False,
        "author_id": user_id,
        "created_at": now,
        "updated_at": now,
    }
    for _ in range(3):  # retry with a random suffix if the slug is taken
        try:
            await request.app.state.db.posts.insert_one(doc)
            return _public(doc)
        except DuplicateKeyError:
            doc.pop("_id", None)  # insert_one sets _id client-side; drop it before retrying
            doc["slug"] = f"{base}-{secrets.token_hex(3)}"
    raise HTTPException(409, "could not generate a unique slug")


async def _owned_post(db: AsyncIOMotorDatabase, oid: ObjectId, user_id: str) -> None:
    doc = await db.posts.find_one({"_id": oid}, {"author_id": 1})
    if doc is None:
        raise HTTPException(404, "post not found")
    if doc["author_id"] != user_id:
        raise HTTPException(403, "not your post")


@router.put("/{post_id}")
async def update_post(
    post_id: str, patch: PostUpdate, request: Request, user_id: str = Depends(current_user_id)
) -> dict:
    db = request.app.state.db
    oid = _oid(post_id)
    await _owned_post(db, oid, user_id)
    updates = {k: v for k, v in patch.model_dump(exclude_unset=True).items() if v is not None}
    if not updates:
        return _public(await db.posts.find_one({"_id": oid}))
    # The slug is intentionally left alone: permalinks survive retitles.
    updates["updated_at"] = datetime.now(timezone.utc)
    doc = await db.posts.find_one_and_update(
        {"_id": oid}, {"$set": updates}, return_document=ReturnDocument.AFTER
    )
    return _public(doc)


@router.delete("/{post_id}", status_code=204)
async def delete_post(
    post_id: str, request: Request, user_id: str = Depends(current_user_id)
) -> Response:
    db = request.app.state.db
    oid = _oid(post_id)
    await _owned_post(db, oid, user_id)
    await db.posts.delete_one({"_id": oid})
    return Response(status_code=204)
