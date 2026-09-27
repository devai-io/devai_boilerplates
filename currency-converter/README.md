# currency-converter

Type an amount, pick two currencies, and see the conversion at the latest
European Central Bank rate, from the free Frankfurter API. It teaches building
URLs with query parameters, and filling dropdowns from data an API gives you.

## Run

Get it: `git clone https://git.devai.io/templates/currency-converter.git`

Double-click `index.html` — it opens in your browser and works, as long as
you're online (it calls the exchange-rate API live). Nothing to install.

Or serve it like production:

```sh
docker compose up --build
```

Then open http://localhost:8080.

## How it works

Two calls to `https://api.frankfurter.dev/v1`, no key needed:

1. **`/currencies`** answers `{ "AUD": "Australian Dollar", … }`. The code
   loops over it and adds an `<option>` per currency to both dropdowns.
2. **`/latest?from=USD&to=EUR`** answers with the rate for that pair. Everything
   after the `?` is the **query string**: `name=value` pairs joined by `&`
   that tell one endpoint what you want. Change the dropdowns, change the URL,
   get a different answer.

The rate is fetched only when a dropdown changes. Typing an amount just
multiplies by the rate you already have, so the page reacts instantly and
doesn't call the API on every keystroke. `Intl.NumberFormat` formats the result
as money in the target currency, and the line above it shows the ECB date the
rate is from (the ECB publishes on working days). "Loading…" and error
messages cover the waits and failures.

Try it: add a "swap ⇅" button that trades the two currencies, convert to
several at once with `to=EUR,GBP,JPY`, or chart a week of rates from
`/2026-09-01..2026-09-07`.

## Layout

```
index.html   the amount box, two dropdowns and the result
app.js       loadCurrencies(), loadRate() and showResult()
styles.css   the look; follows your system's light or dark mode
```

## Deploy

Push to your own GitHub repo and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — the APIs & Data track: fetch real data
from the internet. Next up:
[crypto-ticker](https://git.devai.io/templates/crypto-ticker).
