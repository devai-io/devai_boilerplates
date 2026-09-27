# github-profile

Type a GitHub username and get their public profile as a card — avatar, bio,
repos and followers. The cleanest first taste of talking to a real API with
`fetch()`.

## Run

Get it: `git clone https://git.devai.io/templates/github-profile.git`

Double-click `index.html` — it opens in your browser and works, as long as
you're online (it calls GitHub live). Nothing to install.

Or serve it like production:

```sh
docker compose up --build
```

Then open http://localhost:8080.

## How it works

The whole pattern is four steps:

```js
const res = await fetch(`https://api.github.com/users/${name}`); // 1. request
if (res.status === 404) { /* … */ }                               // 2. check
const user = await res.json();                                    // 3. parse
document.getElementById("name").textContent = user.name;          // 4. render
```

`fetch()` only throws when the network itself fails — a "user not found" 404
is still a response, so the code checks `res.status` and shows a friendly
message. GitHub allows 60 anonymous lookups an hour per IP; past that it
answers 403 or 429, and the page says so. "Loading…" shows while waiting. Text
goes onto the page with `textContent`, so nothing from the API is ever parsed
as HTML. Public profiles need no API key.

Try it: show `user.location` and `user.company` (open the URL in your browser
to see every field), list the user's repos from `/users/NAME/repos`, or add a
spinner.

## Layout

```
index.html   the search form, a status line and a hidden profile card
app.js       loadProfile() and render()
styles.css   the look; follows your system's light or dark mode
```

## Deploy

Push to your own GitHub repo and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — the APIs & Data track: fetch real data
from the internet. Next up:
[random-quote](https://git.devai.io/templates/random-quote).
