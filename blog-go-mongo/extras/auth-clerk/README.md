# Clerk auth (drop-in)

Replaces the template's local email/password auth with [Clerk](https://clerk.com)
session tokens. Users sign up and sign in through Clerk (hosted pages or one of
its frontend SDKs); this API only verifies the session JWT Clerk issues.

`clerk.go` validates `Authorization: Bearer <token>` against your Clerk
instance's JWKS endpoint (RS256 signature, issuer, expiry, `azp`) and exposes
the Clerk user id via `userID(r)` — the same helper the local setup provides, so the post handlers keep working.

## Swap steps

1. Copy `clerk.go` into the project root and change `package clerkauth` to
   `package main`.
2. Delete `auth.go` — register, login, and HS256 tokens are Clerk's job now.
3. In `main.go`, drop the `AUTH_SECRET` lookup (and the `secret` field on
   `app`), drop the `/auth/register` and `/auth/login` routes, and wrap the
   protected routes with the Clerk middleware:

   ```go
   requireAuth := newClerkAuth()
   mux.HandleFunc("POST /posts", requireAuth(a.createPost))
   mux.HandleFunc("PUT /posts/{id}", requireAuth(a.updatePost))
   mux.HandleFunc("DELETE /posts/{id}", requireAuth(a.deletePost))
   ```

4. Author ids are now Clerk user ids (strings like `user_2f...`), not
   ObjectIDs:
   - in `posts.go`, change the `post.AuthorID` field to `string` and use
     `userID(r)` directly instead of `bson.ObjectIDFromHex(userID(r))`;
   - the `users` collection is unused now — remove its entry from the index
     map in `db.go` (and drop any posts created under local auth, since their
     `author_id` values won't match Clerk ids).
5. Environment: remove `AUTH_SECRET`, add your instance's issuer and the
   origins allowed to mint tokens for this API (checked against the `azp`
   claim; leave it unset to skip the check):

   ```
   CLERK_ISSUER=https://your-app.clerk.accounts.dev
   CLERK_AUTHORIZED_PARTIES=https://your-site.com,http://localhost:5173
   ```

   The issuer is your Frontend API URL (Clerk dashboard → API keys);
   production instances use your own domain, e.g. `https://clerk.your-site.com`.

After the swap `go vet ./...` should pass and every `(auth)` route expects a
Clerk session JWT.
