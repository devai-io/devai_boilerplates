import 'package:flutter/material.dart';

// Markdown → widgets (never HTML); links are styled but deliberately not tappable.

List<InlineSpan> _inline(String text, ColorScheme colors) {
  final spans = <InlineSpan>[];
  final re = RegExp(r'(`[^`]+`)|(\*\*[^*]+\*\*)|(\*[^*]+\*)|(\[([^\]]+)\]\(([^)\s]+)\))');
  var last = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
    if (m.group(1) != null) {
      final code = m.group(1)!;
      spans.add(
        TextSpan(
          text: code.substring(1, code.length - 1),
          style: TextStyle(
            fontFamily: 'monospace',
            backgroundColor: colors.surfaceContainerHighest,
          ),
        ),
      );
    } else if (m.group(2) != null) {
      final bold = m.group(2)!;
      spans.add(
        TextSpan(
          text: bold.substring(2, bold.length - 2),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    } else if (m.group(3) != null) {
      final italic = m.group(3)!;
      spans.add(
        TextSpan(
          text: italic.substring(1, italic.length - 1),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: m.group(5)!,
          style: TextStyle(color: colors.primary, decoration: TextDecoration.underline),
        ),
      );
    }
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return spans;
}

class MarkdownBody extends StatelessWidget {
  const MarkdownBody({super.key, required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final body = theme.textTheme.bodyLarge!.copyWith(height: 1.6);
    final headings = [
      theme.textTheme.headlineSmall!,
      theme.textTheme.titleLarge!,
      theme.textTheme.titleMedium!,
      theme.textTheme.titleSmall!,
    ];

    final blocks = <Widget>[];
    final lines = source.split('\n');
    final blockStart = RegExp(r'^(#|```|[-*]\s|> )');
    var i = 0;

    Widget rich(String text, TextStyle style) =>
        Text.rich(TextSpan(children: _inline(text, colors)), style: style);

    while (i < lines.length) {
      final line = lines[i];

      if (line.trim().isEmpty) {
        i++;
        continue;
      }

      if (line.startsWith('```')) {
        final code = <String>[];
        i++;
        while (i < lines.length && !lines[i].startsWith('```')) {
          code.add(lines[i++]);
        }
        i++; // closing fence
        blocks.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              code.join('\n'),
              style: body.copyWith(fontFamily: 'monospace', fontSize: 13, height: 1.5),
            ),
          ),
        );
        continue;
      }

      final h = RegExp(r'^(#{1,4})\s+(.*)$').firstMatch(line);
      if (h != null) {
        final style = headings[h.group(1)!.length - 1].copyWith(fontWeight: FontWeight.w600);
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 6),
            child: rich(h.group(2)!, style),
          ),
        );
        i++;
        continue;
      }

      if (RegExp(r'^[-*]\s+').hasMatch(line)) {
        while (i < lines.length && RegExp(r'^[-*]\s+').hasMatch(lines[i])) {
          final item = lines[i++].replaceFirst(RegExp(r'^[-*]\s+'), '');
          blocks.add(
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: body),
                  Expanded(child: rich(item, body)),
                ],
              ),
            ),
          );
        }
        continue;
      }

      if (line.startsWith('> ')) {
        final quote = <String>[];
        while (i < lines.length && lines[i].startsWith('> ')) {
          quote.add(lines[i++].substring(2));
        }
        blocks.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.only(left: 14),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: colors.primary, width: 2)),
            ),
            child: rich(
              quote.join(' '),
              body.copyWith(fontStyle: FontStyle.italic, color: colors.onSurfaceVariant),
            ),
          ),
        );
        continue;
      }

      final para = <String>[];
      while (i < lines.length && lines[i].trim().isNotEmpty && !blockStart.hasMatch(lines[i])) {
        para.add(lines[i++]);
      }
      blocks.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: rich(para.join(' '), body),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks);
  }
}
