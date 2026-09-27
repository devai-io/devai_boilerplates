# dictionary-lookup

> Type a word, read its meanings — and learn how to dig data out of JSON that has
> arrays tucked inside objects tucked inside arrays.

**What you'll build:** a search box that looks up any English word and shows its
pronunciation plus every meaning, grouped by part of speech, with example sentences.

**What you'll learn:** how to read _nested JSON_. Real APIs rarely hand you one flat
list of values — they hand you arrays inside objects inside arrays, and you have to
walk down the levels with loops to reach what you want. You'll also handle the classic
case where a word simply doesn't exist.

## Run it

**The easy way:** double-click `index.html`. It opens in your browser and works — as
long as you have internet, because it calls the dictionary API live.

Or serve it like production:

```sh
docker compose up --build   # then open http://localhost:8080
```

## The idea in 30 seconds

An **API** is just a URL that returns data instead of a web page. Open
<https://api.dictionaryapi.dev/api/v2/entries/en/serendipity> in your browser — you'll
see the raw JSON this app reads. Notice the square brackets `[` and curly braces `{`:
those are the arrays and objects we have to climb through.

```js
const res = await fetch("https://api.dictionaryapi.dev/api/v2/entries/en/serendipity");
const data = await res.json();   // an ARRAY of entries
const entry = data[0];           // grab the first one
entry.meanings[0].partOfSpeech;  // "noun"  ← three levels deep
```

`await` means "pause here until the answer comes back." Then we loop.

## How the code works

- **`fetch(url)`** sends the request and returns a `Response`.
- **`res.status`** tells you what happened: `200` is success, `404` means "no such
  word." We check for `404` and show a friendly message instead of crashing.
- **`await res.json()`** parses the body. Here it's an **array**, so we take `data[0]`.
- **`render(entry)`** does the nested part: a `for…of` loop over `entry.meanings`, and
  _inside_ it another loop over that meaning's `definitions`. One loop per level of
  nesting. `partOfSpeech` and `example` might be missing, so we guard them with `||`
  and an `if`.
- The whole thing is wrapped in `try / catch` so a dropped connection shows a message
  instead of a blank screen.

## Try changing something

- Show the word's synonyms — look in the raw JSON for a `synonyms` array inside each
  meaning and list them under the definitions.
- Cap it at the first two definitions per part of speech with `meaning.definitions.slice(0, 2)`.
- Add a "Surprise me" button that looks up a random word from a small list you pick.

## A note on missing pieces

Not every word has a `phonetic`, and not every definition has an `example` — that's
why the code checks before showing them. When you read someone else's JSON, always
assume a field _might_ be absent and handle it, or the page breaks the first time it
is. A `404` here just means the word isn't in the dictionary, not that anything failed.

## Files

```
index.html    the search box and the (hidden until loaded) result
styles.css    how it looks (light + dark)
app.js        fetch the word, walk the nested JSON, render it
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
