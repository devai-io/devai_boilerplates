# devai_boilerplates — the standard

Internal guidelines. Read fully before creating or editing any project here.
Every folder is packaged verbatim into a downloadable zip and a browsable code
preview on devai.io — the tree you write IS the product.

## The idea

**Less is more.** Each project is the smallest *complete* thing: it runs, it
ships, and there is nothing in it you would delete on day one. Code should be
so simple it barely needs comments.

**Each piece hints at a bigger project.** Every project uses the same service
names, the same ports, the same env names, the same file layout, and the same
CI/CD pipeline. Any single folder reads like one microservice cut from a
larger fleet — learn one, and you already know your way around all of them.

## Every project ships

```
README.md                   fixed skeleton (below)
compose.yaml                `docker compose up --build` runs the whole thing
Dockerfile                  multi-stage where there is a build step
.env.example                only if the app reads config; one commented line per var
.gitignore                  always; includes data/ and .env where relevant
.github/workflows/ci.yml    the CI/CD example: test → publish → deploy
```

Exceptions (the only ones):

- `nixos-*` — flakes, not containers. No Dockerfile/compose; CI runs `nix flake check`.
- `blog-flutter` — a device app. No Dockerfile/compose; CI runs `flutter analyze`.

Never include: lockfiles, vendored deps, build artifacts, binaries, TODOs,
placeholder bodies, admin UIs (no Adminer, no mongo-express), or claims in a
README that aren't true of the tree it sits in.

## Comments

Write code so simple it doesn't need comments. Beginner tutorials
(`level: "beginner"` on the site) may annotate the ONE concept they teach —
never the syntax around it. Everything else: a single line only where a
decision isn't obvious from the code. No file headers, no section banners.

## compose.yaml

- Named `compose.yaml`. Never `docker-compose.yml`, never a `version:` key.
- Services are named `app`, `db`, `cache` — nothing else, in that order.
- `app`: `build: .`, published on **8080** (`"8080:8080"`, or `"8080:80"` for
  nginx-served static builds). Dev env values inline, matching `.env.example`.
  A frontend that pairs with an API from the same series publishes **8081**
  instead, so both halves run side by side.
- `db` / `cache`: pinned image, **bind-mounted state under `./data/`**,
  healthcheck, no published ports (use `docker compose exec` to inspect).
  Compose creates `./data/*` on first run; `.gitignore` keeps it out of git.

| Service  | Image              | State bind mount                        |
|----------|--------------------|-----------------------------------------|
| postgres | `postgres:16-alpine` | `./data/postgres:/var/lib/postgresql/data` |
| mongo    | `mongo:7`          | `./data/mongo:/data/db`                 |
| redis    | `redis:7-alpine`   | `./data/redis:/data`                    |

Canonical shape (Postgres flavor):

```yaml
services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      PORT: "8080"
      DATABASE_URL: postgres://blog:blog@db:5432/blog?sslmode=disable
      AUTH_SECRET: change-me-in-production
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: blog
      POSTGRES_PASSWORD: blog
      POSTGRES_DB: blog
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U blog -d blog"]
      interval: 5s
      timeout: 3s
      retries: 10
```

Static site flavor is three lines of substance:

```yaml
services:
  app:
    build: .
    ports:
      - "8080:80"
```

## Env names

`PORT` · `DATABASE_URL` (postgres) · `MONGO_URL` + `MONGO_DB` · `REDIS_URL` ·
`AUTH_SECRET`. Nothing project-invented when one of these fits.

## CI/CD — `.github/workflows/ci.yml`

Each workflow is written for the project folder as the root of the user's own
repo (that is how downloads are used). Three jobs, no third-party actions —
plain `docker` and `ssh` commands people can read and steal:

- **test** — `docker compose up -d --build`, curl the app until healthy
  (`/health` if the app has it, `/` otherwise), dump logs on failure. The
  compose stack itself is the smoke test; do not invent a fake test suite.
- **publish** — on `main`: `docker login ghcr.io` with `GITHUB_TOKEN`, build,
  push `ghcr.io/<owner>/<repo>:latest`.
- **deploy** — on `main`, only when the repo variable `DEPLOY_HOST` is set
  (skipped, not red, until then): ssh to the server, `git pull`,
  `docker compose up -d --build` in `/srv/<project>`.

Canonical file — copy it verbatim, change only the project name in the deploy
path and the curl path:

