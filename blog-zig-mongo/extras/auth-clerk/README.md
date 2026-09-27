# Auth via Clerk

`clerk.zig` replaces the local email+password auth with
[Clerk](https://clerk.com): the app stops issuing tokens and instead verifies
Clerk session JWTs (RS256) against your instance's JWKS — signature, `exp` and
`nbf` — using only the standard library.

## Setup

1. Copy `clerk.zig` into `src/` and delete `src/jwt.zig`.
2. `src/auth.zig` shrinks to `requireAuth` (drop `register`, `login`,
   `normalizeEmail` and the argon2/jwt imports):

   ```zig
   pub fn requireAuth(app: *App, arena: Allocator, req: *http.Server.Request) ![]const u8 {
       const token = web.bearerToken(req) orelse return error.Unauthorized;
       return app.verifier.verify(arena, token) catch error.Unauthorized;
   }
   ```

3. In `src/main.zig`, remove the `/auth/register` and `/auth/login` routes,
   add `const clerk = @import("clerk.zig");`, replace the `auth_secret` field
   of `App` with `verifier: *clerk.Verifier`, and replace the `AUTH_SECRET`
   lookup in `main` with:

   ```zig
   const jwks_url = env.get("CLERK_JWKS_URL") orelse
       std.process.fatal("CLERK_JWKS_URL is required", .{});
   var verifier = clerk.Verifier.init(gpa, io, jwks_url);
   defer verifier.deinit();
   ```

   and set `.verifier = &verifier` where `app` is built.
4. Clerk user ids are strings (`user_...`), not ObjectIds, and Clerk is
   the user store now. In `src/db.zig`, store `author_id` as a string: in
   `createPost` drop the `author` ObjectId and append it with
   `appendStr(doc, "author_id", author_id)`, and read it with
   `getStr(arena, doc, "author_id")` in `parsePost`. Delete `User`,
   `createUser`, `getUserByEmail` and the `users` index in `ensureIndexes`.
   `src/posts.zig` already treats user ids as strings.
5. Set `CLERK_JWKS_URL=https://<your-instance>.clerk.accounts.dev/.well-known/jwks.json`
   (Clerk dashboard → API keys) instead of `AUTH_SECRET`.

Clients send the Clerk session token as `Authorization: Bearer <token>`
(`await session.getToken()` in Clerk's frontend SDKs).

## Notes

- The JWKS is fetched over HTTPS with `std.http.Client`, which needs the
  system CA bundle — the runtime image installs `ca-certificates`.
- Keys are cached in memory. A token with an unknown `kid` triggers a refetch
  (at most once a minute), so key rotations need no restart.
- Clerk also puts the requesting origin in the `azp` claim; if browsers from
  other sites could hold your users' tokens, parse `azp` in `verify` and
  compare it with your frontend's origin.
