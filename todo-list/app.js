const form = document.getElementById("form");
const input = document.getElementById("input");
const list = document.getElementById("list");
const countEl = document.getElementById("count");

// The single source of truth: an array of {text, done} objects. The page is
// only ever a drawing of this array. localStorage keeps it between visits, but
// it can only hold text, so we store the array as JSON and parse it back.
let tasks = JSON.parse(localStorage.getItem("tasks") || "[]");

function save() {
  localStorage.setItem("tasks", JSON.stringify(tasks));
}

// Change the array, save, render: every action below follows those three steps.
// render() throws the old list away and draws a fresh one from `tasks`, so the
// screen can never drift out of sync with the data.
function render() {
  list.replaceChildren();

  for (const task of tasks) {
    const li = document.createElement("li");
    li.className = task.done ? "item done" : "item";

    const checkbox = document.createElement("input");
    checkbox.type = "checkbox";
    checkbox.checked = task.done;
    checkbox.setAttribute("aria-label", task.text);
    checkbox.addEventListener("change", () => {
      task.done = checkbox.checked;
      save();
      render();
    });

    const span = document.createElement("span");
    span.className = "text";
    span.textContent = task.text;

    const del = document.createElement("button");
    del.className = "del";
    del.type = "button";
    del.textContent = "✕";
    del.setAttribute("aria-label", `Delete "${task.text}"`);
    del.addEventListener("click", () => {
      tasks = tasks.filter((t) => t !== task);
      save();
      render();
    });

    li.append(checkbox, span, del);
    list.append(li);
  }

  const left = tasks.filter((t) => !t.done).length;
  countEl.textContent = `${left} left`;
}

form.addEventListener("submit", (event) => {
  event.preventDefault();
  const text = input.value.trim();
  if (!text) return;

  tasks.push({ text, done: false });
  input.value = "";
  save();
  render();
});

render();
