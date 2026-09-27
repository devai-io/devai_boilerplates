# form-validation

> A sign-up form that checks each field and explains exactly what's wrong —
> the friendly way.

**What you'll build:** a sign-up form (name, email, password, confirm password)
that validates as you go. Leave a field and it checks itself; hit Sign up and it
checks everything, showing a clear red message under any field that's wrong and a
green "All good! ✓" when the whole form passes.

**What you'll learn:** how to validate user input _before_ accepting it, how to
show helpful inline errors instead of relying on the browser's default popups,
and how to keep it accessible with `aria-invalid`.

## Run it

**The easy way:** double-click `index.html`. It opens in your browser and works.
There is nothing to install and no build step.

Or serve it like production:

```sh
docker compose up --build   # then open http://localhost:8080
```

## The idea in 30 seconds

Each field has one small rule that answers a single question: _"is this value
OK, and if not, what should I tell the user?"_ A rule returns an empty string
when everything is fine, or an error message when it isn't:

```js
validate: (value) => (value.trim() ? "" : "Please enter your name.");
```

`checkField` runs the rule, drops the message under the field, and flags the
input. We run it on **blur** (when you leave a field) for early feedback, and on
**submit** for every field at once.

## How the code works

- **`fields`** is one object describing every field — its input, its error `<p>`,
  and its `validate` rule. Keeping them together makes the rest of the code tiny.
- **The email rule** uses a simple regular expression,
  `/^[^\s@]+@[^\s@]+\.[^\s@]+$/` — "some characters, an `@`, some characters, a
  `.`, some more." Enough to catch obvious typos.
- **The confirm rule** peeks at another field: it compares against
  `fields.password.input.value`.
- **`checkField`** sets `aria-invalid="true"` or `"false"` so screen readers know
  the state, and returns `true`/`false` for whether the field passed.
- **On submit**, `event.preventDefault()` stops the page from navigating, we
  `.map` over every field to show all errors, and `.every` tells us if all
  passed.

## Try changing something

- Require the password to contain a number: add `&& /\d/.test(value)` to its rule.
- Add a "terms" checkbox and a rule that it must be checked.
- Show the green success only, and disable the button until every field is valid.

## Files

```
index.html      the four fields, each with its own error line
styles.css      how it looks (light + dark), including the red/green states
app.js          the rules, the blur checks, and the submit check
Dockerfile      optional: serve it with nginx
compose.yaml    optional: docker compose up --build
```

## Deploy

Push to your own GitHub repo and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — the Web Basics track: HTML, CSS &
JavaScript, one concept at a time.
