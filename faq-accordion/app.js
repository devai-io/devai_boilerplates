const questions = document.querySelectorAll(".question");

// aria-expanded on the <button> is the single source of truth: screen readers
// announce it ("collapsed" / "expanded"), and the .open class lets the CSS
// slide the answer open to match.
function open(button) {
  button.setAttribute("aria-expanded", "true");
  button.parentElement.classList.add("open");
}

function close(button) {
  button.setAttribute("aria-expanded", "false");
  button.parentElement.classList.remove("open");
}

// Closing every item before opening the clicked one is what makes this an
// accordion: only one answer is ever open. Clicking an open question just closes it.
for (const button of questions) {
  button.addEventListener("click", () => {
    const wasOpen = button.getAttribute("aria-expanded") === "true";
    questions.forEach(close);
    if (!wasOpen) open(button);
  });
}
