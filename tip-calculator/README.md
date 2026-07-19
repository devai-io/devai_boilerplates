# tip-calculator

> A working tip calculator in one HTML file, one CSS file, and 30 lines of JavaScript.

**What you'll build:** a little app where you type a bill amount, drag a slider to
pick a tip percentage, say how many people are splitting it, and instantly see the
tip and the total each person owes.

**What you'll learn:** the single most important pattern in web pages —
_read the inputs → do some math → write the answer back onto the screen_ — and how
to make it happen automatically every time something changes.

## Run it

**The easy way:** double-click `index.html`. It opens in your browser and works.
There is nothing to install and no build step.

**With Docker** (optional, this is how the real site ships it):

```sh
docker build -t tip-calculator .
docker run -p 8080:80 tip-calculator   # then open http://localhost:8080
```

## The idea in 30 seconds

A web page is just text (HTML) with styling (CSS). JavaScript is what makes it
_react_. Here the whole app is one function, `calculate()`, that:

1. reads the three input boxes,
2. multiplies to get the tip and divides to get the per-person total,
3. drops those numbers back into the page.

We tell the browser: "run `calculate()` every time any input changes." That's it.
There is no framework and no magic.

## How the code works

- **`index.html`** lays out the boxes. Each input has an `id` (like `id="bill"`) so
  JavaScript can find it.
- **`app.js`** does three things:
  - `document.getElementById("bill")` grabs an element by its id.
  - `parseFloat(...)` turns the text you typed into a number we can do math with.
  - `Intl.NumberFormat` is a built-in that formats `19.5` as `$19.50` for us.
  - `addEventListener("input", calculate)` is the key line — "whenever this box
    changes, run `calculate`."
- **`styles.css`** is plain CSS. The `@media (prefers-color-scheme: light)` block
  swaps the colors if the visitor's device is in light mode.

## Try changing something

- Change the currency: swap `"USD"` for `"EUR"` (and `"en-US"` for `"de-DE"`).
- Add a "round up to the nearest dollar" checkbox.
- Change the slider's `max="30"` to `max="50"` for the generous tippers.

## Files

```
index.html    the boxes and labels
styles.css    how it looks (light + dark)
app.js        the 30 lines that make it work
Dockerfile    optional: serve it with nginx
```
