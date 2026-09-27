const picker = document.getElementById("color");
const swatch = document.getElementById("swatch");
const hexValue = document.getElementById("hexValue");
const rgbValue = document.getElementById("rgbValue");
const shades = document.getElementById("shades");
const toast = document.getElementById("toast");

// HEX and RGB are two ways to write the same three numbers. "#ec4899" is three
// bytes in base 16 — ec, 48, 99 — which is red 236, green 72, blue 153.
function hexToRgb(hex) {
  const n = parseInt(hex.slice(1), 16);
  return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 };
}

function rgbToHex(r, g, b) {
  const two = (v) => v.toString(16).padStart(2, "0");
  return "#" + two(r) + two(g) + two(b);
}

// Move a channel part of the way toward 255 (a lighter tint) or 0 (a darker shade).
function mix(value, target, amount) {
  return Math.round(value + (target - value) * amount);
}

// Pick dark or light text so the label on a swatch stays readable.
function readableText(r, g, b) {
  const brightness = (r * 299 + g * 587 + b * 114) / 1000;
  return brightness > 140 ? "#111" : "#fff";
}

const steps = [
  { target: 255, amount: 0.4 },
  { target: 255, amount: 0.2 },
  { target: 0, amount: 0 },
  { target: 0, amount: 0.2 },
  { target: 0, amount: 0.4 },
];

function update(hex) {
  const { r, g, b } = hexToRgb(hex);
  swatch.style.background = hex;
  hexValue.textContent = hex.toUpperCase();
  rgbValue.textContent = `rgb(${r}, ${g}, ${b})`;

  shades.replaceChildren();
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

let toastTimer = null;

// The Clipboard API is async and the browser may refuse (some block it on
// file:// pages), so we await it inside try/catch and say what happened.
async function copy(text) {
  try {
    await navigator.clipboard.writeText(text);
    toast.textContent = `Copied ${text}`;
  } catch {
    toast.textContent = "Copy blocked here — select the text manually.";
  }
  toast.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove("show"), 1400);
}

hexValue.addEventListener("click", () => copy(hexValue.textContent.trim()));
rgbValue.addEventListener("click", () => copy(rgbValue.textContent.trim()));
// "input" fires continuously while you drag inside the picker, not just at the end.
picker.addEventListener("input", () => update(picker.value));

update(picker.value);
