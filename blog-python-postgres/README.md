# blog-python-postgres

A minimalist blog engine API in Python: FastAPI + asyncpg (raw SQL, no ORM),
argon2 password hashing and HS256 JWTs. Four small modules and one schema
file.

## Run

    git clone https://git.devai.io/templates/blog-python-postgres.git
    cd blog-python-postgres
    docker compose up --build

The API answers on http://localhost:8080 (`curl localhost:8080/health` → `ok`;
interactive docs at `/docs`). Postgres keeps its state in `./data/postgres`;
`schema.sql` is applied on every start (all statements are idempotent), so
there is no migrate step.

Without Docker: point `DATABASE_URL` at any Postgres, copy `.env.example` to
`.env`, then `uv run --env-file .env uvicorn app.main:app --port 8080`.

## How it works

| Method | Path             | Auth | Result                                                   |
|--------|------------------|------|----------------------------------------------------------|
| GET    | `/health`        | —    | `200 ok`                                                 |
| POST   | `/auth/register` | —    | `{email, password}` → `201 {id, email}`, `409` if taken  |
| POST   | `/auth/login`    | —    | `{email, password}` → `200 {token}`, `401` if wrong      |
| GET    | `/posts`         | —    | `200 [{id, title, slug, excerpt, published_at}]`, published only |
| GET    | `/posts/{slug}`  | —    | `200` full published post, or `404`                      |
| POST   | `/posts`         | JWT  | `{title, body}` → `201` full post (a draft)              |
| PUT    | `/posts/{id}`    | JWT  | `{title?, body?, published?}` → `200` full post          |
| DELETE | `/posts/{id}`    | JWT  | `204`                                                    |

- **Auth** — register stores an argon2 hash; login returns an HS256 JWT signed
  with `AUTH_SECRET` (`sub` = user id, 7-day expiry). Send it as
  `Authorization: Bearer <token>`. The `current_user_id` dependency in
  `app/auth.py` pins the algorithm and requires `exp` and `sub`.
- **Ownership** — only a post's author may update or delete it; anyone else
  gets `403`.
- **Slugs** come from the title (`"Hello, World!"` → `hello-world`); a
  duplicate title gets `-2`, `-3`, … Retitling a post regenerates its slug.
- **Drafts** — new posts are unpublished; `PUT {"published": true}` publishes.
  Public endpoints only return published posts. `excerpt` is the first 200
  characters of the body; `published_at` is stamped the first time a post is
  published (`null` until then) and kept through later edits and
  unpublish/republish; the list is newest first by it.
- **Errors** are `{"error": "message"}` with a matching status code; invalid
  input is `400`.

A full round trip:

```sh
J='Content-Type: application/json'
curl -s localhost:8080/auth/register -H "$J" -d '{"email":"me@example.com","password":"sup3rsecret"}'
TOKEN=$(curl -s localhost:8080/auth/login -H "$J" -d '{"email":"me@example.com","password":"sup3rsecret"}' | jq -r .token)
ID=$(curl -s localhost:8080/posts -H "$J" -H "Authorization: Bearer $TOKEN" -d '{"title":"Hello, World!","body":"First post."}' | jq -r .id)
curl -s -X PUT localhost:8080/posts/$ID -H "$J" -H "Authorization: Bearer $TOKEN" -d '{"published":true}'
curl -s localhost:8080/posts/hello-world
```

## Layout

```
app/main.py      app wiring, health check, JSON error handlers
app/db.py        asyncpg pool, schema apply on startup
app/auth.py      register/login, argon2, JWT issue + current_user_id dependency
app/posts.py     post routes, slugs, ownership checks
schema.sql       users + posts tables
extras/          drop-in Clerk and Auth0 verifiers, each with swap steps
```

Local auth lives entirely in `app/auth.py`, so it can be replaced wholesale:
`extras/auth-clerk/` and `extras/auth-auth0/` each hold one JWKS-based RS256
verifier and a README with the exact steps.

## Deploy

Push to your own GitHub repo and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — the blog engine series: one API
contract, eight backends (`blog-{go,rust,zig,python}-{postgres,mongo}`) and
the `blog-react`, `blog-angular`, `blog-dart` and `blog-flutter` frontends.
