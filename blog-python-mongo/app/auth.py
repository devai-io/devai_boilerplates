import os
import re
import time
from datetime import datetime, timezone

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerificationError
from fastapi import APIRouter, HTTPException, Request
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel
from pymongo.errors import DuplicateKeyError

router = APIRouter(prefix="/auth")

SECRET = os.environ["AUTH_SECRET"]
TOKEN_TTL = 7 * 24 * 3600
_hasher = PasswordHasher()
_EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class Credentials(BaseModel):
    email: str
    password: str


def issue_token(user_id: str) -> str:
    now = int(time.time())
    return jwt.encode({"sub": user_id, "iat": now, "exp": now + TOKEN_TTL}, SECRET, algorithm="HS256")


def current_user_id(request: Request) -> str:
    """FastAPI dependency: the user id from a valid Bearer token, else 401."""
    header = request.headers.get("authorization", "")
    if not header.lower().startswith("bearer "):
        raise HTTPException(401, "missing bearer token")
    try:
        claims = jwt.decode(header[7:], SECRET, algorithms=["HS256"], options={"require": ["exp", "sub"]})
    except jwt.InvalidTokenError:
        raise HTTPException(401, "invalid or expired token")
    return claims["sub"]


def _password_matches(password_hash: str, password: str) -> bool:
    try:
        return _hasher.verify(password_hash, password)
    except VerificationError:
        return False


@router.post("/register", status_code=201)
async def register(creds: Credentials, request: Request) -> dict:
    email = creds.email.strip().lower()
    if not _EMAIL.match(email):
        raise HTTPException(422, "invalid email address")
    if len(creds.password) < 8:
        raise HTTPException(422, "password must be at least 8 characters")
    # argon2 is deliberately slow; hash off the event loop so other requests keep flowing.
    password_hash = await run_in_threadpool(_hasher.hash, creds.password)
    try:
        result = await request.app.state.db.users.insert_one(
            {"email": email, "password_hash": password_hash, "created_at": datetime.now(timezone.utc)}
        )
    except DuplicateKeyError:
        raise HTTPException(409, "email already registered")
    return {"id": str(result.inserted_id), "email": email}


@router.post("/login")
async def login(creds: Credentials, request: Request) -> dict:
    user = await request.app.state.db.users.find_one({"email": creds.email.strip().lower()})
    if user is None or not await run_in_threadpool(_password_matches, user["password_hash"], creds.password):
        raise HTTPException(401, "invalid email or password")
    return {"token": issue_token(str(user["_id"]))}
