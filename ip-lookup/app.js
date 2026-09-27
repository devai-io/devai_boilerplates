const statusEl = document.getElementById("status");
const result = document.getElementById("result");
const refresh = document.getElementById("refresh");

// No input at all: ipwho.is looks at the request itself — which IP address it
// came from — and describes that. Whoever opens the page gets their own answer.
async function load() {
  statusEl.textContent = "Loading…";
  result.hidden = true;

  try {
    const res = await fetch("https://ipwho.is/");
    if (!res.ok) throw new Error(`ipwho.is returned ${res.status}`);

    const data = await res.json();

    // This API answers 200 even when a lookup fails, and says so INSIDE the
    // JSON with success: false. So a good status code isn't enough — check it.
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

//   {
//     success: true,
//     ip: "203.0.113.7",
//     city: "Mountain View", region: "California", country: "United States",
//     latitude: 37.3861, longitude: -122.0839,
//     flag: { emoji: "🇺🇸" },
//     connection: { isp: "Google LLC" },
//     timezone: { id: "America/Los_Angeles" },
//   }
function render(d) {
  document.getElementById("ip").textContent = d.ip;
  document.getElementById("location").textContent =
    [d.city, d.region].filter(Boolean).join(", ") || "Unknown";
  document.getElementById("country").textContent = `${d.flag?.emoji || ""} ${d.country}`.trim();
  document.getElementById("isp").textContent = d.connection?.isp || "Unknown";
  document.getElementById("timezone").textContent = d.timezone?.id || "Unknown";

  document.getElementById("map").href =
    `https://www.openstreetmap.org/?mlat=${d.latitude}&mlon=${d.longitude}` +
    `#map=10/${d.latitude}/${d.longitude}`;

  result.hidden = false;
}

refresh.addEventListener("click", load);

load();
