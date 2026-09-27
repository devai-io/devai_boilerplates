const form = document.getElementById("form");
const input = document.getElementById("query");
const country = document.getElementById("country");
const statusEl = document.getElementById("status");

async function search(name) {
  statusEl.textContent = "Loading…";
  country.hidden = true;

  try {
    const res = await fetch(`https://countries.dev/name/${encodeURIComponent(name)}`);

    if (res.status === 404) {
      statusEl.textContent = `No country found for "${name}".`;
      return;
    }
    if (!res.ok) throw new Error(`countries.dev returned ${res.status}`);

    // An ARRAY of every country whose name contains the search ("united" finds
    // five). We show the first one.
    const data = await res.json();
    render(data[0]);
    statusEl.textContent = "";
  } catch (err) {
    statusEl.textContent = "Something went wrong. Try again in a moment.";
    console.error(err);
  }
}

// One country is a RICH object: plain values, nested objects, arrays of objects,
// and fields that are sometimes null. Rendering it is picking each piece apart.
//
//   {
//     name: "Japan",
//     capital: "Tokyo",                                   // null for Antarctica
//     population: 125836021,
//     region: "Asia", subregion: "Eastern Asia",
//     flags: { svg: "https://flagcdn.com/jp.svg" },       // an image URL
//     languages: [{ name: "Japanese" }],                  // an array of objects
//     currencies: [{ code: "JPY", name: "Japanese yen" }],
//     latlng: [36, 138],
//   }
function render(c) {
  // The API hands us a URL; pointing an <img> at it is all it takes.
  const flag = document.getElementById("flag");
  flag.src = c.flags?.svg || "";
  flag.alt = `Flag of ${c.name}`;

  document.getElementById("name").textContent = c.name;
  document.getElementById("region").textContent = c.subregion
    ? `${c.region} · ${c.subregion}`
    : c.region;
  document.getElementById("capital").textContent = c.capital || "—";

  // toLocaleString adds the thousands separators: 125836021 → "125,836,021".
  document.getElementById("population").textContent = c.population?.toLocaleString() || "—";

  // Arrays of objects: map each object down to its .name, then join them.
  document.getElementById("languages").textContent = c.languages?.length
    ? c.languages.map((lang) => lang.name).join(", ")
    : "—";
  document.getElementById("currencies").textContent = c.currencies?.length
    ? c.currencies.map((money) => money.name).join(", ")
    : "—";

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
  event.preventDefault();
  const name = input.value.trim();
  if (name) search(name);
});

search("Japan");
