# Swapping local auth for Auth0

`auth0.zig` is a single-file verifier for Auth0 access tokens (RS256, validated
against your tenant's JWKS with only `std.crypto`). It checks signature,
expiry, issuer, and audience.

## What to delete

- `src/jwt.zig` and the local token issuing
- the `/auth/register` and `/auth/login` routes in `src/main.zig`
- `register`/`login` and the argon2 code in `src/auth.zig`
- the `users` table in `schema.sql` — identity now lives in Auth0

## What to replace

1. Copy `auth0.zig` into `src/`.
2. Auth0 user ids are strings (`auth0|...`), not bigints. Change
   `posts.author_id` to `text` in `schema.sql` (drop the `references users`
   clause) and change `author_id: i64` to `author_id: []const u8` in
   `src/db.zig` / `src/posts.zig` (ownership check becomes `std.mem.eql`).
3. In `src/main.zig`, construct the verifier at startup and put it on `App`:

   ```zig
   const auth0 = @import("auth0.zig");

   const domain = env.get("AUTH0_DOMAIN") orelse
       std.process.fatal("AUTH0_DOMAIN is required", .{});
   const audience = env.get("AUTH0_AUDIENCE") orelse
       std.process.fatal("AUTH0_AUDIENCE is required", .{});
   var verifier = try auth0.Verifier.init(gpa, io, domain, audience);
   defer verifier.deinit();
   // add `auth0: *auth0.Verifier` to App and pass &verifier
   ```

4. Replace `requireAuth` in `src/auth.zig`:

   ```zig
   pub fn requireAuth(app: *App, arena: Allocator, req: *http.Server.Request) ![]const u8 {
       const token = web.bearerToken(req) orelse return error.Unauthorized;
       return app.auth0.verify(arena, token) catch error.Unauthorized;
   }
   ```

5. Env: drop `AUTH_SECRET`, add:

   ```
   AUTH0_DOMAIN=your-tenant.us.auth0.com
   AUTH0_AUDIENCE=https://api.your-blog.example
   ```

   `AUTH0_AUDIENCE` is the API identifier you registered under
   Auth0 → Applications → APIs. Clients must request tokens with that
   `audience`, otherwise Auth0 issues opaque tokens that cannot be verified
   locally.

## Notes

- The verifier caches the JWKS in memory and refetches once when it sees an
  unknown `kid`, so key rotation just works.
