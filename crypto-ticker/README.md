# crypto-ticker

A little price board for Bitcoin, Ethereum and friends that refreshes itself
every 30 seconds, with 24-hour changes in green and red. It teaches polling:
asking an API again on a timer.

## Run

Get it: `git clone https://github.com/devai-io/devai_boilerplates.git`, then `cd devai_boilerplates/crypto-ticker`

Double-click `index.html` — it opens in your browser and works, as long as
you're online (it calls the price API live). Nothing to install.

Or serve it like production:

```sh
docker compose up --build
```

Then open http://localhost:8080.

## How it works

The API can't tell the page when prices change, so the page asks again on a
timer:

```js
refresh();                     // once now…
setInterval(refresh, 30000);   // …then every 30 seconds
```

Each `refresh()` is one ordinary `fetch()` to CoinGecko's free
`/simple/price` endpoint (no key needed) with the coin ids in the query string
and `include_24hr_change=true`. `render()` rebuilds one row per coin with
`createElement` and `textContent`, formats prices with `Intl.NumberFormat`
(extra decimals for coins under $1), and colors the change green `▲` or red
`▼`.

Polling a free API means you will sometimes be throttled. On a 429 ("too many
requests") or a network error, the page keeps the last good prices on screen,
says so, and simply tries again on the next tick. "Loading prices…" shows until
the first answer arrives.

Try it: add a coin to `COINS` (e.g. `cardano`), poll every 60 seconds to be
gentler on the free tier, or add `include_market_cap=true` and show it.

## Layout

```
index.html   an empty rows box, a status line and "last updated"
app.js       COINS, refresh(), render() and the interval
styles.css   the look — green / red change colors; follows light or dark mode
```

## Deploy

Make this folder the root of your own repo (`cp -r devai_boilerplates/crypto-ticker my-app`,
then `git init` inside it), push it to GitHub, and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — the APIs & Data track: fetch real data
from the internet. Next up:
[dictionary-lookup](https://github.com/devai-io/devai_boilerplates/tree/main/dictionary-lookup).
