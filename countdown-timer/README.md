# countdown-timer

A live countdown to any moment you pick — days, hours, minutes and seconds,
ticking away. It's your first look at doing something on a timer with
`setInterval`, and at doing arithmetic with dates.

## Run

Get it: `git clone https://git.devai.io/templates/countdown-timer.git`

Double-click `index.html` — it opens in your browser and works. Nothing to
install, no build step.

Or serve it like production:

```sh
docker compose up --build
```

Then open http://localhost:8080.

## How it works

`setInterval(tick, 1000)` asks the browser to run `tick()` every second. Each
tick subtracts two dates — `target - new Date()` gives the milliseconds between
them — and splits that gap into days (86,400 seconds), hours (3,600), minutes
and seconds with `Math.floor` and `%` (the remainder).

`setInterval` returns an id; `clearInterval(id)` stops it. The code clears the
old timer before starting a new one whenever you pick a date, and stops the
clock for good when it reaches zero. It counts down to next New Year until you
choose something else.

Try it: count down to your birthday with `new Date("2027-05-01")`, add a
"Reset to New Year" button, or make the seconds pulse by toggling a CSS class
on each tick.

## Layout

```
index.html   the date picker and the four number boxes
app.js       tick(), start(), and the interval they share
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
[dark-mode-toggle](https://git.devai.io/templates/dark-mode-toggle).
