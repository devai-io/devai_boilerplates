const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");

// Read .env if there is one. Real environment variables win over the file.
try {
  process.loadEnvFile();
} catch {}

const PORT = process.env.PORT || 8080;
const NASA_API_KEY = process.env.NASA_API_KEY || "DEMO_KEY";

const PUBLIC_DIR = path.join(__dirname, "public");
const MIME = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css",
  ".js": "text/javascript",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
};

// THE PROXY. The browser asks us, we ask NASA with the secret key, and we send
// back only the fields the page needs. The key never leaves this server, so no
// visitor can find it with "View Source".
async function handleApod(res) {
  try {
    const url = `https://api.nasa.gov/planetary/apod?${new URLSearchParams({ api_key: NASA_API_KEY })}`;
    const upstream = await fetch(url, { signal: AbortSignal.timeout(10_000) });
    if (upstream.status === 429) {
      return sendJson(res, 429, {
        error: "NASA's rate limit is used up. Get a free key at https://api.nasa.gov and put it in .env.",
      });
    }
    if (!upstream.ok) throw new Error(`NASA returned ${upstream.status}`);
    const data = await upstream.json();

    sendJson(res, 200, {
      title: data.title,
      date: data.date,
      explanation: data.explanation,
      image: data.media_type === "image" ? data.url : null, // some days it's a video
      credit: data.copyright ? data.copyright.trim() : null,
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

function sendText(res, status, text) {
  res.writeHead(status, { "Content-Type": "text/plain" });
  res.end(text);
}

function serveStatic(pathname, res) {
  let rel;
  try {
    rel = pathname === "/" ? "/index.html" : decodeURIComponent(pathname);
  } catch {
    return sendText(res, 400, "Bad request");
  }
  // Resolve the path and refuse anything that climbs out of ./public (../server.js).
  const file = path.join(PUBLIC_DIR, path.normalize(rel));
  if (!file.startsWith(PUBLIC_DIR + path.sep)) return sendText(res, 403, "Forbidden");

  fs.readFile(file, (err, buf) => {
    if (err) return sendText(res, 404, "Not found");
    res.writeHead(200, { "Content-Type": MIME[path.extname(file)] || "application/octet-stream" });
    res.end(buf);
  });
}

const server = http.createServer((req, res) => {
  const pathname = req.url.split("?")[0];
  if (pathname === "/api/apod") return handleApod(res);
  serveStatic(pathname, res);
});

// In a container this process is PID 1, which ignores SIGTERM unless told otherwise.
process.on("SIGTERM", () => process.exit(0));

server.listen(PORT, () => {
  console.log(`NASA photo proxy running at http://localhost:${PORT}`);
  if (NASA_API_KEY === "DEMO_KEY") {
    console.log("Using NASA's shared DEMO_KEY (rate-limited). Free key: https://api.nasa.gov");
  }
});
