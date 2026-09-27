import os

import jwt
from fastapi import HTTPException, Request

ISSUER = f"https://{os.environ['AUTH0_DOMAIN']}/"  # Auth0 issuers end with a slash
AUDIENCE = os.environ["AUTH0_AUDIENCE"]
# Caches the key set; an unknown key id (a rotation) triggers a refetch, at most every 30s.
_jwks = jwt.PyJWKClient(f"{ISSUER}.well-known/jwks.json")


def current_user_id(request: Request) -> str:
    """FastAPI dependency: the Auth0 user id (`sub`) from a valid access token."""
    header = request.headers.get("authorization", "")
    if not header.lower().startswith("bearer "):
        raise HTTPException(401, "missing bearer token")
    token = header[7:]
    try:
        key = _jwks.get_signing_key_from_jwt(token).key
        claims = jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            audience=AUDIENCE,
            issuer=ISSUER,
            options={"require": ["exp", "iss", "aud", "sub"]},
        )
    except jwt.PyJWTError:
        raise HTTPException(401, "invalid or expired token")
    return claims["sub"]
