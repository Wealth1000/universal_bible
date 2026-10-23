# BibleDataModule — Deepened Bible Data-Access Adapter

## Purpose

Replace the half-formed `TranslationRepository` and eliminate direct `AppDatabase` / Drift-companion access across 5+ presentation files. `BibleDataModule` is the single adapter through which all bible-domain data flows. Its interface returns domain types only — no Drift companions, no generated types leak outward.

## Location

`lib/features/bible/data/bible_data_module.dart`

## Interface

All methods return plain Dart types or existing domain models (`Verse`, `Translation`, `Highlight`, `Bookmark`, `Note` from the Drift tables). No `*Companion` types are exposed.

### Read operations

```dart
/// Returns book metadata for an installed translation.
/// bookMap: raw key → book number (int)
/// chapterCounts: book number → {chapter → verseCount}
/// displayNames: raw key → formatted display name (from bookDisplayNamesJson)
Future<BookInfoResult> getBookInfo(String translationId) async;

/// Returns all verses + highlights for one chapter, in verse order.
class ChapterData {
  final String translationId;
  final int bookNumber;
  final int chapter;
  final List<Verse> verses;
  final Map<VerseRef, Highlight> highlightsByVerse; // verseRef → highlight
}
Future<ChapterData> getChapterData(
  String translationId, int bookNumber, int chapter,
) async;

/// Returns a single verse row, or null.
Future<Verse?> getVerse(String translationId, int book, int chapter, int verse);

/// Returns all installed translations with their metadata.
Future<List<Translation>> getInstalledTranslations();

/// Returns a single translation by id, or null.
Future<Translation?> getTranslation(String id);

/// Returns all bookmarks for a translation, ordered by createdAt desc.
Future<List<Bookmark>> getBookmarks(String translationId);

/// Returns all notes for a translation, ordered by updatedAt desc.
Future<List<Note>> getNotes(String translationId);

/// Returns search results for a translation (case-insensitive substring).
Future<List<Verse>> searchVerses(
  String translationId, String query, {int limit = 200},
);
```

### Write operations

```dart
/// Inserts or replaces highlights for a verse. Called by ReaderSession.applyHighlight.
Future<void> saveHighlight({
  required String id,
  required String translationId,
  required int bookNumber,
  required int chapter,
  required int verse,
  required String color,
  required DateTime createdAt,
});

/// Removes all highlights for a verse.
Future<void> deleteHighlightsForVerse(
  String translationId, int book, int chapter, int verse,
);

/// Inserts a bookmark for a verse.
Future<void> insertBookmark({
  required String id,
  required String translationId,
  required int bookNumber,
  required int chapter,
  required int verse,
  required DateTime createdAt,
});

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
});

/// Deletes a bookmark by id.
Future<void> deleteBookmark(String id);

/// Deletes a note by id.
Future<void> deleteNote(String id);

/// Import a .bdat file (parses on isolate, writes transactionally).
Future<void> importFromFile(String filePath);

/// Delete a translation and all its study data + copied file.
Future<void> deleteTranslation(String id);
```

## Implementation notes

- Constructor takes `AppDatabase db` — no singleton access.
- `getChapterData` runs a single transaction: fetch verses, then fetch highlights, then merge into `ChapterData`. This eliminates the N+1 highlight query pattern currently in `_ReaderContentState._reloadHighlights`.
- `getBookInfo` decodes `bookMapJson`, `bookChapterCountsJson`, and `bookDisplayNamesJson` from the translation row and returns `BookInfo` objects — callers never touch the JSON raw.
- All Drift companion construction is internal to the module. Callers pass plain values.
- `ReadingPositions` table: remove all references. It is dead code.
- Keep `importFromFile` and `deleteTranslation` here — they were in `TranslationRepository` and belong in the consolidated adapter.

## Tests

`test/features/bible/data/bible_data_module_test.dart`

Use an in-memory Drift executor (`NativeDatabase(ByteData(0))` or the drift `MemoryDatabaseConnection`) for unit tests. Test:
- `getChapterData` returns verses in verse order with highlights merged
- `saveHighlight` + `getChapterData` round-trips correctly
- `deleteHighlightsForVerse` removes highlights
- `getBookInfo` decodes JSON correctly including missing fields
- `searchVerses` returns results ordered by (book, chapter, verse)

## Files changed

| File | Action |
|---|---|
| `lib/features/bible/data/bible_data_module.dart` | **Create** — new deep module |
| `lib/features/bible/data/repositories/translation_repository.dart` | **Deprecate** — keep for translation import/delete callers, or inline its remaining methods into BibleDataModule and delete. Prefer inlining and deleting. |
| `lib/features/bible/presentation/widgets/compare_column.dart` | Update: replace `ref.read(databaseProvider)` + direct `db.getVerse()` calls with `bibleDataModule.getChapterData()` / `getVerse()` |
| `lib/features/bible/presentation/pages/bookmarks_page_desktop.dart` | Update: replace direct DB calls with `bibleDataModule.getBookmarks()` |
| `lib/features/bible/presentation/pages/notes_page_desktop.dart` | Update: replace direct DB calls with `bibleDataModule.getNotes()` |
| `lib/features/search/presentation/pages/search_page_desktop.dart` | Update: replace direct DB calls with `bibleDataModule.searchVerses()` |
| `test/features/bible/data/bible_data_module_test.dart` | **Create** |
