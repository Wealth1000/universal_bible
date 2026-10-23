import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:universal_bible/core/utils/book_name_utils.dart';
import 'package:universal_bible/database/app_database.dart';
import 'package:universal_bible/features/bible/domain/reader_provider.dart' show VerseRef;

/// Result of [getBookInfo]: book metadata decoded from a translation's JSON
/// fields.
class BookInfoResult {
  final Map<String, int> bookMap; // raw key → book number
  final Map<int, Map<int, int>> chapterCounts; // book number → {chapter → verseCount}
  final Map<int, String> displayNames; // book number → formatted display name

  const BookInfoResult({
    required this.bookMap,
    required this.chapterCounts,
    required this.displayNames,
  });
}

/// All data for one chapter, returned in a single transaction by
/// [getChapterData]. Eliminates the N+1 highlight query pattern.
class ChapterData {
  final String translationId;
  final int bookNumber;
  final int chapter;
  final List<Verse> verses;
  /// verseRef → highlight (one highlight per verse; the reader stores at
  /// most one).
  final Map<VerseRef, Highlight> highlightsByVerse;

  const ChapterData({
    required this.translationId,
    required this.bookNumber,
    required this.chapter,
    required this.verses,
    required this.highlightsByVerse,
  });
}

/// Single adapter through which all bible-domain data flows.
/// Constructor takes [AppDatabase] — no singleton access.
class BibleDataModule {
  final AppDatabase db;

  BibleDataModule(this.db);

  // --- Read operations ---

  /// Returns book metadata for an installed translation.
  Future<BookInfoResult> getBookInfo(String translationId) async {
    final trans = await db.getTranslation(translationId);
    if (trans == null) {
      return const BookInfoResult(
        bookMap: {},
        chapterCounts: {},
        displayNames: {},
      );
    }

    final bookMapRaw = jsonDecode(trans.bookMapJson) as Map<String, dynamic>;
    final bookNames = <int, String>{};
    bookMapRaw.forEach((name, number) {
      bookNames[number] = _cleanBookName(name);
    });

    final countsRaw = jsonDecode(
      trans.bookChapterCountsJson ?? '{}',
    ) as Map<String, dynamic>;
    final chapterCounts = <int, Map<int, int>>{};
    countsRaw.forEach((bookKey, chapters) {
      final bookNum = int.parse(bookKey);
      final chaptersMap = (chapters as Map<String, dynamic>).map(
        (chKey, count) => MapEntry(int.parse(chKey), count as int),
      );
      chapterCounts[bookNum] = chaptersMap;
    });

    final displayNames = <int, String>{};
    bookMapRaw.forEach((rawKey, number) {
      displayNames[number] = cleanBookName(rawKey);
    });

    return BookInfoResult(
      bookMap: bookMapRaw.cast<String, int>(),
      chapterCounts: chapterCounts,
      displayNames: displayNames,
    );
  }

  /// Returns all verses + highlights for one chapter, in verse order.
  Future<ChapterData> getChapterData(
    String translationId,
    int bookNumber,
    int chapter,
  ) async {
    final verses = await db.getVersesForChapter(
      translationId,
      bookNumber,
      chapter,
    );
    final highlights = await db.getHighlightsForChapter(
      translationId,
      bookNumber,
      chapter,
    );
    final highlightsByVerse = <VerseRef, Highlight>{};
    for (final h in highlights) {
      highlightsByVerse[VerseRef(h.bookNumber, h.chapter, h.verse)] = h;
    }
    return ChapterData(
      translationId: translationId,
      bookNumber: bookNumber,
      chapter: chapter,
      verses: verses,
      highlightsByVerse: highlightsByVerse,
    );
  }

  /// Returns a single verse row, or null.
  Future<Verse?> getVerse(String translationId, int book, int chapter, int verse) {
    return db.getVerse(translationId, book, chapter, verse);
  }

  /// Returns all installed translations with their metadata.
  Future<List<Translation>> getInstalledTranslations() =>
      db.getInstalledTranslations();

  /// Returns a single translation by id, or null.
  Future<Translation?> getTranslation(String id) => db.getTranslation(id);

  /// Returns all bookmarks for a translation, ordered by createdAt desc.
  Future<List<Bookmark>> getBookmarks(String translationId) {
    return (db.select(db.bookmarks)
          ..where((b) => b.translationId.equals(translationId))
          ..orderBy([(b) => OrderingTerm.desc(b.createdAt)]))
        .get();
  }

  /// Returns all notes for a translation, ordered by updatedAt desc.
  Future<List<Note>> getNotes(String translationId) {
    return (db.select(db.notes)
          ..where((n) => n.translationId.equals(translationId))
          ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]))
        .get();
  }

  /// Returns search results for a translation (case-insensitive substring).
  Future<List<Verse>> searchVerses(
    String translationId,
    String query, {
    int limit = 200,
  }) {
    return db.searchVerses(translationId, query, limit: limit);
  }

  // --- Write operations ---

  /// Inserts or replaces highlights for a verse. Called by ReaderSession.applyHighlight.
  Future<void> saveHighlight({
    required String id,
    required String translationId,
    required int bookNumber,
    required int chapter,
    required int verse,
    required String color,
    required DateTime createdAt,
  }) async {
    await db.deleteHighlightsForVerse(translationId, bookNumber, chapter, verse);
    await db.insertHighlight(
      HighlightsCompanion.insert(
        id: id,
        translationId: translationId,
        bookNumber: bookNumber,
        chapter: chapter,
        verse: verse,
        color: color,
        createdAt: createdAt,
      ),
    );
  }

  /// Removes all highlights for a verse.
  Future<void> deleteHighlightsForVerse(
    String translationId,
    int book,
    int chapter,
    int verse,
  ) =>
      db.deleteHighlightsForVerse(translationId, book, chapter, verse);

  /// Inserts a bookmark for a verse.
  Future<void> insertBookmark({
    required String id,
    required String translationId,
    required int bookNumber,
    required int chapter,
    required int verse,
    required DateTime createdAt,
  }) async {
    await db.insertBookmark(
      BookmarksCompanion.insert(
        id: id,
        translationId: translationId,
        bookNumber: bookNumber,
        chapter: chapter,
        verse: verse,
        createdAt: createdAt,
      ),
    );
  }

  /// Inserts a note for a verse.
  Future<void> insertNote({
    required String id,
    required String translationId,
    required int bookNumber,
    required int chapter,
    required int verse,
    required String content,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) async {
    await db.insertNote(
      NotesCompanion.insert(
        id: id,
        translationId: translationId,
        bookNumber: bookNumber,
        chapter: chapter,
        verse: verse,
        content: content,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );
  }

  /// Deletes a bookmark by id.
  Future<void> deleteBookmark(String id) => db.deleteBookmark(id);

  /// Deletes a note by id.
  Future<void> deleteNote(String id) => db.deleteNote(id);

  /// Updates a note's content and timestamp.
  Future<void> updateNoteContent(String id, String content, DateTime updatedAt) =>
      db.updateNoteContent(id, content, updatedAt);

  // --- Internal helpers ---

  static String _cleanBookName(String raw) {
    // Mirrors the simple cleaning that the old code did in presentation
    // layers when bookDisplayNamesJson was absent.
    return raw
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r"[^\w\s\-&']"), '');
  }
}
