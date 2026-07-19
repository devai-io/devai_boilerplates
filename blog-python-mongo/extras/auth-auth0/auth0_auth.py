"""Drop-in replacement for the local JWT dependency: verify Auth0 access tokens.

Copy this file to app/auth0_auth.py, then point the import in app/posts.py at it:

    from .auth0_auth import current_user_id

Requires the RS256 backend (`uv add "pyjwt[crypto]"`) plus AUTH0_DOMAIN
(e.g. your-tenant.us.auth0.com) and AUTH0_AUDIENCE (your API identifier).
"""

import os
from functools import lru_cache

import jwt
from fastapi import HTTPException, Request


def _issuer() -> str:
    return f"https://{os.environ['AUTH0_DOMAIN']}/"


@lru_cache
def _jwks() -> jwt.PyJWKClient:
    # PyJWKClient caches fetched keys, so the JWKS endpoint is hit rarely.
    return jwt.PyJWKClient(f"{_issuer()}.well-known/jwks.json")


def current_user_id(request: Request) -> str:
    """FastAPI dependency: the Auth0 user id (`sub`) from a valid access token."""
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
            audience=os.environ["AUTH0_AUDIENCE"],
            issuer=_issuer(),
            options={"require": ["exp", "sub", "iss", "aud"]},
        )
    except jwt.PyJWTError:
        raise HTTPException(401, "invalid or expired token")
    return claims["sub"]
