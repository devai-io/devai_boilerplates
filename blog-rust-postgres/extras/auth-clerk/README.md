# Auth via Clerk

Replaces the local email+password auth with [Clerk](https://clerk.com) hosted
auth. The app stops issuing tokens itself and instead verifies Clerk session
JWTs (RS256) against your instance's JWKS.

## Setup

1. Create an application in the Clerk dashboard and note your instance's
   Frontend API URL (e.g. `https://your-instance.clerk.accounts.dev`) — that is
   the token issuer.
2. Add the HTTP client to `Cargo.toml`:

   ```toml
   reqwest = { version = "0.12", default-features = false, features = ["rustls-tls", "json"] }
   ```

3. Copy `clerk.rs` to `src/clerk.rs` and register it in `src/main.rs`:

   ```rust
   mod clerk;
   ```

4. In `src/posts.rs`, swap the extractor import:

   ```rust
   use crate::clerk::AuthUser;
   ```

5. Set the environment variable:

   ```
   CLERK_ISSUER=https://your-instance.clerk.accounts.dev
   ```

## What to delete / replace

- `src/auth.rs` and the `/auth/register` + `/auth/login` routes in
  `src/main.rs` — Clerk hosts sign-up and sign-in, so the app no longer needs
  them. `AUTH_SECRET` becomes unused.
- The `users` table in `schema.sql` — Clerk is the user store now. Keep it only
  if you mirror users locally (e.g. via Clerk webhooks), and drop
  `password_hash` in that case.
- `posts.author_id` — Clerk user ids are strings (`user_...`), not UUIDs.
  In `schema.sql` change the column and drop the foreign key:

  ```sql
  author_id TEXT NOT NULL
  ```

  and in `src/posts.rs` change `author_id: Uuid` to `author_id: String`
  (bind it with `&author_id`).

## Notes

- Clients send the Clerk session token as `Authorization: Bearer <token>`
  (`await session.getToken()` in Clerk's frontend SDKs).
- The JWKS is fetched lazily on first use and cached for the process lifetime;
  restart the app after a key rotation.
