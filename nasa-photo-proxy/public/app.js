// This page asks "/api/apod" — its OWN server — never nasa.gov. The browser
// never sees the API key; that's the whole point of having a backend.
const statusEl = document.getElementById("status");
const figure = document.getElementById("figure");
const image = document.getElementById("image");
const reloadBtn = document.getElementById("reload");

async function loadPhoto() {
  statusEl.textContent = "Loading today's photo…";
  statusEl.hidden = false;
  figure.hidden = true;

  let res;
  try {
    res = await fetch("/api/apod");
  } catch (err) {
    statusEl.textContent = "Could not reach the server. Is it running?";
    console.error(err);
    return;
  }

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    statusEl.textContent = data.error || `The server answered ${res.status}.`;
    return;
  }
  if (!data.image) {
    statusEl.textContent = `Today's entry ("${data.title}") is a video, not a photo. Try again tomorrow!`;
    return;
  }

  image.src = data.image;
  image.alt = data.title;
  document.getElementById("title").textContent = data.title;
  document.getElementById("date").textContent = data.date;
  document.getElementById("explanation").textContent = data.explanation;
  document.getElementById("credit").textContent = data.credit ? `© ${data.credit}` : "Public domain (NASA)";

  statusEl.hidden = true;
  figure.hidden = false;
}

reloadBtn.addEventListener("click", loadPhoto);
loadPhoto();
