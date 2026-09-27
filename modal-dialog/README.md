# modal-dialog

> A pop-up done the modern, accessible way — with the browser's built-in
> `<dialog>` element instead of a pile of hand-rolled JavaScript.

**What you'll build:** a button that opens a modal dialog. You can close it four
ways — the ✕ button, an OK button, the <kbd>Esc</kbd> key, or by clicking the dark
backdrop — and a line of text below reports how it was closed.

**What you'll learn:** why `<dialog>` is the right tool for overlays. Calling
`dialog.showModal()` dims the page, traps keyboard focus inside the box, and handles
the Escape key for you. Getting focus-trapping right by hand is genuinely hard, so
letting the browser do it is both less code and more accessible.

## Run it

**The easy way:** double-click `index.html`. It opens in your browser and works.
There is nothing to install and no build step.

Or serve it like production:

```sh
docker compose up --build   # then open http://localhost:8080
```

## The idea in 30 seconds

Before `<dialog>`, a modal meant a stack of `<div>`s plus JavaScript to dim the page,
stop the background from scrolling, keep <kbd>Tab</kbd> from wandering out of the box,
and listen for Escape. The native element does all of that:

```js
dialog.showModal(); // open — page goes inert, focus is trapped
dialog.close("ok"); // close — and optionally say why
```

Everything else is just deciding _when_ to call `close()`.

## How the code works

- **`dialog.showModal()`** opens the dialog as a modal and paints the backdrop.
- **`dialog.close(value)`** closes it. The value is stored on `dialog.returnValue`,
  so the code can tell whether OK, the ✕, or the backdrop closed it.
- **Backdrop click:** because a modal covers the whole screen, a click on the dark
  area registers on the `<dialog>` element itself. We check `event.target === dialog`
  — true only for the backdrop, since the visible content sits in an inner wrapper.
- **Escape** is handled by the browser; it fires the `close` event with no return
  value, which our handler reads as "the user pressed Escape."
- **`padding: 0`** on the dialog (with padding on `.dialog-body` instead) is what
  keeps the backdrop-click check from firing on the dialog's own edges.

## Try changing something

- Add a "Cancel" button that closes with a different `returnValue`.
- Turn it into a confirm box: only run an action when `returnValue === "ok"`.
- Style the opening with a CSS animation on `.dialog[open]`.

## Files

```
index.html      the open button and the <dialog> markup
styles.css      how it looks, including the ::backdrop (light + dark)
app.js          open, and the four ways to close
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
