# dark-mode-toggle

> A light/dark theme switch done the proper way — CSS variables, one attribute,
> and a saved preference.

**What you'll build:** a button that flips the whole page between a light and a
dark theme. It remembers your choice for next time, and on your very first visit
it matches whatever your device is already set to.

**What you'll learn:** how real websites do dark mode — define both color
palettes in CSS as variables, switch between them by setting a single
`data-theme` attribute on `<html>`, save the choice in `localStorage`, and
respect the operating system's `prefers-color-scheme` as the default.

## Run it

**The easy way:** double-click `index.html`. It opens in your browser and works.
There is nothing to install and no build step.

**With Docker** (optional, this is how the real site ships it):

```sh
docker build -t dark-mode-toggle .
docker run -p 8080:80 dark-mode-toggle   # then open http://localhost:8080
```

## The idea in 30 seconds

Every color on the page is a CSS variable like `var(--bg)` or `var(--text)`. We
define those variables twice — once for dark, once for light:

```css
[data-theme="dark"]  { --bg: #0b0c0e; --text: #e7e9ee; }
[data-theme="light"] { --bg: #f5f7f9; --text: #14161a; }
```

To switch themes, JavaScript changes _one thing_:

```js
document.documentElement.setAttribute("data-theme", "light");
```

Instantly every `var(--bg)` on the page picks up the new value. No element is
touched individually — the CSS variables do all the work.

## How the code works

- **`setTheme(theme)`** sets `data-theme` on `<html>`, saves the choice to
  `localStorage`, and updates the button's icon and label.
- **`initialTheme()`** decides the starting theme: a saved choice wins; otherwise
  `window.matchMedia("(prefers-color-scheme: light)")` asks the OS.
- **The click handler** reads the current theme and calls `setTheme` with the
  opposite one.
- **In the CSS**, the `@media (prefers-color-scheme: light)` block only applies to
  `:root:not([data-theme])` — so it styles the first paint before JavaScript
  runs, then steps aside once a real choice is set.
- **`aria-pressed`** on the button tells assistive tech whether dark mode is on.

## Try changing something

- Change the accent: edit `--accent` at the top of `styles.css` to any color.
- Add a third "system" option that removes `data-theme` and clears the saved key.
- Tweak the `transition` on `body` and `.card` to make the swap faster or slower.

## Files

```
index.html    the toggle button and a demo card to preview the theme
styles.css    both palettes, defined as CSS variables per [data-theme]
app.js        set the attribute, save the choice, read the OS default
Dockerfile    optional: serve it with nginx
```
