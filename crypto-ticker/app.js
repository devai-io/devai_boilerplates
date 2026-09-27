const rowsEl = document.getElementById("rows");
const statusEl = document.getElementById("status");
const updatedEl = document.getElementById("updated");

// `id` is the name CoinGecko uses for each coin in its URLs.
const COINS = [
  { id: "bitcoin", name: "Bitcoin", symbol: "BTC" },
  { id: "ethereum", name: "Ethereum", symbol: "ETH" },
  { id: "solana", name: "Solana", symbol: "SOL" },
  { id: "dogecoin", name: "Dogecoin", symbol: "DOGE" },
];
const ids = COINS.map((coin) => coin.id).join(",");

// Cheap coins get more decimals so they don't all read "$0.10".
const money = (n) =>
  new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: n < 1 ? 4 : 2,
  }).format(n);

// POLLING: nothing is pushed to us, so we simply ask again on a timer. Each
// refresh() is one ordinary fetch; setInterval (at the bottom) is the heartbeat.
async function refresh() {
  try {
    const res = await fetch(
      `https://api.coingecko.com/api/v3/simple/price?ids=${ids}&vs_currencies=usd&include_24hr_change=true`,
    );

    // 429 = "too many requests": free APIs throttle you if you poll too often.
    // Keep the last good prices on screen and try again on the next tick.
    if (res.status === 429) {
      statusEl.textContent = "Rate limited — showing the last prices. Retrying soon…";
      return;
    }
    if (!res.ok) throw new Error(`CoinGecko returned ${res.status}`);

    // { bitcoin: { usd: 84557, usd_24h_change: 0.57 }, ethereum: { … }, … }
    const data = await res.json();
    render(data);
    statusEl.textContent = "";
    updatedEl.textContent = "Last updated " + new Date().toLocaleTimeString();
  } catch (err) {
    statusEl.textContent = "Couldn't reach the price service. Retrying soon…";
    console.error(err);
  }
}

function el(tag, className, text = "") {
  const node = document.createElement(tag);
  node.className = className;
  node.textContent = text;
  return node;
}

function render(data) {
  const rows = [];

  for (const coin of COINS) {
    const info = data[coin.id];
    if (typeof info?.usd !== "number") continue; // skip anything the API didn't send

    const name = el("div", "coin");
    name.append(el("strong", "", coin.name), el("span", "", coin.symbol));

    const change = el("div", "change", "—");
    if (typeof info.usd_24h_change === "number") {
      const up = info.usd_24h_change >= 0;
      change.classList.add(up ? "up" : "down");
      change.textContent = `${up ? "▲" : "▼"} ${Math.abs(info.usd_24h_change).toFixed(2)}%`;
    }

    const row = el("div", "row");
    row.append(name, el("div", "price", money(info.usd)), change);
    rows.push(row);
  }

  rowsEl.replaceChildren(...rows);
}

refresh();
setInterval(refresh, 30000);
