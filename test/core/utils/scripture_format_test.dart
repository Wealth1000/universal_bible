import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_bible/core/utils/scripture_format.dart';

void main() {
  group('convertIsusSpansToJTags', () {
    test('converts Isus spans to J tags', () {
      expect(
        convertIsusSpansToJTags("<span class='Isus'>He said</span>"),
        '<J>He said</J>',
      );
      expect(
        convertIsusSpansToJTags('<span class="Isus">He said</span>'),
        '<J>He said</J>',
      );
    });
  });

  group('normalizeResolvedScriptureText', () {
    test('strips inline formatting tags', () {
      expect(
        normalizeResolvedScriptureText('<b>In</b> the <i>beginning</i>'),
        'In the beginning',
      );
    });

    test('decodes entities', () {
      expect(
        normalizeResolvedScriptureText('a &amp; b &lt;c&gt; &quot;d&quot;'),
        'a & b <c> "d"',
      );
    });

    test('converts <br> to newlines and paragraph breaks to blank lines', () {
      expect(normalizeResolvedScriptureText('one<br/>two'), 'one\ntwo');
      expect(
        normalizeResolvedScriptureText('<p>a</p><p>b</p>'),
        'a\n\nb',
      );
    });

    test('collapses runs of blank lines and trailing space', () {
      expect(
        normalizeResolvedScriptureText('a\n\n\n\n\nb   '),
        'a\n\nb',
      );
    });

    test('drops quote-only lines', () {
      final out = normalizeResolvedScriptureText('keep\n"\nalso keep');
      expect(out, 'keep\nalso keep');
    });

    test('words-of-Christ tags are stripped unless preserved', () {
      expect(
        normalizeResolvedScriptureText('<J>Faith</J> comes'),
        'Faith comes',
      );
      final preserved = normalizeResolvedScriptureText(
        '<J>Faith</J> comes',
        preserveWordsOfChrist: true,
      );
      expect(preserved, contains(wordsOfChristOpenMarker));
      expect(preserved, contains(wordsOfChristCloseMarker));
      // And the markers are the only markup left.
      expect(
        preserved.replaceAll(wordsOfChristOpenMarker, '')
            .replaceAll(wordsOfChristCloseMarker, ''),
        'Faith comes',
      );
    });
  });

  group('buildScriptureSpans', () {
    final base = const TextStyle(fontSize: 16);
    final red = base.copyWith(color: const Color(0xFFB00020));

    test('red-letters the segment between the markers', () {
      final text = normalizeResolvedScriptureText(
        'He said, <J>Follow me</J> and they followed.',
        preserveWordsOfChrist: true,
      );
      final spans = buildScriptureSpans(
        text,
        baseStyle: base,
        wordsOfChristColor: const Color(0xFFB00020),
      );
      expect(spans, hasLength(3));
      expect(spans[0].text, 'He said, ');
      expect(spans[0].style, base);
      expect(spans[1].text, 'Follow me');
      expect(spans[1].style, red);
      expect(spans[2].text, ' and they followed.');
      expect(spans[2].style, base);
    });

    test('text without markers is a single base-styled span', () {
      final spans = buildScriptureSpans(
        'Plain text',
        baseStyle: base,
        wordsOfChristColor: const Color(0xFFB00020),
      );
      expect(spans, hasLength(1));
      expect(spans[0].text, 'Plain text');
      expect(spans[0].style, base);
    });
  });
}
