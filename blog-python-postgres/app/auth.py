"""Local auth: registration, login, and the JWT dependency guarding writes."""

import os
import re
import time

import asyncpg
import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

router = APIRouter(prefix="/auth")

_hasher = PasswordHasher()
_EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
TOKEN_TTL = 7 * 24 * 3600  # 7 days


def _secret() -> str:
    return os.environ.get("AUTH_SECRET", "dev-secret-change-me-not-for-production")


class Credentials(BaseModel):
    email: str
    password: str = Field(min_length=8)


def issue_token(user_id: int) -> str:
    now = int(time.time())
    payload = {"sub": str(user_id), "iat": now, "exp": now + TOKEN_TTL}
    return jwt.encode(payload, _secret(), algorithm="HS256")


def current_user_id(request: Request) -> int:
    """FastAPI dependency: the user id from a valid Bearer token, else 401."""
    header = request.headers.get("authorization", "")
    if not header.lower().startswith("bearer "):
        raise HTTPException(401, "missing bearer token")
    try:
        claims = jwt.decode(header[7:], _secret(), algorithms=["HS256"])
    except jwt.InvalidTokenError:
        raise HTTPException(401, "invalid or expired token")
    return int(claims["sub"])


@router.post("/register", status_code=201)
async def register(creds: Credentials, request: Request) -> dict:
    if not _EMAIL.match(creds.email):
        raise HTTPException(422, "invalid email address")
    try:
        row = await request.app.state.pool.fetchrow(
            "INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id, email",
            creds.email.lower(),
            _hasher.hash(creds.password),
        )
    except asyncpg.UniqueViolationError:
        raise HTTPException(409, "email already registered")
    return dict(row)


@router.post("/login")
async def login(creds: Credentials, request: Request) -> dict:
    row = await request.app.state.pool.fetchrow(
        "SELECT id, password_hash FROM users WHERE email = $1", creds.email.lower()
    )
    if row is None:
        raise HTTPException(401, "invalid credentials")
    try:
        _hasher.verify(row["password_hash"], creds.password)
    except VerifyMismatchError:
        raise HTTPException(401, "invalid credentials")
    return {"token": issue_token(row["id"])}
