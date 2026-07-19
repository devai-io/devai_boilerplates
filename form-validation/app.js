// Form Validation — check what the user typed BEFORE accepting it, and show a
// helpful message under each field instead of a scary browser popup.

// 1) Grab the form, and describe each field in one place: its input, its error
//    <p>, and a `validate` rule that returns an error message ("" means OK).
const form = document.getElementById("form");

const fields = {
  name: {
    input: document.getElementById("name"),
    error: document.getElementById("nameError"),
    validate: (value) => (value.trim() ? "" : "Please enter your name."),
  },
  email: {
    input: document.getElementById("email"),
    error: document.getElementById("emailError"),
    // A deliberately simple pattern: something@something.something.
    validate: (value) =>
      /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)
        ? ""
        : "That doesn't look like an email.",
  },
  password: {
    input: document.getElementById("password"),
    error: document.getElementById("passwordError"),
    validate: (value) =>
      value.length >= 8 ? "" : "Use at least 8 characters.",
  },
  confirm: {
    input: document.getElementById("confirm"),
    error: document.getElementById("confirmError"),
    // This rule looks at another field: the password we typed above.
    validate: (value) =>
      value === fields.password.input.value ? "" : "Passwords don't match.",
  },
};

const successEl = document.getElementById("success");

// 2) Check one field: run its rule, show or clear the message, and mark the
//    input with aria-invalid so screen readers announce the problem. Returns
//    true when the field is fine.
function checkField(field) {
  const message = field.validate(field.input.value);
  field.error.textContent = message;
  field.input.setAttribute("aria-invalid", message ? "true" : "false");
  return message === "";
}

// 3) When someone leaves a field (the "blur" event), check just that field.
//    This gives feedback early, without nagging while they're still typing.
for (const field of Object.values(fields)) {
  field.input.addEventListener("blur", () => checkField(field));
}

// 4) On submit, check every field. preventDefault stops the browser from
//    actually sending the form anywhere — this demo only validates.
form.addEventListener("submit", (event) => {
  event.preventDefault();

  // Run every check first (so ALL errors appear at once), then ask: did they
  // all pass? .map returns an array of true/false; .every is true only if all
  // are true.
  const results = Object.values(fields).map(checkField);
  const allValid = results.every((ok) => ok);

  successEl.textContent = allValid ? "All good! ✓" : "";
});
