# random-quote

> Show a random quote, click a button for another — and learn the fetch pattern that
> powers real APIs, using a data file you can read with your own eyes.

**What you'll build:** a quote card with a "New quote" button. Every click shows a
different well-known quote and its author, and it never shows the same one twice in a
row.

**What you'll learn:** how to `fetch()` a data file, turn its JSON into a JavaScript
array, and pick a random item from it. This is the _same_ code you'd write to talk to
a live API on the internet — here we use a local `quotes.json` so it's 100% reliable
and works offline while you learn.

## Run it

Because opening the file directly (via `file://`) can stop some browsers from reading
`quotes.json`, run a tiny local web server — it's one line:

```sh
python3 -m http.server 8000    # then open http://localhost:8000
```

(That command comes built into most machines. Any static server works.)

Or serve it like production — nginx in compose serves `quotes.json` just as
well as the Python one-liner does:

```sh
docker compose up --build   # then open http://localhost:8080
```

## The idea in 30 seconds

`fetch()` doesn't care whether the data lives on a faraway server or right next to
your page — it just reads a URL. Open <http://localhost:8000/quotes.json> while the
server is running and you'll see the raw JSON this app reads: an array of little
objects.

```js
const res = await fetch("quotes.json");
const quotes = await res.json(); // [ { text, author }, { text, author }, ... ]
```

Then picking a random one is just array math:

```js
const i = Math.floor(Math.random() * quotes.length);
const quote = quotes[i];
```

**Want a live API instead?** Swap the one line — for example
`fetch("https://api.quotable.io/random")` — and read the fields that API returns.
Everything else stays the same. That's the whole point: a local file and a remote API
are the same shape of code.

## How the code works

- **`loadQuotes()`** runs once when the page opens. It `fetch`es `quotes.json`, checks
  `res.ok`, then `await res.json()` parses the text into a real array.
- **`showRandom()`** picks a random index. It remembers `lastIndex` and rolls again if
  it lands on the same quote, so you never see an immediate repeat.
- **`addEventListener("click", showRandom)`** wires the button up: every click shows a
  new quote — no page reload, no network call (the data's already in memory).
- The whole load sits in `try / catch`. If the file can't be read (usually the
  `file://` gotcha above), you get a friendly hint instead of a blank card.

## Try changing something

- Open `quotes.json` and add your own favorite quotes to the array. Refresh — done.
- Add a "Copy" button that copies the current quote with `navigator.clipboard`.
- Point `fetch` at a live quotes API and read _its_ field names instead of
  `text` / `author`.

## Files

```
index.html    the quote card and the button
styles.css    how it looks (light + dark)
app.js        fetch the data, pick a random quote, render it
quotes.json   the data — an array of { text, author } objects you can edit
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
