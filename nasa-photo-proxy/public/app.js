// Notice this file calls "/api/apod" — our OWN server — not nasa.gov directly.
// The browser never sees the API key. That's the point of having a backend.

const statusEl = document.getElementById("status");
const figure = document.getElementById("figure");
const reloadBtn = document.getElementById("reload");

async function loadPhoto() {
  statusEl.textContent = "Loading today's photo…";
  statusEl.hidden = false;
  figure.hidden = true;

  try {
    const res = await fetch("/api/apod");
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || "Request failed");

    if (!data.image) {
      statusEl.textContent = `Today's entry ("${data.title}") is a video, not a photo. Try again tomorrow!`;
      return;
    }

    document.getElementById("image").src = data.image;
    document.getElementById("title").textContent = data.title;
    document.getElementById("date").textContent = data.date;
    document.getElementById("explanation").textContent = data.explanation;
    document.getElementById("credit").textContent = "© " + data.credit;

    statusEl.hidden = true;
    figure.hidden = false;
  } catch (err) {
    statusEl.textContent = "Could not load the photo. Is the server running?";
    console.error(err);
  }
}

reloadBtn.addEventListener("click", loadPhoto);
loadPhoto();
