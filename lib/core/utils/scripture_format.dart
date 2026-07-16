import 'package:flutter/material.dart';

/// Sentinel markers for words-of-Christ segments. Unicode private-use
/// characters — guaranteed never to appear in actual scripture text, so
/// they safely survive the generic HTML tag strip.
const wordsOfChristOpenMarker = '';
const wordsOfChristCloseMarker = '';

/// Converts `<span class='Isus'>` and `</span>` to `<J>` and `</J>` tags.
/// This is a preprocessing step for `normalizeResolvedScriptureText`.
String convertIsusSpansToJTags(String input) {
  var s = input;
  // Use a triple-quoted raw string to avoid escaping single/double quotes.
  s = s.replaceAll(
    RegExp(r'''<span\s+class=['"]Isus['"]>''', caseSensitive: false),
    '<J>',
  );
  s = s.replaceAll(
    RegExp(r'</span>', caseSensitive: false),
    '</J>',
  );
  return s;
}

String normalizeResolvedScriptureText(
  String input, {
  bool preserveWordsOfChrist = false,
}) {
  var s = convertIsusSpansToJTags(input);
  s = s.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  // Convert words-of-Christ tags to sentinels BEFORE the generic tag strip
  // below, so the distinction survives. `<J>` is the MyBible/Sword convention.
  if (preserveWordsOfChrist) {
    s = s
        .replaceAll(
          RegExp(r'<\s*J\s*>', caseSensitive: false),
          wordsOfChristOpenMarker,
        )
        .replaceAll(
          RegExp(r'<\s*/\s*J\s*>', caseSensitive: false),
          wordsOfChristCloseMarker,
        );
  }
  s = s.replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n');
  s = s.replaceAll(
    RegExp(r'<\s*/\s*p\s*>\s*<\s*p[^>]*\s*>', caseSensitive: false),
    '\n\n',
  );
  s = s.replaceAll(RegExp(r'<\s*p[^>]*\s*>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<\s*/\s*p\s*>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<\s*li[^>]*\s*>', caseSensitive: false), '• ');
  s = s.replaceAll(RegExp(r'<\s*/\s*li\s*>', caseSensitive: false), '\n');
  s = s.replaceAll(
    RegExp(r'<\s*/?\s*(i|em|b|strong|u|span)[^>]*\s*>', caseSensitive: false),
    '',
  );
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  // Drop isolated quote-only lines and compress extra blank space.
  final lines = s
      .split('\n')
      .map((l) => l.trimRight())
      .map((l) => l.trimLeft())
      .toList(growable: false);
  final filtered = <String>[];
  for (final line in lines) {
    final t = line.trim();
    if (t == '"' || t == "'") continue;
    final withVersionColon = line.replaceFirstMapped(
      RegExp(r'^\[([A-Za-z0-9,\s-]+)\](?!\s*:)\s*'),
      (m) => '[${m.group(1)!.trim()}]: ',
    );
    filtered.add(withVersionColon);
  }
  s = filtered.join('\n');
  s = s.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}

/// Builds styled [TextSpan]s from text normalized with
/// `normalizeResolvedScriptureText(..., preserveWordsOfChrist: true)`.
/// Segments between the words-of-Christ sentinels are rendered in
/// [wordsOfChristColor] (red-letter edition); everything else uses
/// [baseStyle] unchanged.
List<TextSpan> buildScriptureSpans(
  String normalizedText, {
  required TextStyle baseStyle,
  required Color wordsOfChristColor,
}) {
  final spans = <TextSpan>[];
  final redStyle = baseStyle.copyWith(color: wordsOfChristColor);
  var inRed = false;
  var start = 0;
  for (var i = 0; i < normalizedText.length; i++) {
    final ch = normalizedText[i];
    if (ch == wordsOfChristOpenMarker || ch == wordsOfChristCloseMarker) {
      if (i > start) {
        spans.add(TextSpan(
          text: normalizedText.substring(start, i),
          style: inRed ? redStyle : baseStyle,
        ));
      }
      inRed = ch == wordsOfChristOpenMarker;
      start = i + 1;
    }
  }
  if (start < normalizedText.length) {
    spans.add(TextSpan(
      text: normalizedText.substring(start),
      style: inRed ? redStyle : baseStyle,
    ));
  }
  return spans;
}

/// Theme-aware red for words of Christ.
Color wordsOfChristColorFor(Brightness brightness) =>
    brightness == Brightness.dark
        ? const Color(0xFFEF5350) // lighter red for dark backgrounds
        : const Color(0xFFB71C1C); // deep red for light backgrounds
