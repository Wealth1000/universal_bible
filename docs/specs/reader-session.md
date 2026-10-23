# ReaderSession — Deep Module for the Bible Reader

## Purpose

Consolidate the six responsibilities currently scattered across `_ReaderPageState` (1,364 lines) and `_ReaderContentState` (~600 lines) into a single deep module. The presentation layer becomes a thin shell that reads providers for display values and calls `ReaderSession` for every state change.

## Location

`lib/features/bible/domain/reader_session.dart`

## Seam

The seam is between `ReaderSession` and the presentation layer. `ReaderSession` accepts a `Ref` (Riverpod) in its constructor so it can read/write providers, and a `BibleDataModule` adapter so it never touches Drift directly.

```dart
class ReaderSession {
  ReaderSession({
    required this.ref,
    required this.bibleData,
  });

  final Ref ref;
  final BibleDataModule bibleData;
  // ...
}
```

## Interface

All methods operate on domain types (`ChapterRef`, `VerseRef`, `Color`). No Drift types, no Flutter types.

### Navigation

```dart
/// Navigate to (book, chapter). Updates currentBook/currentChapter providers
/// and persists via readingPositionProvider. Called when user picks book/chapter.
void navigateTo(ChapterRef ref);
```

### Scroll position

```dart
/// Called by _ReaderContentState after computing which chapter header is visible.
/// Updates visibleLocationProvider and triggers persistence (debounced inside
/// ReadingPositionNotifier — session just passes the value through).
void onScrollPositionUpdated(ChapterRef visibleChapter);
```

### Preloading (continuous reading)

```dart
/// Returns true if a next chapter should be preloaded. Driven by scroll offset
/// thresholds; the widget calls this each frame and decides whether to trigger.
bool shouldPreloadNext();

/// Returns true if a previous chapter should be preloaded.
bool shouldPreloadPrev();

/// Load and return the next chapter's data, or null at end of Bible.
Future<ChapterData?> preloadNext(int book, int chapter);

/// Load and return the previous chapter's data, or null at start of Bible.
Future<ChapterData?> preloadPrev(int book, int chapter);
```

### Verse selection

```dart
/// Toggle a verse in/out of selection. Returns the updated Set<VerseRef>.
Set<VerseRef> toggleVerse(VerseRef ref);

/// Clear all selected verses and close compare.
void clearSelection();

/// Get the current sorted selection (for passing to CompareColumn).
List<VerseRef> getSortedSelection();

/// Open the compare pane.
void openCompare();

/// Close the compare pane.
void closeCompare();
```

### Study actions

```dart
/// Apply or remove a highlight color on all selected verses. Toggle-off when
/// every selected verse already has exactly this color.
Future<void> applyHighlight(Color color);

/// Insert bookmarks for all selected verses.
Future<void> bookmarkSelection();

/// Insert notes for all selected verses. [content] is provided by the caller
/// (the dialog lives in the view).
Future<void> addNote(String content);
```

### State queries (for the view to read display values)

```dart
/// Returns the persisted reading position, or null.
ReadingPosition? get persistedPosition => ref.read(readingPositionProvider);

/// Returns whether continuous reading is enabled.
bool get isContinuousReading => ref.read(continuousReadingProvider);

/// Returns the current translation id.
String? get currentTranslationId => ref.read(currentTranslationProvider);

/// Returns the current book number.
int? get currentBook => ref.read(currentBookProvider);

/// Returns the current chapter number.
int? get currentChapter => ref.read(currentChapterProvider);

/// Returns the currently visible chapter (scroll-follow).
ChapterRef? get visibleLocation => ref.read(visibleLocationProvider);
```

## What moves into ReaderSession (from current code)

| Current location | Responsibility | New location |
|---|---|---|
| `_ReaderPageState._loadBooks()` | Book/translation loading, clamping, persisted-position restore | `ReaderSession._loadBooks()` (called from session constructor or `initialize()`) |
| `_ReaderPageState._ensureVersesFuture()` | Chapter verses caching | `ReaderSession.getChapterData()` |
| `_ReaderPageState._goTo()` | Navigation + persistence | `ReaderSession.navigateTo()` |
| `_ReaderPageState._loadChapterAfter/Before()` | Preload helpers | `ReaderSession.preloadNext/Prev()` |
| `_ReaderPageState._persistPosition()` | Position persistence | internal to `ReaderSession` |
| `_ReaderPageState._applyHighlight()` | Highlight toggle | `ReaderSession.applyHighlight()` |
| `_ReaderPageState._bookmarkSelection()` | Bookmark insertion | `ReaderSession.bookmarkSelection()` |
| `_ReaderPageState._noteSelection()` | Note insertion (incl. dialog) | `ReaderSession.addNote(content)` — dialog stays in view |
| `_ReaderPageState._clearSelection()` | Selection clear + compare close | `ReaderSession.clearSelection()` |
| `_ReaderContentState._toggleVerse()` | Verse toggle | `ReaderSession.toggleVerse()` |
| `_ReaderContentState._updateVisibleChapter()` | Scroll-follow computation | Widget computes, session persists (`onScrollPositionUpdated`) |
| `_ReaderContentState._maybeLoadNext/Prev()` | Preload triggers | `ReaderSession.preloadNext/Prev()` |
| `_ReaderContentState._reloadHighlights()` | Highlight refresh | `ReaderSession._reloadHighlights()` (internal) |
| `_ReaderContentState._maybeTrimChapters()` | Chapter cache eviction | `ReaderSession.trimCache()` |
| `_ReaderContentState._stepByVerse()` | Keyboard stepping | `ReaderSession.stepVerse(direction)` |
| `_ReaderContentState._handleReaderKey()` | Key event dispatch | `ReaderSession.handleKey(event)` → returns `KeyEventResult` |

