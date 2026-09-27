# currency-converter

> Type an amount, pick two currencies, and see the conversion at today's real exchange
> rate — a first look at building URLs with query parameters.

**What you'll build:** a converter with an amount box and two dropdowns (from / to).
As you type or switch currencies it fetches the live rate and shows both the rate
("1 USD = 0.92 EUR") and your converted amount.

**What you'll learn:** how a URL carries _query parameters_ — the `?from=USD&to=EUR`
part — and how the same value flows through your code: read the inputs, ask the API,
multiply, show the answer. You'll also fill a `<select>` dropdown from live data.

## Run it

**The easy way:** double-click `index.html`. It works as long as you have internet,
because it calls the exchange-rate API live.

Or serve it like production:

```sh
docker compose up --build   # then open http://localhost:8080
```

## The idea in 30 seconds

Everything after the `?` in a URL is the **query string**, and each `name=value` is a
**parameter**. This one URL asks "what is 1 USD in EUR today?" — open it in your
browser to see the JSON:

<https://api.frankfurter.dev/v1/latest?from=USD&to=EUR>

```json
{ "amount": 1, "base": "USD", "date": "…", "rates": { "EUR": 0.92 } }
```

We read `rates.EUR` (a plain number) and multiply:

```js
const converted = amount * rate; // 100 × 0.92 = 92
```

The list of currencies for the dropdowns comes from a second URL,
<https://api.frankfurter.dev/v1/currencies>, which returns
`{ "USD": "United States Dollar", ... }`.

## How the code works

- **`loadCurrencies()`** fetches the currency list, then loops over it with
  `Object.keys(...)` to add one `<option>` to each dropdown. It sets a default pair
  (USD → EUR) and runs the first conversion.
- **`convert()`** builds the URL with the two chosen codes, fetches it, reads
  `data.rates[to]`, and writes the rate and the result onto the page.
- **Same currency both sides?** We skip the network entirely — the rate is just `1`.
- **`Intl.NumberFormat`** is a built-in that formats `92` as `€92.00`, matching
  whichever currency you picked.
- Every change (`input` on the amount, `change` on a dropdown) re-runs `convert()`, and
  each fetch checks `res.ok` inside `try / catch`.

## Try changing something

- Add a "swap ⇅" button that trades the `from` and `to` values, then calls `convert()`.
- Show the rate's `date` from the JSON so users know how fresh it is.
- Convert to several currencies at once: `...?from=USD&to=EUR,GBP,JPY` returns all
  three in `rates`.

## A note on the data

Frankfurter is free and keyless, using European Central Bank reference rates (updated
on working days), so it's great for learning — not for trading. If a request ever
fails, the `catch` block shows a friendly message instead of a broken number.

## Files

```
index.html    the amount box and the two dropdowns
styles.css    how it looks (light + dark)
app.js        load currencies, fetch the rate, do the math
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
