# Auth via Auth0

Replaces the built-in email/password auth with [Auth0](https://auth0.com).
Auth0 issues RS256 access tokens; the API verifies them against your tenant's
JWKS, checking issuer and audience. One file, no Auth0 SDK.

## Install

1. In the Auth0 dashboard, create an **API** — its identifier becomes your
   audience.
2. Add the RS256 backend: `uv add "pyjwt[crypto]"`
3. Copy `auth0_auth.py` to `app/auth0_auth.py`
4. In `app/posts.py`, change one import:
   `from .auth0_auth import current_user_id`
5. Set `AUTH0_DOMAIN` (e.g. `your-tenant.us.auth0.com`) and `AUTH0_AUDIENCE`
   (the API identifier from step 1).

## Delete / adjust

- `app/auth.py` and its router registration in `app/main.py` — Auth0 replaces
  `/auth/register` and `/auth/login`.
- The `users` collection and its email index in `app/db.py` — Auth0 stores
  your users.
- `posts.author_id` now holds an Auth0 user id (a string like `auth0|64ef…`)
  instead of an ObjectId string. It was already stored as a string, so nothing
  to migrate — only the id format changes.
- `AUTH_SECRET` is unused.

Clients obtain tokens through any Auth0 flow (Authorization Code + PKCE for
SPAs; the API's **Test** tab issues one for quick manual checks) and send them
as `Authorization: Bearer <token>`.
