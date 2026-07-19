# blog-python-postgres

A minimalist blog engine API in Python: **FastAPI** + **asyncpg** (raw SQL, no
ORM), **argon2** password hashing, **HS256 JWT** auth. Four small modules, one
schema file, nothing else.

## Requirements

- Python 3.11+ and [uv](https://docs.astral.sh/uv/) — or just Docker
- PostgreSQL 14+ (the compose file provides one)

## Quickstart

Everything in containers:

```sh
docker compose up --build
```

Or local dev against the compose database:

```sh
docker compose up -d db
uv run uvicorn app.main:app --reload
```

The API listens on http://localhost:8000. `schema.sql` is applied automatically
on first startup when the tables are missing — there is no separate migrate
step. Interactive docs at `/docs`.

Take it for a spin:

```sh
curl localhost:8000/health
curl -X POST localhost:8000/auth/register \
  -H 'content-type: application/json' \
  -d '{"email":"me@example.com","password":"correct-horse"}'
TOKEN=$(curl -s -X POST localhost:8000/auth/login \
  -H 'content-type: application/json' \
  -d '{"email":"me@example.com","password":"correct-horse"}' \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')
curl -X POST localhost:8000/posts \
  -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' \
  -d '{"title":"Hello world","body":"My **first** post."}'
curl -X PUT localhost:8000/posts/1 \
  -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' \
  -d '{"published":true}'
curl localhost:8000/posts
```

## API

| Method | Path            | Auth | Description |
|--------|-----------------|------|-------------|
| GET    | `/health`       | –    | liveness, returns `ok` |
| POST   | `/auth/register`| –    | `{email, password}` → `201 {id, email}` |
| POST   | `/auth/login`   | –    | `{email, password}` → `{token}` |
| GET    | `/posts`        | –    | published posts: id, title, slug, excerpt (first 200 chars), published_at |
| GET    | `/posts/{slug}` | –    | full post; drafts return 404 |
| POST   | `/posts`        | yes  | `{title, body}` → `201`; slug derived from title; starts as draft |
| PUT    | `/posts/{id}`   | yes  | partial update `{title?, body?, published?}`; author only |
| DELETE | `/posts/{id}`   | yes  | author only, returns `204` |

Errors are always JSON: `{"error": "message"}`. Slugs are derived from the
title once, at creation, and never change afterwards — permalinks stay stable.

## Layout

```
app/
  main.py     app wiring: lifespan, routers, /health, JSON error shape
  db.py       asyncpg pool + first-run schema application
  auth.py     register/login, argon2 hashing, JWT issue/verify dependency
  posts.py    post CRUD, slug generation, ownership checks
schema.sql    two tables + one index, applied automatically on first start
Dockerfile    multi-stage build, slim non-root runtime
extras/       drop-in Clerk and Auth0 verifiers (see below)
```

## How auth works

`POST /auth/register` stores an argon2id hash of the password. `POST
/auth/login` verifies it and returns a JWT: HS256, signed with `AUTH_SECRET`,
`sub` = user id, 7-day expiry. Write endpoints expect it as
`Authorization: Bearer <token>`, and only a post's author may update or delete
it.

Set a real `AUTH_SECRET` in production — the dev fallback is public knowledge.

## Switching auth providers

`extras/auth-clerk/` and `extras/auth-auth0/` each contain a single drop-in
module that verifies that provider's RS256 tokens against its JWKS endpoint,
plus a README with the exact swap: one import change in `app/posts.py`, which
pieces of the local auth to delete, and the env vars to set.

## Configuration

| Env            | Default                                      | Notes |
|----------------|----------------------------------------------|-------|
| `PORT`         | `8000`                                       | listen port (compose maps it to the host) |
| `DATABASE_URL` | `postgresql://blog:blog@localhost:5432/blog` | asyncpg DSN |
| `AUTH_SECRET`  | `dev-secret-change-me-not-for-production`    | JWT signing key — change it |
