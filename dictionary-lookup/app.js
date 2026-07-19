// Dictionary Lookup — type a word, fetch its definitions, show them.
// Concept: reading NESTED JSON — arrays inside objects inside arrays.

const form = document.getElementById("form");
const input = document.getElementById("word");
const entry = document.getElementById("entry");
const statusEl = document.getElementById("status");
const meaningsEl = document.getElementById("meanings");

async function lookup(word) {
  statusEl.textContent = "Loading…";
  entry.hidden = true;

  try {
    // The free Dictionary API. No key needed.
    // encodeURIComponent keeps odd characters from breaking the URL.
    const res = await fetch(
      `https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(word)}`,
    );

    if (res.status === 404) {
      // This API answers 404 when it simply has no entry for the word.
      statusEl.textContent = `No definition found for "${word}".`;
      return;
    }
    if (!res.ok) {
      throw new Error(`Dictionary API returned ${res.status}`);
    }

    // A successful answer is an ARRAY of entries. We show the first one: data[0].
    const data = await res.json();
    render(data[0]);
    statusEl.textContent = "";
  } catch (err) {
    statusEl.textContent = "Something went wrong. Try again in a moment.";
    console.error(err);
  }
}

// The shape we're reading — this is why it's a "nested JSON" lesson:
//
//   entry = {
//     word: "serendipity",
//     phonetic: "/ˌsɛɹənˈdɪpɪti/",              // may be missing
//     meanings: [                               // an array…
//       {
//         partOfSpeech: "noun",
//         definitions: [                        // …of objects, each holding an array…
//           { definition: "…", example: "…" }   // …of objects. Three levels deep!
//         ]
//       }
//     ]
//   }
//
// To reach the data we walk down the levels with loops.
function render(entryData) {
  document.getElementById("word-title").textContent = entryData.word;
  // `phonetic` is optional — fall back to an empty string if it's not there.
  document.getElementById("phonetic").textContent = entryData.phonetic || "";

  // Rebuild the meanings from scratch on every lookup.
  meaningsEl.replaceChildren();

  // Loop the OUTER array: one block per part of speech (noun, verb, …).
  for (const meaning of entryData.meanings) {
    const section = document.createElement("section");
    section.className = "meaning";

    const pos = document.createElement("h3");
    pos.className = "pos";
    pos.textContent = meaning.partOfSpeech;
    section.appendChild(pos);

    // Loop the INNER array: one list item per definition.
    const list = document.createElement("ol");
    list.className = "definitions";
    for (const def of meaning.definitions) {
      const li = document.createElement("li");
      li.textContent = def.definition;

      // `example` is optional too — only show it when the API gives us one.
      if (def.example) {
        const ex = document.createElement("p");
        ex.className = "example";
        ex.textContent = `“${def.example}”`;
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
  event.preventDefault(); // stop the form from reloading the page
  const word = input.value.trim();
  if (word) lookup(word);
});

// Look up one word on first load so the page isn't empty.
lookup("serendipity");
