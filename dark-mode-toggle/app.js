const toggle = document.getElementById("toggle");
const icon = document.getElementById("toggleIcon");

// The whole theme lives in ONE attribute on <html>. Every color in styles.css is
// a variable that changes with [data-theme="light"] / [data-theme="dark"], so
// flipping this attribute repaints the entire page.
const root = document.documentElement;

// Start with the visitor's saved choice, or else whatever their OS prefers.
function initialTheme() {
  const saved = localStorage.getItem("theme");
  if (saved === "light" || saved === "dark") return saved;
  return window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
}

function applyTheme(theme) {
  root.dataset.theme = theme;
  icon.textContent = theme === "dark" ? "🌙" : "☀️";
  toggle.setAttribute("aria-pressed", String(theme === "dark"));
}

toggle.addEventListener("click", () => {
  const next = root.dataset.theme === "dark" ? "light" : "dark";
  applyTheme(next);
  localStorage.setItem("theme", next); // only a real click is remembered
});

applyTheme(initialTheme());
