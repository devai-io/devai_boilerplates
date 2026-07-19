// Character Counter — live feedback as you type, with a progress ring.
// Concepts: reacting to every "input" event, mapping one number (the length)
// onto a color, and mapping that same number onto a visual (an SVG ring).

const LIMIT = 280; // the tweet-style cap

// 1) Grab the elements we need.
const textarea = document.getElementById("text");
const remaining = document.getElementById("remaining");
const postBtn = document.getElementById("post");
const ring = document.getElementById("ringProgress");
const status = document.getElementById("status");

// 2) A circle's outline is 2 * pi * r long. We draw a partial ring by hiding part
//    of that outline with stroke-dashoffset: full offset = empty, zero = complete.
//    So the whole trick is picking the right offset for the current length.
const radius = ring.r.baseVal.value; // read r="18" straight off the SVG circle
const circumference = 2 * Math.PI * radius;
ring.style.strokeDasharray = String(circumference);

// 3) Recalculate everything from the current text. One function, called on every edit.
function update() {
  const used = textarea.value.length;
  const left = LIMIT - used;

  // The remaining count, colored by how close (or past) the limit we are.
  remaining.textContent = String(left);
  remaining.classList.toggle("warn", left <= 20 && left >= 0); // getting close
  remaining.classList.toggle("over", left < 0); // gone too far

  // Over the limit? Block posting so a too-long message can't be sent.
  postBtn.disabled = left < 0;

  // Map the length onto the ring: fill from 0 to 1 (capped), then match the color.
  const fraction = Math.min(used / LIMIT, 1);
  ring.style.strokeDashoffset = String(circumference * (1 - fraction));
  ring.classList.toggle("warn", left <= 20 && left >= 0);
  ring.classList.toggle("over", left < 0);
}

// 4) Fire on EVERY change — typing, pasting, or deleting all count as "input".
textarea.addEventListener("input", update);

// 5) Nothing really posts here; just show it worked, clear the box, and reset.
postBtn.addEventListener("click", () => {
  status.textContent = "Posted! ✓";
  textarea.value = "";
  update();
  setTimeout(() => (status.textContent = ""), 1500);
});

update(); // set the starting state: 280 remaining, empty ring
