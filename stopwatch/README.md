# stopwatch

A working stopwatch — start, stop, reset and laps — accurate to the hundredth
of a second. It teaches the one thing most first attempts get wrong about time:
measure it, don't count it.

## Run

Get it: `git clone https://github.com/devai-io/devai_boilerplates.git`, then `cd devai_boilerplates/stopwatch`

Double-click `index.html` — it opens in your browser and works. Nothing to
install, no build step.

Or serve it like production:

```sh
docker compose up --build
```

Then open http://localhost:8080.

## How it works

The tempting version adds 10 ms every time a 10 ms timer fires. It drifts:
timers fire late, and background tabs skip them entirely.

This one remembers **when** the current run started and subtracts:

```js
elapsed + (performance.now() - startTime)
```

`performance.now()` is the browser's clock for measuring durations — it only
moves forward, even if the computer's date and time are adjusted mid-run.
`setInterval(render, 30)` only decides how often the display repaints; what it
shows is always computed from the clock, so a late tick can never make it
wrong. Stopping banks the time so far into `elapsed`; starting again carries on
from there. A lap is just `format(currentTime())` added to the list.

Try it: show milliseconds (three digits) instead of hundredths, highlight the
fastest lap, or start and stop with the space bar.

## Layout

```
index.html   the display, three buttons and an empty lap list
app.js       the timing state, format() and the button handlers
styles.css   the look — tabular digits so the numbers don't jiggle
```

## Deploy

Make this folder the root of your own repo (`cp -r devai_boilerplates/stopwatch my-app`,
then `git init` inside it), push it to GitHub, and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — the Web Basics track: HTML, CSS &
JavaScript, one concept at a time. Next up:
[color-picker](https://github.com/devai-io/devai_boilerplates/tree/main/color-picker).
