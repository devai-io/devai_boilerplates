// GitHub Profile Card — type a username, fetch their public profile, show it.
// Concept: call a real API with fetch(), wait for the JSON, then render it.

const form = document.getElementById("form");
const input = document.getElementById("username");
const card = document.getElementById("card");
const statusEl = document.getElementById("status");

async function loadProfile(username) {
  statusEl.textContent = "Loading…";
  card.hidden = true;

  try {
    // GitHub's REST API. No key needed for public profiles.
    // encodeURIComponent keeps odd characters from breaking the URL.
    const res = await fetch(
      `https://api.github.com/users/${encodeURIComponent(username)}`,
    );

    if (res.status === 404) {
      statusEl.textContent = `No user called "${username}".`;
      return;
    }
    if (!res.ok) {
      // e.g. 403 when you've made too many requests without signing in.
      throw new Error(`GitHub returned ${res.status}`);
    }

    const user = await res.json(); // the response body, turned into a JS object
    render(user);
    statusEl.textContent = "";
  } catch (err) {
    statusEl.textContent = "Something went wrong. Try again in a moment.";
    console.error(err);
  }
}

// Copy fields off the `user` object onto the page.
function render(user) {
  document.getElementById("avatar").src = user.avatar_url;
  document.getElementById("name").textContent = user.name || user.login;
  document.getElementById("login").textContent = "@" + user.login;
  document.getElementById("bio").textContent = user.bio || "No bio yet.";
  document.getElementById("repos").textContent = user.public_repos;
  document.getElementById("followers").textContent = user.followers;
  document.getElementById("following").textContent = user.following;
  document.getElementById("link").href = user.html_url;
  card.hidden = false;
}

form.addEventListener("submit", (event) => {
  event.preventDefault(); // stop the form from reloading the page
  const name = input.value.trim();
  if (name) loadProfile(name);
});

// Show one example on first load so the page isn't empty.
loadProfile("torvalds");
