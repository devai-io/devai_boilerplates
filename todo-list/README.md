# todo-list

> A real to-do app that saves your tasks — built from one array and a redraw
> function.

**What you'll build:** a list where you type a task, hit Add, check things off
(they get a line through them), and delete the ones you're done with. Close the
tab, come back later — your list is still there.

**What you'll learn:** the pattern behind almost every app that shows a list —
_keep the data in an array, and rebuild the screen from that array whenever it
changes_ — plus how to save data in the browser so it survives a refresh.

## Run it

**The easy way:** double-click `index.html`. It opens in your browser and works.
There is nothing to install and no build step.

Or serve it like production:

```sh
docker compose up --build   # then open http://localhost:8080
```

## The idea in 30 seconds

The whole app is one array called `tasks`. Each task is a little object like
`{ text: "Buy milk", done: false }`.

Three things can change that array — adding, checking off, deleting. After each
change we do the exact same two steps:

1. `save()` — write the array to `localStorage` so it's remembered.
2. `render()` — wipe the list on screen and rebuild it from the array.

Because the screen is always rebuilt _from_ the array, the two can never drift
out of sync. That's the trick.

## How the code works

- **`localStorage`** is a tiny box of storage in the browser. It only holds text,
  so we use `JSON.stringify` to save the array and `JSON.parse` to read it back.
- **`render()`** clears the `<ul>` with `list.innerHTML = ""`, then loops over
  `tasks` and builds a `<li>` (checkbox + text + ✕) for each one.
- **`createElement` / `append`** build those elements in JavaScript instead of
  writing HTML by hand.
- **The delete button** uses `tasks.filter((t) => t !== task)` — "give me a new
  array with every task except this one."
- **The count** is `tasks.filter((t) => !t.done).length` — how many aren't done.

## Try changing something

- Add a "Clear completed" button that filters out every task where `done` is true.
- Show the newest task at the top by using `tasks.unshift(...)` instead of `push`.
- Give each task a date with `new Date().toLocaleDateString()` and show it faded.

## Files

```
index.html      the input box, the list, and the count
styles.css      how it looks (light + dark)
app.js          the array, save/load, and the render function
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
