// Image Slideshow — keep a list of slides and a number that says which one
// we're on. Change the number, redraw the slide. Wrap around the ends with the
// % (remainder) trick so Next past the last slide loops back to the first.

// 1) Our "images". No image files needed — each slide is just a title and a CSS
//    gradient, so the whole slideshow is self-contained and works offline.
const slides = [
  { title: "Sunrise", gradient: "linear-gradient(135deg, #f97316, #fbbf24)" },
  { title: "Ocean", gradient: "linear-gradient(135deg, #0ea5e9, #22d3ee)" },
  { title: "Forest", gradient: "linear-gradient(135deg, #16a34a, #84cc16)" },
  { title: "Berry", gradient: "linear-gradient(135deg, #db2777, #a855f7)" },
  { title: "Midnight", gradient: "linear-gradient(135deg, #1e293b, #4f46e5)" },
];

// 2) The elements, and the index of the slide we're showing right now.
const slide = document.getElementById("slide");
const slideTitle = document.getElementById("slideTitle");
const dotsBox = document.getElementById("dots");
let index = 0;

// 3) Build one clickable dot per slide, once. Each dot jumps to its slide.
const dots = slides.map((_, i) => {
  const dot = document.createElement("button");
  dot.className = "dot";
  dot.type = "button";
  dot.setAttribute("aria-label", `Go to slide ${i + 1}`);
  dot.addEventListener("click", () => show(i));
  dotsBox.append(dot);
  return dot;
});

// 4) Show the slide at position `i`: paint its gradient and title, and light up
//    the matching dot.
function show(i) {
  index = i;
  const current = slides[index];
  slide.style.background = current.gradient;
  slideTitle.textContent = current.title;
  dots.forEach((dot, d) => dot.classList.toggle("active", d === index));
}

// 5) Move by a step (+1 for next, -1 for prev). Adding slides.length before the
//    % keeps the result positive even when we go back past 0, so it wraps
//    cleanly in both directions.
function move(step) {
  show((index + step + slides.length) % slides.length);
}

document.getElementById("prev").addEventListener("click", () => move(-1));
document.getElementById("next").addEventListener("click", () => move(1));

// 6) Auto-play: advance every 4 seconds. We keep the timer's id so we can
//    pause it. Hovering the slide clears the timer; leaving starts it again.
let timer = setInterval(() => move(1), 4000);
slide.addEventListener("mouseenter", () => clearInterval(timer));
slide.addEventListener("mouseleave", () => {
  timer = setInterval(() => move(1), 4000);
});

// 7) Show the first slide to get started.
show(0);
