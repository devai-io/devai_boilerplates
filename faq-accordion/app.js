// FAQ Accordion — a list of questions where clicking one opens its answer and
// closes the others. Built on real <button>s, so it works with a mouse, a tap,
// or the keyboard, and screen readers announce whether each item is open.

// 1) Find every question button on the page.
const questions = document.querySelectorAll(".question");

// 2) Open one item: mark its button "expanded" and add a class the CSS uses to
//    slide the answer open. The button's parent is the whole .item.
function open(button) {
  button.setAttribute("aria-expanded", "true");
  button.parentElement.classList.add("open");
}

// 3) Close one item: exactly the opposite of open().
function close(button) {
  button.setAttribute("aria-expanded", "false");
  button.parentElement.classList.remove("open");
}

// 4) Clicking a question: if it's already open, just close it. Otherwise close
//    every question first (that's what makes it an accordion — only one open at
//    a time), then open the one that was clicked.
for (const button of questions) {
  button.addEventListener("click", () => {
    const isOpen = button.getAttribute("aria-expanded") === "true";
    questions.forEach(close);
    if (!isOpen) open(button);
  });
}
