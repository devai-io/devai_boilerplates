// Each "image" is a title and a CSS gradient, so there are no files to download.
const slides = [
  { title: "Sunrise", gradient: "linear-gradient(135deg, #f97316, #fbbf24)" },
  { title: "Ocean", gradient: "linear-gradient(135deg, #0ea5e9, #22d3ee)" },
  { title: "Forest", gradient: "linear-gradient(135deg, #16a34a, #84cc16)" },
  { title: "Berry", gradient: "linear-gradient(135deg, #db2777, #a855f7)" },
  { title: "Midnight", gradient: "linear-gradient(135deg, #1e293b, #4f46e5)" },
];

const slideshow = document.getElementById("slideshow");
const slide = document.getElementById("slide");
const slideTitle = document.getElementById("slideTitle");
const dotsBox = document.getElementById("dots");

// The whole slideshow is this one number: which slide we're on. Every button
// just changes `index` and calls show() to redraw.
let index = 0;

const dots = slides.map((_, i) => {
  const dot = document.createElement("button");
  dot.className = "dot";
  dot.type = "button";
  dot.setAttribute("aria-label", `Go to slide ${i + 1}`);
  dot.addEventListener("click", () => show(i));
  dotsBox.append(dot);
  return dot;
});

function show(i) {
  index = i;
  slide.style.background = slides[index].gradient;
  slideTitle.textContent = slides[index].title;
  dots.forEach((dot, d) => {
    dot.classList.toggle("active", d === index);
    dot.setAttribute("aria-current", String(d === index));
  });
}

// % (remainder) wraps the index around the ends: from the last slide, +1 lands
// on 0. Adding slides.length first keeps it positive, so -1 from 0 wraps too.
function move(step) {
  show((index + step + slides.length) % slides.length);
}

document.getElementById("prev").addEventListener("click", () => move(-1));
document.getElementById("next").addEventListener("click", () => move(1));

let timer = null;
function play() {
  clearInterval(timer);
  timer = setInterval(() => move(1), 4000);
}
function pause() {
  clearInterval(timer);
}

// Auto-play stops while the pointer or keyboard focus is on the slideshow, so
// it never moves out from under someone who is reading or clicking.
slideshow.addEventListener("mouseenter", pause);
slideshow.addEventListener("mouseleave", play);
slideshow.addEventListener("focusin", pause);
slideshow.addEventListener("focusout", play);

show(0);
play();
