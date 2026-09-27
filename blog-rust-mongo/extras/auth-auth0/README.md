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
   reqwest = { version = "0.13", features = ["json"] }
   ```

3. Copy `auth0.rs` to `src/auth0.rs` and delete `src/auth.rs` — Auth0 hosts
   sign-up and sign-in. In `src/main.rs`, replace `mod auth;` with
   `mod auth0;`, then remove the `/auth/register` and `/auth/login` routes,
   the unused `post` import, and the `jwt_secret` state field along with its
   `AUTH_SECRET` line.
4. In `src/posts.rs`:
   - import the new extractor: `use crate::auth0::AuthUser;`
   - Auth0 user ids are strings (`auth0|...`), not ObjectIds: change
     `author_id: ObjectId` in `Post` to `author_id: String`, the
     `user_id: ObjectId` parameter of `find_own_post` to `user_id: String`,
     and `post.author_id.to_hex()` in `post_json` to `post.author_id`.
5. Auth0 is the user store now: in `src/db.rs`, remove the `users` field,
   its `email` index and the `User` import.
6. Set the environment variables:

   ```
   AUTH0_DOMAIN=your-tenant.us.auth0.com
   AUTH0_AUDIENCE=https://api.example.com
   ```

## Notes

- Clients obtain access tokens through one of Auth0's flows (Authorization
  Code + PKCE for SPAs; Client Credentials for a quick server-side test) and
  send them as `Authorization: Bearer <token>`. Request the token with your
  API's audience, or it is rejected.
- The JWKS is fetched on first use and cached. A token signed with an unknown
  key id triggers a refetch (at most once a minute), so key rotations need no
  restart.
