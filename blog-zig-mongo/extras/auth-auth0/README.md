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
5. Auth0 user ids are strings (`auth0|...`), not ObjectIds, and Auth0 is
   the user store now. In `src/db.zig`, store `author_id` as a string: in
   `createPost` drop the `author` ObjectId and append it with
   `appendStr(doc, "author_id", author_id)`, and read it with
   `getStr(arena, doc, "author_id")` in `parsePost`. Delete `User`,
   `createUser`, `getUserByEmail` and the `users` index in `ensureIndexes`.
   `src/posts.zig` already treats user ids as strings.
6. Set `AUTH0_DOMAIN=your-tenant.us.auth0.com` and
   `AUTH0_AUDIENCE=https://api.example.com` instead of `AUTH_SECRET`.

Clients obtain access tokens through one of Auth0's flows (Authorization Code
+ PKCE for SPAs; Client Credentials for a quick server-side test) and send
them as `Authorization: Bearer <token>`. Request the token with your API's
audience, or it is rejected.

## Notes

- The JWKS is fetched over HTTPS with `std.http.Client`, which needs the
  system CA bundle — the runtime image installs `ca-certificates`.
- Keys are cached in memory. A token with an unknown `kid` triggers a refetch
  (at most once a minute), so key rotations need no restart.
