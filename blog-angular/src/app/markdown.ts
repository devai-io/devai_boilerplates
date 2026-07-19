import { Pipe, PipeTransform } from "@angular/core";

// Tiny markdown → HTML converter: headings, paragraphs, code fences, lists,
// blockquotes, bold/italic/inline code/links. Everything is HTML-escaped before
// any markup is generated, and Angular sanitizes the [innerHTML] binding on top.

function escape(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function inline(raw: string): string {
  return escape(raw)
    .replace(/`([^`]+)`/g, "<code>$1</code>")
    .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
    .replace(/\*([^*]+)\*/g, "<em>$1</em>")
    .replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, '<a href="$2">$1</a>');
}

export function mdToHtml(source: string): string {
  const lines = source.split("\n");
  const out: string[] = [];
  let i = 0;

  while (i < lines.length) {
    const line = lines[i];

    if (line.trim() === "") {
      i++;
      continue;
    }

    if (line.startsWith("```")) {
      const code: string[] = [];
      i++;
      while (i < lines.length && !lines[i].startsWith("```")) code.push(lines[i++]);
      i++; // closing fence
      out.push(`<pre><code>${escape(code.join("\n"))}</code></pre>`);
      continue;
    }

    const h = /^(#{1,4})\s+(.*)$/.exec(line);
    if (h) {
      const level = h[1].length;
      out.push(`<h${level}>${inline(h[2])}</h${level}>`);
      i++;
      continue;
    }

    if (/^[-*]\s+/.test(line)) {
      const items: string[] = [];
      while (i < lines.length && /^[-*]\s+/.test(lines[i]))
        items.push(`<li>${inline(lines[i++].replace(/^[-*]\s+/, ""))}</li>`);
      out.push(`<ul>${items.join("")}</ul>`);
      continue;
    }

    if (line.startsWith("> ")) {
      const quote: string[] = [];
      while (i < lines.length && lines[i].startsWith("> ")) quote.push(lines[i++].slice(2));
      out.push(`<blockquote>${inline(quote.join(" "))}</blockquote>`);
      continue;
    }

    const para: string[] = [];
    while (i < lines.length && lines[i].trim() !== "" && !/^(#|```|[-*]\s|> )/.test(lines[i]))
      para.push(lines[i++]);
    out.push(`<p>${inline(para.join(" "))}</p>`);
  }

  return out.join("\n");
}

@Pipe({ name: "markdown", standalone: true })
export class MarkdownPipe implements PipeTransform {
  transform(source: string): string {
    return mdToHtml(source);
  }
}
