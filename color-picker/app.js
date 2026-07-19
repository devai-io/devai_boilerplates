// Color Picker & Palette — pick a color, read its codes, copy any of them.
// Concepts: reading an <input type="color">, converting HEX <-> RGB by hand,
// and copying text with the Clipboard API.

// 1) Grab the elements we need.
const picker = document.getElementById("color");
const swatch = document.getElementById("swatch");
const hexValue = document.getElementById("hexValue");
const rgbValue = document.getElementById("rgbValue");
const shades = document.getElementById("shades");
const toast = document.getElementById("toast");

// 2) HEX and RGB are two ways of writing the same color.
//    "#ec4899" is just three bytes — ec, 48, 99 — i.e. red 236, green 72, blue 153.
function hexToRgb(hex) {
  const n = parseInt(hex.slice(1), 16); // drop the "#", read the rest as base-16
  return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 };
}

function rgbToHex(r, g, b) {
  const two = (v) => v.toString(16).padStart(2, "0"); // 5 -> "05", always 2 digits
  return "#" + two(r) + two(g) + two(b);
}

// 3) Mix one channel toward a target: 255 lightens (a tint), 0 darkens (a shade).
//    `amount` is 0..1 — how far to move.
function mix(value, target, amount) {
  return Math.round(value + (target - value) * amount);
}

// 4) Dark colors need light text on top, and vice versa. This picks a readable one.
function readableText(r, g, b) {
  const brightness = (r * 299 + g * 587 + b * 114) / 1000; // rough perceived brightness
  return brightness > 140 ? "#111" : "#fff";
}

// 5) Rebuild the whole UI from a single hex color.
function update(hex) {
  const { r, g, b } = hexToRgb(hex);
  swatch.style.background = hex;
  hexValue.textContent = hex.toUpperCase();
  rgbValue.textContent = `rgb(${r}, ${g}, ${b})`;

  // Five variations: two lighter tints, the color itself, two darker shades.
  const steps = [
    { target: 255, amount: 0.4 },
    { target: 255, amount: 0.2 },
    { target: 0, amount: 0 }, // amount 0 leaves the color unchanged
    { target: 0, amount: 0.2 },
    { target: 0, amount: 0.4 },
  ];

  shades.innerHTML = ""; // clear the old palette before drawing the new one
  for (const step of steps) {
    const sr = mix(r, step.target, step.amount);
    const sg = mix(g, step.target, step.amount);
    const sb = mix(b, step.target, step.amount);
    const shadeHex = rgbToHex(sr, sg, sb).toUpperCase();

    const button = document.createElement("button");
    button.className = "shade";
    button.type = "button";
    button.style.background = shadeHex;
    button.style.color = readableText(sr, sg, sb);
    button.textContent = shadeHex;
    button.addEventListener("click", () => copy(shadeHex));
    shades.append(button);
  }
}

// 6) Copy text to the clipboard, then flash "Copied!" for a moment.
async function copy(text) {
  try {
    await navigator.clipboard.writeText(text);
    toast.textContent = `Copied ${text}`;
  } catch {
    // Some browsers block the clipboard on file:// pages — say so instead of failing silently.
    toast.textContent = "Copy blocked here — select the text manually.";
  }
  toast.classList.add("show");
  clearTimeout(copy.timer); // if you click again quickly, restart the countdown
  copy.timer = setTimeout(() => toast.classList.remove("show"), 1400);
}

// 7) Wire it up. The two big values copy themselves; the picker redraws on change.
hexValue.addEventListener("click", () => copy(hexValue.textContent.trim()));
rgbValue.addEventListener("click", () => copy(rgbValue.textContent.trim()));
picker.addEventListener("input", () => update(picker.value));

update(picker.value); // draw once with the input's starting color
