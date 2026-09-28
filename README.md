# devai_boilerplates

Every boilerplate and tutorial behind **[devai.io](https://devai.io)** — real, runnable code.

Each folder is a complete, self-contained project with its own `README.md`. This repo is
the public home of all of them — clone it once and run any folder:

```sh
git clone https://github.com/devai-io/devai_boilerplates.git
cd devai_boilerplates/tip-calculator
docker compose up --build
```

Want one as your own project? Copy its folder out and make it a repo root — every
folder ships its own CI/CD workflow that runs from there.

Browse them with previews and one-click zips at **[devai.io/templates](https://devai.io/templates)**.

Every project follows the same standard — [`GUIDELINES.md`](./GUIDELINES.md):
`docker compose up --build` runs it, service state lives in bind-mounted
`./data/` folders, and a shipped GitHub Actions workflow tests, publishes and
deploys it the moment a folder becomes your own repo. Learn one project and
you know your way around all of them.


## Web Basics

Beginner tutorials — HTML, CSS & JavaScript, one concept at a time.

| Project | What it is |
|---|---|
| [`tip-calculator`](./tip-calculator) | Your first interactive page: type a bill, see the tip update live. |
| [`todo-list`](./todo-list) | Keep a list, tick things off, and have it still be there after a refresh. |
| [`countdown-timer`](./countdown-timer) | Count down to any moment — days, hours, minutes, seconds, ticking live. |
| [`dark-mode-toggle`](./dark-mode-toggle) | A theme switch that remembers your choice — the feature every site wants. |
| [`image-slideshow`](./image-slideshow) | Prev, next, dots and auto-play — stepping through a list with an index. |
| [`form-validation`](./form-validation) | Catch mistakes before they submit, with helpful inline messages. |
| [`faq-accordion`](./faq-accordion) | Click a question, reveal its answer — show and hide, done accessibly. |
| [`stopwatch`](./stopwatch) | Start, stop, lap — accurate timing that doesn't drift. |
| [`color-picker`](./color-picker) | Pick a color, get its codes and shades, copy any of them with a click. |
| [`modal-dialog`](./modal-dialog) | A pop-up done the modern way — with the built-in <dialog> element. |
| [`star-rating`](./star-rating) | Hover to preview, click to choose — a real interactive widget. |
| [`char-counter`](./char-counter) | A tweet-style box that counts down and warns you before you run out. |

## APIs & Data

Beginner tutorials — fetch real data from the internet.

| Project | What it is |
|---|---|
| [`weather-now`](./weather-now) | Type a city, get the live weather — your first two-step API call. |
| [`github-profile`](./github-profile) | Type a username, get their profile — your first taste of an API. |
| [`random-quote`](./random-quote) | Load quotes from a data file and show a new one on demand. |
| [`currency-converter`](./currency-converter) | Convert between currencies at the latest real exchange rates. |
| [`crypto-ticker`](./crypto-ticker) | Live coin prices that refresh themselves every 30 seconds. |
| [`dictionary-lookup`](./dictionary-lookup) | Look up any word and read its definitions — nested JSON, unpacked. |
| [`country-explorer`](./country-explorer) | Search a country, see its flag, capital, population and languages. |
| [`ip-lookup`](./ip-lookup) | See your own IP, city and network — the API reads your request. |
| [`nasa-photo-proxy`](./nasa-photo-proxy) | The same fetch idea — but now with a real backend hiding the API key. |

## Blog Engines

One API contract, eight backends — compare languages on identical ground.

| Project | What it is |
|---|---|
| [`blog-go-postgres`](./blog-go-postgres) | A refined, minimalist blog API in Go on Postgres — auth to publishing in four source files. |
| [`blog-go-mongo`](./blog-go-mongo) | The Go blog engine on MongoDB — same API, document storage, zero migrations. |
| [`blog-rust-postgres`](./blog-rust-postgres) | The blog engine in Rust — axum handlers, sqlx queries, argon2 hashing. |
| [`blog-rust-mongo`](./blog-rust-mongo) | Rust + MongoDB: the blog engine with documents instead of rows. |
| [`blog-zig-postgres`](./blog-zig-postgres) | The blog engine in Zig — std.http, pg.zig, and a hand-rolled HS256. |
| [`blog-zig-mongo`](./blog-zig-mongo) | Zig meets MongoDB through libmongoc — the systems-programming take on documents. |
| [`blog-python-postgres`](./blog-python-postgres) | FastAPI + asyncpg: the blog engine with the shortest path from zero to endpoint. |
| [`blog-python-mongo`](./blog-python-mongo) | FastAPI + PyMongo's async client: async documents end to end. |

## Blog Frontends

The same blog API, four frontend takes.

| Project | What it is |
|---|---|
| [`blog-react`](./blog-react) | A Tailwind-clean React client for the blog engine series — list, read, write, publish. |
| [`blog-angular`](./blog-angular) | The blog client in modern Angular — standalone components, signals, Tailwind. |
| [`blog-dart`](./blog-dart) | A hand-rolled Dart web SPA — no Flutter, no framework, just the platform. |
| [`blog-flutter`](./blog-flutter) | The blog client as a Flutter app — Material 3, three screens and an editor. |

## UI Starters

Minimal, styled starting points.

| Project | What it is |
|---|---|
| [`react-tailwind-starter`](./react-tailwind-starter) | The fastest sane path to a styled React app — three commands, no decisions. |
| [`react-shadcn-starter`](./react-shadcn-starter) | Tailwind plus a real component system — shadcn/ui set up the way it's meant to be. |

## API & Backend

Production-shaped API boilerplates.

| Project | What it is |
|---|---|
| [`rust-crud-sql-api`](./rust-crud-sql-api) | A JWT-secured REST API in Rust: Warp handlers, sqlx, Postgres, role-based routes. |
| [`rust-crud-nosql-api`](./rust-crud-nosql-api) | The same JWT-secured Rust API, backed by MongoDB instead of Postgres. |
| [`rust-crud-actix-mongo-api`](./rust-crud-actix-mongo-api) | Actix-web 4 + MongoDB with JWT from cookie or Bearer, and rotating refresh tokens. |

## Deploy & Infra

Build and ship pipelines.

| Project | What it is |
|---|---|
| [`rust-docker-pipeline`](./rust-docker-pipeline) | Build and ship Rust in Docker fast, with cargo-chef layer caching. |

## NixOS Desktops

Declarative desktop configurations.

| Project | What it is |
|---|---|
| [`nixos-hyprland`](./nixos-hyprland) | A declarative Hyprland desktop: flake, home-manager, waybar — rebuild and it's yours. |
| [`nixos-gnome`](./nixos-gnome) | GNOME on NixOS, declarative and de-cluttered — dconf and extensions in code. |
| [`nixos-plasma`](./nixos-plasma) | KDE Plasma 6 on NixOS — SDDM, Wayland, and a flake that stays out of your way. |

---

42 projects. MIT licensed — copy them, change them, make them your own.
