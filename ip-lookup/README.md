# ip-lookup

> No search box needed — this app asks an API to describe _your own_ connection, then
> pins it on a map.

**What you'll build:** a page that shows your public IP address big and bold, plus the
city, country, internet provider and time zone the internet sees for you — with a
"View on map" link and a "Refresh" button.

**What you'll learn:** that some APIs read facts about the request _you_ send, so you
give them no input at all. You'll also learn a subtle real-world trap: an API that
always replies "200 OK" but hides failures in a `success: false` field you have to
check yourself. And you'll build a URL from live data to link out to a map.

## Run it

**The easy way:** double-click `index.html`. It opens in your browser and works — as
long as you have internet, because it asks the lookup service about you live.

**With Docker** (optional, this is how the real site ships it):

```sh
docker build -t ip-lookup .
docker run -p 8080:80 ip-lookup   # then open http://localhost:8080
```

## The idea in 30 seconds

An **API** is just a URL that returns data instead of a web page. Open
<https://ipwho.is/> in your browser — with no parameters, it describes whoever is
asking, which right now is _you_. That's the raw JSON this app reads.

```js
const res = await fetch("https://ipwho.is/");
const data = await res.json(); // { ip, city, country, connection: { isp }, ... }
```

There's nothing to type in. The request itself carries your address, and the server
reads it. Refreshing just asks again.

## How the code works

- **`fetch("https://ipwho.is/")`** with no query string — the API uses the address the
  request came from.
- **The `success` check:** this service answers `200` even when it can't help, and
  signals trouble with `data.success === false` plus a `message`. So after `res.ok` we
  _also_ check that flag — a good reminder that "200 OK" doesn't always mean "it worked."
- **`render(d)`** copies fields onto the page. `d.connection.isp` and `d.timezone.id`
  are one level down inside nested objects; we reach them with `?.` so a missing object
  can't crash the page.
- **The map link** is built from `d.latitude` and `d.longitude` — string-building a URL
  from live data is a handy trick.
- **Refresh** just calls the same `load()` function again.

## Try changing something

- Show your `region_code`, `postal` code or `connection.org` (open the raw JSON to see
  every field available).
- Swap the OpenStreetMap link for a Google Maps one:
  `https://www.google.com/maps?q=LAT,LON`.
- Auto-refresh every 30 seconds with `setInterval(load, 30000)`.

## A note on VPNs and accuracy

IP location is a best guess, not GPS. It usually lands on the right city, but it can be
off. And if you're on a **VPN**, you'll see the VPN server's location and provider
instead of your own — that's exactly how a VPN hides you. Turn one on and hit Refresh
to watch your "location" jump to another country. Great party trick, useful lesson.

## Files

```
index.html    the layout and the Refresh button
styles.css    how it looks (light + dark)
app.js        fetch your details, check for success, render them
Dockerfile    optional: serve it with nginx
```
