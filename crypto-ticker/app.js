// Crypto Price Ticker — live coin prices that refresh on a timer.
// Concept: POLLING. Nothing is "pushed" to us; we simply ask the API again
// every 30 seconds and repaint the numbers. setInterval is the heartbeat.

const rowsEl = document.getElementById("rows");
const statusEl = document.getElementById("status");
const updatedEl = document.getElementById("updated");

// The coins we track. `id` is the name CoinGecko uses in the URL.
const COINS = [
  { id: "bitcoin", name: "Bitcoin", symbol: "BTC" },
  { id: "ethereum", name: "Ethereum", symbol: "ETH" },
  { id: "solana", name: "Solana", symbol: "SOL" },
  { id: "dogecoin", name: "Dogecoin", symbol: "DOGE" },
];

// Join the ids into the comma list the API wants: "bitcoin,ethereum,solana,dogecoin".
const ids = COINS.map((coin) => coin.id).join(",");

// Format a number as US dollars. Cheap coins get more decimals so they aren't "$0.00".
const money = (n) =>
  new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: n < 1 ? 4 : 2,
  }).format(n);

async function refresh() {
  try {
    const res = await fetch(
      `https://api.coingecko.com/api/v3/simple/price?ids=${ids}&vs_currencies=usd&include_24h_change=true`,
    );

    // 429 = "too many requests." Free APIs throttle you if you ask too often.
    // Keep the last good prices on screen and just note it — don't blank the page.
    if (res.status === 429) {
      statusEl.textContent = "Rate limited — showing the last prices. Retrying soon…";
      return;
    }
    if (!res.ok) throw new Error(`CoinGecko returned ${res.status}`);

    // Shape: { bitcoin: { usd: 65000, usd_24h_change: 1.8 }, ethereum: {...}, ... }
    const data = await res.json();
    render(data);
    statusEl.textContent = "";
    updatedEl.textContent = "Last updated " + new Date().toLocaleTimeString();
  } catch (err) {
    // A dropped connection lands here; the old rows stay put until the next tick.
    statusEl.textContent = "Couldn't reach the price service. Retrying soon…";
    console.error(err);
  }
}

// Clear the list and rebuild one row per coin.
function render(data) {
  rowsEl.innerHTML = "";

  for (const coin of COINS) {
    const info = data[coin.id];
    if (!info) continue; // skip anything the API didn't send back

    const price = info.usd;
    const change = info.usd_24h_change; // a percent, positive or negative
    const up = change >= 0;

    const row = document.createElement("div");
    row.className = "row";
    // coin.name / .symbol are our own constants (not user input), so template
    // strings here are safe.
    row.innerHTML = `
      <div class="coin">
        <strong>${coin.name}</strong>
        <span>${coin.symbol}</span>
      </div>
      <div class="price">${money(price)}</div>
      <div class="change ${up ? "up" : "down"}">
        ${up ? "▲" : "▼"} ${Math.abs(change).toFixed(2)}%
      </div>`;
    rowsEl.appendChild(row);
  }
}

// Do the first load immediately, then poll every 30 seconds (30000 milliseconds).
refresh();
setInterval(refresh, 30000);
