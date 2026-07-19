// Tip Calculator — reads three inputs, shows two live results.
// The whole idea: whenever an input changes, recalculate and repaint the numbers.

// 1) Grab the elements we need from the page.
const billInput = document.getElementById("bill");
const tipInput = document.getElementById("tip");
const peopleInput = document.getElementById("people");

const tipLabel = document.getElementById("tipLabel");
const tipAmountEl = document.getElementById("tipAmount");
const perPersonEl = document.getElementById("perPerson");

// 2) A helper that formats a number as US dollars: 1234.5 -> "$1,234.50".
const money = (n) =>
  new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(n);

// 3) The one function that does the math and updates the screen.
function calculate() {
  const bill = parseFloat(billInput.value) || 0; // empty box counts as 0
  const tipPct = parseInt(tipInput.value, 10); // the slider, 0 to 30
  const people = Math.max(1, parseInt(peopleInput.value, 10) || 1); // never divide by 0

  const tip = bill * (tipPct / 100);
  const perPerson = (bill + tip) / people;

  tipLabel.textContent = tipPct + "%";
  tipAmountEl.textContent = money(tip);
  perPersonEl.textContent = money(perPerson);
}

// 4) Recalculate on every keystroke or slider move, and once when the page loads.
for (const el of [billInput, tipInput, peopleInput]) {
  el.addEventListener("input", calculate);
}
calculate();
