# github-profile

> Type a GitHub username, get their profile card — your first taste of talking to a
> real API.

**What you'll build:** a search box that fetches anyone's public GitHub profile
(avatar, bio, follower counts) and shows it as a neat card.

**What you'll learn:** how to call an _API_ — a service on the internet that hands
back data — using the browser's built-in `fetch()`, how to wait for the answer, and
how to turn the JSON it returns into things on the page. You'll also handle the two
things that always go wrong: the user doesn't exist, and the network hiccups.

## Run it

**The easy way:** double-click `index.html`. It works offline-free — as long as you
have internet, because it calls GitHub live.

Or serve it like production:

```sh
docker compose up --build   # then open http://localhost:8080
```

## The idea in 30 seconds

An **API** is just a URL that returns data instead of a web page. Open
<https://api.github.com/users/torvalds> in your browser — you'll see the raw JSON
this app reads. `fetch()` grabs that same URL from JavaScript:

```js
const res = await fetch("https://api.github.com/users/torvalds");
const user = await res.json(); // { name, bio, followers, ... }
```

`await` means "pause here until the answer comes back." Then we copy fields from
`user` onto the page. That's the entire trick behind most modern web apps.

## How the code works

- **`fetch(url)`** sends the request and returns a `Response`.
- **`res.status`** tells you what happened: `200` is success, `404` means "no such
  user." We check for `404` and show a friendly message instead of crashing.
- **`await res.json()`** reads the response body and parses it into a JS object.
- **`render(user)`** copies `user.name`, `user.followers`, etc. onto the page.
- The whole thing is wrapped in `try / catch` so a dropped connection shows a message
  instead of a blank screen.

## Try changing something

- Show `user.location` and `user.company` too (open the raw JSON to see every field).
- List the user's latest repos from `https://api.github.com/users/NAME/repos`.
- Add a loading spinner while the request is in flight.

## A note on rate limits

Without signing in, GitHub allows ~60 requests per hour per computer. Plenty for
learning; if you hit a `403`, wait a bit. Production apps send an auth token — see the
`github-profile` sibling ideas for how a small backend would add one safely.

## Files

```
index.html    the search box and the (hidden until loaded) card
styles.css    how it looks (light + dark)
app.js        fetch the profile, handle errors, render it
Dockerfile    serve it with nginx (what compose builds)
compose.yaml  serve it like production: docker compose up --build
```

## Deploy

Push to your own GitHub repo and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — the APIs & Data track: fetch real data
from the internet.
