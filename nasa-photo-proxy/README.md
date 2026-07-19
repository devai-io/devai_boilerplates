# nasa-photo-proxy

> The same "fetch some data and show it" idea as the browser tutorials — but now with
> a real (tiny) backend, so you learn _why_ apps have servers.

**What you'll build:** a page that shows NASA's Astronomy Picture of the Day. A small
Node server fetches it from NASA and passes it to your browser.

**What you'll learn:** why you can't just put an API key in your web page (everyone
can read it), and how a _backend_ solves that by making the call for you. You'll see a
complete, dependency-free Node HTTP server — the smallest real backend there is.

## Requirements

- [Node.js](https://nodejs.org) 18 or newer (for the built-in `fetch`). Nothing else —
  this server has **no npm packages to install**.

## Run it

```sh
cp .env.example .env      # optional: paste your own NASA key
node server.js            # then open http://localhost:3000
```

**With Docker:**

```sh
docker build -t nasa-photo-proxy .
docker run -p 3000:3000 --env NASA_API_KEY=DEMO_KEY nasa-photo-proxy
```

## The idea in 60 seconds

In the browser-only API tutorials, the web page called the API directly. That's fine
when the API is public. But many APIs need a **secret key**, and anything in your web
page is visible to anyone who opens "View Source." Ship a key there and strangers will
happily spend your quota.

The fix: put a **server** in the middle.

```
  Browser  ──►  /api/apod (your server)  ──►  api.nasa.gov?api_key=SECRET
           ◄──         (just the photo)  ◄──
```

Your server holds the key, calls NASA, and returns only what the page needs. The key
never leaves the server.

## How the code works

`server.js` is one file with two responsibilities:

- **Serve the page.** Any normal request (`/`, `/styles.css`, `/app.js`) reads a file
  out of `public/` and returns it.
- **Be the proxy.** A request to `/api/apod` runs `handleApod()`, which `fetch()`es
  NASA using the key from `process.env.NASA_API_KEY`, then forwards a trimmed-down JSON
  object back to the browser.

Open `public/app.js` and notice it fetches `"/api/apod"` — its _own_ server — never
`nasa.gov`. The browser has no idea the key exists.

## Try changing something

- Cache the result for an hour so you don't call NASA on every reload.
- Add `/api/apod?date=2022-07-11` support (NASA's API accepts a `date` parameter).
- Swap NASA for any key-protected API you like — the proxy pattern is identical.

## Files

```
server.js            the whole backend: static files + the /api/apod proxy
package.json         name + "start" script (no dependencies)
.env.example         where the API key goes
public/
  index.html         the page
  styles.css         how it looks (light + dark)
  app.js             calls /api/apod on our own server
Dockerfile           runs it on node:20-alpine
```
