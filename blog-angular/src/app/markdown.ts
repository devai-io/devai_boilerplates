import { Component, computed, input } from "@angular/core";

export interface Span {
  kind: "text" | "code" | "strong" | "em" | "link";
  text: string;
  href?: string;
}

export interface Block {
  tag: "h1" | "h2" | "h3" | "h4" | "p" | "blockquote" | "pre" | "ul";
  spans: Span[];
  items: Span[][];
}

// Parsed to data, rendered by interpolation (no [innerHTML]); only web/mail links become <a>.
const SAFE_HREF = /^(https?:|mailto:|\/|#)/i;
const INLINE = /(`[^`]+`)|(\*\*[^*]+\*\*)|(\*[^*]+\*)|(\[([^\]]+)\]\(([^)\s]+)\))/g;
const BLOCK_START = /^(#|```|[-*]\s|> )/;

function spans(text: string): Span[] {
  const out: Span[] = [];
  let last = 0;
  for (const m of text.matchAll(INLINE)) {
    if (m.index > last) out.push({ kind: "text", text: text.slice(last, m.index) });
    if (m[1]) out.push({ kind: "code", text: m[1].slice(1, -1) });
    else if (m[2]) out.push({ kind: "strong", text: m[2].slice(2, -2) });
    else if (m[3]) out.push({ kind: "em", text: m[3].slice(1, -1) });
    else if (SAFE_HREF.test(m[6])) out.push({ kind: "link", text: m[5], href: m[6] });
    else out.push({ kind: "text", text: m[5] });
    last = m.index + m[0].length;
  }
  if (last < text.length) out.push({ kind: "text", text: text.slice(last) });
  return out;
}

export function parseMarkdown(source: string): Block[] {
  const lines = source.split("\n");
  const blocks: Block[] = [];
  const block = (tag: Block["tag"], text: string): Block => ({ tag, spans: spans(text), items: [] });
  let i = 0;

  while (i < lines.length) {
    const line = lines[i];

    if (line.trim() === "") {
      i++;
    } else if (line.startsWith("```")) {
      const code: string[] = [];
      i++;
      while (i < lines.length && !lines[i].startsWith("```")) code.push(lines[i++]);
      i++; // closing fence
      blocks.push({ tag: "pre", spans: [{ kind: "text", text: code.join("\n") }], items: [] });
    } else if (/^#{1,4}\s/.test(line)) {
      const [, hashes, text] = /^(#{1,4})\s+(.*)$/.exec(line)!;
      blocks.push(block(`h${hashes.length}` as Block["tag"], text));
      i++;
    } else if (/^[-*]\s+/.test(line)) {
      const items: Span[][] = [];
      while (i < lines.length && /^[-*]\s+/.test(lines[i]))
        items.push(spans(lines[i++].replace(/^[-*]\s+/, "")));
      blocks.push({ tag: "ul", spans: [], items });
    } else if (line.startsWith("> ")) {
      const quote: string[] = [];
      while (i < lines.length && lines[i].startsWith("> ")) quote.push(lines[i++].slice(2));
      blocks.push(block("blockquote", quote.join(" ")));
    } else {
      const para: string[] = [];
      while (i < lines.length && lines[i].trim() !== "" && !BLOCK_START.test(lines[i]))
        para.push(lines[i++]);
      blocks.push(block("p", para.join(" ")));
    }
  }
  return blocks;
}

@Component({
  selector: "app-spans",
  template: `
    @for (s of spans(); track $index) {
      @switch (s.kind) {
        @case ("code") {
          <code>{{ s.text }}</code>
        }
        @case ("strong") {
          <strong>{{ s.text }}</strong>
        }
        @case ("em") {
          <em>{{ s.text }}</em>
        }
        @case ("link") {
          <a [href]="s.href" target="_blank" rel="noreferrer">{{ s.text }}</a>
        }
        @default {
          <ng-container>{{ s.text }}</ng-container>
        }
      }
    }
  `,
})
export class Spans {
  readonly spans = input.required<Span[]>();
}

@Component({
  selector: "app-markdown",
  imports: [Spans],
  template: `
    <div class="prose-blog">
      @for (b of blocks(); track $index) {
        @switch (b.tag) {
          @case ("h1") {
            <h1><app-spans [spans]="b.spans" /></h1>
          }
          @case ("h2") {
            <h2><app-spans [spans]="b.spans" /></h2>
          }
          @case ("h3") {
            <h3><app-spans [spans]="b.spans" /></h3>
          }
          @case ("h4") {
            <h4><app-spans [spans]="b.spans" /></h4>
          }
          @case ("blockquote") {
            <blockquote><app-spans [spans]="b.spans" /></blockquote>
          }
          @case ("pre") {
            <pre><code>{{ b.spans[0].text }}</code></pre>
          }
          @case ("ul") {
            <ul>
              @for (item of b.items; track $index) {
                <li><app-spans [spans]="item" /></li>
              }
            </ul>
          }
          @default {
            <p><app-spans [spans]="b.spans" /></p>
          }
        }
      }
    </div>
  `,
})
export class Markdown {
  readonly source = input.required<string>();
  protected readonly blocks = computed(() => parseMarkdown(this.source()));
}
