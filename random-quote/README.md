# random-quote

Show a random quote, click for another — and learn the `fetch()` pattern that
powers real APIs, using a data file you can open and read yourself. It never
shows the same quote twice in a row.

## Run

Get it: `git clone https://git.devai.io/templates/random-quote.git`

This one needs a tiny local web server: browsers won't let a page opened
straight from disk (`file://`) `fetch()` another file, even one in the same
folder. From this folder:

```sh
python3 -m http.server 8000
```

Then open http://localhost:8000. (That one needs Python 3; any static file
server works just as well.)

Or serve it like production:

```sh
docker compose up --build
```

Then open http://localhost:8080.

## How it works

`quotes.json` is an array of `{ "text": …, "author": … }` objects sitting next
to the page. `loadQuotes()` reads it exactly the way you'd read a live API:

```js
const res = await fetch("quotes.json");
quotes = await res.json();
```

Swap that URL for a real endpoint and the rest barely changes. `showRandom()`
picks `Math.floor(Math.random() * quotes.length)` and re-rolls if it matches
the last pick. "Loading…" shows while the file loads, and if it can't be read
(most often because the page was opened from disk) the page tells you to serve
the folder instead.

Try it: add your own quotes to `quotes.json` and refresh, add a "Copy" button
with `navigator.clipboard.writeText`, or point `fetch` at a live quotes API.

## Layout

```
index.html   the quote, its author and the button
app.js       loadQuotes() and showRandom()
quotes.json  the data — edit it freely
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
[currency-converter](https://git.devai.io/templates/currency-converter).
