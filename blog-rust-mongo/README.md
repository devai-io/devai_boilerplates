# blog-rust-mongo

A minimalist blog engine API in Rust: axum + tokio, MongoDB via the official
`mongodb` driver, argon2 password hashing, HS256 JWT auth.

## Requirements

- Docker + Docker Compose (quickest path), or
- Rust 1.85+ and MongoDB 6+

## Quickstart

With Docker:

```sh
docker compose up --build
```

The API listens on http://localhost:8080; MongoDB is published on localhost:27017.

Locally:

```sh
cp .env.example .env      # adjust MONGO_URL if needed
docker compose up -d db   # or point MONGO_URL at your own MongoDB
cargo run
```

Unique indexes on `users.email` and `posts.slug` (plus a list index on
`published` + `created_at`) are created on startup; index creation is
idempotent, so restarts are safe.

## Try it

```sh
curl localhost:8080/health

curl -X POST localhost:8080/auth/register -H 'content-type: application/json' \
  -d '{"email":"me@example.com","password":"supersecret"}'

TOKEN=$(curl -sX POST localhost:8080/auth/login -H 'content-type: application/json' \
  -d '{"email":"me@example.com","password":"supersecret"}' | jq -r .token)

POST_ID=$(curl -sX POST localhost:8080/posts -H "authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' \
  -d '{"title":"Hello World","body":"My first post."}' | jq -r .id)

curl -X PUT localhost:8080/posts/$POST_ID -H "authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' -d '{"published":true}'

curl localhost:8080/posts
curl localhost:8080/posts/hello-world
```

## API

| Method | Path            | Auth   | Description                                     |
|--------|-----------------|--------|-------------------------------------------------|
| GET    | `/health`       | –      | Liveness check, returns `ok`                    |
| POST   | `/auth/register`| –      | `{email, password}` → `201 {id, email}`         |
| POST   | `/auth/login`   | –      | `{email, password}` → `200 {token}`             |
| GET    | `/posts`        | –      | Published posts: `{id,title,slug,excerpt,published_at}` |
| GET    | `/posts/{slug}` | –      | Full post by slug, `404` if unknown/unpublished |
| POST   | `/posts`        | Bearer | `{title, body}` → `201` full post (draft)       |
| PUT    | `/posts/{id}`   | Bearer | `{title?, body?, published?}` → `200` full post |
| DELETE | `/posts/{id}`   | Bearer | `204` on success                                |

Slugs are derived from the title (`Hello World` → `hello-world`); collisions get
a random suffix. `excerpt` is the first 200 characters of the body. Ids are
ObjectId hex strings. Errors are always JSON: `{"error": "message"}`.

## Project layout

```
src/main.rs    env, router, startup
src/db.rs      MongoDB client, typed collections, startup indexes
src/auth.rs    register/login, argon2 hashing, JWT issue/verify (AuthUser extractor)
src/posts.rs   post CRUD + slug generation
src/error.rs   JSON error type and JSON body extractor
```

## How auth works

`POST /auth/register` stores an argon2id hash of the password. `POST /auth/login`
verifies it and returns a JWT — HS256 signed with `AUTH_SECRET`, `sub` = user id,
7-day expiry. Protected routes read `Authorization: Bearer <token>` through the
`AuthUser` extractor in `src/auth.rs`. Posts can only be updated or deleted by
their author.

## Switching auth providers

The local email+password flow is self-contained and easy to swap for hosted
auth. Working drop-in verifiers, each with exact swap steps in its README:

- `extras/auth-clerk/` — validate Clerk session JWTs via JWKS
- `extras/auth-auth0/` — validate Auth0 access tokens (issuer + audience)

## Configuration

| Env           | Default | Meaning                                        |
|---------------|---------|------------------------------------------------|
| `PORT`        | `8080`  | Listen port                                    |
| `MONGO_URL`   | –       | MongoDB connection string                      |
| `MONGO_DB`    | –       | Database name                                  |
| `AUTH_SECRET` | –       | HS256 signing key; use a long random value     |
