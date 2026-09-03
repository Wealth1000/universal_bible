import 'package:flutter_test/flutter_test.dart';
import 'package:universal_bible/features/rhapsody/application/devotional_body_parser.dart';

void main() {
  group('parseDevotionalBody', () {
    test('empty input produces no paragraphs', () {
      expect(parseDevotionalBody(''), isEmpty);
      expect(parseDevotionalBody('   \n  '), isEmpty);
    });

    test('plain paragraph becomes a single span', () {
      final ps = parseDevotionalBody('<p>Hello world</p>');
      expect(ps, hasLength(1));
      expect(ps[0].spans, hasLength(1));
      expect(ps[0].spans[0].text, 'Hello world');
      expect(ps[0].spans[0].bold, isFalse);
      expect(ps[0].spans[0].scriptureRef, isNull);
    });

    test('bold and italic nesting set span styles', () {
      final ps = parseDevotionalBody(
        '<p><strong>Bold</strong> and <em>italic</em> and '
        '<b><i>both</i></b></p>',
      );
      final spans = ps.single.spans;
      expect(spans, hasLength(5));
      expect(spans[0].text, 'Bold');
      expect(spans[0].bold, isTrue);
      expect(spans[1].italic, isFalse);
      expect(spans[2].text, 'italic');
      expect(spans[2].italic, isTrue);
      expect(spans[4].bold, isTrue);
      expect(spans[4].italic, isTrue);
    });

    test('anchor text becomes a scripture reference span', () {
      final ps = parseDevotionalBody(
        '<p>Read <a href="/scripture">Proverbs 22:6</a> today</p>',
      );
      final spans = ps.single.spans;
      final ref = spans.firstWhere((s) => s.text == 'Proverbs 22:6');
      expect(ref.isScripture, isTrue);
      expect(ref.scriptureRef, 'Proverbs 22:6');
      // Text outside the anchor is not a link.
      expect(spans.firstWhere((s) => s.text == 'Read ').isScripture, isFalse);
      expect(spans.lastWhere((s) => s.text == ' today').isScripture, isFalse);
    });

    test('paragraphs split on <p> boundaries', () {
      final ps = parseDevotionalBody('<p>One</p><p>Two</p>');
      expect(ps, hasLength(2));
      expect(ps[0].spans.single.text, 'One');
      expect(ps[1].spans.single.text, 'Two');
    });

    test('trailing text after the last tag is kept', () {
      final ps = parseDevotionalBody('<p>One</p>Two');
      expect(ps, hasLength(2));
      expect(ps[1].spans.single.text, 'Two');
    });

    test('unbalanced closing tags never drive depth negative', () {
      final ps = parseDevotionalBody('<p></b>Bold? No.</p>');
      final span = ps.single.spans.single;
      expect(span.bold, isFalse);
      expect(span.text, 'Bold? No.');
    });

    test('unrecognized tags degrade to plain text', () {
      final ps = parseDevotionalBody('<p><marquee>Weird</marquee> tail</p>');
      final text = ps.single.spans.map((s) => s.text).join();
      expect(text, contains('Weird'));
      expect(text, contains('tail'));
    });

    test('entities are decoded', () {
      final ps = parseDevotionalBody('<p>Fish &amp; chips &quot;q&quot;</p>');
      expect(ps.single.spans.single.text, 'Fish & chips "q"');
    });

    test('empty paragraphs are dropped', () {
      final ps = parseDevotionalBody('<p></p><p>Real</p><p>  </p>');
      expect(ps, hasLength(1));
      expect(ps[0].spans.single.text, 'Real');
    });
  });

  group('parseReferenceList', () {
    test('null yields nothing', () {
      expect(parseReferenceList(null), isEmpty);
    });

    test('splits on semicolons and trims', () {
      expect(
        parseReferenceList('Ephesians 6:4 NIV; 2 Timothy 3:14-15 NIV'),
        ['Ephesians 6:4 NIV', '2 Timothy 3:14-15 NIV'],
      );
    });

    test('splits on literal & after entity decoding', () {
      expect(
        parseReferenceList('Psalm 83 &amp; Gen 1:45'),
        ['Psalm 83', 'Gen 1:45'],
      );
      expect(parseReferenceList('Psalm 83 & Gen 1:45'), ['Psalm 83', 'Gen 1:45']);
    });

    test('drops empty segments', () {
      expect(parseReferenceList(';; John 3:16 ;'), ['John 3:16']);
    });
  });
}
