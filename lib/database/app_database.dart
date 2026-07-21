import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:universal_bible/core/services/storage_service.dart';
import 'dart:io';
import 'tables/translations.dart';
import 'tables/verses.dart';
import 'tables/notes.dart';
import 'tables/highlights.dart';
import 'tables/bookmarks.dart';
import 'tables/reading_positions.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Translations,
    Verses,
    Notes,
    Highlights,
    Bookmarks,
    ReadingPositions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    // Use LazyDatabase to handle async initialization
    return LazyDatabase(() async {
      final path = StorageService().databasePath;
      return NativeDatabase(File(path));
    });
  }

  // --- DAO methods ---

  // Translation
  Future<void> upsertTranslation(TranslationsCompanion companion) =>
      into(translations).insertOnConflictUpdate(companion);

  Future<Translation?> getTranslation(String id) =>
      (select(translations)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Translation>> getInstalledTranslations() =>
      (select(translations)..where((t) => t.installed.equals(true))).get();

  // Verses
  Future<void> insertVerse(VersesCompanion companion) =>
      into(verses).insert(companion);

  Future<void> insertVerses(List<VersesCompanion> companions) =>
      batch((batch) => batch.insertAll(verses, companions));

  Future<List<Verse>> getVersesForChapter(String translationId, int bookNumber, int chapter) =>
      (select(verses)
        ..where((v) =>
            v.translationId.equals(translationId) &
            v.bookNumber.equals(bookNumber) &
            v.chapter.equals(chapter))
        ..orderBy([(v) => OrderingTerm.asc(v.verse)]))
      .get();

  Future<Map<int, String>> getVerseMap(String translationId) async {
    final rows = await (select(verses)
          ..where((v) => v.translationId.equals(translationId)))
        .get();
    return {for (var row in rows) _verseId(row.bookNumber, row.chapter, row.verse): row.verseText};
  }

  int _verseId(int book, int chapter, int verse) =>
      book * 1_000_000 + chapter * 1_000 + verse;

  // Notes
  Future<void> insertNote(NotesCompanion companion) =>
      into(notes).insert(companion);

  Future<List<Note>> getNotesForVerse(String translationId, int book, int chapter, int verse) =>
      (select(notes)
        ..where((n) =>
            n.translationId.equals(translationId) &
            n.bookNumber.equals(book) &
            n.chapter.equals(chapter) &
            n.verse.equals(verse)))
      .get();
  
  // --- Highlights ---
Future<void> insertHighlight(HighlightsCompanion companion) =>
    into(highlights).insert(companion);

Future<void> deleteHighlight(String id) =>
    (delete(highlights)..where((h) => h.id.equals(id))).go();

Future<List<Highlight>> getHighlightsForVerse(String translationId, int book, int chapter, int verse) =>
    (select(highlights)
      ..where((h) =>
          h.translationId.equals(translationId) &
          h.bookNumber.equals(book) &
          h.chapter.equals(chapter) &
          h.verse.equals(verse)))
    .get();

Future<List<Highlight>> getHighlightsForChapter(String translationId, int book, int chapter) =>
    (select(highlights)
      ..where((h) =>
          h.translationId.equals(translationId) &
          h.bookNumber.equals(book) &
          h.chapter.equals(chapter)))
    .get();

Future<void> deleteHighlightsForVerse(String translationId, int book, int chapter, int verse) =>
    (delete(highlights)
      ..where((h) =>
          h.translationId.equals(translationId) &
          h.bookNumber.equals(book) &
          h.chapter.equals(chapter) &
          h.verse.equals(verse)))
    .go();

// --- Bookmarks ---
Future<void> insertBookmark(BookmarksCompanion companion) =>
    into(bookmarks).insert(companion);

Future<void> deleteBookmark(String id) =>
    (delete(bookmarks)..where((b) => b.id.equals(id))).go();

Future<List<Bookmark>> getBookmarksForTranslation(String translationId) =>
    (select(bookmarks)..where((b) => b.translationId.equals(translationId))).get();

// --- Reading Position ---
Future<void> upsertReadingPosition(ReadingPositionsCompanion companion) =>
    into(readingPositions).insertOnConflictUpdate(companion);

Future<ReadingPosition?> getReadingPosition(String translationId) =>
    (select(readingPositions)..where((r) => r.translationId.equals(translationId))).getSingleOrNull();
}