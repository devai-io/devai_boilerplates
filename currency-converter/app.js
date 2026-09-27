const amountInput = document.getElementById("amount");
const fromSelect = document.getElementById("from");
const toSelect = document.getElementById("to");
const rateEl = document.getElementById("rate");
const convertedEl = document.getElementById("converted");
const statusEl = document.getElementById("status");

const API = "https://api.frankfurter.dev/v1";

const money = (n, currency) =>
  new Intl.NumberFormat("en-US", { style: "currency", currency }).format(n);

// The rate for the chosen pair. Typing an amount only multiplies by it; the API
// is asked again only when a dropdown changes. null = no rate yet.
let rate = null;
let rateDate = "";

async function loadCurrencies() {
  statusEl.textContent = "Loading…";

  try {
    const res = await fetch(`${API}/currencies`);
    if (!res.ok) throw new Error(`Currencies returned ${res.status}`);

    // { "AUD": "Australian Dollar", "BRL": "Brazilian Real", … }
    const currencies = await res.json();
    for (const [code, name] of Object.entries(currencies)) {
      fromSelect.append(new Option(`${code} — ${name}`, code));
      toSelect.append(new Option(`${code} — ${name}`, code));
    }
    fromSelect.value = "USD";
    toSelect.value = "EUR";

    statusEl.textContent = "";
    loadRate();
  } catch (err) {
    statusEl.textContent = "Couldn't load the currency list. Try again in a moment.";
    console.error(err);
  }
}

async function loadRate() {
  const from = fromSelect.value;
  const to = toSelect.value;
  rate = null;

  if (from === to) {
    rate = 1;
    rateDate = "";
    showResult();
    return;
  }

  showResult();
  statusEl.textContent = "Loading rate…";

  try {
    // QUERY PARAMETERS: everything after the "?" is name=value pairs joined by
    // "&". They tell the same endpoint WHAT you want: here, from which currency
    // to which. Change the values and you get a different answer.
    const res = await fetch(`${API}/latest?from=${from}&to=${to}`);
    if (!res.ok) throw new Error(`Rate returned ${res.status}`);

    // { amount: 1, base: "USD", date: "2026-09-25", rates: { EUR: 0.87696 } }
    const data = await res.json();
    if (from !== fromSelect.value || to !== toSelect.value) return; // pair changed meanwhile

    rate = data.rates[to];
    rateDate = data.date;
    statusEl.textContent = "";
    showResult();
  } catch (err) {
    statusEl.textContent = "Couldn't get the rate. Try again in a moment.";
    console.error(err);
  }
}

function showResult() {
  if (rate === null) {
    rateEl.textContent = "";
    convertedEl.textContent = "—";
    return;
  }
  const amount = parseFloat(amountInput.value) || 0;
  const to = toSelect.value;
  rateEl.textContent = `1 ${fromSelect.value} = ${rate} ${to}` + (rateDate ? ` · ECB rate of ${rateDate}` : "");
  convertedEl.textContent = money(amount * rate, to);
}

amountInput.addEventListener("input", showResult);
fromSelect.addEventListener("change", loadRate);
toSelect.addEventListener("change", loadRate);

loadCurrencies();
