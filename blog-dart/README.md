# blog-dart

The blog client as a hand-rolled Dart web SPA — no Flutter, no framework, no CSS
library: `package:web` for the DOM, a hash router, one stylesheet, and `dart compile js`.
Post list, post page with rendered markdown, login, and an editor with a publish
toggle. It works against any backend of the devai.io blog engine series.

## Run

Get it: `git clone https://github.com/devai-io/devai_boilerplates.git`, then `cd devai_boilerplates/blog-dart`

    docker compose up --build

Open http://localhost:8081. The app expects a blog API on http://localhost:8080 —
start one of the backend siblings first (e.g. `docker compose up --build` in
`blog-go-postgres`), then create a user, since there is no sign-up page:

    curl -X POST localhost:8080/auth/register -H 'Content-Type: application/json' \
      -d '{"email":"me@example.com","password":"secret123"}'

Without Docker (Dart 3.13), check and compile:

    dart pub get
    dart analyze
    dart compile js -O2 -o build/main.dart.js web/main.dart

## How it works

The browser only ever talks to one origin. The app calls `/api/...` and nginx
forwards `/api/*` to `API_URL` — so the API needs no CORS setup.

- `API_URL` (runtime, default `http://host.docker.internal:8080`, no trailing
  slash) — where nginx sends `/api/*`. Set it in `.env` or the environment; no
  rebuild needed. On Linux, a host firewall (firewalld, NixOS) may block
  containers from reaching the host — allow the Docker bridges, or point
  `API_URL` at the API directly.
- `API_URL` as a compile-time define (default `/api`) — the base URL baked into
  `main.dart.js`: `dart compile js -DAPI_URL=https://api.example.com ...`. Use a
  full URL only if the app should call an API directly; that API must then send
  CORS headers.

Everything lives in `web/main.dart` (~480 lines): a typed `fetch` wrapper, the
`Post`/`PostSummary` models, a small DOM helper, the markdown renderer and four
views dispatched from the hash route (`#/`, `#/posts/<slug>`, `#/login`,
`#/write`, `#/edit/<slug>`) — hash routes need no server-side fallback.

Auth: `POST /auth/login` returns a JWT. It is kept in memory, mirrored to
`localStorage` (`blog_token`) so a reload stays signed in, and sent as
`Authorization: Bearer <token>`. Log out clears both.

Markdown becomes DOM nodes whose text is set with `textContent` — nothing is
parsed as HTML — and only `http(s):`, `mailto:` and relative links become anchors,
so a post body cannot inject markup.

The API never returns unpublished posts, so the editor keeps a freshly saved draft
open; tick Published and save again to make it public.

API calls used:

    POST   /auth/login          {email, password} -> {token}
    GET    /posts               -> [{id, title, slug, excerpt, published_at}]
    GET    /posts/{slug}        -> full post
    POST   /posts        (auth) {title, body} -> post (unpublished)
    PUT    /posts/{id}   (auth) {title?, body?, published?} -> post
    DELETE /posts/{id}   (auth) -> 204

## Layout

    web/index.html          shell page: loads styles.css and main.dart.js
    web/main.dart           API client, markdown renderer, views, hash router
    web/styles.css          plain CSS, light and dark via prefers-color-scheme
    nginx.conf.template     /api proxy; API_URL filled in at start-up

## Deploy

Make this folder the root of your own repo (`cp -r devai_boilerplates/blog-dart my-app`,
then `git init` inside it), push it to GitHub, and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh. Set `API_URL` in
`/srv/blog-dart/.env` on the server to reach your API.

---
Part of [devai.io](https://devai.io) — the blog frontend series, one API and four
clients: [`blog-react`](https://github.com/devai-io/devai_boilerplates/tree/main/blog-react),
[`blog-angular`](https://github.com/devai-io/devai_boilerplates/tree/main/blog-angular), `blog-dart`,
[`blog-flutter`](https://github.com/devai-io/devai_boilerplates/tree/main/blog-flutter).
