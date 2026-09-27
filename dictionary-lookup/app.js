const form = document.getElementById("form");
const input = document.getElementById("word");
const entry = document.getElementById("entry");
const statusEl = document.getElementById("status");
const meaningsEl = document.getElementById("meanings");

async function lookup(word) {
  statusEl.textContent = "Loading…";
  entry.hidden = true;

  try {
    // Free Dictionary API: English Wiktionary as JSON, no key needed.
    const res = await fetch(
      `https://freedictionaryapi.com/api/v1/entries/en/${encodeURIComponent(word)}`,
    );
    if (res.status === 429) {
      statusEl.textContent = "Too many lookups this hour — try again later.";
      return;
    }
    if (!res.ok) throw new Error(`Dictionary API returned ${res.status}`);

    const data = await res.json();
    // An unknown word still answers 200 — just with an empty entries array.
    if (data.entries.length === 0) {
      statusEl.textContent = `No definition found for "${word}".`;
      return;
    }

    render(data);
    statusEl.textContent = "";
  } catch (err) {
    statusEl.textContent = "Something went wrong. Try again in a moment.";
    console.error(err);
  }
}

// The answer is NESTED: arrays inside objects inside arrays. Three levels deep.
//
//   data = {
//     word: "curious",
//     entries: [                                  // level 1: one per part of speech
//       {
//         partOfSpeech: "adjective",
//         pronunciations: [{ type: "ipa", text: "/ˈkjʊə.ɹi.əs/" }],
//         senses: [                               // level 2: one per meaning
//           {
//             definition: "Tending to ask questions…",
//             examples: ["Young children are naturally curious…"],  // level 3
//           },
//         ],
//       },
//     ],
//   }
//
// To reach the data, walk down one loop per level.
function render(data) {
  document.getElementById("word-title").textContent = data.word;

  // Pronunciations are optional: take the first IPA one from any entry, if any.
  const ipa = data.entries
    .flatMap((e) => e.pronunciations || [])
    .find((p) => p.type === "ipa");
  document.getElementById("phonetic").textContent = ipa ? ipa.text : "";

  meaningsEl.replaceChildren();

  for (const item of data.entries) {
    const section = document.createElement("section");
    section.className = "meaning";

    const pos = document.createElement("h3");
    pos.className = "pos";
    pos.textContent = item.partOfSpeech;
    section.appendChild(pos);

    const list = document.createElement("ol");
    list.className = "definitions";
    for (const sense of item.senses) {
      const li = document.createElement("li");
      li.textContent = sense.definition;

      // examples is optional too — show the first one when there is one.
      const example = sense.examples?.[0];
      if (example) {
        const ex = document.createElement("p");
        ex.className = "example";
        ex.textContent = `“${example}”`;
        li.appendChild(ex);
      }
      list.appendChild(li);
    }
    section.appendChild(list);
    meaningsEl.appendChild(section);
  }

  entry.hidden = false;
}

form.addEventListener("submit", (event) => {
  event.preventDefault();
  const word = input.value.trim();
  if (word) lookup(word);
});

lookup("curious");
