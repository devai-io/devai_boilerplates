# char-counter

> A tweet-style text box that counts down as you type, changes color as you near
> the limit, and blocks the Post button once you've gone over.

**What you'll build:** a `<textarea>` with a 280-character limit. A number shows how
many characters you have left; it turns amber when you're close and red when you're
over, the Post button disables past the limit, and a little circular progress ring
fills up alongside.

**What you'll learn:** how to give _live_ feedback by reacting to the `input` event,
which fires on every keystroke, paste, and delete. You'll also learn to map a single
number onto two things at once — a color and a visual — including the neat trick of
driving an SVG ring with `stroke-dashoffset`.

## Run it

**The easy way:** double-click `index.html`. It opens in your browser and works.
There is nothing to install and no build step.

Or serve it like production:

```sh
docker compose up --build   # then open http://localhost:8080
```

## The idea in 30 seconds

Every time the text changes, we recompute one number — `280 - text.length` — and let
everything else follow from it: the count, whether the button is disabled, the ring's
fill, and the color. One `update()` function, called on every `input` event:

```js
textarea.addEventListener("input", update);
```

The ring is the fun part. A circle's outline has a length (`2 · π · r`). If we tell
the browser to draw a dashed line whose dash is that whole length, then push the dash
along by `stroke-dashoffset`, we can reveal exactly as much of the circle as we like.

## How the code works

- **`input` event** fires on _every_ change to the textarea, so the display never
  lags behind what you typed.
- **`update()`** reads `textarea.value.length`, works out how many characters remain,
  and updates the text, the button's `disabled`, and the ring in one pass.
- **`classList.toggle("warn", condition)`** adds the class when the condition is true
  and removes it when false — that's how the color switches at the thresholds.
- **The ring:** `strokeDasharray` is set to the circle's circumference, and
  `strokeDashoffset` is set to `circumference · (1 - fraction)` so offset `0` means
  full and a large offset means empty.

## Try changing something

- Change `LIMIT` to `500` — everything, including the ring, adjusts automatically.
- Count words instead of characters: `textarea.value.trim().split(/\s+/).length`.
- Flash the textarea border red for a second when someone types past the limit.

## Files

```
index.html      the textarea, the SVG ring, and the Post button
styles.css      how it looks, including the ring and warn/over colors (light + dark)
app.js          the update() function that ties the number to the visuals
Dockerfile      optional: serve it with nginx
compose.yaml    optional: docker compose up --build
```

## Deploy

Push to your own GitHub repo and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — the Web Basics track: HTML, CSS &
JavaScript, one concept at a time.
