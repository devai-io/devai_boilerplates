// A tiny Node server that does two jobs:
//   1. serves the web page in ./public
//   2. exposes /api/apod, which calls NASA *for* the browser so the secret API key
//      stays on the server and is never sent to the visitor.
//
// This is the whole reason backends exist for a lot of apps: to hold secrets and to
// talk to other services on your behalf.
//
// Run it:  node server.js      (needs Node 18+ for the built-in fetch)

const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");

const PORT = process.env.PORT || 3000;
// DEMO_KEY works out of the box (shared + rate-limited). Get your own free key,
// in seconds, at https://api.nasa.gov and put it in .env
const NASA_API_KEY = process.env.NASA_API_KEY || "DEMO_KEY";

const PUBLIC_DIR = path.join(__dirname, "public");
const MIME = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css",
  ".js": "text/javascript",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
};

// GET /api/apod -> fetch NASA's Astronomy Picture of the Day, forward the useful bits.
async function handleApod(res) {
  try {
    const url = `https://api.nasa.gov/planetary/apod?api_key=${NASA_API_KEY}`;
    const upstream = await fetch(url);
    if (!upstream.ok) throw new Error(`NASA returned ${upstream.status}`);
    const data = await upstream.json();

    sendJson(res, 200, {
      title: data.title,
      date: data.date,
      explanation: data.explanation,
      // APOD is sometimes a video; only images have a url we can show as a photo.
      image: data.media_type === "image" ? data.hdurl || data.url : null,
      credit: data.copyright ? data.copyright.trim() : "Public domain / NASA",
    });
  } catch (err) {
    console.error(err);
    sendJson(res, 502, { error: "Could not reach NASA right now." });
  }
}

function sendJson(res, status, body) {
  const json = JSON.stringify(body);
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Content-Length": Buffer.byteLength(json),
  });
  res.end(json);
}

// Serve a file from ./public, refusing anything that tries to climb out of it.
function serveStatic(req, res) {
  const rel = req.url === "/" ? "/index.html" : decodeURIComponent(req.url.split("?")[0]);
  const file = path.join(PUBLIC_DIR, path.normalize(rel));
  if (!file.startsWith(PUBLIC_DIR)) {
    res.writeHead(403);
    return res.end("Forbidden");
  }
  fs.readFile(file, (err, buf) => {
    if (err) {
      res.writeHead(404);
      return res.end("Not found");
    }
    res.writeHead(200, { "Content-Type": MIME[path.extname(file)] || "application/octet-stream" });
    res.end(buf);
  });
}

const server = http.createServer((req, res) => {
  if (req.url.startsWith("/api/apod")) return handleApod(res);
  serveStatic(req, res);
});

server.listen(PORT, () => {
  console.log(`NASA photo proxy running at http://localhost:${PORT}`);
  if (NASA_API_KEY === "DEMO_KEY") {
    console.log("Using NASA's shared DEMO_KEY (rate-limited). Free key: https://api.nasa.gov");
  }
});
