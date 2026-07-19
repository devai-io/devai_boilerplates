"""Drop-in replacement for the local JWT dependency: verify Clerk session tokens.

Copy this file to app/clerk_auth.py, then point the import in app/posts.py at it:

    from .clerk_auth import current_user_id

Requires the RS256 backend (`uv add "pyjwt[crypto]"`) and CLERK_ISSUER set to
your instance's Frontend API URL, e.g. https://your-app.clerk.accounts.dev
"""

import os
from functools import lru_cache

import jwt
from fastapi import HTTPException, Request


def _issuer() -> str:
    return os.environ["CLERK_ISSUER"].rstrip("/")


@lru_cache
def _jwks() -> jwt.PyJWKClient:
    # PyJWKClient caches fetched keys, so the JWKS endpoint is hit rarely.
    return jwt.PyJWKClient(f"{_issuer()}/.well-known/jwks.json")


def current_user_id(request: Request) -> str:
    """FastAPI dependency: the Clerk user id (`sub`) from a valid session token."""
    header = request.headers.get("authorization", "")
    if not header.lower().startswith("bearer "):
        raise HTTPException(401, "missing bearer token")
    token = header[7:]
    try:
        key = _jwks().get_signing_key_from_jwt(token).key
        claims = jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            issuer=_issuer(),
            options={"require": ["exp", "sub", "iss"]},
        )
    except jwt.PyJWTError:
        raise HTTPException(401, "invalid or expired token")
    return claims["sub"]
