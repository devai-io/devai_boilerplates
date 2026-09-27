const row = document.getElementById("stars");
const stars = [...row.querySelectorAll(".star")];
const output = document.getElementById("output");

// Two values, two jobs. `selected` is the COMMITTED rating: set by a click,
// saved in localStorage. Hovering only PREVIEWS: it repaints the stars but
// never touches `selected`, so leaving the row snaps back to the real rating.
let selected = Number(localStorage.getItem("rating")) || 0;

function paint(value) {
  stars.forEach((star, index) => star.classList.toggle("on", index < value));
}

function commit(value) {
  selected = value;
  localStorage.setItem("rating", String(value));
  output.textContent = value ? `You rated: ${value}/5` : "Click a star to rate.";
  paint(value);
}

stars.forEach((star, index) => {
  star.addEventListener("mouseenter", () => paint(index + 1)); // preview
  star.addEventListener("click", () => commit(index + 1)); // commit
});
row.addEventListener("mouseleave", () => paint(selected));

// Each star is a real <button>, so Tab, Enter and Space already work. The arrow
// keys add a quicker way to move the rating up and down.
row.addEventListener("keydown", (event) => {
  let next;
  if (event.key === "ArrowRight" || event.key === "ArrowUp") next = Math.min(5, selected + 1);
  else if (event.key === "ArrowLeft" || event.key === "ArrowDown") next = Math.max(1, selected - 1);
  else return;

  event.preventDefault(); // don't also scroll the page
  commit(next);
  stars[next - 1].focus();
});

commit(selected);
