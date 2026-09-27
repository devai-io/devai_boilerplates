# faq-accordion

> A classic FAQ accordion — click a question, its answer slides open and the
> others close. Accessible, animated, no libraries.

**What you'll build:** a list of five questions about learning to code. Click any
question and its answer slides open while the others fold away, with the little
"+" spinning into an "×". Works with a mouse, a tap, or the keyboard.

**What you'll learn:** how to show and hide sections the accessible way — using
real `<button>` headers, the `aria-expanded` attribute so screen readers keep up,
and a CSS `max-height` transition for a smooth open/close animation.

## Run it

**The easy way:** double-click `index.html`. It opens in your browser and works.
There is nothing to install and no build step.

Or serve it like production:

```sh
docker compose up --build   # then open http://localhost:8080
```

## The idea in 30 seconds

Each item is a `<button>` (the question) followed by a `<div>` (the answer). The
answer starts collapsed with `max-height: 0; overflow: hidden`. Add one class and
it expands:

```css
.answer { max-height: 0; overflow: hidden; transition: max-height 0.3s ease; }
.item.open .answer { max-height: 200px; }
```

JavaScript's only job is to add or remove that `open` class — and to flip
`aria-expanded` so the button honestly reports its state. To make it an
_accordion_, we close everything before opening the one you clicked.

## How the code works

- **`document.querySelectorAll(".question")`** grabs all five question buttons at
  once, as a list we can loop over.
- **`open` / `close`** set `aria-expanded` and add/remove the `open` class on the
  button's `parentElement` (the whole `.item`).
- **The click handler** reads whether the item is already open, closes them all,
  then reopens the clicked one _unless_ it was the one already open (so a second
  click closes it).
- **Why real `<button>`s?** They're focusable and respond to Enter/Space for free,
  so keyboard users get a working accordion with no extra code.
- **The `+` → `×`** is pure CSS: `transform: rotate(45deg)` on the icon when open.

## Try changing something

- Let multiple answers stay open at once: delete the `questions.forEach(close)` line.
- Open the first item on load: call `open(questions[0])` at the bottom of `app.js`.
- Add a sixth question — just copy one `.item` block in `index.html` (give it a
  new `id`/`aria-controls`).

## Files

```
index.html      the five question/answer items
styles.css      how it looks (light + dark) and the open/close animation
app.js          toggle one item, close the rest
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
