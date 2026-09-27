# blog-zig-mongo

The blog engine API in Zig 0.16 on MongoDB: `std.http.Server` with a thread
per connection and an arena per request, the official C driver (libmongoc)
used directly through `@cImport`, argon2id from `std.crypto.pwhash`, and a
hand-rolled HS256 JWT. No web framework, no Zig dependencies.

## Run

    git clone https://git.devai.io/templates/blog-zig-mongo.git
    cd blog-zig-mongo
    docker compose up --build

The API answers on http://localhost:8080 (`curl localhost:8080/health` → `ok`).
MongoDB keeps its state in `./data/mongo`; the unique indexes on `users.email`
and `posts.slug` are ensured on every start, so there is no migrate step.

Without Docker you need Zig 0.16.0 and libmongoc 1.x with pkg-config
(Debian/Ubuntu: `apt install libmongoc-dev pkg-config`). Point `MONGO_URL` at
a MongoDB, export the variables from `.env.example`, then `zig build run`.

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

- **Auth** — register stores an argon2id hash (OWASP parameters, passwords of
  8+ characters); login returns an HS256 JWT signed with `AUTH_SECRET`
  (`sub` = user id, 7-day expiry). Send it as `Authorization: Bearer <token>`.
  `src/jwt.zig` rejects any `alg` but HS256, compares signatures in constant
  time and enforces `exp`.
- **Ownership** — only a post's author may update or delete it; anyone else
  gets `403`.
- **Slugs** come from the title (`"Hello, World!"` → `hello-world`); a
  duplicate title gets `-2`, `-3`, … Retitling a post regenerates its slug.
- **Drafts** — new posts are unpublished; `PUT {"published": true}` publishes.
  Public endpoints only return published posts. `excerpt` is the first 200
  characters (codepoints, never a split UTF-8 sequence) of the body;
  `published_at` is the post's creation time. Timestamps are stored as BSON
  dates and returned as RFC 3339 strings in UTC.
- **Ids** are MongoDB ObjectIds as 24-character hex strings.
- **Errors** are `{"error": "message"}` with a matching status code.

A full round trip:

```sh
curl -s localhost:8080/auth/register -d '{"email":"me@example.com","password":"sup3rsecret"}'
TOKEN=$(curl -s localhost:8080/auth/login -d '{"email":"me@example.com","password":"sup3rsecret"}' | jq -r .token)
ID=$(curl -s localhost:8080/posts -H "Authorization: Bearer $TOKEN" -d '{"title":"Hello, World!","body":"First post."}' | jq -r .id)
curl -s -X PUT localhost:8080/posts/$ID -H "Authorization: Bearer $TOKEN" -d '{"published":true}'
curl -s localhost:8080/posts/hello-world
```

## Layout

```
build.zig        links libc + libmongoc/libbson (pkg-config)
src/main.zig     config, listener, one thread per connection, routing
src/web.zig      JSON in/out, body limit, bearer token, clock
src/auth.zig     register/login, argon2id, requireAuth
src/jwt.zig      HS256 sign/verify on std.crypto
src/posts.zig    post handlers, slugs, excerpts, ownership checks
src/db.zig       libmongoc via @cImport: pooled clients, indexes, BSON <-> structs
extras/          drop-in Clerk and Auth0 verifiers, each with swap steps
```

`build.zig.zon` lists no dependencies — libmongoc comes from the system (the
Dockerfile installs Debian's `libmongoc-dev`, and the runtime image only its
shared library). Local auth lives in `src/auth.zig` + `src/jwt.zig`;
`extras/auth-clerk/` and `extras/auth-auth0/` each hold one JWKS-based RS256
verifier (std only) and a README with the exact steps.

## Deploy

Push to your own GitHub repo and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — the blog engine series: one API
contract, eight backends (`blog-{go,rust,zig,python}-{postgres,mongo}`) and
the `blog-react`, `blog-angular`, `blog-dart` and `blog-flutter` frontends.
