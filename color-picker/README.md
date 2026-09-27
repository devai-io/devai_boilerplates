# color-picker

Pick a color and instantly see its HEX and RGB codes, a big preview and a
palette of lighter and darker shades — then copy any of them with one click. It
teaches the color input, how HEX and RGB relate, and the Clipboard API.

## Run

Get it: `git clone https://git.devai.io/templates/color-picker.git`

Double-click `index.html` — it opens in your browser and works. Nothing to
install, no build step.

Or serve it like production:

```sh
docker compose up --build
```

Then open http://localhost:8080.

## How it works

`<input type="color">` gives you the browser's own color picker, and its value
is always a HEX string like `#ec4899`. Every `input` event redraws the page from
that one value with `update(hex)`.

HEX and RGB are the same three numbers written two ways: `ec`, `48`, `99` in
base 16 are `236`, `72`, `153` in base 10. `hexToRgb` reads the hex digits with
`parseInt(…, 16)`; `rgbToHex` writes them back with `toString(16)`. The palette
moves each channel part of the way toward 255 (a tint) or 0 (a shade).

Clicking a value calls `navigator.clipboard.writeText(text)`. It's async and
the browser may refuse, so the code awaits it in a `try` / `catch` and tells
you either way in a small status line.

Try it: add more swatches to the `steps` array, copy values as a CSS
declaration (`background: #EC4899;`), or show an HSL version too.

## Layout

```
index.html   the preview, the color input, two value buttons and the palette row
app.js       hex ↔ rgb conversion, the palette and copy()
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
[modal-dialog](https://git.devai.io/templates/modal-dialog).
