// Currency Converter — type an amount, pick two currencies, see the conversion.
// Concept: QUERY PARAMETERS. We build a URL ending in ?from=USD&to=EUR and the
// API answers with today's exchange rate. Then it's simple math: amount × rate.

const amountInput = document.getElementById("amount");
const fromSelect = document.getElementById("from");
const toSelect = document.getElementById("to");
const rateEl = document.getElementById("rate");
const convertedEl = document.getElementById("converted");
const statusEl = document.getElementById("status");

// Format a number as money in the given currency: (0.92, "EUR") -> "€0.92".
const money = (n, currency) =>
  new Intl.NumberFormat("en-US", { style: "currency", currency }).format(n);

// STEP 1 — fill both dropdowns from the list of currencies the API supports.
async function loadCurrencies() {
  statusEl.textContent = "Loading…";

  try {
    const res = await fetch("https://api.frankfurter.dev/v1/currencies");
    if (!res.ok) throw new Error(`Currencies returned ${res.status}`);

    // An object mapping code -> name, e.g. { "USD": "United States Dollar", ... }
    const currencies = await res.json();
    const codes = Object.keys(currencies); // ["AUD", "BGN", ..., "USD", ...]

    for (const code of codes) {
      // Add one <option> to each dropdown. cloneNode(true) copies it for the second.
      const option = makeOption(code, currencies[code]);
      fromSelect.appendChild(option);
      toSelect.appendChild(option.cloneNode(true));
    }

    // Sensible starting pair.
    fromSelect.value = "USD";
    toSelect.value = "EUR";

    statusEl.textContent = "";
    convert();
  } catch (err) {
    statusEl.textContent = "Couldn't load the currency list. Try again in a moment.";
    console.error(err);
  }
}

function makeOption(code, name) {
  const option = document.createElement("option");
  option.value = code;
  option.textContent = `${code} — ${name}`;
  return option;
}

// STEP 2 — fetch the rate for the chosen pair and update the result.
async function convert() {
  const from = fromSelect.value;
  const to = toSelect.value;
  const amount = parseFloat(amountInput.value) || 0; // empty box counts as 0

  // Same currency on both sides? The rate is exactly 1 — no API call needed.
  if (from === to) {
    rateEl.textContent = `1 ${from} = 1 ${to}`;
    convertedEl.textContent = money(amount, to);
    return;
  }

  statusEl.textContent = "Converting…";

  try {
    // Everything after the "?" is the query string. Each name=value is a parameter.
    const res = await fetch(`https://api.frankfurter.dev/v1/latest?from=${from}&to=${to}`);
    if (!res.ok) throw new Error(`Rate returned ${res.status}`);

    // { amount: 1, base: "USD", date: "…", rates: { EUR: 0.92 } }
    const data = await res.json();
    const rate = data.rates[to];

    rateEl.textContent = `1 ${from} = ${rate} ${to}`;
    convertedEl.textContent = money(amount * rate, to);
    statusEl.textContent = "";
  } catch (err) {
    statusEl.textContent = "Couldn't get the rate. Try again in a moment.";
    console.error(err);
  }
}

// Recompute whenever the amount is typed in or a dropdown changes.
amountInput.addEventListener("input", convert);
fromSelect.addEventListener("change", convert);
toSelect.addEventListener("change", convert);

// Kick everything off: load the currency list, which then runs the first convert().
loadCurrencies();
