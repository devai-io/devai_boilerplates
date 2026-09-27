# crypto-ticker

> A live crypto price board that refreshes itself every 30 seconds — your first taste
> of polling an API on a timer.

**What you'll build:** a little ticker showing Bitcoin, Ethereum, Solana and Dogecoin
with their current USD price and 24-hour change, colored green ▲ or red ▼. It updates
on its own and shows when it last refreshed.

**What you'll learn:** how to _poll_ — call an API repeatedly on a schedule with
`setInterval` — and how to survive the real world: when a free API rate-limits you,
you keep the last good numbers on screen instead of flashing an error.

## Run it

**The easy way:** double-click `index.html`. It works as long as you have internet,
because it calls the price API live.

Or serve it like production:

```sh
docker compose up --build   # then open http://localhost:8080
```

## The idea in 30 seconds

An **API** is a URL that returns data. This one returns the price and 24h change for
several coins at once — open it in your browser to see the JSON:

<https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,solana,dogecoin&vs_currencies=usd&include_24h_change=true>

```json
{ "bitcoin": { "usd": 65000, "usd_24h_change": 1.8 }, "ethereum": { ... } }
```

Prices change constantly, so one fetch isn't enough. We ask again on a timer:

```js
refresh();                      // once, right away
setInterval(refresh, 30000);    // then every 30 seconds (30000 ms)
```

That repeated asking is called **polling**. It's how dashboards, scoreboards and
ticker widgets stay current.

## How the code works

- **`COINS`** is our list. We `map` it into the comma-separated `ids=` the URL wants
  and read each coin back as `data[coin.id]`.
- **`refresh()`** fetches the prices, then `render()` rebuilds one row per coin. Price
  is formatted with `Intl.NumberFormat`; the change is `.toFixed(2)` with an ▲/▼ and a
  green/red class depending on its sign.
- **Rate limits (HTTP 429).** Free APIs cap how often you may call. If we see `429` we
  leave the existing rows untouched and show a small note — much friendlier than
  wiping the board. Any other failure lands in `catch` and also keeps the old numbers.
- **`setInterval(refresh, 30000)`** is the heartbeat; `refresh()` on its own gives the
  page data immediately instead of waiting 30 seconds for the first tick.

## Try changing something

- Add more coins to the `COINS` array (e.g. `{ id: "cardano", name: "Cardano",
  symbol: "ADA" }`) — CoinGecko's `/coins/list` has every id.
- Slow the polling to 60s (`60000`) to be gentler on the free tier, or add a manual
  "Refresh now" button that calls `refresh()`.
- Add `include_market_cap=true` to the URL and show each coin's market cap too.

## A note on rate limits

CoinGecko's free, keyless endpoint is generous but not unlimited. If you refresh very
often you'll see the "Rate limited" note — that's the app doing the right thing:
holding the last good prices until the next successful call. Waiting a bit clears it.

## Files

```
index.html    the ticker container
styles.css    how it looks (light + dark), green/red change colors
app.js        poll the API, format prices, render rows
Dockerfile    serve it with nginx (what compose builds)
compose.yaml  serve it like production: docker compose up --build
```

## Deploy

Push to your own GitHub repo and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — the APIs & Data track: fetch real data
from the internet.
