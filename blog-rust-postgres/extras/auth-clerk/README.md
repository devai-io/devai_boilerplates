# Auth via Clerk

Replaces the local email+password auth with [Clerk](https://clerk.com) hosted
auth. The app stops issuing tokens itself and instead verifies Clerk session
JWTs (RS256) against your instance's JWKS, checking the issuer.

## Setup

1. Create an application in the Clerk dashboard and note your instance's
   Frontend API URL (e.g. `https://your-instance.clerk.accounts.dev`) — that is
   the token issuer.
2. Add the HTTP client to `Cargo.toml`:

   ```toml
   reqwest = { version = "0.13", features = ["json"] }
   ```

3. Copy `clerk.rs` to `src/clerk.rs` and delete `src/auth.rs` — Clerk hosts
   sign-up and sign-in. In `src/main.rs`, replace `mod auth;` with
   `mod clerk;`, then remove the `/auth/register` and `/auth/login` routes,
   the unused `post` import, and the `jwt_secret` state field along with its
   `AUTH_SECRET` line.
4. In `src/posts.rs`:
   - import the new extractor: `use crate::clerk::AuthUser;`
   - Clerk user ids are strings (`user_...`), not UUIDs: change
     `author_id: Uuid` in `Post` to `author_id: String`, the `user_id: Uuid`
     parameter of `find_own_post` to `user_id: String`, and `.bind(author_id)`
     in `create` to `.bind(&author_id)`.
5. In `schema.sql`, make the column match and drop the foreign key
   (`CREATE TABLE IF NOT EXISTS` won't alter an existing table, so start
   from an empty database):

   ```sql
   author_id TEXT NOT NULL
   ```

6. Set the environment variable:

   ```
   CLERK_ISSUER=https://your-instance.clerk.accounts.dev
   ```

## What to delete

- The `users` table in `schema.sql` — Clerk is the user store now. Keep it only
  if you mirror users locally (e.g. via Clerk webhooks), without
  `password_hash`.

## Notes

- Clients send the Clerk session token as `Authorization: Bearer <token>`
  (`await session.getToken()` in Clerk's frontend SDKs).
- The JWKS is fetched on first use and cached. A token signed with an unknown
  key id triggers a refetch (at most once a minute), so key rotations need no
  restart.
- Clerk also puts the requesting origin in the `azp` claim; if browsers from
  other sites could hold your users' tokens, add an `azp: String` field to
  `Claims` and compare it with your frontend's origin.
