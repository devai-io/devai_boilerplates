# Auth0 auth (drop-in)

Replaces the template's local email/password auth with
[Auth0](https://auth0.com) access tokens. Users authenticate through Auth0
(Universal Login or one of its SDKs); this API only verifies the RS256 access
token Auth0 issues for your API audience.

`auth0.go` validates `Authorization: Bearer <token>` against your tenant's
JWKS endpoint, checks issuer and audience, and exposes the Auth0 user id via
`userID(r)` — the same helper the local setup provides, so the post handlers
keep working.

## Auth0 setup

In the Auth0 dashboard create an **API** (Applications → APIs). Its
*identifier* is your audience. Tokens requested with that audience — from any
Auth0 login flow — will pass this middleware.

## Swap steps

1. Copy `auth0.go` into the project root and change `package auth0auth` to
   `package main`.
2. Delete `auth.go` — register, login, and HS256 tokens are Auth0's job now.
3. In `main.go`, drop the `AUTH_SECRET` lookup (and the `secret` field on
   `app`), drop the `/auth/register` and `/auth/login` routes, and wrap the
   protected routes with the Auth0 middleware:

   ```go
   requireAuth := newAuth0Auth()
   mux.HandleFunc("POST /posts", requireAuth(a.createPost))
   mux.HandleFunc("PUT /posts/{id}", requireAuth(a.updatePost))
   mux.HandleFunc("DELETE /posts/{id}", requireAuth(a.deletePost))
   ```

4. Author ids are now Auth0 user ids (strings like `auth0|abc123`), not
   integers:
   - in `schema.sql`, drop the `users` table and change `posts.author_id` to
     `TEXT NOT NULL` (no foreign key) — then reset the database
     (`docker compose down`, delete `./data`) so the new schema applies;
   - in `posts.go`, change the `post.AuthorID` field to `string` and use
     `userID(r)` directly instead of `strconv.ParseInt(userID(r), 10, 64)`.
5. Environment: remove `AUTH_SECRET`, add your tenant and audience:

   ```
   AUTH0_DOMAIN=your-tenant.eu.auth0.com
   AUTH0_AUDIENCE=https://blog-api
   ```

After the swap `go vet ./...` should pass and every `(auth)` route expects an
Auth0 access token.
