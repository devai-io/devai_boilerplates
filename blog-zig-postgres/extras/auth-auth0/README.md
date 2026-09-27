# Auth via Auth0

`auth0.zig` replaces the local email+password auth with
[Auth0](https://auth0.com): the app stops issuing tokens and instead verifies
Auth0 access tokens (RS256) against your tenant's JWKS — signature, `exp`,
`nbf`, issuer and audience — using only the standard library.

## Setup

1. In the Auth0 dashboard create an API (Applications → APIs); its identifier
   is your audience. Your tenant domain (e.g. `your-tenant.us.auth0.com`) is
   the issuer host.
2. Copy `auth0.zig` into `src/` and delete `src/jwt.zig`.
3. `src/auth.zig` shrinks to `requireAuth` (drop `register`, `login`,
   `normalizeEmail` and the argon2/jwt imports):

   ```zig
   pub fn requireAuth(app: *App, arena: Allocator, req: *http.Server.Request) ![]const u8 {
       const token = web.bearerToken(req) orelse return error.Unauthorized;
       return app.verifier.verify(arena, token) catch error.Unauthorized;
   }
   ```

4. In `src/main.zig`, remove the `/auth/register` and `/auth/login` routes,
   add `const auth0 = @import("auth0.zig");`, replace the `auth_secret` field
   of `App` with `verifier: *auth0.Verifier`, and replace the `AUTH_SECRET`
   lookup in `main` with:

   ```zig
   const domain = env.get("AUTH0_DOMAIN") orelse
       std.process.fatal("AUTH0_DOMAIN is required", .{});
   const audience = env.get("AUTH0_AUDIENCE") orelse
       std.process.fatal("AUTH0_AUDIENCE is required", .{});
   var verifier = try auth0.Verifier.init(gpa, io, domain, audience);
   defer verifier.deinit();
   ```

   and set `.verifier = &verifier` where `app` is built.
5. Auth0 user ids are strings (`auth0|...`), not bigints. In `src/db.zig`,
   make `author_id` a `[]const u8` in `Post` and in `createPost`, read it with
   `try arena.dupe(u8, try row.get([]const u8, 5))` in `postRow`, and delete
   `User`, `createUser` and `getUserByEmail`. In `src/posts.zig`,
   `findOwnPost` takes `user_id: []const u8` and compares with
   `std.mem.eql(u8, post.author_id, user_id)`.
6. In `schema.sql`, delete the `users` table and change the column to
   `author_id text not null` (`create table if not exists` won't alter an
   existing table, so start from an empty database).
7. Set `AUTH0_DOMAIN=your-tenant.us.auth0.com` and
   `AUTH0_AUDIENCE=https://api.example.com` instead of `AUTH_SECRET`.

Clients obtain access tokens through one of Auth0's flows (Authorization Code
+ PKCE for SPAs; Client Credentials for a quick server-side test) and send
them as `Authorization: Bearer <token>`. Request the token with your API's
audience, or it is rejected.

## Notes

- The JWKS is fetched over HTTPS with `std.http.Client`, which needs the
  system CA bundle — the distroless runtime image ships one.
- Keys are cached in memory. A token with an unknown `kid` triggers a refetch
  (at most once a minute), so key rotations need no restart.
