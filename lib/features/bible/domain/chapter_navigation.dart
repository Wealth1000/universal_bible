import 'package:universal_bible/features/bible/domain/book_info.dart';

/// A (book, chapter) location within a translation.
class ChapterRef {
  final int book;
  final int chapter;

  const ChapterRef(this.book, this.chapter);
}

List<int> _sortedChapters(BookInfo book) =>
    book.chapterCounts.keys.toList()..sort();

int _bookIndex(List<BookInfo> books, int bookNumber) =>
    books.indexWhere((b) => b.number == bookNumber);

/// The chapter after (book, chapter), rolling into the first chapter of the
/// next book when the current book ends (Genesis 50 -> Exodus 1).
/// Returns null past the last chapter of the last book.
ChapterRef? nextChapterRef(List<BookInfo> books, int book, int chapter) {
  final bi = _bookIndex(books, book);
  if (bi == -1) return null;

  final chapters = _sortedChapters(books[bi]);
  final ci = chapters.indexOf(chapter);
  if (ci != -1 && ci < chapters.length - 1) {
    return ChapterRef(book, chapters[ci + 1]);
  }

  for (var i = bi + 1; i < books.length; i++) {
    final next = _sortedChapters(books[i]);
    if (next.isNotEmpty) return ChapterRef(books[i].number, next.first);
  }
  return null;
}

/// The chapter before (book, chapter), rolling into the last chapter of the
/// previous book (Exodus 1 -> Genesis 50). Returns null before the first
/// chapter of the first book.
ChapterRef? prevChapterRef(List<BookInfo> books, int book, int chapter) {
  final bi = _bookIndex(books, book);
  if (bi == -1) return null;

  final chapters = _sortedChapters(books[bi]);
  final ci = chapters.indexOf(chapter);
  if (ci > 0) {
    return ChapterRef(book, chapters[ci - 1]);
  }

  for (var i = bi - 1; i >= 0; i--) {
    final prev = _sortedChapters(books[i]);
    if (prev.isNotEmpty) return ChapterRef(books[i].number, prev.last);
  }
  return null;
}

/// Display name for the book of [ref], or '' if unknown.
String bookNameFor(List<BookInfo> books, ChapterRef ref) {
  final bi = _bookIndex(books, ref.book);
  return bi == -1 ? '' : books[bi].name;
}
