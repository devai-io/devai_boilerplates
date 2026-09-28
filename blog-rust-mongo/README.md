# blog-rust-mongo

The blog engine API in Rust on MongoDB: axum + tokio, the official `mongodb`
driver, argon2 password hashing and HS256 JWTs. Same API as the Postgres
flavor — documents instead of rows, indexes instead of a schema.

## Run

    git clone https://github.com/devai-io/devai_boilerplates.git
    cd devai_boilerplates/blog-rust-mongo
    docker compose up --build

The API answers on http://localhost:8080 (`curl localhost:8080/health` → `ok`).
MongoDB keeps its state in `./data/mongo`; the unique indexes on `users.email`
and `posts.slug` are ensured on every start, so there is no migrate step.

Without Docker: point `MONGO_URL` at any MongoDB, copy `.env.example` to
`.env` (it is loaded on start), then `cargo run` (Rust 1.88+).

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

- **Auth** — register stores an argon2id hash (passwords of 8+ characters);
  login returns an HS256 JWT signed with `AUTH_SECRET` (`sub` = user id,
  7-day expiry). Send it as `Authorization: Bearer <token>`. The `AuthUser`
  extractor in `src/auth.rs` accepts only HS256, requires `exp` and `sub`,
  and rejects expired tokens.
- **Ownership** — only a post's author may update or delete it; anyone else
  gets `403`.
- **Slugs** come from the title (`"Hello, World!"` → `hello-world`); a
  duplicate title gets `-2`, `-3`, … Retitling a post regenerates its slug.
- **Drafts** — new posts are unpublished; `PUT {"published": true}` publishes.
  Public endpoints only return published posts. `excerpt` is the first 200
  characters of the body; `published_at` is stamped the first time a post is
  published (`null` until then) and kept through later edits and
  unpublish/republish; the list is newest first by it.
- **Ids** are MongoDB ObjectIds as 24-character hex strings.
- **Errors** are `{"error": "message"}` with a matching status code.

A full round trip:

```sh
curl -s localhost:8080/auth/register -H 'content-type: application/json' \
  -d '{"email":"me@example.com","password":"sup3rsecret"}'
TOKEN=$(curl -s localhost:8080/auth/login -H 'content-type: application/json' \
  -d '{"email":"me@example.com","password":"sup3rsecret"}' | jq -r .token)
ID=$(curl -s localhost:8080/posts -H "Authorization: Bearer $TOKEN" -H 'content-type: application/json' \
  -d '{"title":"Hello, World!","body":"First post."}' | jq -r .id)
curl -s -X PUT localhost:8080/posts/$ID -H "Authorization: Bearer $TOKEN" -H 'content-type: application/json' \
  -d '{"published":true}'
curl -s localhost:8080/posts/hello-world
```

## Layout

```
src/main.rs    env, router, startup
src/db.rs      MongoDB client, collections + indexes on startup
src/auth.rs    register/login, argon2, JWT issue + the AuthUser extractor
src/posts.rs   post handlers, slugs, ownership checks
src/error.rs   {"error": ...} responses and a JSON extractor that uses them
extras/        drop-in Clerk and Auth0 verifiers, each with swap steps
```

Local auth lives entirely in `src/auth.rs`, so it can be replaced wholesale:
`extras/auth-clerk/` and `extras/auth-auth0/` each hold one JWKS-based RS256
verifier and a README with the exact steps.

## Deploy

Make this folder the root of your own repo (`cp -r devai_boilerplates/blog-rust-mongo my-app`,
then `git init` inside it), push it to GitHub, and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — the blog engine series: one API
contract, eight backends (`blog-{go,rust,zig,python}-{postgres,mongo}`) and
the `blog-react`, `blog-angular`, `blog-dart` and `blog-flutter` frontends.
