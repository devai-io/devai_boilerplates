"""Local auth: registration, login, and the JWT dependency guarding writes."""

import os
import re
import time
from datetime import datetime, timezone

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field
from pymongo.errors import DuplicateKeyError

router = APIRouter(prefix="/auth")

_hasher = PasswordHasher()
_EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
TOKEN_TTL = 7 * 24 * 3600  # 7 days


def _secret() -> str:
    return os.environ.get("AUTH_SECRET", "dev-secret-change-me-not-for-production")


class Credentials(BaseModel):
    email: str
    password: str = Field(min_length=8)


def issue_token(user_id: str) -> str:
    now = int(time.time())
    payload = {"sub": user_id, "iat": now, "exp": now + TOKEN_TTL}
    return jwt.encode(payload, _secret(), algorithm="HS256")


def current_user_id(request: Request) -> str:
    """FastAPI dependency: the user id from a valid Bearer token, else 401."""
    header = request.headers.get("authorization", "")
    if not header.lower().startswith("bearer "):
        raise HTTPException(401, "missing bearer token")
    try:
        claims = jwt.decode(header[7:], _secret(), algorithms=["HS256"])
    except jwt.InvalidTokenError:
        raise HTTPException(401, "invalid or expired token")
    return claims["sub"]


@router.post("/register", status_code=201)
async def register(creds: Credentials, request: Request) -> dict:
    if not _EMAIL.match(creds.email):
        raise HTTPException(422, "invalid email address")
    email = creds.email.lower()
    try:
        result = await request.app.state.db.users.insert_one(
            {
                "email": email,
                "password_hash": _hasher.hash(creds.password),
                "created_at": datetime.now(timezone.utc),
            }
        )
    except DuplicateKeyError:
        raise HTTPException(409, "email already registered")
    return {"id": str(result.inserted_id), "email": email}


@router.post("/login")
async def login(creds: Credentials, request: Request) -> dict:
    user = await request.app.state.db.users.find_one({"email": creds.email.lower()})
    if user is None:
        raise HTTPException(401, "invalid credentials")
    try:
        _hasher.verify(user["password_hash"], creds.password)
    except VerifyMismatchError:
        raise HTTPException(401, "invalid credentials")
    return {"token": issue_token(str(user["_id"]))}
