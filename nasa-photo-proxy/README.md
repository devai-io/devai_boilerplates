# nasa-photo-proxy

NASA's Astronomy Picture of the Day, fetched through your own tiny Node server.
The same "fetch some data and show it" idea as the browser tutorials — but now
with a real backend, so you learn *why* apps have servers: to keep secrets like
API keys out of the browser.

## Run

Get it: `git clone https://git.devai.io/templates/nasa-photo-proxy.git`

With [Node.js](https://nodejs.org) 22 or newer — there are no npm packages to
install:

```sh
cp .env.example .env    # optional: paste your own NASA key
node server.js
```

Then open http://localhost:8080.

Or run it like production:

```sh
docker compose up --build
```

Same address. Compose reads `NASA_API_KEY` from `.env` too, and falls back to
NASA's shared `DEMO_KEY`.

## How it works

In the browser-only tutorials the page called the API directly. That's fine
for keyless APIs, but many APIs need a **secret key** — and anything in a web
page is visible to anyone who opens "View Source". So put a server in the
middle:

```
Browser  ──►  /api/apod (your server)  ──►  api.nasa.gov/planetary/apod?api_key=SECRET
         ◄──   title, date, image URL   ◄──
```

`server.js` has two jobs:

- **Serve the page.** Requests like `/`, `/styles.css` and `/app.js` read a
  file from `public/` — and anything that tries to climb out of it
  (`/../server.js`) is refused.
- **Be the proxy.** `/api/apod` calls NASA with `NASA_API_KEY` from the
  environment (or `.env`, loaded with Node's built-in `process.loadEnvFile()`),
  and sends back only the fields the page needs.

`public/app.js` fetches `/api/apod` — its *own* server — never `nasa.gov`, so
the key never reaches the browser. `DEMO_KEY` is shared by everyone and allows
only a few dozen requests an hour; when NASA says "too many", the page tells
you to get a free key at https://api.nasa.gov.

Try it: cache NASA's answer for an hour so reloads don't call NASA, add
`/api/apod?date=2022-07-11` (NASA accepts a `date` parameter), or swap NASA
for any other key-protected API — the proxy pattern is identical.

## Layout

```
server.js           the whole backend: static files + the /api/apod proxy
public/index.html   the page
public/app.js       calls /api/apod on our own server
public/styles.css   the look; follows your system's light or dark mode
.env.example        where the API key goes
package.json        name + "start" script; the lockfile is empty on purpose
```

## Deploy

Push to your own GitHub repo and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh. Put your real
`NASA_API_KEY` in `.env` next to `compose.yaml` on the server.

---
Part of [devai.io](https://devai.io) — the APIs & Data track: fetch real data
from the internet. Previous:
[ip-lookup](https://git.devai.io/templates/ip-lookup).
