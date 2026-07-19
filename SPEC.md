# devai.io template series — shared spec

Read fully before authoring a template. Every template in this directory is packaged
verbatim into a downloadable zip and browsable code preview on devai.io — the tree you
write IS the product. Do not modify this file or any sibling template directory.

## Ground rules (all templates)

- **Refined and minimalist.** Small number of files, idiomatic code, no framework
  ceremony, no dead abstractions. Comments only where a decision needs explaining.
- Every template dir contains `README.md` (what it is, requirements, quickstart
  commands, project layout, how auth works, how to switch auth providers where
  applicable). Confident tone; do not claim CI coverage that doesn't exist.
- `.env.example` for anything configurable. Env names: `PORT`, `DATABASE_URL`
  (postgres), `MONGO_URL` + `MONGO_DB`, `AUTH_SECRET`.
- No lockfiles, no vendored deps, no node_modules, no build artifacts, no binaries.
  Text files only.
- Backends and web frontends include a multi-stage `Dockerfile`; backends also include
  `docker-compose.yml` (app + its database, healthchecked). NixOS templates have
  neither (they are flakes).
- License header not required; keep files clean.

## Blog engine API contract (all 8 backends implement exactly this)

Data model `posts`: id, title, slug (unique, derived from title), body (markdown),
published (bool, default false), author_id, created_at, updated_at.
Data model `users`: id, email (unique), password_hash, created_at.

```
GET    /health              -> 200 "ok"
POST   /auth/register       {email, password} -> 201 {id, email}
POST   /auth/login          {email, password} -> 200 {token}
GET    /posts               -> 200 [published posts: {id,title,slug,excerpt,published_at}]
GET    /posts/{slug}        -> 200 full post | 404
POST   /posts        (auth) -> 201 create {title, body}
PUT    /posts/{id}   (auth) -> 200 update {title?, body?, published?}
DELETE /posts/{id}   (auth) -> 204
```

- `excerpt` = first 200 chars of body, server-computed.
- Auth token: JWT HS256 signed with `AUTH_SECRET`, `sub` = user id, 7d expiry, sent as
  `Authorization: Bearer <token>`.
- Passwords hashed with the language's standard strong hash (bcrypt or argon2).
- JSON errors: `{"error": "message"}` with correct status codes.

## Auth variations (each backend ships all of these)

1. **Local (default, fully implemented):** users table/collection + password hashing +
   JWT issuance as above.
2. **External provider examples** under `extras/`:
   - `extras/auth-clerk/` — README + one drop-in middleware/verifier source file that
     validates a Clerk session JWT via JWKS and explains what to delete/replace.
   - `extras/auth-auth0/` — same shape for Auth0 (issuer/audience env, JWKS).
   Keep each to ~1 code file + README. They are working examples of the swap, not a
   second full implementation.

## Per-backend stack choices

- **Go:** stdlib `net/http` (1.22+ mux). Postgres: `pgx/v5`. Mongo: official
  `mongo-driver`. Hash: `golang.org/x/crypto/bcrypt`. JWT: `golang-jwt/jwt/v5`.
- **Rust:** `axum` + `tokio`. Postgres: `sqlx` (runtime queries, no macros needed).
  Mongo: `mongodb` crate. Hash: `argon2`. JWT: `jsonwebtoken`. Serde throughout.
- **Zig:** `std.http.Server`. Postgres: `pg.zig` (karlseguin). Mongo: wrap the MongoDB
  C driver (`libmongoc`) via `@cImport` — note the requirement in README. Hash:
  argon2 from `std.crypto.pwhash`. JWT: implement minimal HS256 sign/verify with
  `std.crypto` (small, self-contained).
- **Python:** FastAPI + uvicorn. Postgres: `asyncpg` (raw SQL, no ORM). Mongo:
  `motor`. Hash: `argon2-cffi`. JWT: `pyjwt`. `pyproject.toml` with deps (uv-friendly).

Schema setup: SQL backends ship `schema.sql` applied on startup if tables are missing
(or a tiny migrate step in main). Mongo backends create indexes on startup.

## Frontend blog clients (React / Angular / Dart / Flutter)

Consume the API contract above; base URL from env (`VITE_API_URL` /
`NG_APP_API_URL` / `--dart-define=API_URL` / `--dart-define=API_URL`). Pages: post
list, post detail (render markdown minimally), login, and a small authoring form
(create/edit, publish toggle). Store JWT in memory + localStorage; attach as Bearer.

- **React:** Vite + React 19 + TypeScript + Tailwind. No component library, no router
  beyond `react-router-dom` if needed.
- **Angular:** Angular 19+ standalone components + Tailwind, signals where natural.
- **Dart:** Dart web (no Flutter) using `package:web` + `dart:js_interop`-safe code,
  built with `dart compile js` or `webdev`; minimal hand-rolled SPA, Tailwind via CDN
  is acceptable here (note in README).
- **Flutter:** Material 3, three screens + editor; `http` package; no state-management
  framework (plain ChangeNotifier or setState). Include only `lib/`, `pubspec.yaml`,
  README (no android/ios shells — README notes `flutter create .` regenerates them).

Design: clean, minimal, dark-first aesthetic; Tailwind for React/Angular.

## Quality bar

If the toolchain exists on this machine (`go`, `cargo`, `zig`, `python3` do; flutter/
dart/ng do NOT), run the cheapest available check (`go vet`/`go build`,
`cargo check` if fast, `zig ast-check`, `python -m py_compile` / import check) and fix
what it finds. Where no toolchain exists, review your own code twice for correctness.
Never leave TODOs or placeholder bodies.
