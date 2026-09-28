# blog-flutter

The blog client as a Flutter app — Material 3, a post list, a post screen with
rendered markdown, login, and an editor with a publish switch. Plain `setState`
plus one `ChangeNotifier` for auth — no state-management package, no code
generation. It works against any backend of the devai.io blog engine series.

## Run

Get it: `git clone https://github.com/devai-io/devai_boilerplates.git`, then `cd devai_boilerplates/blog-flutter`

Only `lib/`, `pubspec.yaml`, `pubspec.lock` and `analysis_options.yaml` ship here —
no platform shells. Generate the ones you want once, then run (Flutter 3.47):

    flutter create --empty --platforms=android,ios,web .
    flutter run --dart-define=API_URL=http://localhost:8080

`--empty` keeps `flutter create` from adding a sample test that refers to its own
demo app. Start a backend sibling first (e.g. `docker compose up --build` in
`blog-go-postgres`), then create a user, since there is no sign-up screen:

    curl -X POST localhost:8080/auth/register -H 'Content-Type: application/json' \
      -d '{"email":"me@example.com","password":"secret123"}'

## How it works

The API base URL is a compile-time constant, `String.fromEnvironment('API_URL')`,
defaulting to `http://localhost:8080`; pass `--dart-define=API_URL=...` to
`flutter run` or `flutter build`. On the Android emulator use
`http://10.0.2.2:8080` to reach a backend on your machine. Mobile and desktop
builds call the API directly; a web build is subject to CORS, which the series
backends do not send, so serve it behind a proxy on the API's origin instead.

`ApiClient` (a `ChangeNotifier`) keeps the JWT from `POST /auth/login` in memory
and sends `Authorization: Bearer <token>`; the app bar swaps between Log in and
Write / Log out as it changes. The token is not persisted — add
`shared_preferences` to `ApiClient` if sessions should survive a restart.

Markdown is turned into Flutter widgets (`Text.rich` spans), never HTML; links are
styled but not tappable.

The API never returns unpublished posts, so the editor keeps a freshly saved draft
open; switch on Published and save again to make it public.

API calls used:

    POST   /auth/login          {email, password} -> {token}
    GET    /posts               -> [{id, title, slug, excerpt, published_at}]
    GET    /posts/{slug}        -> full post
    POST   /posts        (auth) {title, body} -> post (unpublished)
    PUT    /posts/{id}   (auth) {title?, body?, published?} -> post
    DELETE /posts/{id}   (auth) -> 204

## Layout

    lib/main.dart                  app shell, Material 3 light and dark themes
    lib/api.dart                   ApiClient: auth state + typed API calls
    lib/markdown.dart              dependency-free markdown → widgets
    lib/screens/posts_screen.dart  published posts, pull to refresh
    lib/screens/post_screen.dart   full post; edit/delete when signed in
    lib/screens/login_screen.dart  email + password → JWT
    lib/screens/editor_screen.dart create/edit with publish switch

## Deploy

A device app ships through the app stores (`flutter build appbundle`,
`flutter build ipa`), not to a server, so there is no Dockerfile or compose file.
Make this folder the root of your own repo (`cp -r devai_boilerplates/blog-flutter my-app`,
then `git init` inside it), push it to GitHub, and the shipped workflow (`.github/workflows/ci.yml`)
clones Flutter 3.47.4 from the official repository and runs
`flutter pub get --enforce-lockfile` and `flutter analyze`.

---
Part of [devai.io](https://devai.io) — the blog frontend series, one API and four
clients: [`blog-react`](https://github.com/devai-io/devai_boilerplates/tree/main/blog-react),
[`blog-angular`](https://github.com/devai-io/devai_boilerplates/tree/main/blog-angular),
[`blog-dart`](https://github.com/devai-io/devai_boilerplates/tree/main/blog-dart), `blog-flutter`.
