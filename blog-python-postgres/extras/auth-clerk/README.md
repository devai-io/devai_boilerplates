# Auth via Clerk

Replaces the built-in email/password auth with [Clerk](https://clerk.com).
Clerk owns sign-up, sign-in and sessions; the API only verifies the session
JWT it receives against your instance's JWKS (RS256 signature, issuer,
expiry, `azp`). One file, no Clerk SDK.

## Install

1. Add the RS256 backend: `uv add "pyjwt[crypto]"`
2. Copy `clerk_auth.py` to `app/clerk_auth.py`
3. In `app/posts.py`, change one import:
   `from .clerk_auth import current_user_id`
4. Set `CLERK_ISSUER` to your Frontend API URL from the Clerk dashboard,
   e.g. `https://your-app.clerk.accounts.dev`, and `CLERK_AUTHORIZED_PARTIES`
   to the origins allowed to mint tokens for this API (comma-separated,
   checked against the `azp` claim; leave it unset to skip the check),
   e.g. `https://your-site.com,http://localhost:5173`

## Delete / adjust

- `app/auth.py` and its router registration in `app/main.py` — Clerk replaces
  `/auth/register` and `/auth/login`.
- The `users` table in `schema.sql` — Clerk stores your users.
- `posts.author_id` now holds a Clerk user id (a string like `user_2f…`):
  change the column to `author_id text NOT NULL` and drop the `REFERENCES`
  clause (edit `schema.sql` before first start, or `ALTER TABLE` a live db).
  Type hints in `app/posts.py` change from `int` to `str` to match.
- `AUTH_SECRET` is unused.

Clients get a token from Clerk's SDK (`getToken()`) and send it as
`Authorization: Bearer <token>` — the write endpoints work unchanged.
