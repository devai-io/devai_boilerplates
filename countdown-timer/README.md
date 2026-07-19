# countdown-timer

> A live countdown to any moment you pick — your first look at doing something
> every second with `setInterval`.

**What you'll build:** a timer that shows the days, hours, minutes, and seconds
left until a date you choose (or until New Year by default), ticking down in real
time and celebrating with "🎉 It's time!" when it hits zero.

**What you'll learn:** how to run code on a repeating schedule with
`setInterval`, how to _stop_ it with `clearInterval`, and how to do simple date
math by subtracting two dates.

## Run it

**The easy way:** double-click `index.html`. It opens in your browser and works.
There is nothing to install and no build step.

**With Docker** (optional, this is how the real site ships it):

```sh
docker build -t countdown-timer .
docker run -p 8080:80 countdown-timer   # then open http://localhost:8080
```

## The idea in 30 seconds

A `Date` in JavaScript is really just a number: milliseconds since 1970. So if
you subtract two dates, you get the milliseconds between them:

```js
const msLeft = target - new Date(); // how far away the target is, in ms
```

`setInterval(tick, 1000)` tells the browser "run `tick` every 1000 milliseconds."
Each tick recalculates that gap and repaints the numbers. When the gap reaches
zero we call `clearInterval` to stop — otherwise it would tick forever.

## How the code works

- **`tick()`** is the function that runs every second. It computes `msLeft`, and
  if that's `<= 0` it shows the message and calls `clearInterval(timer)`.
- **The math** converts milliseconds to units: `86400` seconds make a day, `3600`
  an hour, `60` a minute. The `%` (remainder) operator peels off each piece.
- **`setInterval`** returns an id; we keep it in `timer` so `clearInterval(timer)`
  can find and cancel it later.
- **`start()`** clears any old timer before starting a new one — important, or
  picking a new date would leave two timers running at once.
- **Picking a date** builds a `Date` from the input; if it's invalid we fall back
  to New Year.

## Try changing something

- Count down to your birthday by setting `target` to `new Date("2027-05-01")`.
- Add a "Reset to New Year" button that sets `target = nextNewYear()` and restarts.
- Make the seconds pulse by toggling a CSS class on the seconds element each tick.

## Files

```
index.html    the date picker and the four number boxes
styles.css    how it looks (light + dark)
app.js        the tick, the date math, and start/stop
Dockerfile    optional: serve it with nginx
```
