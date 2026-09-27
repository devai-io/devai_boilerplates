const billInput = document.getElementById("bill");
const tipInput = document.getElementById("tip");
const peopleInput = document.getElementById("people");

const tipLabel = document.getElementById("tipLabel");
const tipAmountEl = document.getElementById("tipAmount");
const perPersonEl = document.getElementById("perPerson");

const money = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" });

// The whole app is one loop: READ the inputs, do the MATH, WRITE the answers
// back onto the page.
function calculate() {
  const bill = parseFloat(billInput.value) || 0; // an empty box counts as 0
  const tipPct = parseInt(tipInput.value, 10);
  const people = Math.max(1, parseInt(peopleInput.value, 10) || 1); // never divide by 0

  const tip = bill * (tipPct / 100);
  const perPerson = (bill + tip) / people;

  tipLabel.textContent = tipPct + "%";
  tipAmountEl.textContent = money.format(tip);
  perPersonEl.textContent = money.format(perPerson);
}

// The key line: "whenever this input changes, run calculate()". That's what
// makes the page react as you type or drag — no framework, no magic.
for (const el of [billInput, tipInput, peopleInput]) {
  el.addEventListener("input", calculate);
}
calculate();
