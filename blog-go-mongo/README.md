# blog-go-mongo

A minimalist blog engine API in Go: stdlib `net/http` routing, MongoDB via the
official `mongo-driver/v2`, bcrypt passwords and HS256 JWTs. No ODM, no
framework — four source files you can read in one sitting.

## Run

    git clone https://git.devai.io/templates/blog-go-mongo.git
    cd blog-go-mongo
    docker compose up --build

The API answers on http://localhost:8080 (`curl localhost:8080/health` → `ok`).
MongoDB keeps its state in `./data/mongo`; the unique indexes (`users.email`,
`posts.slug`) are ensured on every start, so there is no migrate step.

Without Docker: point `MONGO_URL` at any MongoDB, set the variables from
`.env.example`, then `go run .` (Go 1.26).

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

- **Ids** are MongoDB ObjectIDs, serialized as hex strings.
- **Auth** — register stores a bcrypt hash; login returns an HS256 JWT signed
  with `AUTH_SECRET` (`sub` = user id, 7-day expiry). Send it as
  `Authorization: Bearer <token>`. `requireAuth` in `auth.go` pins the
  algorithm, requires `exp`, and hands the user id to handlers via `userID(r)`.
- **Ownership** — only a post's author may update or delete it; anyone else
  gets `403`.
- **Slugs** come from the title (`"Hello, World!"` → `hello-world`); a
  duplicate title gets `-2`, `-3`, … Retitling a post regenerates its slug.
- **Drafts** — new posts are unpublished; `PUT {"published": true}` publishes.
  Public endpoints only return published posts. `excerpt` is the first 200
  characters of the body; `published_at` is stamped the first time a post is
  published (`null` until then) and kept through later edits and
  unpublish/republish; the list is newest first by it.
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
main.go        server, routes, JSON helpers
db.go          client connect, index setup on startup, duplicate-key check
auth.go        register/login, bcrypt, JWT issue + requireAuth middleware
posts.go       post handlers, slugs, excerpts
extras/        drop-in Clerk and Auth0 verifiers, each with swap steps
```

Local auth lives entirely in `auth.go`, so it can be replaced wholesale:
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
