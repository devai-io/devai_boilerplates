# color-picker

> Pick a color, see its HEX and RGB codes, get a matching palette, and copy any
> value with one click.

**What you'll build:** a color tool with a native color picker, a big live swatch,
the color's HEX and RGB written out, and five auto-generated tints and shades. Click
any code and it lands on your clipboard with a little "Copied!" flash.

**What you'll learn:** how to read an `<input type="color">`, how a HEX code and an
RGB triple are really the _same number_ in two costumes (and how to convert between
them), and how to copy text to the clipboard with `navigator.clipboard.writeText`.

## Run it

**The easy way:** double-click `index.html`. It opens in your browser and works.
There is nothing to install and no build step.

**With Docker** (optional, this is how the real site ships it):

```sh
docker build -t color-picker .
docker run -p 8080:80 color-picker   # then open http://localhost:8080
```

## The idea in 30 seconds

A HEX color like `#EC4899` is three pairs of hex digits — one each for red, green,
and blue. `EC` is `236`, `48` is `72`, `99` is `153`. So HEX and `rgb(236, 72, 153)`
describe the exact same color. Once you can move between the two, you can do math on
colors: nudge every channel toward white and you get a lighter _tint_; toward black
and you get a darker _shade_. That's the whole palette generator.

## How the code works

- **`hexToRgb(hex)`** reads the string as one base-16 number, then slices out each
  8-bit channel with bit shifts and masks.
- **`rgbToHex(r, g, b)`** does the reverse, padding each channel to two digits.
- **`mix(value, target, amount)`** slides one channel part-way toward `255` (lighter)
  or `0` (darker). Five different amounts make the five palette swatches.
- **`copy(text)`** calls `navigator.clipboard.writeText`, then adds a CSS class to
  fade the toast in and a `setTimeout` to fade it back out.
- **`readableText(...)`** guesses whether each swatch needs dark or light text so the
  code on top stays legible.

## Try changing something

- Add more swatches: extend the `steps` array with extra `amount` values.
- Copy the value as CSS: change the toast to copy `background: #EC4899;`.
- Show an HSL version too — look up how hue, saturation, and lightness work.

## Files

```
index.html    the picker, swatch, values, and palette
styles.css    how it looks (light + dark)
app.js        color conversion, palette, and clipboard copying
Dockerfile    optional: serve it with nginx
```
