# star-rating

Five stars that light up as you hover, lock in when you click, and remember
your rating next time you visit. It teaches the difference between a
*previewed* value and a *committed* one — the heart of most interactive widgets.

## Run

Get it: `git clone https://github.com/devai-io/devai_boilerplates.git`, then `cd devai_boilerplates/star-rating`

Double-click `index.html` — it opens in your browser and works. Nothing to
install, no build step.

Or serve it like production:

```sh
docker compose up --build
```

Then open http://localhost:8080.

## How it works

There's one drawing function, `paint(value)`, which fills the first `value`
stars. Two different things call it:

- **Hover** calls `paint()` directly — a preview. Nothing is saved.
- **Click** calls `commit()`, which stores the rating in `selected`, saves it to
  `localStorage`, updates the text, and then paints.

When the pointer leaves the row, `paint(selected)` snaps back to the committed
value. On load, the saved rating is read back from `localStorage`.

Each star is a real `<button>` with an `aria-label` ("Rate 3 stars"), so Tab,
Enter and Space work for free; the arrow keys move the rating up and down. The
result line is a `role="status"` region, so screen readers announce it.

Try it: show a word per score ("Terrible" … "Great"), add a "Clear" button
that calls `localStorage.removeItem("rating")`, or support half stars.

## Layout

```
index.html   five star buttons and the result line
app.js       paint(), commit(), hover, click and arrow-key handlers
styles.css   the stars' off / on look; follows light or dark mode
```

## Deploy

Make this folder the root of your own repo (`cp -r devai_boilerplates/star-rating my-app`,
then `git init` inside it), push it to GitHub, and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — the Web Basics track: HTML, CSS &
JavaScript, one concept at a time. Next up:
[char-counter](https://github.com/devai-io/devai_boilerplates/tree/main/char-counter).
