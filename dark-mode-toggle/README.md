# dark-mode-toggle

A light/dark theme switch done the proper way — CSS variables, one attribute on
`<html>`, and a remembered choice. It starts from the visitor's system setting
and never flashes the wrong theme on load.

## Run

Get it: `git clone https://github.com/devai-io/devai_boilerplates.git`, then `cd devai_boilerplates/dark-mode-toggle`

Double-click `index.html` — it opens in your browser and works. Nothing to
install, no build step.

Or serve it like production:

```sh
docker compose up --build
```

Then open http://localhost:8080.

## How it works

Every color on the page is a CSS variable like `var(--bg)`. `styles.css`
defines them twice:

```css
[data-theme="dark"]  { --bg: #0b0c0e; --text: #e7e9ee; }
[data-theme="light"] { --bg: #f5f7f9; --text: #14161a; }
```

To switch themes, JavaScript changes one thing:

```js
document.documentElement.dataset.theme = "light";
```

and every `var(--bg)` on the page picks up the new value. No element is touched
individually.

- **First visit:** there's no saved choice, so `initialTheme()` asks the OS with
  `matchMedia("(prefers-color-scheme: light)")`. Before any JavaScript runs,
  the CSS media query styles `:root:not([data-theme])` the same way.
- **Clicking the button** flips the theme and saves it to `localStorage`. Only a
  real click is saved, so until you click, every visit follows the OS setting.
- **No flash:** a tiny `<script>` in `<head>` applies the saved theme before
  the page is first drawn.
- **`aria-pressed`** tells screen readers whether dark mode is on; the button's
  label stays "Dark mode" so the state is never ambiguous.

Try it: change `--accent` to any color, add a third "System" option that
removes `data-theme` and the saved key, or tweak the `transition` speeds.

## Layout

```
index.html   the toggle button, a preview card, and the no-flash <script>
app.js       initialTheme(), applyTheme() and the click handler
styles.css   the two palettes as CSS variables
```

## Deploy

Make this folder the root of your own repo (`cp -r devai_boilerplates/dark-mode-toggle my-app`,
then `git init` inside it), push it to GitHub, and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — the Web Basics track: HTML, CSS &
JavaScript, one concept at a time. Next up:
[image-slideshow](https://github.com/devai-io/devai_boilerplates/tree/main/image-slideshow).
