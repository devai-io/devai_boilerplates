# blog-zig-postgres

A minimalist blog engine in Zig 0.16 on `std.http.Server`, with Postgres via
[pg.zig](https://github.com/karlseguin/pg.zig), argon2id password hashing from
`std.crypto.pwhash`, and a small self-contained HS256 JWT implementation. No web
framework — one thread per connection, an arena per request.

## Requirements

- Zig **0.16.0** (the `std.Io` interface era; older std.http APIs will not compile)
- Postgres 14+ (or just Docker)

## Quickstart

```sh
cp .env.example .env             # then edit AUTH_SECRET
docker compose up --build        # app on :8080, postgres on :5432
```

Or locally against your own Postgres:

```sh
export DATABASE_URL=postgres://blog:blog@localhost:5432/blog
export AUTH_SECRET=$(head -c 32 /dev/urandom | base64)
zig build run
```

The schema (`schema.sql`) is applied automatically on startup; every statement
is `if not exists`.

```sh
curl -s localhost:8080/health
curl -s localhost:8080/auth/register -d '{"email":"me@example.com","password":"hunter2hunter2"}'
TOKEN=$(curl -s localhost:8080/auth/login -d '{"email":"me@example.com","password":"hunter2hunter2"}' | sed 's/.*"token":"\([^"]*\)".*/\1/')
curl -s localhost:8080/posts -H "Authorization: Bearer $TOKEN" -d '{"title":"Hello Zig","body":"First post."}'
curl -s -X PUT localhost:8080/posts/1 -H "Authorization: Bearer $TOKEN" -d '{"published":true}'
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
Timestamps (`published_at`, `created_at`, `updated_at`) are unix seconds.
`excerpt` is the first 200 characters of the body, computed by Postgres.
Slugs are derived from the title once at creation and never change; creating a
second post with a colliding slug is a 409. Update and delete are restricted to
the post's author.

## Project layout

```
build.zig, build.zig.zon   zig build config; pg.zig is the only dependency
schema.sql                 applied on startup
src/main.zig               config, listener, per-connection threads, routing
src/web.zig                JSON body/response helpers, bearer token, clock
src/auth.zig               register/login handlers, argon2id, requireAuth
src/posts.zig              post CRUD handlers, slugify
src/jwt.zig                HS256 sign/verify (std.crypto only, ~100 lines)
extras/                    drop-in verifiers for Clerk and Auth0
```

## How auth works

`POST /auth/register` stores the argon2id hash (OWASP parameters) of the
password. `POST /auth/login` verifies it and returns a JWT signed with
HS256 over `AUTH_SECRET`, `sub` = user id, 7-day expiry. Protected handlers
call `auth.requireAuth`, which checks the `Authorization: Bearer` header.
`src/jwt.zig` rejects any token whose header is not exactly the HS256 header it
issues, so algorithm-confusion tricks don't apply.

## Switching to Clerk or Auth0

See `extras/auth-clerk/` and `extras/auth-auth0/`. Each contains a single
verifier file and a README describing exactly what to delete (local users,
`src/jwt.zig`, the `/auth` routes) and what to replace (`requireAuth`).

## Notes

- The pg.zig dependency is pinned to a commit in `build.zig.zon`; `zig build`
  fetches it on first run.
- `zig build -Doptimize=ReleaseSafe` for production binaries (the Dockerfile
  does this).
