# char-counter

A tweet-style text box that counts down as you type, turns amber near the
limit and red past it, fills a little progress ring, and disables the Post
button once you've gone over. It teaches live feedback: one number, drawn
several ways.

## Run

Get it: `git clone https://github.com/devai-io/devai_boilerplates.git`, then `cd devai_boilerplates/char-counter`

Double-click `index.html` — it opens in your browser and works. Nothing to
install, no build step.

Or serve it like production:

```sh
docker compose up --build
```

Then open http://localhost:8080.

## How it works

Everything on screen comes from one number: `textarea.value.length`. The
`input` event fires on every keystroke, paste or delete, and `update()`
recomputes it all from that number:

- **the count** — `LIMIT - used`, with a `warn` class at 20 left and `over`
  past zero (the CSS colors them amber and red);
- **the button** — `postBtn.disabled = over`;
- **the ring** — an SVG circle whose outline is `2πr` long. Dash it as one
  dash of that length, then slide it with `stroke-dashoffset`: hide the whole
  length for empty, none of it for full.

The textarea's `aria-describedby` points at the count, so screen readers read
how many characters are left when you focus the box — without announcing
every single keystroke.

Try it: set `LIMIT` to `500` (the ring adapts), count words instead with
`value.trim().split(/\s+/).length`, or flash the border when you go over.

## Layout

```
index.html   the textarea, the SVG ring, the count and the Post button
app.js       update() and the ring math
styles.css   the amber / red states and the ring; follows light or dark mode
```

## Deploy

Make this folder the root of your own repo (`cp -r devai_boilerplates/char-counter my-app`,
then `git init` inside it), push it to GitHub, and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — the Web Basics track: HTML, CSS &
JavaScript, one concept at a time. Next up, fetching real data:
[weather-now](https://github.com/devai-io/devai_boilerplates/tree/main/weather-now).
