# Swapping local auth for Clerk

`clerk.zig` is a single-file verifier for Clerk session JWTs (RS256, validated
against your instance's JWKS with only `std.crypto` — no new dependencies).

## What to delete

- `src/jwt.zig` and the local token issuing
- the `/auth/register` and `/auth/login` routes in `src/main.zig`
- `register`/`login` and the argon2 code in `src/auth.zig`
- the `users` table in `schema.sql` — identity now lives in Clerk

## What to replace

1. Copy `clerk.zig` into `src/`.
2. Clerk user ids are strings (`user_...`), not bigints. Change
   `posts.author_id` to `text` in `schema.sql` (drop the `references users`
   clause) and change `author_id: i64` to `author_id: []const u8` in
   `src/db.zig` / `src/posts.zig` (ownership check becomes `std.mem.eql`).
3. In `src/main.zig`, construct the verifier at startup and put it on `App`:

   ```zig
   const clerk = @import("clerk.zig");

   const jwks_url = env.get("CLERK_JWKS_URL") orelse
       std.process.fatal("CLERK_JWKS_URL is required", .{});
   var verifier = clerk.Verifier.init(gpa, io, jwks_url);
   defer verifier.deinit();
   // add `clerk: *clerk.Verifier` to App and pass &verifier
   ```

4. Replace `requireAuth` in `src/auth.zig`:

   ```zig
   pub fn requireAuth(app: *App, arena: Allocator, req: *http.Server.Request) ![]const u8 {
       const token = web.bearerToken(req) orelse return error.Unauthorized;
       return app.clerk.verify(arena, token) catch error.Unauthorized;
   }
   ```

5. Env: drop `AUTH_SECRET`, add
   `CLERK_JWKS_URL=https://<your-instance>.clerk.accounts.dev/.well-known/jwks.json`
   (Dashboard → API Keys → JWKS URL).

Clients now send the Clerk session token as `Authorization: Bearer <token>`
(from `useAuth().getToken()` in Clerk's frontend SDKs).

## Notes

- The verifier caches the JWKS in memory and refetches once when it sees an
  unknown `kid`, so key rotation just works.
- For defense in depth you can additionally check the `azp` claim against your
  frontend origin(s) — see Clerk's manual JWT verification docs.
