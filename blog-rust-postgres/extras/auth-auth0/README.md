# Auth via Auth0

Replaces the local email+password auth with [Auth0](https://auth0.com). The app
stops issuing tokens itself and instead verifies Auth0-issued access tokens
(RS256) against your tenant's JWKS, checking issuer and audience.

## Setup

1. In the Auth0 dashboard create an API (Applications → APIs). Its identifier
   is your audience. Your tenant domain (e.g. `your-tenant.us.auth0.com`) is
   the issuer host.
2. Add the HTTP client to `Cargo.toml`:

   ```toml
   reqwest = { version = "0.12", default-features = false, features = ["rustls-tls", "json"] }
   ```

3. Copy `auth0.rs` to `src/auth0.rs` and register it in `src/main.rs`:

   ```rust
   mod auth0;
   ```

4. In `src/posts.rs`, swap the extractor import:

   ```rust
   use crate::auth0::AuthUser;
   ```

5. Set the environment variables:

   ```
   AUTH0_DOMAIN=your-tenant.us.auth0.com
   AUTH0_AUDIENCE=https://api.example.com
   ```

## What to delete / replace

- `src/auth.rs` and the `/auth/register` + `/auth/login` routes in
  `src/main.rs` — Auth0 hosts sign-up and sign-in, so the app no longer needs
  them. `AUTH_SECRET` becomes unused.
- The `users` table in `schema.sql` — Auth0 is the user store now. Keep it only
  if you mirror users locally, and drop `password_hash` in that case.
- `posts.author_id` — Auth0 user ids are strings (`auth0|...`), not UUIDs.
  In `schema.sql` change the column and drop the foreign key:

  ```sql
  author_id TEXT NOT NULL
  ```

  and in `src/posts.rs` change `author_id: Uuid` to `author_id: String`
  (bind it with `&author_id`).

## Notes

- Clients obtain access tokens through one of Auth0's flows (Authorization
  Code + PKCE for SPAs; Client Credentials works for a quick server-side test)
  and send them as `Authorization: Bearer <token>`. Request the token with
  your API's audience or the signature check will fail.
- The JWKS is fetched lazily on first use and cached for the process lifetime;
  restart the app after a key rotation.
