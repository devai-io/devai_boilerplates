# form-validation

A sign-up form that checks each field and explains exactly what's wrong, right
under the field that's wrong. It teaches form events, a readable regex, and how
to give feedback that screen readers announce too.

## Run

Get it: `git clone https://github.com/devai-io/devai_boilerplates.git`, then `cd devai_boilerplates/form-validation`

Double-click `index.html` — it opens in your browser and works. Nothing to
install, no build step.

Or serve it like production:

```sh
docker compose up --build
```

Then open http://localhost:8080.

## How it works

Each field is described once, in the `fields` object: its input, its error
`<p>`, and a `validate(value)` rule that returns an error message, or `""` when
the value is fine. One function, `checkField`, runs a rule and shows the result.

- **On blur** (leaving a field) just that field is checked — early feedback
  without nagging while you type.
- **On submit** every field is checked so all errors appear at once, then the
  cursor jumps to the first one to fix. `preventDefault()` stops the form from
  being sent; this demo only validates.
- **Accessibility:** `aria-invalid="true"` marks a wrong field, and each input's
  `aria-describedby` points at its error `<p>`, so screen readers read the
  message aloud.
- `novalidate` on the `<form>` turns off the browser's own popups so ours show
  instead. The email rule is deliberately simple: `something@something.something`.

Try it: require a digit in the password (`&& /\d/.test(value)`), add a "terms"
checkbox that must be ticked, or disable the button until every field passes.

## Layout

```
index.html   the form: each input followed by its (empty) error <p>
app.js       the fields object, checkField() and the two event listeners
styles.css   the look — invalid fields get a red border
```

## Deploy

Make this folder the root of your own repo (`cp -r devai_boilerplates/form-validation my-app`,
then `git init` inside it), push it to GitHub, and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — the Web Basics track: HTML, CSS &
JavaScript, one concept at a time. Next up:
[faq-accordion](https://github.com/devai-io/devai_boilerplates/tree/main/faq-accordion).
