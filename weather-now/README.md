# weather-now

> Type any city and see the temperature, sky, humidity and wind right now — using
> two real weather APIs, one feeding the other.

**What you'll build:** a search box where you type a city name and instantly get its
current weather: a big temperature, a friendly "Partly cloudy ⛅" label, plus humidity
and wind.

**What you'll learn:** how to _chain_ two API calls — where the answer from the first
request becomes the input to the second. Real apps do this constantly. You'll also
turn cryptic API codes (weather is reported as plain numbers!) into words a human can
read.

## Run it

**The easy way:** double-click `index.html`. It works as long as you have internet,
because it calls the weather services live.

**With Docker:**

```sh
docker build -t weather-now .
docker run -p 8080:80 weather-now   # then open http://localhost:8080
```

## The idea in 30 seconds

An **API** is a URL that returns data instead of a web page. The catch: the weather
API doesn't know what "London" means — it only speaks in coordinates. So we ask two
questions in a row.

First, "where is London?" Open this in your browser to see the raw JSON:
<https://geocoding-api.open-meteo.com/v1/search?name=London&count=1&language=en&format=json>

That gives back a `latitude` and `longitude`. Then we ask the second API, "what's the
weather at those coordinates?":
<https://api.open-meteo.com/v1/forecast?latitude=51.5&longitude=-0.13&current=temperature_2m,weather_code>

```js
const place = geo.results[0]; // { name, country, latitude, longitude }
const weather = await getWeatherAt(place.latitude, place.longitude);
```

That two-step dance — look something up, then use the answer — is the whole lesson.

## How the code works

- **Step 1 (geocode).** We `fetch()` the search URL. The reply has a `results` array;
  `results[0]` is the best match. If `results` is missing or empty, the city wasn't
  found and we say so instead of crashing.
- **Step 2 (weather).** We take `results[0].latitude` and `.longitude` and drop them
  into the forecast URL, then `fetch()` that. The reply's `current` object holds
  `temperature_2m`, `relative_humidity_2m`, `wind_speed_10m` and `weather_code`.
- **`WEATHER_CODES`** is a small lookup object. The API reports the sky as a WMO code
  (`0` = clear, `61` = light rain, `95` = thunderstorm…). We translate the number into
  a label and an emoji.
- **`await`** makes each call finish before the next line runs, so step 2 always has
  step 1's coordinates. The whole thing sits inside `try / catch` so a dropped
  connection shows a message, not a blank screen.

## Try changing something

- Switch to Fahrenheit: add `&temperature_unit=fahrenheit` to the forecast URL and
  change the `°C` label in `render`.
- Show `count=5` in the geocode URL and list the matches so the user can pick the
  right "Springfield."
- Add more `weather_code` entries (see the full WMO list) or swap in your own emoji.

## A note on limits

Open-Meteo is free and needs no key for this kind of use. If you refresh very rapidly
you might briefly get an error response — that's why every call checks `res.ok` and
falls into the friendly `catch` message.

## Files

```
index.html    the search box and the (hidden until loaded) weather card
styles.css    how it looks (light + dark)
app.js        chain the two fetches, map the code, render it
Dockerfile    optional: serve it with nginx
```
