// What's My IP & Location — ask an API to describe YOUR OWN connection.
// Concept: some APIs read facts about the request you send, so you pass no input.

const statusEl = document.getElementById("status");
const result = document.getElementById("result");
const refresh = document.getElementById("refresh");

async function load() {
  statusEl.textContent = "Loading…";
  result.hidden = true;

  try {
    // ipwho.is looks at where THIS request came from — no parameters needed.
    // Whatever computer opens the page is the one it describes.
    const res = await fetch("https://ipwho.is/");

    if (!res.ok) {
      throw new Error(`ipwho.is returned ${res.status}`);
    }

    const data = await res.json();

    // This API answers 200 even when something's off. It flags trouble with a
    // `success: false` field inside the JSON, so we check that ourselves.
    if (data.success === false) {
      statusEl.textContent = data.message || "Couldn't look up your address.";
      return;
    }

    render(data);
    statusEl.textContent = "";
  } catch (err) {
    statusEl.textContent = "Something went wrong. Try again in a moment.";
    console.error(err);
  }
}

// The data describes your connection:
//   {
//     success: true,
//     ip: "203.0.113.7",
//     city: "Mountain View",
//     region: "California",
//     country: "United States",
//     latitude: 37.3861,  longitude: -122.0839,
//     flag: { emoji: "🇺🇸" },
//     connection: { isp: "Google LLC" },
//     timezone: { id: "America/Los_Angeles" }
//   }
function render(d) {
  document.getElementById("ip").textContent = d.ip;

  // city and region can be blank on some networks — filter out the empties,
  // then join what's left with a comma.
  document.getElementById("location").textContent =
    [d.city, d.region].filter(Boolean).join(", ") || "Unknown";

  // flag.emoji is just an emoji character, so it's safe to show as text.
  document.getElementById("country").textContent =
    `${d.flag?.emoji || ""} ${d.country}`.trim();

  // isp and timezone live one level down, inside nested objects. `?.` keeps the
  // page from crashing if either object is missing.
  document.getElementById("isp").textContent = d.connection?.isp || "Unknown";
  document.getElementById("timezone").textContent = d.timezone?.id || "Unknown";

  // Build an OpenStreetMap link centered on the coordinates the API returned.
  const map = document.getElementById("map");
  map.href =
    `https://www.openstreetmap.org/?mlat=${d.latitude}&mlon=${d.longitude}` +
    `#map=10/${d.latitude}/${d.longitude}`;

  result.hidden = false;
}

// The button just runs the same fetch again.
refresh.addEventListener("click", load);

// Look yourself up as soon as the page opens.
load();