## What stays in the widget

- `ScrollController`, `_verseKeys`, `_chapterHeaderKeys`, `_chapters` list — these are Flutter-rendering state, impossible to extract.
- `_ReaderContentState.build()` — the CustomScrollView structure.
- `_TopBar` widget — presentational, no logic to deepening.
- `_VerseTile`, `_ChapterHeader`, `_ChapterNavButtons` — presentational widgets.
- The scroll listener that calls `onScrollPositionUpdated()` and the preload-trigger checks — these stay in the widget because they depend on `ScrollController` and `RenderBox`. The widget *delegates* the computation to the session where possible.

## Provider interactions

`ReaderSession` reads and writes these providers:
- `currentTranslationProvider`
- `currentBookProvider`
- `currentChapterProvider`
- `visibleLocationProvider`
- `selectedVersesProvider`
- `compareOpenProvider`
- `highlightsVersionProvider`
- `readingPositionProvider`
- `continuousReadingProvider`
- `fontSizeProvider`
- `showVerseNumbersProvider`

The session *never* reads `preserveOriginalBookNamesProvider` directly — that stays in the page's `_loadBooks()` which the session calls. The page listens to it and re-calls `session.reloadBooks()`.

## Provider registration

```dart
// In lib/features/bible/domain/reader_session.dart (or a new reader_session_provider.dart)
final readerSessionProvider = Provider<ReaderSession>((ref) {
  final db = ref.watch(databaseProvider);
  final bibleData = BibleDataModule(db);
  return ReaderSession(ref: ref, bibleData: bibleData);
});
```

Or, to avoid recreating `BibleDataModule` on every `databaseProvider` change:

```dart
final bibleDataModuleProvider = Provider<BibleDataModule>((ref) {
  final db = ref.watch(databaseProvider);
  return BibleDataModule(db);
});

final readerSessionProvider = Provider<ReaderSession>((ref) {
  return ReaderSession(
    ref: ref,
    bibleData: ref.watch(bibleDataModuleProvider),
  );
});
```

## Tests

`test/features/bible/domain/reader_session_test.dart`

Use a fake `BibleDataModule` (a dart `class` implementing the interface with in-memory maps) and a `ProviderContainer` for Riverpod state. Test:
- `navigateTo(ChapterRef(1, 5))` updates `currentBookProvider`, `currentChapterProvider`, and persists
- `toggleVerse(ref)` adds then removes from `selectedVersesProvider`
- `applyHighlight(red)` on empty selection → no-op; on selected verse without highlight → inserts; on selected verse with red → removes (toggle)
- `clearSelection()` empties `selectedVersesProvider` and sets `compareOpenProvider` to false
- `preloadNext` at end of Bible returns null
- `preloadPrev` at start of Bible returns null
- Navigation clamping: navigating to non-existent book clamps to first valid book

## Files changed

| File | Action |
|---|---|
| `lib/features/bible/domain/reader_session.dart` | **Create** — deep module |
| `lib/features/bible/domain/reader_session_provider.dart` | **Create** — Riverpod provider registration |
| `lib/features/bible/presentation/pages/reader_page_desktop.dart` | **Refactor** — thin to ~300 lines, delegate to `ReaderSession` |
| `lib/features/bible/presentation/widgets/compare_column.dart` | Update: use `BibleDataModule` instead of direct DB |
| `lib/features/bible/presentation/pages/bookmarks_page_desktop.dart` | Update: use `BibleDataModule` |
| `lib/features/bible/presentation/pages/notes_page_desktop.dart` | Update: use `BibleDataModule` |
| `lib/features/search/presentation/pages/search_page_desktop.dart` | Update: use `BibleDataModule` |
| `test/features/bible/domain/reader_session_test.dart` | **Create** |

## Removal of dead code

Delete the `ReadingPositions` Drift table and all references to it (`lib/database/tables/reading_positions.dart`, `lib/database/app_database.dart` reading-position methods, `lib/database/app_database.g.dart` — regenerate). This table is never queried by any feature.
