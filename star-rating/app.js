// Star Rating — a hover-preview widget that remembers your choice.
// Concepts: the difference between a *previewed* value and a *committed* one,
// keyboard support with real <button>s, and saving to localStorage.

// 1) Grab the row, the five star buttons, and the output line.
const row = document.getElementById("stars");
const stars = [...row.querySelectorAll(".star")]; // spread turns the NodeList into an array
const output = document.getElementById("output");

// 2) The committed rating. Restore last time's if the browser saved one.
//    localStorage only stores strings, so Number() turns "4" back into 4.
let selected = Number(localStorage.getItem("rating")) || 0;

// 3) Fill every star up to `value` (1-based), empty the rest. This is the ONLY
//    thing that changes what you see — both hover and click route through it.
function paint(value) {
  stars.forEach((star, index) => {
    star.classList.toggle("on", index < value);
  });
}

// 4) Commit a choice: remember it, save it, update the words, and repaint.
function commit(value) {
  selected = value;
  localStorage.setItem("rating", String(value));
  output.textContent = value ? `You rated: ${value}/5` : "Click a star to rate.";
  paint(value);
}

// 5) Wire up each star. `index + 1` is that star's value (1..5).
stars.forEach((star, index) => {
  const value = index + 1;
  star.addEventListener("mouseenter", () => paint(value)); // preview, don't commit
  star.addEventListener("click", () => commit(value)); // commit for real
});

// 6) When the pointer leaves the whole row, snap back to the committed value.
row.addEventListener("mouseleave", () => paint(selected));

// 7) Keyboard: arrow keys move the rating up or down and commit as they go, so
//    someone who can't use a mouse still gets there. Each star is a real <button>,
//    so Tab reaches them and Enter/Space click them without any extra code.
row.addEventListener("keydown", (event) => {
  let next = selected;
  if (event.key === "ArrowRight" || event.key === "ArrowUp") next = Math.min(5, selected + 1);
  else if (event.key === "ArrowLeft" || event.key === "ArrowDown") next = Math.max(1, selected - 1);
  else return; // ignore every other key

  event.preventDefault(); // stop the arrow key from also scrolling the page
  commit(next);
  stars[next - 1].focus(); // move focus onto the star we just landed on
});

commit(selected); // draw the saved rating (or the empty state) on load
