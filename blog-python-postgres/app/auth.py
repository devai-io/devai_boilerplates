import os
import re
import time

import asyncpg
import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerificationError
from fastapi import APIRouter, HTTPException, Request
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel

router = APIRouter(prefix="/auth")

SECRET = os.environ["AUTH_SECRET"]
TOKEN_TTL = 7 * 24 * 3600
_hasher = PasswordHasher()
_EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class Credentials(BaseModel):
    email: str
    password: str


def issue_token(user_id: int) -> str:
    now = int(time.time())
    return jwt.encode({"sub": str(user_id), "iat": now, "exp": now + TOKEN_TTL}, SECRET, algorithm="HS256")


def current_user_id(request: Request) -> int:
    """FastAPI dependency: the user id from a valid Bearer token, else 401."""
    header = request.headers.get("authorization", "")
    if not header.lower().startswith("bearer "):
        raise HTTPException(401, "missing bearer token")
    try:
        claims = jwt.decode(header[7:], SECRET, algorithms=["HS256"], options={"require": ["exp", "sub"]})
        return int(claims["sub"])
    except (jwt.InvalidTokenError, ValueError):
        raise HTTPException(401, "invalid or expired token")


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
        row = await request.app.state.pool.fetchrow(
            "INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id, email",
            email,
            password_hash,
        )
    except asyncpg.UniqueViolationError:
        raise HTTPException(409, "email already registered")
    return dict(row)


@router.post("/login")
async def login(creds: Credentials, request: Request) -> dict:
    row = await request.app.state.pool.fetchrow(
        "SELECT id, password_hash FROM users WHERE email = $1", creds.email.strip().lower()
    )
    if row is None or not await run_in_threadpool(_password_matches, row["password_hash"], creds.password):
        raise HTTPException(401, "invalid email or password")
    return {"token": issue_token(row["id"])}
