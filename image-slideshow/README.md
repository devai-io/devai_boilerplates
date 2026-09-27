# image-slideshow

A slideshow you can click through — prev, next and dots — or let play by
itself. It's all about one idea: keep a list and an index into it, and wrap the
index around the ends.

## Run

Get it: `git clone https://git.devai.io/templates/image-slideshow.git`

Double-click `index.html` — it opens in your browser and works. Nothing to
install, no build step.

Or serve it like production:

```sh
docker compose up --build
```

Then open http://localhost:8080.

## How it works

The slides are an array; the slideshow is one number, `index`, saying which
slide is showing. `show(i)` paints slide `i` and lights up its dot. Prev and
next call `move(-1)` and `move(1)`, which wrap with the `%` (remainder)
operator:

```js
show((index + step + slides.length) % slides.length);
```

Step past the last slide and you land on 0; step back from 0 and you land on
the last one. Adding `slides.length` first keeps the number positive.

Auto-play is `setInterval(() => move(1), 4000)`. It pauses while your mouse is
over the slideshow or your keyboard focus is inside it, and resumes when you
leave. The slides are CSS gradients, so there are no image files to download.

Try it: add a slide to the `slides` array, change `4000` to `2000`, or make the
arrow keys call `move(-1)` / `move(1)`.

## Layout

```
index.html   the slide box, prev/next buttons and an empty dots row
app.js       the slides array, show(), move() and auto-play
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
[form-validation](https://git.devai.io/templates/form-validation).
