# dictionary-lookup

Type a word and read its pronunciation and definitions, grouped by part of
speech, from a free dictionary API. It's your lesson in digging data out of
real JSON — arrays tucked inside objects tucked inside arrays.

## Run

Get it: `git clone https://github.com/devai-io/devai_boilerplates.git`, then `cd devai_boilerplates/dictionary-lookup`

Double-click `index.html` — it opens in your browser and works, as long as
you're online (it calls the dictionary live). Nothing to install.

Or serve it like production:

```sh
docker compose up --build
```

Then open http://localhost:8080.

## How it works

`lookup(word)` fetches
`https://freedictionaryapi.com/api/v1/entries/en/<word>` — English Wiktionary
as JSON, no key needed. The answer is nested three levels deep:

```
data.entries[]            one per part of speech (noun, verb, …)
  .senses[]               one per meaning
    .definition           the text
    .examples[]           optional example sentences
```

`render()` walks down with one loop per level: an `<h3>` for each entry's
`partOfSpeech`, an `<ol>` of its senses, and the first example under a
definition when there is one. Everything goes onto the page with
`textContent`, never `innerHTML`, so text from the API can't inject HTML.

The states are handled too: "Loading…" while waiting, a friendly message when
the word isn't found (the API answers with an empty `entries` array), when
you hit the 1,000-lookups-an-hour limit (HTTP 429), or when the network fails.

Try it: show each sense's `synonyms`, cap each part of speech at two
definitions with `item.senses.slice(0, 2)`, or add a "Surprise me" button.

## Layout

```
index.html   the search form, a status line and an empty entry card
app.js       lookup() and render()
styles.css   the look; follows your system's light or dark mode
```

## Deploy

Make this folder the root of your own repo (`cp -r devai_boilerplates/dictionary-lookup my-app`,
then `git init` inside it), push it to GitHub, and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — the APIs & Data track: fetch real data
from the internet. Next up:
[country-explorer](https://github.com/devai-io/devai_boilerplates/tree/main/country-explorer).
