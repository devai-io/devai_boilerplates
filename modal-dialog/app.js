// Modal Dialog — the modern, accessible way to show an overlay.
// Concept: the native <dialog> element. showModal() dims the page, traps keyboard
// focus inside the box, and wires up the Escape key — all for free, no library.

// 1) Grab the dialog and the buttons that open or close it.
const dialog = document.getElementById("dialog");
const openBtn = document.getElementById("open");
const closeBtn = document.getElementById("close");
const okBtn = document.getElementById("ok");
const status = document.getElementById("status");

// 2) Open it as a *modal*: everything behind it becomes inert and a backdrop appears.
//    (There's also dialog.show() for a non-modal pop-up, but modal is what we want.)
openBtn.addEventListener("click", () => dialog.showModal());

// 3) Two ways to close on purpose. close() can carry a value describing *why* it
//    closed — handy for knowing which button the user pressed.
closeBtn.addEventListener("click", () => dialog.close("dismissed"));
okBtn.addEventListener("click", () => dialog.close("ok"));

// 4) Click-outside-to-close. A modal's clickable area covers the whole screen, so a
//    click on the dark backdrop actually lands on the <dialog> element itself. If the
//    thing clicked IS the dialog (not the content inside it), close. This works
//    because the content lives in an inner wrapper that fills the visible box.
dialog.addEventListener("click", (event) => {
  if (event.target === dialog) dialog.close("backdrop");
});

// 5) The "close" event fires however it closed — button, backdrop, or Escape.
//    Escape sets no return value, so an empty returnValue tells us the user bailed.
dialog.addEventListener("close", () => {
  const reason = dialog.returnValue || "escape";
  status.textContent = `The dialog is closed (${reason}).`;
});
