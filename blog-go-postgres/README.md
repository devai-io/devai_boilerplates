# blog-go-postgres

A minimalist blog engine in Go: stdlib `net/http` (Go 1.22+ method routing),
Postgres via `pgx/v5`, bcrypt password hashing, and HS256 JWTs. Raw SQL, no
ORM, no framework — five source files you can read in one sitting.

## Requirements

- Go 1.25+
- Postgres 14+ (or just Docker)

## Quickstart

With Docker:

```sh
docker compose up --build
curl localhost:8080/health
```

Locally (Postgres from compose, app on your machine):

```sh
docker compose up -d db
cp .env.example .env          # adjust if needed
export $(grep -v '^#' .env | xargs)
go mod tidy                   # fetches dependencies and writes go.sum
go run .
```

The schema (`schema.sql`) is applied automatically on startup; there is no
separate migrate step.

## API

| Method | Path            | Auth | Description                                        |
|--------|-----------------|------|----------------------------------------------------|
| GET    | `/health`       | —    | Liveness check, returns `ok`                       |
| POST   | `/auth/register`| —    | `{email, password}` → `201 {id, email}`            |
| POST   | `/auth/login`   | —    | `{email, password}` → `200 {token}`                |
| GET    | `/posts`        | —    | Published posts: `{id, title, slug, excerpt, published_at}` |
| GET    | `/posts/{slug}` | —    | Full published post, or 404                        |
| POST   | `/posts`        | JWT  | `{title, body}` → `201` full post (draft)          |
| PUT    | `/posts/{id}`   | JWT  | `{title?, body?, published?}` → `200` full post    |
| DELETE | `/posts/{id}`   | JWT  | `204`, author only                                 |

Behavior worth knowing:

- Slugs are derived from the title (`"Hello, World!"` → `hello-world`); on a
  collision the engine appends `-2`, `-3`, … Renaming a post regenerates its
  slug.
- `excerpt` is the first 200 characters of the body, computed server-side.
- New posts are drafts (`published: false`); publish with
  `PUT /posts/{id}` and `{"published": true}`. Public endpoints only ever
  return published posts.
- Only the author of a post can update or delete it.
- Errors are JSON: `{"error": "message"}` with an appropriate status code.

A full round trip:

```sh
curl -s -X POST localhost:8080/auth/register \
  -d '{"email":"me@example.com","password":"sup3rsecret"}'
TOKEN=$(curl -s -X POST localhost:8080/auth/login \
  -d '{"email":"me@example.com","password":"sup3rsecret"}' | jq -r .token)
curl -s -X POST localhost:8080/posts -H "Authorization: Bearer $TOKEN" \
  -d '{"title":"Hello, World!","body":"First post."}'
curl -s -X PUT localhost:8080/posts/1 -H "Authorization: Bearer $TOKEN" \
  -d '{"published":true}'
curl -s localhost:8080/posts/hello-world
```

## Project layout

```
main.go             server setup, routing, JSON helpers
db.go               pgx pool, startup schema apply, duplicate-key detection
auth.go             register/login, bcrypt, JWT issue + verify middleware
posts.go            post handlers, slugs, excerpts
schema.sql          users + posts tables (idempotent)
Dockerfile          multi-stage build → distroless static image
docker-compose.yml  app + Postgres 16 with healthcheck
extras/             drop-in Clerk and Auth0 auth (see below)
```

## How auth works

`POST /auth/register` stores the email with a bcrypt password hash.
`POST /auth/login` verifies the password and returns a JWT — HS256, signed
with `AUTH_SECRET`, `sub` = user id, 7-day expiry. Protected routes expect it
as `Authorization: Bearer <token>`; the `requireAuth` middleware in `auth.go`
validates it and hands the user id to handlers via `userID(r)`.

## Switching auth providers

Local auth is deliberately contained in `auth.go` so it can be swapped
wholesale. `extras/auth-clerk/` and `extras/auth-auth0/` each contain a single
drop-in verifier (JWKS-based RS256 validation) plus a README with the exact
delete/replace steps.
