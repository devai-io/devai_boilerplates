# country-explorer

> Search any country and get its flag, capital, population, languages and money —
> a lesson in pulling apart a rich, real-world data object.

**What you'll build:** a search box that looks up a country and shows a card with its
flag image, capital city, population, spoken languages, and currencies, plus a link to
see it on a map.

**What you'll learn:** how to render a _rich object_ — one where the interesting bits
are buried in nested arrays. You'll meet `toLocaleString()` for turning a bare number
into a comma-grouped one, and `.map()` for turning an array of little objects
(`[{ name: "Japanese" }]`) into a clean, readable line of text.

## Run it

**The easy way:** double-click `index.html`. It opens in your browser and works — as
long as you have internet, because it calls the countries API live.

Or serve it like production:

```sh
docker compose up --build   # then open http://localhost:8080
```

## The idea in 30 seconds

An **API** is just a URL that returns data instead of a web page. Open
<https://countries.dev/name/Japan> in your browser — that's the exact raw JSON this app
reads. It comes back as a list, because a search can match more than one country.

```js
const res = await fetch("https://countries.dev/name/Japan");
const data = await res.json();   // an ARRAY of matches
const country = data[0];         // take the closest one
country.flags.svg;               // an image URL we drop straight into <img>
```

## How the code works

- **`fetch(url)`** sends the request. Typing part of a name (like "united") can match
  several countries, so the answer is a **list**.
- **`res.status === 404`** means nothing matched; we say so instead of crashing.
- **`await res.json()`** gives an **array**, so we render `data[0]`.
- **`render(c)`** is where the shapes get interesting:
  - `c.population.toLocaleString()` — turns `125836021` into `125,836,021`.
  - `c.languages.map((lang) => lang.name)` — `languages` is an _array of objects_ like
    `[{ name: "Japanese" }]`; `.map()` pulls the `.name` out of each one so we can
    `.join(", ")` them into one line. `currencies` works exactly the same way.
  - `c.flags.svg` — an image URL, so we just point an `<img>` at it.
  - `c.latlng` is `[lat, lng]`; we paste those into an OpenStreetMap link.
- The whole thing sits in `try / catch` so a dropped connection shows a message.

## Try changing something

- Show the `subregion` and `nativeName` too (open the raw JSON to see every field).
- List _every_ match, not just the first — loop over `data` and build a card for each.
- Add the currency symbol next to its name: each currency object also has a `symbol`.

## A note on images and missing fields

The flag is an image the API gives you — the one kind of remote picture this app loads,
and only because the data _is_ a picture. Also notice the guards: `languages`,
`currencies`, `capital` and `latlng` can all be missing or empty for some places (try
"Antarctica"), so we check before using them. Real data is messy; assume a field might
be absent. A `404` here just means nothing matched what you typed.

## Files

```
index.html    the search box and the (hidden until loaded) country card
styles.css    how it looks (light + dark)
app.js        fetch the country, unpack the object, render it
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
