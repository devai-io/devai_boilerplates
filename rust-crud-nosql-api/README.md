# rust-crud-nosql-api

The JWT-secured REST API from `rust-crud-sql-api`, on MongoDB: warp filters, the
official `mongodb` driver, argon2 passwords and role-based routes (`User` / `Admin`)
— users, articles and comments, laid out as routes → handlers → service per module.

## Run

    git clone https://github.com/devai-io/devai_boilerplates.git
    cd devai_boilerplates/rust-crud-nosql-api
    docker compose up --build

The API answers on http://localhost:8080 (`curl localhost:8080/health` → `ok`).
MongoDB keeps its state in `./data/mongo`; the unique indexes on `users.email` and
`articles.url` are ensured on every start, so there is no migrate step.

Without Docker: run a MongoDB, export the variables from `.env.example`, then
`cargo run` (Rust 1.98, the toolchain the Dockerfile pins).

## How it works

| Method | Path                                         | Auth    | Result                                                      |
|--------|----------------------------------------------|---------|-------------------------------------------------------------|
| GET    | `/health`                                    | —       | `200 ok`                                                    |
| POST   | `/api/auth/register`                         | —       | `{email, name, password}` → `201` user (role `User`), `409` if taken |
| POST   | `/api/auth/login`                            | —       | `{email, password}` → `200 {id, email, name, role, access_token}` |
| GET    | `/api/articles`                              | —       | `200` all articles, without content                         |
| GET    | `/api/articles_home`                         | —       | `200` articles with `in_home: true`, without content        |
| GET    | `/api/articles/{url}`                        | —       | `200` full article, or `404`                                |
| POST   | `/api/articles`                              | Admin   | `{title, url, content?, tags?, in_home?}` → `201`, `409` if the url exists |
| PUT    | `/api/articles`                              | Admin   | same body plus `id` → `200`, or `404`                       |
| DELETE | `/api/articles/{id}`                         | Admin   | `204` (its comments go with it), or `404`                   |
| PUT    | `/api/articles/updateHomeView/{id}`          | Admin   | flips `in_home` → `200` article                             |
| GET    | `/api/articles/comments/{article_id}`        | —       | `200` comments, oldest first                                |
| POST   | `/api/articles/comments`                     | —       | `{article_id, author, email, content}` → `201`, `404` for an unknown article |
| DELETE | `/api/articles/comments/{article_id}/{id}`   | Admin   | `204`, or `404`                                             |
| GET    | `/api/users`                                 | Admin   | `200` all users                                             |
| GET    | `/api/users/{id}`                            | Admin   | `200` user, or `404`                                        |
| POST   | `/api/users`                                 | Admin   | `{email, name, password, role?}` → `201`                    |
| PUT    | `/api/users`                                 | Admin   | `{id, email, name, role}` → `200`                           |
| DELETE | `/api/users/{id}`                            | Admin   | `204`, or `404`                                             |
| PUT    | `/api/users/changePassword`                  | any     | `{id, current_password?, new_password}` → `204`             |

- **Auth** — login returns an HS256 JWT signed with `AUTH_SECRET` (`sub` = user id,
  `role`, 24 h expiry); send it as `Authorization: Bearer <token>`. Verification pins
  HS256 and requires `exp`. `with_auth(env, Role::Admin)` in `src/auth/middleware.rs`
  is the warp filter that answers `401` without a valid token and `403` when the role
  is not enough.
- **Passwords** — argon2id (RustCrypto `argon2`), hashed on tokio's blocking pool.
  Users change their own password with `current_password`; admins can reset anyone's.
- **Roles** — registration always creates a `User`. Promote the first admin in the
  database, then log in again (the role travels inside the JWT):

      docker compose exec db mongosh demo --eval \
        'db.users.updateOne({email: "admin@test.com"}, {$set: {role: "Admin"}})'

- **Comments** live inside their article document (`$push` / `$pull`). They are
  public to read and write; the commenter's email is stored but never returned.
- **Ids** are MongoDB ObjectIds, serialized as hex strings.
- **Errors** are always JSON: `{"error": "message"}`, including warp's own
  rejections (bad JSON `400`, wrong content-type `415`, wrong method `405`).

Try it:

    curl -X POST localhost:8080/api/auth/register -H 'content-type: application/json' \
      -d '{"email":"admin@test.com","name":"Admin","password":"supersecret"}'
    # promote it with the mongosh command above, then:
    TOKEN=$(curl -s localhost:8080/api/auth/login -H 'content-type: application/json' \
      -d '{"email":"admin@test.com","password":"supersecret"}' | jq -r .access_token)
    curl -X POST localhost:8080/api/articles -H "Authorization: Bearer $TOKEN" \
      -H 'content-type: application/json' -d '{"title":"Hello","url":"hello","content":"First post"}'
    curl localhost:8080/api/articles/hello

## Layout

    src/main.rs          route tree, request log, graceful shutdown
    src/environment.rs   config, MongoDB collections, unique indexes, shared filters
    src/error.rs         ApiError and the rejection → {"error": ...} mapping
    src/auth/            JWT + argon2 (mod.rs), with_auth filter, register/login
    src/users/           routes → handlers → service (MongoDB queries)
    src/articles/        routes → handlers → service, embedded comments included

## Deploy

Make this folder the root of your own repo (`cp -r devai_boilerplates/rust-crud-nosql-api my-app`,
then `git init` inside it), push it to GitHub, and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh. Set a long random
`AUTH_SECRET` on the server; the one in `compose.yaml` is for local use only.

---
Part of [devai.io](https://devai.io) — Rust API boilerplates. Same API on Postgres:
[`rust-crud-sql-api`](https://github.com/devai-io/devai_boilerplates/tree/main/rust-crud-sql-api); actix-web take:
[`rust-crud-actix-mongo-api`](https://github.com/devai-io/devai_boilerplates/tree/main/rust-crud-actix-mongo-api).
