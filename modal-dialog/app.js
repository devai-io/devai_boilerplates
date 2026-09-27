const dialog = document.getElementById("dialog");
const openBtn = document.getElementById("open");
const closeBtn = document.getElementById("close");
const okBtn = document.getElementById("ok");
const status = document.getElementById("status");

// showModal() is the whole trick: the browser dims the page behind a
// ::backdrop, makes it inert, moves focus into the dialog, closes it on Escape,
// and hands focus back to this button afterwards. No library needed.
openBtn.addEventListener("click", () => {
  dialog.returnValue = ""; // forget why it closed last time
  dialog.showModal();
});

// close(value) records WHY it closed in dialog.returnValue.
closeBtn.addEventListener("click", () => dialog.close("dismissed"));
okBtn.addEventListener("click", () => dialog.close("ok"));

// A click on the dimmed backdrop lands on the <dialog> element itself; clicks
// on the content land on its children. The dialog has no padding and the inner
// .dialog-body fills it, so "target is the dialog" means "outside the box".
dialog.addEventListener("click", (event) => {
  if (event.target === dialog) dialog.close("backdrop");
});

// "close" fires however it closed. Escape sets no returnValue, so an empty
// one means the user pressed Escape.
dialog.addEventListener("close", () => {
  status.textContent = `The dialog is closed (${dialog.returnValue || "escape"}).`;
});
