# Auth via Clerk

Replaces the built-in email/password auth with [Clerk](https://clerk.com).
Clerk owns sign-up, sign-in and sessions; the API only verifies the session
JWT it receives against your instance's JWKS. One file, no Clerk SDK.

## Install

1. Add the RS256 backend: `uv add "pyjwt[crypto]"`
2. Copy `clerk_auth.py` to `app/clerk_auth.py`
3. In `app/posts.py`, change one import:
   `from .clerk_auth import current_user_id`
4. Set `CLERK_ISSUER` to your Frontend API URL from the Clerk dashboard,
   e.g. `https://your-app.clerk.accounts.dev`

## Delete / adjust

- `app/auth.py` and its router registration in `app/main.py` — Clerk replaces
  `/auth/register` and `/auth/login`.
- The `users` collection and its email index in `app/db.py` — Clerk stores
  your users.
- `posts.author_id` now holds a Clerk user id (a string like `user_2f…`)
  instead of an ObjectId string. It was already stored as a string, so nothing
  to migrate — only the id format changes.
- `AUTH_SECRET` is unused.

Clients get a token from Clerk's SDK (`getToken()`) and send it as
`Authorization: Bearer <token>` — the write endpoints work unchanged.
