import 'package:flutter_test/flutter_test.dart';
import 'package:universal_bible/features/rhapsody/application/scripture_resolver.dart';

void main() {
  group('parseScriptureReference', () {
    test('book + chapter + single verse', () {
      final r = parseScriptureReference('Proverbs 22:6')!;
      expect(r, isNotNull);
      expect(r.bookName, 'Proverbs');
      expect(r.chapter, 22);
      expect(r.startVerse, 6);
      expect(r.endVerse, isNull);
    });

    test('verse range with hyphen', () {
      final r = parseScriptureReference('2 Timothy 3:14-15')!;
      expect(r.bookName, '2 Timothy');
      expect(r.chapter, 3);
      expect(r.startVerse, 14);
      expect(r.endVerse, 15);
    });

    test('verse range with en-dash and spaced operands', () {
      final r = parseScriptureReference('2 Timothy 3:14 – 15')!;
      expect(r.startVerse, 14);
      expect(r.endVerse, 15);
    });

    test('book + chapter only means the whole chapter', () {
      final r = parseScriptureReference('Psalm 83')!;
      expect(r.chapter, 83);
      expect(r.startVerse, isNull);
      expect(r.endVerse, isNull);
    });

    test('trailing translation code is stripped', () {
      final r = parseScriptureReference('2 Timothy 3:14-15 NIV')!;
      expect(r.bookName, '2 Timothy');
      expect(r.startVerse, 14);
      expect(r.endVerse, 15);
    });

    test('leading-ordinal book names keep their ordinal', () {
      final r = parseScriptureReference('1 Samuel 2')!;
      expect(r.bookName, '1 Samuel');
      expect(r.chapter, 2);
    });

    test('non-references are rejected', () {
      expect(parseScriptureReference('not a reference'), isNull);
      expect(parseScriptureReference(''), isNull);
      expect(parseScriptureReference('   '), isNull);
      expect(parseScriptureReference('Genesis'), isNull); // no chapter
    });
  });

  group('normalizeBookKey', () {
    test('canonicalises short names', () {
      expect(normalizeBookKey('Psalm'), 'psalms');
      expect(normalizeBookKey('Genesis'), 'genesis');
    });

    test('canonicalises long titles to numbered-book keys', () {
      expect(
        normalizeBookKey(
          'The First Epistle of Paul the Apostle to the Corinthians',
        ),
        '1corinthians',
      );
    });

    test('canonicalises the galations source typo', () {
      expect(normalizeBookKey('galations'), 'galatians');
    });

    test('strips non-alphanumerics', () {
      expect(normalizeBookKey('Song of Solomon'), 'songofsolomon');
    });
  });
}