```yaml
name: ci

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: docker compose up -d --build
      - run: |
          timeout 60 sh -c 'until curl -fs localhost:8080/health; do sleep 2; done' \
            || { docker compose logs; exit 1; }
      - run: docker compose down

  publish:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      packages: write
    steps:
      - uses: actions/checkout@v4
      - run: echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u "${{ github.actor }}" --password-stdin
      - run: docker build -t "ghcr.io/${{ github.repository }}:latest" .
      - run: docker push "ghcr.io/${{ github.repository }}:latest"

  deploy:
    needs: publish
    if: github.ref == 'refs/heads/main' && vars.DEPLOY_HOST != ''
    runs-on: ubuntu-latest
    steps:
      - run: |
          install -m 600 /dev/null key && echo "${{ secrets.DEPLOY_KEY }}" > key
          ssh -i key -o StrictHostKeyChecking=accept-new \
            "${{ vars.DEPLOY_USER }}@${{ vars.DEPLOY_HOST }}" \
            "cd /srv/blog-go-postgres && git pull && docker compose up -d --build"
```

Deploy configuration lives in the user's repo settings: variables
`DEPLOY_HOST`, `DEPLOY_USER`; secret `DEPLOY_KEY` (an ssh private key). The
server needs Docker and a one-time `git clone` into `/srv/<project>`.

## README.md skeleton

Fixed section order; keep every section short. Sections that don't apply are
omitted, never left empty.

```markdown
# <project-name>

<One or two sentences: what it is and what it teaches or provides.>

## Run

    docker compose up --build

<One line: what you see and where — usually http://localhost:8080.>

<Optional: running without Docker, in a few lines.>

Beginner static tutorials invert this: their zero-install line ("open
index.html") stays first — that gentleness is the product — and compose
follows as "or serve it like production".

## How it works            ← the one concept, or the API table for backends

## Layout                  ← file → one-line purpose, only non-obvious files

## Deploy

Push to your own GitHub repo and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — <series line, linking siblings where a series exists>.
```

## .gitignore

Base for every project: `data/`, `.env`, `.DS_Store`. Add only what the stack
generates: `node_modules/`, `dist/`, `target/`, `zig-out/`, `zig-cache/`,
`__pycache__/`, `.dart_tool/`.

## Blog engine series contract

One schema, one API, eight backends (`blog-{go,rust,zig,python}-{postgres,mongo}`).
All implement exactly:

```
GET    /health              -> 200 "ok"
POST   /auth/register       {email, password} -> 201 {id, email}
POST   /auth/login          {email, password} -> 200 {token}
GET    /posts               -> 200 [published: {id,title,slug,excerpt,published_at}]
GET    /posts/{slug}        -> 200 full post | 404
POST   /posts        (auth) -> 201 create {title, body}
PUT    /posts/{id}   (auth) -> 200 update {title?, body?, published?}
DELETE /posts/{id}   (auth) -> 204
```

- `posts`: id, title, slug (unique, from title), body (markdown), published
  (default false), author_id, created_at, updated_at. `users`: id, email
  (unique), password_hash, created_at. `excerpt` = first 200 chars, server-side.
- JWT HS256 signed with `AUTH_SECRET`, `sub` = user id, 7d expiry, sent as
  `Authorization: Bearer`. Passwords: bcrypt or argon2. Errors:
  `{"error": "message"}` with correct status codes.
- SQL backends ship `schema.sql`, applied on startup; Mongo backends ensure
  indexes on startup.
- Each backend keeps local auth swappable and ships `extras/auth-clerk/` and
  `extras/auth-auth0/`: one drop-in JWKS verifier file + README each.

Stacks: **Go** stdlib `net/http` + `pgx/v5` / `mongo-driver`, bcrypt,
`golang-jwt/v5`. **Rust** axum + tokio, `sqlx` (runtime queries) / `mongodb`,
argon2, `jsonwebtoken`. **Zig** `std.http.Server`, `pg.zig` / libmongoc via
`@cImport`, `std.crypto` argon2 + hand-rolled HS256. **Python** FastAPI +
`asyncpg` / `motor`, `argon2-cffi`, `pyjwt`, uv-friendly `pyproject.toml`.

Frontends (`blog-react`, `blog-angular`, `blog-dart`, `blog-flutter`) consume
this contract; base URL from env (`VITE_API_URL` / `NG_APP_API_URL` /
`--dart-define=API_URL`). Views: post list, post detail (minimal markdown),
login, authoring form with publish toggle.

## Quality bar

- `docker compose config -q` passes for every compose.yaml.
- If the toolchain exists locally, run the cheapest native check
  (`go vet`, `cargo check`, `zig ast-check`, `python -m py_compile`,
  `tsc --noEmit`) and fix what it finds. Otherwise review twice.
- Prefer actually running `docker compose up` and curling the app before
  committing a new or restructured project.

## Adding a new project — checklist

1. Pick a kebab-case folder name that says what it is.
2. Write the smallest complete implementation; follow every section above.
3. `docker compose up --build` + curl it. Fix until boring.
4. Add the project to the table in this repo's `README.md`.
5. Register it on the site: one entry in `src/data/templates.ts` of
   `devai_io` (`codeDir` = the folder name), then push both repos —
   the site's CI clones this repo at build time.
