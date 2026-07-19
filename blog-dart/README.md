# blog-dart

Minimal blog client written in plain Dart for the web — no Flutter. A hand-rolled
SPA with hash routing built on `package:web` and `dart:js_interop`, compiled with
`dart compile js` or served with `webdev`. Works against any of the devai.io blog
backends (they all implement the same API contract).

Styling uses the Tailwind Play CDN (a `<script>` tag in `web/index.html`). That is a
deliberate trade-off to keep this template free of any Node toolchain; for a
production site you would switch to a compiled Tailwind build or plain CSS.

## Requirements

- Dart SDK 3.6+
- A blog backend running (default: `http://localhost:8080`)

## Quickstart

```sh
dart pub get
dart pub global activate webdev
webdev serve            # http://localhost:8080 is the default API; app on :8081 if 8080 is taken
```

`webdev serve` runs the dev compiler with hot refresh. If your API also listens on
8080, pick another port for the app: `webdev serve web:8082`.

## Production build

Either:

```sh
webdev build            # outputs build/ (dart2js -O2, see build.yaml)
```

or compile directly, which is also how you point the app at a different API:

```sh
dart compile js web/main.dart -o build/main.dart.js -DAPI_URL=https://api.example.com
cp web/index.html build/
```

The API base URL is a compile-time constant (`String.fromEnvironment('API_URL')`,
default `http://localhost:8080`). For `webdev build`, add the `-DAPI_URL=...` define
to `dart2js_args` in `build.yaml`.

Deploy `build/` behind any static file server. Hash routing means no server-side
fallback configuration is needed.

## Project layout

```
web/
  index.html   shell page, Tailwind CDN, loads main.dart.js
  main.dart    everything: API client, hash router, views, markdown renderer
build.yaml     dart2js flags for webdev build
```

`main.dart` is intentionally a single file (~450 lines): config and auth state, a
typed fetch wrapper, `Post`/`PostSummary` models, DOM helpers, a dependency-free
markdown-to-DOM renderer, and four views (list, detail, login, editor with publish
toggle) dispatched from the `#/` hash route.

## How auth works

`POST /auth/login` returns a JWT. It is kept in memory and mirrored to
`localStorage` (key `blog_token`) so a reload stays signed in; every request adds
`Authorization: Bearer <token>` when present. Log out clears both.

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
