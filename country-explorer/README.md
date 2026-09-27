# country-explorer

Search any country and get a tidy fact card — flag, capital, region,
population, languages and currencies — from the free countries.dev API. It's a
lesson in pulling apart a rich, real-world JSON object.

## Run

Get it: `git clone https://git.devai.io/templates/country-explorer.git`

Double-click `index.html` — it opens in your browser and works, as long as
you're online (it calls the countries API live). Nothing to install.

Or serve it like production:

```sh
docker compose up --build
```

Then open http://localhost:8080.

## How it works

`search(name)` fetches `https://countries.dev/name/<name>` (no key needed). The
answer is an array of every country whose name contains your search, and the
page shows the first. One country is a rich object, and `render()` picks each
kind of field apart:

- **plain values** — `name`, `capital`, `region` go straight into `textContent`;
- **an image URL** — `flags.svg` becomes the `<img>`'s `src`, so the flag loads
  from the address the API handed back;
- **a big number** — `population.toLocaleString()` turns `125836021` into
  `125,836,021`;
- **arrays of objects** — `languages` and `currencies` are mapped down to their
  `.name` and joined with commas;
- **missing pieces** — Antarctica has no capital and no currency, so `?.` and
  `|| "—"` show a dash instead of crashing.

A 404 means no country matched and the page says so; "Loading…" and a friendly
error cover the rest.

Try it: show every match as its own card, add each currency's `symbol`, or
show the `nativeName` of each language.

## Layout

```
index.html   the search form, a status line and a hidden fact card
app.js       search() and render()
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
[ip-lookup](https://git.devai.io/templates/ip-lookup).
