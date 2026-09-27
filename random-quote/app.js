const quoteEl = document.getElementById("quote");
const authorEl = document.getElementById("author");
const button = document.getElementById("new");
const statusEl = document.getElementById("status");

let quotes = [];
let lastIndex = -1;

// fetch() a LOCAL data file — the exact pattern you'd use for a live API. Swap
// "quotes.json" for a real URL and the rest of this function stays the same.
async function loadQuotes() {
  statusEl.textContent = "Loading…";

  try {
    const res = await fetch("quotes.json");
    if (!res.ok) throw new Error(`Could not load quotes (${res.status})`);

    quotes = await res.json(); // an array of { text, author }
    if (!Array.isArray(quotes) || quotes.length === 0) {
      statusEl.textContent = "No quotes found.";
      return;
    }

    statusEl.textContent = "";
    showRandom();
  } catch (err) {
    // Usually this means the page was opened straight from disk (file://),
    // where browsers refuse to fetch() other files. Serve the folder instead.
    statusEl.textContent = "Couldn't load the quotes. Serve this folder with a local server (see the README).";
    console.error(err);
  }
}

function showRandom() {
  if (quotes.length === 0) return;

  // Math.random() is 0 to 0.999…; times the length, rounded down, is a valid index.
  let index = Math.floor(Math.random() * quotes.length);
  while (quotes.length > 1 && index === lastIndex) {
    index = Math.floor(Math.random() * quotes.length); // never the same one twice in a row
  }
  lastIndex = index;

  quoteEl.textContent = quotes[index].text;
  authorEl.textContent = "— " + quotes[index].author;
}

button.addEventListener("click", showRandom);

loadQuotes();
