// To-Do List — keep the tasks in an array, redraw the list from that array,
// and save it so your tasks are still here after you refresh the page.

// 1) Grab the elements we need from the page.
const form = document.getElementById("form");
const input = document.getElementById("input");
const list = document.getElementById("list");
const countEl = document.getElementById("count");

// 2) Our single source of truth: an array of task objects like {text, done}.
//    We load whatever was saved last time, or start with an empty list.
//    localStorage can only hold text, so we JSON.parse it back into an array.
let tasks = JSON.parse(localStorage.getItem("tasks") || "[]");

// 3) Save the current array back to the browser as text.
function save() {
  localStorage.setItem("tasks", JSON.stringify(tasks));
}

// 4) Rebuild the whole <ul> from the array. Whenever `tasks` changes we just
//    call this and let it redraw everything — simpler than editing the list
//    by hand, and the screen always matches the array.
function render() {
  list.innerHTML = ""; // clear what's there, then build it fresh

  for (const task of tasks) {
    const li = document.createElement("li");
    li.className = task.done ? "item done" : "item";

    // A checkbox to mark the task done or not-done.
    const checkbox = document.createElement("input");
    checkbox.type = "checkbox";
    checkbox.checked = task.done;
    checkbox.addEventListener("change", () => {
      task.done = checkbox.checked; // task is a reference into the array
      save();
      render();
    });

    // The task text.
    const span = document.createElement("span");
    span.className = "text";
    span.textContent = task.text;

    // A ✕ button that removes just this one task.
    const del = document.createElement("button");
    del.className = "del";
    del.type = "button";
    del.textContent = "✕";
    del.setAttribute("aria-label", "Delete task");
    del.addEventListener("click", () => {
      tasks = tasks.filter((t) => t !== task); // keep every task except this one
      save();
      render();
    });

    li.append(checkbox, span, del);
    list.append(li);
  }

  // 5) Count how many are still unfinished and show it.
  const left = tasks.filter((t) => !t.done).length;
  countEl.textContent = `${left} left`;
}

// 6) Adding a task: read the box, push onto the array, save, redraw.
form.addEventListener("submit", (event) => {
  event.preventDefault(); // stop the form from reloading the page
  const text = input.value.trim();
  if (!text) return; // ignore empty submits

  tasks.push({ text, done: false });
  input.value = "";
  save();
  render();
});

// 7) Draw once when the page first loads.
render();
