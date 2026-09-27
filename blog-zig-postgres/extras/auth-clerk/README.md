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
4. Clerk user ids are strings (`user_...`), not bigints. In `src/db.zig`,
   make `author_id` a `[]const u8` in `Post` and in `createPost`, read it with
   `try arena.dupe(u8, try row.get([]const u8, 5))` in `postRow`, and delete
   `User`, `createUser` and `getUserByEmail`. In `src/posts.zig`,
   `findOwnPost` takes `user_id: []const u8` and compares with
   `std.mem.eql(u8, post.author_id, user_id)`.
5. In `schema.sql`, delete the `users` table and change the column to
   `author_id text not null` (`create table if not exists` won't alter an
   existing table, so start from an empty database).
6. Set `CLERK_JWKS_URL=https://<your-instance>.clerk.accounts.dev/.well-known/jwks.json`
   (Clerk dashboard → API keys) instead of `AUTH_SECRET`.

Clients send the Clerk session token as `Authorization: Bearer <token>`
(`await session.getToken()` in Clerk's frontend SDKs).

## Notes

- The JWKS is fetched over HTTPS with `std.http.Client`, which needs the
  system CA bundle — the distroless runtime image ships one.
- Keys are cached in memory. A token with an unknown `kid` triggers a refetch
  (at most once a minute), so key rotations need no restart.
- Clerk also puts the requesting origin in the `azp` claim; if browsers from
  other sites could hold your users' tokens, parse `azp` in `verify` and
  compare it with your frontend's origin.
