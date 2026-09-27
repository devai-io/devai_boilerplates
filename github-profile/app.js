const form = document.getElementById("form");
const input = document.getElementById("username");
const card = document.getElementById("card");
const statusEl = document.getElementById("status");

// The whole fetch() pattern: request a URL, check the status, turn the body
// into a JavaScript object with res.json(), then put its fields on the page.
async function loadProfile(username) {
  statusEl.textContent = "Loading…";
  card.hidden = true;

  try {
    const res = await fetch(`https://api.github.com/users/${encodeURIComponent(username)}`);

    // fetch() only throws when the network fails. A 404 or 403 is still a
    // "successful" response, so check res.status yourself.
    if (res.status === 404) {
      statusEl.textContent = `No user called "${username}".`;
      return;
    }
    if (res.status === 403 || res.status === 429) {
      statusEl.textContent = "GitHub's hourly limit for anonymous lookups is used up — try again later.";
      return;
    }
    if (!res.ok) throw new Error(`GitHub returned ${res.status}`);

    const user = await res.json();
    render(user);
    statusEl.textContent = "";
  } catch (err) {
    statusEl.textContent = "Something went wrong. Try again in a moment.";
    console.error(err);
  }
}

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
  event.preventDefault();
  const name = input.value.trim();
  if (name) loadProfile(name);
});

loadProfile("torvalds");
