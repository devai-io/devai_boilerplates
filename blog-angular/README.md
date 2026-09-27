# blog-angular

The blog client in modern Angular 22 — standalone components, signals, the built-in
control flow (`@if`, `@for`), zoneless change detection and Tailwind CSS v4. Post
list, post page with rendered markdown, login, and an editor with a publish toggle.
It works against any backend of the devai.io blog engine series.

## Run

Get it: `git clone https://git.devai.io/templates/blog-angular.git`

    docker compose up --build

Open http://localhost:8081. The app expects a blog API on http://localhost:8080 —
start one of the backend siblings first (e.g. `docker compose up --build` in
`blog-go-postgres`), then create a user, since there is no sign-up page:

    curl -X POST localhost:8080/auth/register -H 'Content-Type: application/json' \
      -d '{"email":"me@example.com","password":"secret123"}'

Dev server with live reload (Node 24), same API on :8080:

    npm ci
    npm start          # ng serve → http://localhost:4200

## How it works

The browser only ever talks to one origin. The app calls `/api/...`; in the
container nginx forwards `/api/*` to `API_URL`, and `ng serve` does the same
through `proxy.conf.json` — so the API needs no CORS setup.

- `API_URL` (runtime, default `http://host.docker.internal:8080`, no trailing
  slash) — where nginx sends `/api/*`. Set it in `.env` or the environment; no
  rebuild needed. On Linux, a host firewall (firewalld, NixOS) may block
  containers from reaching the host — allow the Docker bridges, or point
  `API_URL` at the API directly.
- `NG_APP_API_URL` (build time, default `/api`) — a compile-time constant set by
  the `define` option in `angular.json`. To call an API directly (it must then
  send CORS headers): `npx ng build --define "NG_APP_API_URL='https://api.example.com'"`.

Auth: `Auth.login()` posts to `/auth/login` and keeps the JWT in a signal,
mirrored to `localStorage` (`blog_token`) so a reload stays signed in. The
functional `authInterceptor` adds `Authorization: Bearer <token>` to every
request. Log out clears both.

Markdown: `markdown.ts` parses a post into blocks and spans, and the `Markdown`
component renders them with ordinary template interpolation — there is no
`[innerHTML]` anywhere — and only `http(s):`, `mailto:` and relative links become
anchors, so a post body cannot inject markup.

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

    src/app/app.ts              shell: header, nav, <router-outlet>
    src/app/app.config.ts       router (route params bound to inputs), HttpClient + interceptor
    src/app/app.routes.ts       /, /posts/:slug, /login, /write, /edit/:slug
    src/app/auth.ts             token signal + login/logout
    src/app/blog-api.ts         typed API calls
    src/app/markdown.ts         markdown → blocks → template, no innerHTML
    src/app/pages/              post-list, post-detail, login, editor
    proxy.conf.json             ng serve: /api → localhost:8080
    nginx.conf.template         SPA fallback + /api proxy; API_URL filled in at start-up

## Deploy

Push to your own GitHub repo and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh. Set `API_URL` in
`/srv/blog-angular/.env` on the server to reach your API.

---
Part of [devai.io](https://devai.io) — the blog frontend series, one API and four
clients: [`blog-react`](https://git.devai.io/templates/blog-react), `blog-angular`,
[`blog-dart`](https://git.devai.io/templates/blog-dart),
[`blog-flutter`](https://git.devai.io/templates/blog-flutter).
