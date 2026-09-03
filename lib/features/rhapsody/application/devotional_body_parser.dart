/// Parses the Rhapsody devotional `body` HTML into a lightweight span model
/// the UI can render with `RichText`, and splits the `;`-separated reading
/// lists into scripture references.
///
/// The source HTML is small and regular — a sequence of `<p>` blocks whose
/// inline content uses only `<strong>/<b>`, `<i>/<em>`, and `<a href>` (the
/// links are always scripture references). Rather than pull in a full HTML
/// rendering dependency, we walk the markup with a tiny tag tokenizer that
/// tracks bold/italic/link nesting depth. Anything we don't recognise is
/// treated as text, so unexpected markup degrades to plain reading text.
library;

/// One paragraph of the devotional body.
class DevotionalParagraph {
  const DevotionalParagraph(this.spans);

  final List<DevotionalSpan> spans;

  bool get isEmpty => spans.every((s) => s.text.trim().isEmpty);
}

/// A run of body text sharing the same styling. When [scriptureRef] is
/// non-null the run is a tappable scripture reference (rubricated in the UI).
class DevotionalSpan {
  const DevotionalSpan({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.scriptureRef,
  });

  final String text;
  final bool bold;
  final bool italic;
  final String? scriptureRef;

  bool get isScripture => scriptureRef != null;
}

final _tagPattern = RegExp(
  r'<\s*(/?)\s*(strong|b|i|em|a|p|br)\b([^>]*)>',
  caseSensitive: false,
);

final _hrefPattern = RegExp(
  '''href\\s*=\\s*(?:"([^"]*)"|'([^']*)')''',
  caseSensitive: false,
);

/// Parses [html] into display paragraphs. Never throws — malformed input is
/// rendered as best-effort plain text.
List<DevotionalParagraph> parseDevotionalBody(String html) {
  if (html.trim().isEmpty) return const [];

  final paragraphs = <DevotionalParagraph>[];
  var current = <DevotionalSpan>[];

  var boldDepth = 0;
  var italicDepth = 0;
  String? currentHref;

  void flushParagraph() {
    // Drop leading/trailing empty runs but keep meaningful ones. Whitespace
    // (or <br>-only) paragraphs count as empty — DevotionalParagraph.isEmpty
    // checks trimmed text.
    final trimmed = current
        .where((s) => s.text.isNotEmpty)
        .toList(growable: false);
    final paragraph = DevotionalParagraph(trimmed);
    if (!paragraph.isEmpty) paragraphs.add(paragraph);
    current = <DevotionalSpan>[];
  }

  void addText(String raw) {
    if (raw.isEmpty) return;
    final text = _decodeEntities(raw);
    if (text.isEmpty) return;
    current.add(
      DevotionalSpan(
        text: text,
        bold: boldDepth > 0,
        italic: italicDepth > 0,
        // A link's display text is the human reference (e.g. "Proverbs 22:6").
        scriptureRef: currentHref != null ? text.trim() : null,
      ),
    );
  }

  var cursor = 0;
  for (final m in _tagPattern.allMatches(html)) {
    if (m.start > cursor) {
      addText(html.substring(cursor, m.start));
    }
    cursor = m.end;

    final isClosing = m.group(1) == '/';
    final tag = m.group(2)!.toLowerCase();
    final attrs = m.group(3) ?? '';

    switch (tag) {
      case 'strong':
      case 'b':
        boldDepth += isClosing ? -1 : 1;
        if (boldDepth < 0) boldDepth = 0;
        break;
      case 'i':
      case 'em':
        italicDepth += isClosing ? -1 : 1;
        if (italicDepth < 0) italicDepth = 0;
        break;
      case 'a':
        if (isClosing) {
          currentHref = null;
        } else {
          final href = _hrefPattern.firstMatch(attrs);
          currentHref = href?.group(1) ?? href?.group(2) ?? '';
        }
        break;
      case 'p':
        // Close on either open or close of a <p> — paragraphs never nest here.
        flushParagraph();
        break;
      case 'br':
        current.add(const DevotionalSpan(text: '\n'));
        break;
    }
  }
  if (cursor < html.length) {
    addText(html.substring(cursor));
  }
  flushParagraph();

  return paragraphs;
}

/// Splits a reference string on the top-level delimiters `;` and `&` (e.g.
/// "Ephesians 6:4 NIV; 2 Timothy 3:14-15 NIV", "Psalm 83 & Gen 1:45") into
/// trimmed references. Entities are decoded first so an `&amp;` in source
/// data behaves like a literal `&` delimiter rather than splitting mid-entity.
List<String> parseReferenceList(String? raw) {
  if (raw == null) return const [];
  return _decodeEntities(raw)
      .split(RegExp(r'[;&]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
}

/// Decodes the handful of HTML entities that appear in the source content.
String _decodeEntities(String input) {
  if (!input.contains('&')) return input;
  return input
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}
