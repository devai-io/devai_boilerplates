# tip-calculator

A working tip calculator in one HTML file, one CSS file and about 30 lines
of JavaScript. Type a bill, drag the tip slider, split it between friends — and
learn the pattern behind almost every web page: read the inputs, do the math,
write the answer back.

## Run

Get it: `git clone https://git.devai.io/templates/tip-calculator.git`

Double-click `index.html` — it opens in your browser and works. Nothing to
install, no build step.

Or serve it like production:

```sh
docker compose up --build
```

Then open http://localhost:8080.

## How it works

The whole app is one function, `calculate()`: it reads the three inputs, works
out the tip and the per-person total, and writes both back onto the page. One
line makes it live:

```js
el.addEventListener("input", calculate);
```

"Whenever this input changes, run `calculate`." Everything else is plain
JavaScript: `getElementById` finds an element, `parseFloat` turns typed text
into a number, and the built-in `Intl.NumberFormat` turns `19.5` into `$19.50`.

Try it: swap `"USD"` for `"EUR"` (and `"en-US"` for `"de-DE"`), add a
"round up" checkbox, or raise the slider's `max="30"` for generous tippers.

## Layout

```
index.html   the inputs — each has an id so JavaScript can find it
app.js       calculate() and the listeners that run it
styles.css   the look; follows your system's light or dark mode
```

## Deploy

Push to your own GitHub repo and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — the Web Basics track: HTML, CSS &
JavaScript, one concept at a time. Next up:
[todo-list](https://git.devai.io/templates/todo-list).
