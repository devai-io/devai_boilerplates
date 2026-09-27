# blog-react

Minimal blog client built with Vite, React 19, TypeScript, and Tailwind CSS.
Dark-first, no component library, no state-management framework. Works against any
of the devai.io blog backends (they all implement the same API contract).

## Requirements

- Node.js 20+ (or just Docker)
- A blog backend running (default: `http://localhost:8080`)

## Run

    docker compose up --build

The app is served at http://localhost:8081 — it expects a blog engine on
http://localhost:8080, so start one of the backend siblings first (e.g.
`docker compose up` in `blog-go-postgres/`).

`VITE_API_URL` is compiled into the bundle at build time; the compose build keeps
the default `http://localhost:8080`. Point the image at another API by rebuilding:

```sh
docker build --build-arg VITE_API_URL=https://api.example.com -t blog-react .
```

The image serves the built SPA from nginx with `try_files` fallback so deep links work.

Dev mode with hot reload:

```sh
cp .env.example .env      # set VITE_API_URL if your API is elsewhere
npm install
npm run dev
```

Production build: `npm run build` → static files in `dist/`.

## Project layout

```
src/
  api.ts            typed API client (fetch, JWT handling)
  markdown.tsx      dependency-free markdown → React renderer
  App.tsx           layout + routes
  pages/
    PostList.tsx    published posts
    PostDetail.tsx  full post, rendered markdown, edit/delete when authed
    Login.tsx       email + password → JWT
    Editor.tsx      create/edit with publish toggle
```

## How auth works

`POST /auth/login` returns a JWT. The client keeps it in memory and mirrors it to
`localStorage` (key `blog_token`) so a reload stays signed in. Every request adds
`Authorization: Bearer <token>` when a token is present. Log out clears both.

There is no registration UI; create a user against the API directly:

```sh
curl -X POST $API/auth/register -H 'Content-Type: application/json' \
  -d '{"email":"me@example.com","password":"secret"}'
```

(`register()` exists in `src/api.ts` if you want to wire up a page.)

## API contract consumed

```
POST /auth/login          {email, password} -> {token}
GET  /posts               -> [{id,title,slug,excerpt,published_at}]
GET  /posts/{slug}        -> full post
POST /posts        (auth) -> create {title, body}
PUT  /posts/{id}   (auth) -> update {title?, body?, published?}
DELETE /posts/{id} (auth) -> 204
```

## Deploy

Push this folder to your own GitHub repo and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` repo variables and
the `DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — the blog frontend series: the same API,
four takes. Siblings: `blog-{react,angular,dart,flutter}`.
