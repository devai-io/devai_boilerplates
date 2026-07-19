# blog-flutter

Minimal blog client built with Flutter and Material 3. Plain `setState` plus one
`ChangeNotifier` for auth state — no state-management framework, no code generation.
Works against any of the devai.io blog backends (they all implement the same API
contract).

Only `lib/`, `pubspec.yaml`, and `analysis_options.yaml` ship in this template.
There are no platform shells — run `flutter create .` once inside the project and
Flutter regenerates `android/`, `ios/`, `web/`, and desktop scaffolding.

## Requirements

- Flutter SDK 3.27+ (Dart 3.6+)
- A blog backend running (default: `http://localhost:8080`)

## Quickstart

```sh
flutter create .        # regenerate platform shells (first run only)
flutter pub get
flutter run --dart-define=API_URL=http://localhost:8080
```

The API base URL is a compile-time constant read with
`String.fromEnvironment('API_URL')`; pass `--dart-define=API_URL=...` to `flutter run`
or `flutter build`. It defaults to `http://localhost:8080`. On the Android emulator
use `http://10.0.2.2:8080` to reach a backend on your host machine.

## Project layout

```
lib/
  main.dart                 app shell, Material 3 theme (dark-first)
  api.dart                  ApiClient (ChangeNotifier): auth + typed API calls
  markdown.dart             dependency-free markdown → widgets renderer
  screens/
    posts_screen.dart       published posts list (pull to refresh)
    post_screen.dart        full post, rendered markdown, edit/delete when authed
    login_screen.dart       email + password → JWT
    editor_screen.dart      create/edit with publish switch
```

## How auth works

`ApiClient.login()` posts to `/auth/login` and keeps the returned JWT in memory;
every request then sends `Authorization: Bearer <token>`. The client is a
`ChangeNotifier`, so the UI swaps between Log in / Write / Log out automatically.

The token is intentionally not persisted (the web clients in this series mirror it
to localStorage; Flutter has no direct equivalent). If you want sessions to survive
an app restart, add `shared_preferences` and load/save the token in `ApiClient`.

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
