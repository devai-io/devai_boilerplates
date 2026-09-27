const form = document.getElementById("form");
const successEl = document.getElementById("success");

// Every field is described in one place: its input, the <p> for its error, and
// a validate rule that returns an error message — or "" when the value is fine.
const fields = {
  name: {
    input: document.getElementById("name"),
    error: document.getElementById("nameError"),
    validate: (value) => (value.trim() ? "" : "Please enter your name."),
  },
  email: {
    input: document.getElementById("email"),
    error: document.getElementById("emailError"),
    // Deliberately simple: something@something.something. The real test of an
    // address is sending it an email.
    validate: (value) =>
      /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value) ? "" : "That doesn't look like an email.",
  },
  password: {
    input: document.getElementById("password"),
    error: document.getElementById("passwordError"),
    validate: (value) => (value.length >= 8 ? "" : "Use at least 8 characters."),
  },
  confirm: {
    input: document.getElementById("confirm"),
    error: document.getElementById("confirmError"),
    validate: (value) =>
      value === fields.password.input.value ? "" : "Passwords don't match.",
  },
};

// Run one rule and show the result right under its field. aria-invalid marks
// the input as wrong for screen readers, and the input's aria-describedby
// (in index.html) makes them read the message out too.
function checkField(field) {
  const message = field.validate(field.input.value);
  field.error.textContent = message;
  field.input.setAttribute("aria-invalid", message ? "true" : "false");
  return message === "";
}

// Check a field when you leave it ("blur"): early feedback, without nagging
// while you're still typing.
for (const field of Object.values(fields)) {
  field.input.addEventListener("blur", () => checkField(field));
}

// On submit, check every field so ALL the errors show at once, then move the
// cursor to the first one that needs fixing.
form.addEventListener("submit", (event) => {
  event.preventDefault(); // this demo only validates; nothing is sent anywhere

  const invalid = Object.values(fields).filter((field) => !checkField(field));

  successEl.textContent = invalid.length === 0 ? "All good! ✓" : "";
  if (invalid.length > 0) invalid[0].input.focus();
});
