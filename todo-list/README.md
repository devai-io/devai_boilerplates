# todo-list

A real to-do app that remembers your tasks after a refresh — built from one
array, one `render()` function and `localStorage`. It teaches the idea every
framework is built on: the data is the truth, and the screen is redrawn from it.

## Run

Get it: `git clone https://git.devai.io/templates/todo-list.git`

Double-click `index.html` — it opens in your browser and works. Nothing to
install, no build step.

Or serve it like production:

```sh
docker compose up --build
```

Then open http://localhost:8080.

## How it works

All the tasks live in one array, `tasks`, of `{ text, done }` objects. Every
action — add, tick, delete — follows the same three steps:

1. change the array (`push`, flip `done`, or `filter` a task out),
2. `save()` it to `localStorage` (as JSON, because it only stores text),
3. `render()` — clear the list and rebuild every `<li>` from the array.

Because the screen is always rebuilt from the data, the two can never drift
apart. On load, the array is read back with `JSON.parse`, so your list is still
there after a refresh.

Try it: add a "Clear completed" button (`tasks.filter((t) => !t.done)`), put
new tasks on top with `unshift` instead of `push`, or stamp each task with
`new Date().toLocaleDateString()`.

## Layout

```
index.html   the form, an empty <ul>, and the "left" counter
app.js       the tasks array, save() and render()
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
[countdown-timer](https://git.devai.io/templates/countdown-timer).
