# star-rating

> Five stars that light up as you hover, lock in when you click, and remember your
> rating the next time you visit.

**What you'll build:** the classic star-rating widget. Hovering previews the fill up
to the star under your pointer; moving away snaps back to whatever you last chose;
clicking commits it. It shows "You rated: 4/5", works with the arrow keys, and saves
your rating so it's still there after a refresh.

**What you'll learn:** the key idea behind interactive widgets — keeping a _preview_
state separate from the _committed_ state — plus how to make something keyboard
accessible with real `<button>`s and `aria-label`s, and how to persist a value with
`localStorage`.

## Run it

**The easy way:** double-click `index.html`. It opens in your browser and works.
There is nothing to install and no build step.

**With Docker** (optional, this is how the real site ships it):

```sh
docker build -t star-rating .
docker run -p 8080:80 star-rating   # then open http://localhost:8080
```

## The idea in 30 seconds

There are two different "current values" at play. While your mouse hovers, the stars
show a _preview_ — but nothing is decided yet. The moment you click (or press an
arrow key), that becomes the _committed_ value. When the pointer leaves, we simply
repaint the committed value and the preview disappears:

```js
star.onmouseenter = () => paint(value); // preview
star.onclick = () => commit(value); // commit
row.onmouseleave = () => paint(selected); // back to committed
```

One `paint()` function draws whatever number you hand it; everything else just
decides which number that is.

## How the code works

- **`paint(value)`** toggles an `on` class on each star up to `value`. It's the only
  code that touches the display, so preview and commit look identical.
- **`commit(value)`** stores the choice in `selected`, writes it to `localStorage`,
  updates the text, and repaints.
- **`mouseenter` / `mouseleave`** drive the hover preview and the snap-back.
- **`keydown`** on the row lets the arrow keys raise or lower the rating and moves
  focus to the matching star — real `<button>`s already handle Tab and Enter.
- **`localStorage.getItem("rating")`** on load restores your last rating (it's stored
  as text, so `Number(...)` converts it back).

## Try changing something

- Add half-stars by tracking which half of a star the pointer is over.
- Show a word for each score: "Terrible" … "Great" under the stars.
- Add a "Clear" button that removes the saved rating with `localStorage.removeItem`.

## Files

```
index.html    the five star buttons and the output line
styles.css    how it looks, including the filled "on" state (light + dark)
app.js        hover preview, click/keyboard commit, and localStorage
Dockerfile    optional: serve it with nginx
```
