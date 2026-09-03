import 'package:flutter_test/flutter_test.dart';
import 'package:universal_bible/features/bible/domain/book_info.dart';
import 'package:universal_bible/features/bible/domain/chapter_navigation.dart';

BookInfo _book(int number, String name, int chapters) => BookInfo(
      number: number,
      name: name,
      chapterCounts: {
        for (var c = 1; c <= chapters; c++) c: 3, // verse count irrelevant
      },
    );

void main() {
  // Genesis (50) → Exodus (40), keys deliberately inserted unsorted to prove
  // chapter ordering is not assumed.
  final books = [
    BookInfo(
      number: 1,
      name: 'Genesis',
      chapterCounts: {
        for (var c = 50; c >= 1; c--) c: 3,
      },
    ),
    _book(2, 'Exodus', 40),
  ];

  group('nextChapterRef', () {
    test('advances within a book', () {
      final next = nextChapterRef(books, 1, 3);
      expect(next, isNotNull);
      expect(next!.book, 1);
      expect(next.chapter, 4);
    });

    test('rolls over into the next book', () {
      final next = nextChapterRef(books, 1, 50);
      expect(next, isNotNull);
      expect(next!.book, 2);
      expect(next.chapter, 1);
    });

    test('returns null past the last chapter of the last book', () {
      expect(nextChapterRef(books, 2, 40), isNull);
    });

    test('returns null for an unknown book', () {
      expect(nextChapterRef(books, 99, 1), isNull);
    });

    test('skips books with no chapters', () {
      final withEmpty = [...books, BookInfo(number: 3, name: 'Lev', chapterCounts: const {}), _book(4, 'Leviticus', 27)];
      final next = nextChapterRef(withEmpty, 2, 40);
      expect(next, isNotNull);
      expect(next!.book, 4);
      expect(next.chapter, 1);
    });
  });

  group('prevChapterRef', () {
    test('retreats within a book', () {
      final prev = prevChapterRef(books, 2, 5);
      expect(prev, isNotNull);
      expect(prev!.book, 2);
      expect(prev.chapter, 4);
    });

    test('rolls back into the previous book', () {
      final prev = prevChapterRef(books, 2, 1);
      expect(prev, isNotNull);
      expect(prev!.book, 1);
      expect(prev.chapter, 50);
    });

    test('returns null before the first chapter of the first book', () {
      expect(prevChapterRef(books, 1, 1), isNull);
    });

    test('returns null for an unknown book', () {
      expect(prevChapterRef(books, 99, 1), isNull);
    });
  });

  group('bookNameFor', () {
    test('finds the display name', () {
      expect(bookNameFor(books, const ChapterRef(2, 1)), 'Exodus');
    });

    test("returns '' for an unknown book", () {
      expect(bookNameFor(books, const ChapterRef(99, 1)), '');
    });
  });
}
