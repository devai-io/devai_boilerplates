# ip-lookup

Open the page and it tells you your public IP address, rough location,
internet provider and time zone — with a link to the spot on a map. No search
box: the API describes the very request you send it.

## Run

Get it: `git clone https://git.devai.io/templates/ip-lookup.git`

Double-click `index.html` — it opens in your browser and works, as long as
you're online (it asks the lookup service about you live). Nothing to install.

Or serve it like production:

```sh
docker compose up --build
```

Then open http://localhost:8080.

## How it works

Most APIs need you to say what you're asking about. This one doesn't:
`fetch("https://ipwho.is/")` sends no parameters, and the service looks at
where the request came from — your IP address — and answers with what it knows
about it. Whoever opens the page gets their own answer. It's free and needs no
key.

Two details worth copying:

- **`success: false` inside a 200.** When a lookup fails, this API still
  answers HTTP 200 and puts `success: false` in the JSON. Checking `res.ok` is
  not enough, so the code checks the field too.
- **Nested, optional fields.** `connection.isp` and `timezone.id` live one level
  down; `d.connection?.isp || "Unknown"` keeps the page working if either is
  missing.

The coordinates become an OpenStreetMap link, the Refresh button runs the same
fetch again, and "Loading…" and a friendly error cover the waits and failures.

Try it: show your `postal` code or `connection.org`, link to another map
service instead, or refresh automatically with `setInterval(load, 30000)`.

## Layout

```
index.html   a status line, a hidden result card and the Refresh button
app.js       load() and render()
styles.css   the look; follows your system's light or dark mode
```

## Deploy

Push to your own GitHub repo and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — the APIs & Data track: fetch real data
from the internet. Next up, a real backend:
[nasa-photo-proxy](https://git.devai.io/templates/nasa-photo-proxy).
