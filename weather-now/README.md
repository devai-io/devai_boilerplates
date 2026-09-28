# weather-now

Type any city and see its temperature, sky, humidity and wind right now, from
the free Open-Meteo APIs. It teaches chaining two API calls: the answer to the
first becomes the question for the second.

## Run

Get it: `git clone https://github.com/devai-io/devai_boilerplates.git`, then `cd devai_boilerplates/weather-now`

Double-click `index.html` — it opens in your browser and works, as long as
you're online (it calls the weather service live). Nothing to install.

Or serve it like production:

```sh
docker compose up --build
```

Then open http://localhost:8080.

## How it works

Weather is looked up by coordinates, not city names, so `loadWeather(city)`
makes two requests, one after the other:

1. **Geocode** — `geocoding-api.open-meteo.com/v1/search?name=Tokyo` answers
   with the best match's `latitude` and `longitude`.
2. **Forecast** — those numbers go into
   `api.open-meteo.com/v1/forecast?latitude=…&longitude=…&current=…`, which
   answers with the current temperature, humidity, wind and a `weather_code`.

`await` makes the second call wait for the first. The weather code is a WMO
number (`0` = clear, `61` = light rain, …); `WEATHER_CODES` maps the common
ones to words and an emoji. `encodeURIComponent` keeps spaces and accents in a
city name from breaking the URL. Both APIs are free and need no key.

"Loading…" shows while the requests run, "City not found." when geocoding has
no match, and a friendly error if either call fails.

Try it: add `&temperature_unit=fahrenheit` to the forecast URL, ask for
`count=5` and let the user pick between matches, or add more weather codes.

## Layout

```
index.html   the search form, a status line and a hidden weather card
app.js       the code table, loadWeather() and render()
styles.css   the look; follows your system's light or dark mode
```

## Deploy

Make this folder the root of your own repo (`cp -r devai_boilerplates/weather-now my-app`,
then `git init` inside it), push it to GitHub, and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — the APIs & Data track: fetch real data
from the internet. Next up:
[github-profile](https://github.com/devai-io/devai_boilerplates/tree/main/github-profile).
