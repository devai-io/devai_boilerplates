# stopwatch

> A working stopwatch — start, stop, reset, and laps — that stays accurate down
> to the hundredth of a second.

**What you'll build:** a stopwatch with a big `mm:ss.cs` display, one button that
toggles between Start and Stop, a Reset, and a Lap button that stacks split times
into a numbered list.

**What you'll learn:** the right way to measure time in a browser. The naive way —
add a little to a counter on every tick — slowly drifts, because ticks never fire
exactly on schedule. The reliable way is to remember _when_ you started and subtract.
You'll also meet `setInterval` and how to build up a list of elements.

## Run it

**The easy way:** double-click `index.html`. It opens in your browser and works.
There is nothing to install and no build step.

Or serve it like production:

```sh
docker compose up --build   # then open http://localhost:8080
```

## The idea in 30 seconds

A stopwatch has to answer one question: "how long has it been running?" We keep two
numbers — `elapsed` (time banked from previous runs) and `startTime` (the moment the
current run began) — and the answer is always:

```js
elapsed + (Date.now() - startTime);
```

`Date.now()` is the real clock, so this is exact no matter how choppy the screen
updates are. We repaint the display ~33 times a second just so the hundredths look
smooth — but the update rate never changes the actual time.

## How the code works

- **`Date.now()`** returns the current time in milliseconds. Subtracting two of them
  gives an accurate elapsed duration.
- **`setInterval(render, 30)`** re-runs `render` about every 30ms while running, and
  returns an id we later hand to `clearInterval` to stop.
- **`toggle()`** checks whether a timer is running: if it is, it banks the time and
  stops; if not, it records `startTime` and starts ticking.
- **`format(ms)`** does the arithmetic to split milliseconds into minutes, seconds,
  and hundredths, padding each with a leading zero.
- **`addLap()`** creates a new `<li>` and appends it, so laps stack up in order.

## Try changing something

- Show milliseconds (three digits) instead of hundredths — divide by 1 and pad to 3.
- Highlight the fastest and slowest lap by comparing consecutive split times.
- Add a keyboard shortcut: start/stop when the space bar is pressed.

## Files

```
index.html      the display and the three buttons
styles.css      how it looks (light + dark)
app.js          the timing logic and lap list
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
