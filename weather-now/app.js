const form = document.getElementById("form");
const input = document.getElementById("city");
const card = document.getElementById("card");
const statusEl = document.getElementById("status");

// The API reports the sky as a WMO "weather code" number; this turns the common
// ones into words and an emoji.
const WEATHER_CODES = {
  0: { text: "Clear", icon: "☀️" },
  1: { text: "Mainly clear", icon: "🌤️" },
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

function describe(code) {
  return WEATHER_CODES[code] || { text: "Unknown", icon: "❓" };
}

// Two CHAINED calls: the answer to the first is the question for the second.
// Weather is looked up by coordinates, not names, so first we ask a geocoding
// API where the city is, then feed its latitude/longitude to the forecast API.
async function loadWeather(city) {
  statusEl.textContent = "Loading…";
  card.hidden = true;

  try {
    // Call 1 — city name → coordinates.
    const geoRes = await fetch(
      `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(city)}&count=1&language=en&format=json`,
    );
    if (!geoRes.ok) throw new Error(`Geocoding returned ${geoRes.status}`);

    const geo = await geoRes.json();
    if (!geo.results || geo.results.length === 0) {
      statusEl.textContent = "City not found.";
      return;
    }
    const place = geo.results[0]; // { name, country, latitude, longitude, … }

    // Call 2 — coordinates → current weather.
    const weatherRes = await fetch(
      `https://api.open-meteo.com/v1/forecast?latitude=${place.latitude}&longitude=${place.longitude}&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code`,
    );
    if (!weatherRes.ok) throw new Error(`Weather returned ${weatherRes.status}`);

    const weather = await weatherRes.json();
    render(place, weather.current);
    statusEl.textContent = "";
  } catch (err) {
    statusEl.textContent = "Something went wrong. Try again in a moment.";
    console.error(err);
  }
}

function render(place, current) {
  const sky = describe(current.weather_code);
  document.getElementById("place").textContent = [place.name, place.country]
    .filter(Boolean)
    .join(", ");
  document.getElementById("icon").textContent = sky.icon;
  document.getElementById("temp").textContent = `${Math.round(current.temperature_2m)}°C`;
  document.getElementById("condition").textContent = sky.text;
  document.getElementById("humidity").textContent = `${current.relative_humidity_2m}%`;
  document.getElementById("wind").textContent = `${current.wind_speed_10m} km/h`;
  card.hidden = false;
}

form.addEventListener("submit", (event) => {
  event.preventDefault();
  const city = input.value.trim();
  if (city) loadWeather(city);
});

loadWeather("London");
