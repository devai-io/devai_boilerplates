const LIMIT = 280;

const textarea = document.getElementById("text");
const remaining = document.getElementById("remaining");
const postBtn = document.getElementById("post");
const ring = document.getElementById("ringProgress");
const status = document.getElementById("status");

// A circle's outline is 2πr long. Dash it into one dash that long, then slide
// it with stroke-dashoffset: offset = full length shows nothing, 0 shows the
// whole ring. So the ring is just "how much of the length to hide".
const circumference = 2 * Math.PI * ring.r.baseVal.value;
ring.style.strokeDasharray = String(circumference);

// Everything on screen is derived from ONE number — the text length — and
// update() recomputes all of it on every keystroke.
function update() {
  const used = textarea.value.length;
  const left = LIMIT - used;
  const warn = left <= 20 && left >= 0;
  const over = left < 0;

  remaining.textContent = String(left);
  remaining.classList.toggle("warn", warn);
  remaining.classList.toggle("over", over);
  postBtn.disabled = over;

  const fraction = Math.min(used / LIMIT, 1);
  ring.style.strokeDashoffset = String(circumference * (1 - fraction));
  ring.classList.toggle("warn", warn);
  ring.classList.toggle("over", over);
}

// "input" fires for typing, pasting, deleting and dictation alike.
textarea.addEventListener("input", update);

postBtn.addEventListener("click", () => {
  status.textContent = "Posted! ✓";
  textarea.value = "";
  update();
  setTimeout(() => (status.textContent = ""), 1500);
});

update();
