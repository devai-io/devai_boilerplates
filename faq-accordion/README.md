# faq-accordion

A classic FAQ: click a question and its answer slides open while the others
close. It teaches showing and hiding content the accessible way — real
`<button>`s, `aria-expanded`, and a pure-CSS animation.

## Run

Get it: `git clone https://git.devai.io/templates/faq-accordion.git`

Double-click `index.html` — it opens in your browser and works. Nothing to
install, no build step.

Or serve it like production:

```sh
docker compose up --build
```

Then open http://localhost:8080.

## How it works

Each question is a real `<button>`, so mouse, touch and keyboard (Tab, then
Enter or Space) all work without extra code. Its `aria-expanded` attribute is
the state: screen readers announce it, and `aria-controls` points at the answer
it opens.

On click, `app.js` closes every item, then opens the one you clicked (unless it
was already open). Opening means two things: set `aria-expanded="true"`, and
add an `open` class to the item. The CSS does the rest — the answer animates
`max-height` from `0` to `200px`, and `visibility: hidden` keeps closed answers
out of reach of screen readers and the Tab key.

Try it: let several answers stay open by deleting `questions.forEach(close)`,
open the first one on load with `open(questions[0])`, or add a question by
copying an `.item` block (with a new `id` / `aria-controls` pair).

## Layout

```
index.html   the questions and answers
app.js       open(), close() and the click handler
styles.css   the look and the slide animation; follows light or dark mode
```

## Deploy

Push to your own GitHub repo and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — the Web Basics track: HTML, CSS &
JavaScript, one concept at a time. Next up:
[stopwatch](https://git.devai.io/templates/stopwatch).
