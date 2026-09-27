# modal-dialog

A pop-up done the modern way — with the browser's built-in `<dialog>` element
instead of a pile of hand-rolled JavaScript. Open it, then close it with a
button, the Escape key, or a click on the dimmed backdrop.

## Run

Get it: `git clone https://git.devai.io/templates/modal-dialog.git`

Double-click `index.html` — it opens in your browser and works. Nothing to
install, no build step.

Or serve it like production:

```sh
docker compose up --build
```

Then open http://localhost:8080.

## How it works

`dialog.showModal()` does the hard parts for you: it paints a `::backdrop`
behind the dialog, makes the rest of the page inert (no clicking or tabbing
behind it), moves keyboard focus inside, closes on Escape, and returns focus to
the button that opened it. Hand-built modals need dozens of lines for that.

- **Closing on purpose:** `dialog.close("ok")` closes it and records why in
  `dialog.returnValue`. The code clears that value on every open, so an empty
  one afterwards means the user pressed Escape.
- **Backdrop click:** a click on the backdrop lands on the `<dialog>` element
  itself. The dialog has no padding and its inner `.dialog-body` fills it, so
  `event.target === dialog` means "clicked outside the box".
- **One `close` event** fires however it closed, and the status line reports why.

Try it: add a "Cancel" button with its own `returnValue`, turn it into a
confirm box that only acts when `returnValue === "ok"`, or animate
`.dialog[open]` with CSS.

## Layout

```
index.html   the open button, and the <dialog> with its inner .dialog-body
app.js       open, close, backdrop click and the close event
styles.css   the dialog and its ::backdrop; follows light or dark mode
```

## Deploy

Push to your own GitHub repo and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — the Web Basics track: HTML, CSS &
JavaScript, one concept at a time. Next up:
[star-rating](https://git.devai.io/templates/star-rating).
