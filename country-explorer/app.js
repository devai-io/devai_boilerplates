// Country Explorer — type a country name, fetch the facts, show them.
// Concept: search an API, then render a rich object — including an image it gives you.

const form = document.getElementById("form");
const input = document.getElementById("query");
const country = document.getElementById("country");
const statusEl = document.getElementById("status");

async function search(name) {
  statusEl.textContent = "Loading…";
  country.hidden = true;

  try {
    // countries.dev is a free, no-key country database.
    // encodeURIComponent keeps spaces and odd characters from breaking the URL.
    const res = await fetch(
      `https://countries.dev/name/${encodeURIComponent(name)}`,
    );

    if (res.status === 404) {
      // No country matched what was typed.
      statusEl.textContent = `No country found for "${name}".`;
      return;
    }
    if (!res.ok) {
      throw new Error(`countries.dev returned ${res.status}`);
    }

    // The answer is an ARRAY of matches (searching "united" finds several).
    // We show the first, closest match: data[0].
    const data = await res.json();
    render(data[0]);
    statusEl.textContent = "";
  } catch (err) {
    statusEl.textContent = "Something went wrong. Try again in a moment.";
    console.error(err);
  }
}

// One match looks roughly like this — a rich object with a few tricky corners:
//
//   {
//     name: "Japan",
//     capital: "Tokyo",
//     population: 125836021,
//     region: "Asia",
//     subregion: "Eastern Asia",
//     flags: { svg: "https://flagcdn.com/jp.svg" },        // an image URL!
//     languages: [ { name: "Japanese" } ],                 // an ARRAY of objects
//     currencies: [ { code: "JPY", name: "Japanese yen" } ],
//     latlng: [ 36, 138 ]                                  // [lat, lng]
//   }
function render(c) {
  const flag = document.getElementById("flag");
  flag.src = c.flags.svg; // the flag image the API hands us — we just point <img> at it
  flag.alt = `Flag of ${c.name}`;

  document.getElementById("name").textContent = c.name;
  document.getElementById("region").textContent = c.subregion
    ? `${c.region} · ${c.subregion}`
    : c.region;

  // A few places have no single capital — fall back to a dash.
  document.getElementById("capital").textContent = c.capital || "—";

  // toLocaleString adds thousands separators: 125836021 → "125,836,021".
  document.getElementById("population").textContent = c.population.toLocaleString();

  // languages is an ARRAY of objects like [{ name: "Japanese" }]. We map each
  // object down to its .name, then join the names into one line.
  document.getElementById("languages").textContent = c.languages?.length
    ? c.languages.map((lang) => lang.name).join(", ")
    : "—";

  // currencies is the same shape — an array of objects, each with a .name.
  document.getElementById("currencies").textContent = c.currencies?.length
    ? c.currencies.map((money) => money.name).join(", ")
    : "—";

  // Build an OpenStreetMap link from the [lat, lng] the API gives us.
  const map = document.getElementById("map");
  if (Array.isArray(c.latlng) && c.latlng.length === 2) {
    const [lat, lng] = c.latlng;
    map.href = `https://www.openstreetmap.org/?mlat=${lat}&mlon=${lng}#map=5/${lat}/${lng}`;
    map.hidden = false;
  } else {
    map.hidden = true;
  }

  country.hidden = false;
}

form.addEventListener("submit", (event) => {
  event.preventDefault(); // stop the form from reloading the page
  const name = input.value.trim();
  if (name) search(name);
});

// Show one country on first load so the page isn't empty.
search("Japan");
