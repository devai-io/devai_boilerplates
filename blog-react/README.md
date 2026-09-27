# blog-react

A small blog client in React 19, Vite 8, TypeScript and Tailwind CSS v4 — post list,
post page with rendered markdown, login, and an editor with a publish toggle. No
component library, no state framework. It works against any backend of the devai.io
blog engine series (they all implement the same API).

## Run

Get it: `git clone https://git.devai.io/templates/blog-react.git`

    docker compose up --build

Open http://localhost:8081. The app expects a blog API on http://localhost:8080 —
start one of the backend siblings first (e.g. `docker compose up --build` in
`blog-go-postgres`), then create a user, since there is no sign-up page:

    curl -X POST localhost:8080/auth/register -H 'Content-Type: application/json' \
      -d '{"email":"me@example.com","password":"secret123"}'

Hot-reload dev server (Node 24), same API on :8080:

    npm ci
    npm run dev        # http://localhost:5173

## How it works

The browser only ever talks to one origin. The SPA calls `/api/...`; in the
container nginx forwards `/api/*` to `API_URL`, and `npm run dev` does the same
through Vite's proxy — so the API needs no CORS setup.

- `API_URL` (runtime, default `http://host.docker.internal:8080`, no trailing
  slash) — where nginx sends `/api/*`. Set it in `.env` or the environment; no
  rebuild needed. On Linux, a host firewall (firewalld, NixOS) may block
  containers from reaching the host — allow the Docker bridges, or point
  `API_URL` at the API directly.
- `VITE_API_URL` (build time, default `/api`) — the base URL compiled into the
  bundle. Set it to a full URL only if the SPA should call an API directly, and
  that API must then send CORS headers.

Auth: `POST /auth/login` returns a JWT. The client keeps it in memory, mirrors it
to `localStorage` (`blog_token`) so a reload stays signed in, and sends
`Authorization: Bearer <token>` on every request. Log out clears both.

Markdown is rendered by a ~100-line parser in `src/markdown.tsx` that builds React
elements — never an HTML string — and only turns `http(s):`, `mailto:` and relative
links into anchors, so a post body cannot inject script.

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

    src/api.ts              typed fetch client + token handling
    src/markdown.tsx        dependency-free, injection-safe markdown → React
    src/App.tsx             layout + routes (/, /posts/:slug, /login, /write, /edit/:slug)
    src/pages/              PostList, PostDetail, Login, Editor
    vite.config.ts          React + Tailwind plugins, dev proxy /api → :8080
    nginx.conf.template     SPA fallback + /api proxy; API_URL filled in at start-up

## Deploy

Push to your own GitHub repo and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh. Set `API_URL` in
`/srv/blog-react/.env` on the server to reach your API.

---
Part of [devai.io](https://devai.io) — the blog frontend series, one API and four
clients: `blog-react`, [`blog-angular`](https://git.devai.io/templates/blog-angular),
[`blog-dart`](https://git.devai.io/templates/blog-dart),
[`blog-flutter`](https://git.devai.io/templates/blog-flutter).
