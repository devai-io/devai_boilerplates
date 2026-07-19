# blog-angular

Minimal blog client built with Angular 19 standalone components, signals, and
Tailwind CSS. Dark-first, no component library. Works against any of the devai.io
blog backends (they all implement the same API contract).

## Requirements

- Node.js 20+
- A blog backend running (default: `http://localhost:8080`)

## Quickstart

```sh
npm install
npm start          # ng serve → http://localhost:4200
```

Production build: `npm run build` → static files in `dist/blog-angular/browser/`.

## Configuring the API base URL

`NG_APP_API_URL` is a compile-time constant injected through the `define` option in
`angular.json` (default `http://localhost:8080`). Override it at build time:

```sh
ng build --define "NG_APP_API_URL='https://api.example.com'"
```

Docker does the same via a build arg:

```sh
docker build --build-arg NG_APP_API_URL=https://api.example.com -t blog-angular .
docker run -p 3000:80 blog-angular
```

The image serves the built SPA from nginx with `try_files` fallback so deep links work.

## Project layout

```
src/app/
  app.component.ts        layout shell (header, nav, outlet)
  app.config.ts           providers: router, HttpClient + auth interceptor
  app.routes.ts           routes for the four views
  auth.service.ts         login/logout, token signal + localStorage
  auth.interceptor.ts     attaches Authorization: Bearer <token>
  blog.service.ts         typed API calls
  markdown.ts             dependency-free markdown → HTML + pipe
  models.ts               Post/PostSummary types, error helper
  pages/
    post-list.component.ts    published posts
    post-detail.component.ts  full post, rendered markdown, edit/delete when authed
    login.component.ts        email + password → JWT
    editor.component.ts       create/edit with publish toggle
```

## How auth works

`AuthService.login()` posts to `/auth/login` and stores the returned JWT in a signal,
mirrored to `localStorage` (key `blog_token`) so a reload stays signed in. The
functional `authInterceptor` adds `Authorization: Bearer <token>` to every HttpClient
request while signed in. Log out clears both.

There is no registration UI; create a user against the API directly:

```sh
curl -X POST $API/auth/register -H 'Content-Type: application/json' \
  -d '{"email":"me@example.com","password":"secret"}'
```

## API contract consumed

```
POST /auth/login          {email, password} -> {token}
GET  /posts               -> [{id,title,slug,excerpt,published_at}]
GET  /posts/{slug}        -> full post
POST /posts        (auth) -> create {title, body}
PUT  /posts/{id}   (auth) -> update {title?, body?, published?}
DELETE /posts/{id} (auth) -> 204
```
