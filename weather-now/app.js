// Weather Right Now — type a city, see its current weather.
// Concept: CHAINING two API calls. First we look up WHERE the city is
// (its latitude/longitude), then we use that answer to ask a second API
// what the weather is there. The output of call #1 feeds call #2.

const form = document.getElementById("form");
const input = document.getElementById("city");
const card = document.getElementById("card");
const statusEl = document.getElementById("status");

// Weather services report the sky as a WMO "weather code" — just a number.
// This lookup turns each number into a short label and an emoji a human
// can read. We only list the common ones; anything else falls back below.
const WEATHER_CODES = {
  0: { text: "Clear", icon: "☀️" },
  1: { text: "Partly cloudy", icon: "⛅" },
  2: { text: "Partly cloudy", icon: "⛅" },
  3: { text: "Overcast", icon: "☁️" },
  45: { text: "Fog", icon: "🌫️" },
  48: { text: "Fog", icon: "🌫️" },
  51: { text: "Light drizzle", icon: "🌧️" },
  53: { text: "Drizzle", icon: "🌧️" },
  55: { text: "Heavy drizzle", icon: "🌧️" },
  56: { text: "Freezing drizzle", icon: "🌧️" },
  57: { text: "Freezing drizzle", icon: "🌧️" },
  61: { text: "Light rain", icon: "🌧️" },
  63: { text: "Rain", icon: "🌧️" },
  65: { text: "Heavy rain", icon: "🌧️" },
  66: { text: "Freezing rain", icon: "🌧️" },
  67: { text: "Freezing rain", icon: "🌧️" },
  71: { text: "Light snow", icon: "❄️" },
  73: { text: "Snow", icon: "❄️" },
  75: { text: "Heavy snow", icon: "❄️" },
  77: { text: "Snow grains", icon: "❄️" },
  80: { text: "Showers", icon: "🌦️" },
  81: { text: "Showers", icon: "🌦️" },
  82: { text: "Heavy showers", icon: "🌦️" },
  85: { text: "Snow showers", icon: "❄️" },
  86: { text: "Snow showers", icon: "❄️" },
  95: { text: "Thunderstorm", icon: "⛈️" },
  96: { text: "Thunderstorm", icon: "⛈️" },
  99: { text: "Thunderstorm", icon: "⛈️" },
};

// Look up a code, or return a safe default if we've never seen it.
function describe(code) {
  return WEATHER_CODES[code] || { text: "Unknown", icon: "❓" };
}

async function loadWeather(city) {
  statusEl.textContent = "Loading…";
  card.hidden = true;

  try {
    // STEP 1 — GEOCODE: turn the city name into coordinates.
    // encodeURIComponent keeps spaces and odd characters from breaking the URL.
    const geoRes = await fetch(
      `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(city)}&count=1&language=en&format=json`,
    );
    if (!geoRes.ok) throw new Error(`Geocoding returned ${geoRes.status}`);

    const geo = await geoRes.json();
    // When nothing matches, `results` is missing entirely or is an empty array.
    if (!geo.results || geo.results.length === 0) {
      statusEl.textContent = "City not found.";
      return;
    }

    // results[0] = { name, country, latitude, longitude, ... } — the best match.
    const place = geo.results[0];

    // STEP 2 — WEATHER: feed those coordinates into the forecast API.
    const weatherRes = await fetch(
      `https://api.open-meteo.com/v1/forecast?latitude=${place.latitude}&longitude=${place.longitude}&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code`,
    );
    if (!weatherRes.ok) throw new Error(`Weather returned ${weatherRes.status}`);

    const weather = await weatherRes.json();
    // `weather.current` = { temperature_2m, relative_humidity_2m, wind_speed_10m, weather_code }
    render(place, weather.current);
    statusEl.textContent = "";
  } catch (err) {
    statusEl.textContent = "Something went wrong. Try again in a moment.";
    console.error(err);
  }
}

// Copy the numbers from both calls onto the page.
function render(place, current) {
  const sky = describe(current.weather_code);
  document.getElementById("place").textContent = `${place.name}, ${place.country}`;
  document.getElementById("icon").textContent = sky.icon;
  document.getElementById("temp").textContent = `${Math.round(current.temperature_2m)}°C`;
  document.getElementById("condition").textContent = sky.text;
  document.getElementById("humidity").textContent = `${current.relative_humidity_2m}%`;
  document.getElementById("wind").textContent = `${current.wind_speed_10m} km/h`;
  card.hidden = false;
}

form.addEventListener("submit", (event) => {
  event.preventDefault(); // stop the form from reloading the page
  const city = input.value.trim();
  if (city) loadWeather(city);
});

// Show one city on first load so the page isn't empty.
loadWeather("London");
