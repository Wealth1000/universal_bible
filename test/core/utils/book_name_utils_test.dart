import 'package:flutter_test/flutter_test.dart';
import 'package:universal_bible/core/utils/book_name_utils.dart';

void main() {
  group('cleanBookName', () {
    test('long concatenated titles resolve to the canonical book', () {
      expect(
        cleanBookName('thefirstbookofmosescalledgenesis'),
        'Genesis',
      );
      expect(cleanBookName('thegospelaccordingtomatthew'), 'Matthew');
      expect(cleanBookName('theacts oftheapostles'), 'Acts');
    });

    test('ordinals prefix genuinely numbered books only', () {
      expect(
        cleanBookName('thefirstepistleofpaultheapostletothecorinthians'),
        '1 Corinthians',
      );
      expect(cleanBookName('thesecondbookofthekings'), '2 Kings');
      expect(cleanBookName('1peter'), '1 Peter');
      // "the FIRST book of moses called genesis" must NOT become
      // "1 Genesis" — Genesis is not a numbered book.
      expect(cleanBookName('thefirstbookofmosescalledgenesis'), isNot('1 Genesis'));
    });

    test('Song of Solomon / Song of Songs special case', () {
      expect(cleanBookName('thesongofsolomon'), 'Song of Solomon');
      expect(cleanBookName('thesongofsongs'), 'Song of Songs');
    });

    test('variants and source-data typos', () {
      expect(cleanBookName('psalm'), 'Psalms');
      expect(cleanBookName('galations'), 'Galatians'); // known typo
      expect(
        cleanBookName('therevelationofjesuschrist'),
        'Revelation',
      );
    });

    test('unknown keys fall back to the formatted original title', () {
      // Not a real book: keep the words intact rather than shredding them.
      final result = cleanBookName('thebookofenoch');
      expect(result, isNot(contains('1')));
      expect(result.toLowerCase(), contains('enoch'));
    });
  });

  group('preserveBookName', () {
    test('segments and title-cases with minor words lowercase', () {
      expect(
        preserveBookName('thefirstbookofmosescalledgenesis'),
        'The First Book of Moses called Genesis',
      );
      expect(
        preserveBookName('thegospelaccordingtomatthew'),
        'The Gospel according to Matthew',
      );
    });

    test('empty input passes through', () {
      expect(preserveBookName(''), '');
    });
  });

  group('segmentBookKey', () {
    test('greedy dictionary match splits concatenated words', () {
      expect(
        segmentBookKey('thegospelaccordingtojohn'),
        containsAllInOrder(['the', 'gospel', 'according', 'to', 'john']),
      );
    });

    test('unknown runs survive as single tokens', () {
      // "galations" matches no dictionary word; it must come out whole so
      // the typo-variant lookup in _canonicalBooks still works.
      expect(segmentBookKey('galations'), ['galations']);
    });

    test('punctuation is a hard word boundary', () {
      expect(segmentBookKey('1 corinthians'), contains('1'));
      expect(segmentBookKey('1 corinthians'), contains('corinthians'));
    });

    test('empty key segments to nothing', () {
      expect(segmentBookKey(''), isEmpty);
    });
  });

  group('formatBookName', () {
    test('dispatches on preserveOriginal', () {
      expect(
        formatBookName('thefirstbookofmosescalledgenesis'),
        'Genesis',
      );
      expect(
        formatBookName('thefirstbookofmosescalledgenesis',
            preserveOriginal: true),
        'The First Book of Moses called Genesis',
      );
    });
  });
}
