// Random Quote Machine — show a quote, click the button for another.
// Concept: fetch() a LOCAL data file (quotes.json) and pick a random item.
// This is the EXACT same pattern you'd use for a live API on the internet —
// only the URL is different. Swap "quotes.json" for a real endpoint and the
// rest of the code barely changes.

const quoteEl = document.getElementById("quote");
const authorEl = document.getElementById("author");
const button = document.getElementById("new");
const statusEl = document.getElementById("status");

let quotes = []; // filled in once the file loads
let lastIndex = -1; // remember the last pick so we don't repeat it immediately

async function loadQuotes() {
  statusEl.textContent = "Loading…";

  try {
    // fetch() works on your own files too. "quotes.json" sits next to this page.
    const res = await fetch("quotes.json");
    if (!res.ok) throw new Error(`Could not load quotes (${res.status})`);

    quotes = await res.json(); // an array of { text, author } objects
    if (!Array.isArray(quotes) || quotes.length === 0) {
      statusEl.textContent = "No quotes found.";
      return;
    }

    statusEl.textContent = "";
    showRandom();
  } catch (err) {
    // The most common cause here is opening the file via file:// — some browsers
    // block reading local files that way. The README shows the one-line fix.
    statusEl.textContent =
      "Couldn't load the quotes. Try running a local server (see the README).";
    console.error(err);
  }
}

// Pick a random quote and put it on the page.
function showRandom() {
  if (quotes.length === 0) return; // nothing loaded yet

  // Math.random() gives 0–0.999…; multiply by the length to get a valid index.
  let index = Math.floor(Math.random() * quotes.length);

  // If we happened to pick the same one, roll again (only matters with 2+ quotes).
  while (quotes.length > 1 && index === lastIndex) {
    index = Math.floor(Math.random() * quotes.length);
  }
  lastIndex = index;

  const quote = quotes[index];
  quoteEl.textContent = quote.text;
  authorEl.textContent = "— " + quote.author;
}

button.addEventListener("click", showRandom);

// Load the file once when the page opens.
loadQuotes();
