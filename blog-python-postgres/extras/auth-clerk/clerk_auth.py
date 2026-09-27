import os

import jwt
from fastapi import HTTPException, Request

ISSUER = os.environ["CLERK_ISSUER"].rstrip("/")
# Origins allowed in the token's azp claim, comma-separated; unset skips the check.
AUTHORIZED_PARTIES = [p for p in os.environ.get("CLERK_AUTHORIZED_PARTIES", "").split(",") if p]
# Caches the key set; an unknown key id (a rotation) triggers a refetch, at most every 30s.
_jwks = jwt.PyJWKClient(f"{ISSUER}/.well-known/jwks.json")


def current_user_id(request: Request) -> str:
    """FastAPI dependency: the Clerk user id (`sub`) from a valid session token."""
    header = request.headers.get("authorization", "")
    if not header.lower().startswith("bearer "):
        raise HTTPException(401, "missing bearer token")
    token = header[7:]
    try:
        key = _jwks.get_signing_key_from_jwt(token).key
        # Clerk session tokens live for 60s, so allow a little clock skew.
        claims = jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            issuer=ISSUER,
            leeway=5,
            options={"require": ["exp", "iss", "sub"]},
        )
    except jwt.PyJWTError:
        raise HTTPException(401, "invalid or expired token")
    if AUTHORIZED_PARTIES and claims.get("azp") not in AUTHORIZED_PARTIES:
        raise HTTPException(401, "token issued for an unknown origin")
    return claims["sub"]
