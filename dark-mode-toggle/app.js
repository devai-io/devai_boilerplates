// Dark Mode Toggle — flip between light and dark by setting one attribute on
// <html>. Remember the choice, and fall back to the visitor's OS setting.

// 1) The elements: the button and the two little labels inside it.
const toggle = document.getElementById("toggle");
const icon = document.getElementById("toggleIcon");
const text = document.getElementById("toggleText");

// 2) <html> is where the theme lives. Every color in styles.css reacts to
//    [data-theme="light"] / [data-theme="dark"] on this one element.
const root = document.documentElement;

// 3) Decide which theme to start with:
//    - the choice the user made last time (saved in localStorage), or
//    - if there's no saved choice, whatever the operating system prefers.
function initialTheme() {
  const saved = localStorage.getItem("theme");
  if (saved === "light" || saved === "dark") return saved;

  const prefersLight = window.matchMedia("(prefers-color-scheme: light)").matches;
  return prefersLight ? "light" : "dark";
}

// 4) Apply a theme: set the attribute (the CSS does the rest), update the
//    button, and save the choice for next time.
function setTheme(theme) {
  root.setAttribute("data-theme", theme);
  localStorage.setItem("theme", theme);

  // Show the current state on the button.
  const isDark = theme === "dark";
  icon.textContent = isDark ? "🌙" : "☀️";
  text.textContent = isDark ? "Dark" : "Light";
  toggle.setAttribute("aria-pressed", String(isDark));
}

// 5) Clicking flips to the opposite theme.
toggle.addEventListener("click", () => {
  const current = root.getAttribute("data-theme");
  setTheme(current === "dark" ? "light" : "dark");
});

// 6) Set everything up the moment the page loads.
setTheme(initialTheme());
