# image-slideshow

> A slideshow you can click through — or let it play itself. All about stepping
> through a list with an index that wraps around.

**What you'll build:** a slideshow of five colorful slides with Prev/Next
buttons and clickable dots. It advances on its own every four seconds, pauses
when you hover, and loops seamlessly from the last slide back to the first.

**What you'll learn:** how to walk through a list using an _index_ (a number that
says "which item"), how to wrap around the ends with the `%` remainder operator,
and how to start and stop auto-play with `setInterval` / `clearInterval`.

## Run it

**The easy way:** double-click `index.html`. It opens in your browser and works.
There is nothing to install and no build step. (The slides are CSS gradients, so
there are no image files to load — it even works fully offline.)

**With Docker** (optional, this is how the real site ships it):

```sh
docker build -t image-slideshow .
docker run -p 8080:80 image-slideshow   # then open http://localhost:8080
```

## The idea in 30 seconds

There's a list of slides and one number, `index`, that says which one is
showing. Everything else is just changing that number and redrawing:

```js
function show(i) { index = i; /* paint slides[index] onto the screen */ }
```

Next is `index + 1`, Prev is `index - 1`. The clever bit is the wrap:

```js
show((index + step + slides.length) % slides.length);
```

`% slides.length` keeps the number inside `0…4`. Adding `slides.length` first
makes sure it stays positive when you go backwards past `0`, so it loops both
ways.

## How the code works

- **`slides`** is an array of `{ title, gradient }` objects — the "images."
- **`show(i)`** sets `index`, paints `slides[index].gradient` as the background,
  writes the title, and highlights the matching dot.
- **`move(step)`** does the wrap-around math so Next and Prev never fall off the
  ends of the list.
- **The dots** are built once with `slides.map(...)`; each remembers its own `i`
  and jumps straight there on click.
- **Auto-play** is a `setInterval` that calls `move(1)` every 4s. Hovering the
  slide runs `clearInterval` to pause; leaving starts a fresh interval.

## Try changing something

- Add a slide: drop another `{ title, gradient }` into the `slides` array.
- Speed it up: change both `4000`s to `2000` for a slide every two seconds.
- Add keyboard arrows: listen for `keydown` and call `move(-1)` / `move(1)`.

## Files

```
index.html    the slide, the arrows, and the dots container
styles.css    how it looks (light + dark)
app.js        the slides array, the index, and wrap-around logic
Dockerfile    optional: serve it with nginx
```
