# blog-zig-mongo

A minimalist blog engine in Zig 0.16 on `std.http.Server`, backed by MongoDB
through the official C driver (**libmongoc**) via `@cImport` — no Zig wrapper
dependency, the C API is used directly. Argon2id password hashing from
`std.crypto.pwhash` and a small self-contained HS256 JWT implementation.
One thread per connection, an arena per request.

## Requirements

- Zig **0.16.0** (the `std.Io` interface era; older std.http APIs will not compile)
- **mongo-c-driver 1.x** (system requirement — headers + libs, found via
  pkg-config as `libmongoc-1.0`):
  - Debian/Ubuntu: `apt install libmongoc-dev`
  - Fedora: `dnf install mongo-c-driver-devel`
  - macOS: `brew install mongo-c-driver@1`
  - Nix: `nix-shell -p mongoc pkg-config`

  mongo-c-driver 2.x renamed the pkg-config modules (`mongoc2`/`bson2`); if
  that's what your system ships, adjust the two `linkSystemLibrary` names in
  `build.zig`.
- MongoDB 6+ (or just Docker)

## Quickstart

```sh
cp .env.example .env             # then edit AUTH_SECRET
docker compose up --build        # app on :8080, mongo on :27017
```

Or locally against your own MongoDB:

```sh
export MONGO_URL=mongodb://localhost:27017
export MONGO_DB=blog
export AUTH_SECRET=$(head -c 32 /dev/urandom | base64)
zig build run
```

Unique indexes (`users.email`, `posts.slug`) are created on startup.

```sh
curl -s localhost:8080/health
curl -s localhost:8080/auth/register -d '{"email":"me@example.com","password":"hunter2hunter2"}'
TOKEN=$(curl -s localhost:8080/auth/login -d '{"email":"me@example.com","password":"hunter2hunter2"}' | sed 's/.*"token":"\([^"]*\)".*/\1/')
curl -s localhost:8080/posts -H "Authorization: Bearer $TOKEN" -d '{"title":"Hello Zig","body":"First post."}'
# grab the returned id, then:
curl -s -X PUT localhost:8080/posts/<id> -H "Authorization: Bearer $TOKEN" -d '{"published":true}'
curl -s localhost:8080/posts
curl -s localhost:8080/posts/hello-zig
```

## API

```
GET    /health              -> 200 "ok"
POST   /auth/register       {email, password} -> 201 {id, email}
POST   /auth/login          {email, password} -> 200 {token}
GET    /posts               -> 200 [{id,title,slug,excerpt,published_at}]  (published only)
GET    /posts/{slug}        -> 200 full post | 404                         (published only)
POST   /posts        (auth) -> 201 {title, body}   (created unpublished)
PUT    /posts/{id}   (auth) -> 200 {title?, body?, published?}
DELETE /posts/{id}   (auth) -> 204
```

Errors are always `{"error":"message"}` with a matching status code.
Ids are ObjectId hex strings. Timestamps (`published_at`, `created_at`,
`updated_at`) are unix seconds. `excerpt` is the first 200 characters of the
body (UTF-8 aware). Slugs are derived from the title once at creation and never
change; creating a second post with a colliding slug is a 409. Update and
delete are restricted to the post's author.

## Project layout

```
build.zig, build.zig.zon   zig build config; links system libmongoc, no Zig deps
src/main.zig               config, listener, per-connection threads, routing
src/web.zig                JSON body/response helpers, bearer token, clock
src/auth.zig               register/login handlers, argon2id, requireAuth
src/posts.zig              post CRUD handlers, slugify, excerpt
src/jwt.zig                HS256 sign/verify (std.crypto only, ~100 lines)
src/db.zig                 libmongoc via @cImport: pool, collections, BSON glue
extras/                    drop-in verifiers for Clerk and Auth0
```

## How auth works

`POST /auth/register` stores the argon2id hash (OWASP parameters) of the
password in the `users` collection. `POST /auth/login` verifies it and returns
a JWT signed with HS256 over `AUTH_SECRET`, `sub` = user ObjectId hex, 7-day
expiry. Protected handlers call `auth.requireAuth`, which checks the
`Authorization: Bearer` header. `src/jwt.zig` rejects any token whose header is
not exactly the HS256 header it issues, so algorithm-confusion tricks don't
apply.

## Switching to Clerk or Auth0

See `extras/auth-clerk/` and `extras/auth-auth0/`. Each contains a single
verifier file and a README describing exactly what to delete (local users,
`src/jwt.zig`, the `/auth` routes) and what to replace (`requireAuth`).

## Notes

- User-supplied values are always appended with `bson_append_*` (never
  interpolated into JSON), so there is no injection surface; `bson_new_from_json`
  is only used for static command/option documents.
- `zig build -Doptimize=ReleaseSafe` for production binaries (the Dockerfile
  does this).
