# Spec: Deepen the Reader Module — ReaderSession

## Problem Statement

The reader page (`reader_page_desktop.dart`, 1,364 lines) is a god module. A single `_ReaderPageState` class owns six distinct responsibilities — book/translation loading, scroll-follow location tracking, continuous reading with chapter preloading and trimming, keyboard verse stepping, verse selection with highlights/bookmarks/notes, and compare-pane coordination. The interface (≈20 provider reads, 8 callback fields on `_ReaderContent`, 6 private methods plus internal state) is nearly as complex as the implementation. Scroll-tracking logic bounces between `_ReaderPageState` and `_ReaderContentState` via callbacks. Drift companion types leak into the page's highlight, bookmark, and note methods. The whole thing is untestable without a full Flutter widget tree.

## Solution

Introduce a **ReaderSession** deep module at the seam between the presentation page and the domain. The presentation page becomes a thin orchestrator: it reads providers for display values and calls `ReaderSession` methods for every state change. All six responsibilities above are consolidated into `ReaderSession`'s implementation. The interface is a small, stable set of operations the view can call — roughly eight methods. Drift companion construction stays inside the session's adapter layer; the view never sees them.

## User Stories

1. As a reader, I want the app to reopen at my last reading position, so that I can resume where I left off without searching.
2. As a reader, I want to switch translations from the top-bar pill, so that I can compare how different translations render the same passage.
3. As a reader, I want to pick a book from the top-bar picker, so that I can jump to any book in the Bible.
4. As a reader, I want to pick a chapter number from the top-bar picker, so that I can jump to any chapter within the current book.
5. As a reader, I want the top-bar to show the book and chapter I'm currently viewing (not just the last one I navigated to), so that the header tracks my actual position during continuous reading.
6. As a reader, I want to toggle continuous reading mode, so that chapters load automatically as I scroll instead of manually paging through them.
7. As a reader in continuous mode, I want chapters to preload when I approach the end of the loaded content, so that scrolling feels seamless without manual intervention.
8. As a reader in continuous mode, I want chapters to also preload when I scroll toward the beginning, so that going backward is as smooth as going forward.
9. As a reader in continuous mode, I want the reader to cross book boundaries automatically (e.g., Genesis 50 → Exodus 1), so that I can read through an entire book without interruption.
10. As a reader in continuous mode, I want old chapters to be trimmed from memory once they're far enough away, so that long reading sessions don't consume unbounded memory.
11. As a reader, I want to tap a verse to select or deselect it, so that I can mark verses for study actions.
12. As a reader, I want selected verses to be displayed with a visual highlight wash, so that I can see at a glance which verses are selected.
13. As a reader, I want to apply a highlight color to my selected verses, so that I can mark important passages for later reference.
14. As a reader, I want to toggle a highlight off by re-tapping the same color, so that I can remove highlights without deselecting first.
15. As a reader, I want to add a bookmark to my selected verses, so that I can return to them later.
16. As a reader, I want to add a note to my selected verses, so that I can record my thoughts alongside the text.
17. As a reader, I want to copy selected verse text to the clipboard, so that I can paste it into other apps.
18. As a reader, I want to open the compare pane for my selected verses, so that I can see how multiple translations render the same passage side by side.
19. As a reader, I want to navigate between chapters using the prev/next buttons at the bottom of the screen, so that I can move through the text without scrolling.
20. As a reader, I want to use the Up and Down arrow keys to step through verses one at a time, so that I can navigate precisely without touching the mouse.
21. As a reader, I want the arrow keys to stop at chapter boundaries instead of scrolling past them, so that navigation feels natural and predictable.
22. As a reader, I want the auto-preload to respect a cooldown timer between checks, so that rapid scroll events don't trigger duplicate loads.
23. As a reader switching translations, I want my current book and chapter to be preserved if they exist in the new translation, so that I don't lose my place unexpectedly.
24. As a reader switching to a translation that lacks my current book or chapter, I want the reader to clamp to a valid position instead of showing empty content, so that I always see real scripture.
25. As a reader, I want the reader to show a loading spinner while the initial chapter fetches, so that I know something is happening.
26. As a reader, I want to be redirected to the translation import page if no translations are installed, so that I'm guided to set up the app.
27. As a reader, I want verse numbers to be optionally shown or hidden based on my settings, so that I can choose my preferred reading layout.
28. As a reader, I want the verse font size to be adjustable via settings and applied immediately, so that I can customize readability.
29. As a reader in continuous mode, I want highlights to re-fetch automatically after I add or remove one, so that the visual state stays in sync with the database.
30. As a devotional reader (Rhapsody), I want to click a scripture reference and have it resolve to the actual verse text in my current translation, so that I can read the passage in context.

## Implementation Decisions

### The seam

The seam sits between the presentation layer (`ReaderPageDesktop`, `_ReaderContent`) and the domain/data layer. The existing domain notifiers (`CurrentTranslationNotifier`, `CurrentBookNotifier`, `CurrentChapterNotifier`, `VisibleLocationNotifier`, `SelectedVersesNotifier`, `CompareOpenNotifier`, `HighlightsVersionNotifier`, `ReadingPositionNotifier`, `ContinuousReadingNotifier`, `FontSizeNotifier`, `ShowVerseNumbersNotifier`) stay in place as the state machine. `ReaderSession` owns the logic that transitions between states; the presentation layer only reads from providers and calls `ReaderSession` methods.

### The ReaderSession module

A new deep module in `lib/features/bible/domain/` (or a new `lib/features/bible/application/` package — the package structure is flexible; the module itself is what matters). Its interface:

- `navigateTo(ChapterRef ref)` — sets book, chapter, persists position
- `toggleVerse(VerseRef ref)` — toggles selection, returns updated selection
- `clearSelection()` — clears selection and closes compare
- `applyHighlight(Color color)` — writes or removes highlights for selected verses
- `bookmarkSelection()` — inserts bookmarks for selected verses
- `addNote(String content)` — inserts notes for selected verses (takes content as parameter; the dialog lives in the view)
- `loadScrollState()` / `onScrollUpdate(ChapterRef visibleLoc)` — manages scroll-follow position and persistence
- `preloadNextChapter()` / `preloadPrevChapter()` — triggers preloading (called by the scroll listener inside the session, or the view passes scroll deltas into the session)

The exact method signatures are a design decision; the principle is: the interface is small, stable, and expressed in domain terms (`ChapterRef`, `VerseRef`, `Color`), not Drift types.

### BibleDataModule adapter

The existing `TranslationRepository` is shallow and incomplete. It is deepened into `BibleDataModule`, a proper adapter with interface:

- `getInstalledTranslations()` → `List<Translation>`
- `getTranslation(id)` → `Translation?`
- `getVersesForChapter(translationId, book, chapter)` → `List<Verse>`
- `getVerse(translationId, book, chapter, verse)` → `Verse?`
- `getHighlightsForChapter(translationId, book, chapter)` → `List<Highlight>`
- `getHighlightsForVerse(translationId, book, chapter, verse)` → `List<Highlight>`
- `insertHighlight(verse, color)` → `void`
- `deleteHighlightsForVerse(translationId, book, chapter, verse)` → `void`
- `insertBookmark(verse)` → `void`
- `insertNote(verse, content)` → `void`
- `getBookmarksForTranslation(translationId)` → `List<Bookmark>`
- `getNotesForTranslation(translationId)` → `List<Note>`

The implementation wraps `AppDatabase`. Drift companion construction is internal to the adapter. In tests, an in-memory adapter (satisfying the same interface) replaces it. The `ReadingPositions` Drift table is removed — it is dead code, never queried by any feature.

### Scroll tracking

Scroll-follow logic (`_updateVisibleChapter` with its RenderBox gymnastics) moves into `ReaderSession` as a method that the scroll controller calls. The `_ReaderContentState` keeps the `ScrollController` and the center-anchored `CustomScrollView` structure (that's inherently Flutter rendering logic), but delegates the "which chapter is visible?" calculation and the "what to preload next" decision to `ReaderSession`. This gives `ReaderSession` a clean input (scroll offset or visible chapter) and a clean output (updated `visibleLocationProvider` state).

### Presentation layer thinning

`ReaderPageDesktop._ReaderPageState` becomes a thin coordinator:
- Calls `ReaderSession.navigateTo()` on book/chapter pick
- Calls `ReaderSession.toggleVerse()` on verse tap
- Calls `ReaderSession.applyHighlight()`, `bookmarkSelection()`, `addNote()` from the FAB callbacks
- Calls `ReaderSession.clearSelection()` on close
- Reads providers for display values (current book, chapter, translation, visible location)
- Passes minimal callbacks to `_ReaderContent` (the scroll content widget)

`_ReaderContentState` keeps the scroll controller, verse key map, highlight map, and chapter list — these are inherently tied to the Flutter rendering pipeline — but its logic for *when* to load, trim, and persist is driven by `ReaderSession` rather than being self-contained.

### Provider responsibilities (unchanged)

All existing domain notifiers keep their current shape. `ReaderSession` writes to them; nothing else in the presentation layer writes to them directly. This concentrates the "who updates the state" logic in one place.

### Cross-feature imports

The cross-feature imports (`rhapsody_screen.dart` → `reader_provider.dart`, `scripture_resolver.dart` → `reader_provider.dart`) are eliminated because `ReaderSession` becomes the canonical accessor. Rhapsody reads from `ReaderSession` (or its own copy of the needed providers) rather than importing the bible domain directly. This is a secondary benefit that falls out of the deeper module.

### Book name formatting

`formatBookName()` stays as a pure utility in `core/utils/`. `ReaderSession` receives the already-formatted `BookInfo` list from `_loadBooks()` and uses it internally; it never calls `formatBookName` itself. The "preserve original names" provider is read by `ReaderSession` when rebuilding the book list, not scattered across multiple pages.

## Testing Decisions

### What makes a good test

Tests verify external behavior — state transitions observable through the module's interface — not internal implementation details. A test should be able to swap the `BibleDataModule` adapter for a fake and confirm the correct provider state changes, without needing Flutter bindings, a database, or a widget tree.

### Modules to test

1. **ReaderSession** — unit tests against a fake `BibleDataModule`. Verify:
   - `navigateTo(ChapterRef(1, 5))` updates `currentBookProvider` to 1, `currentChapterProvider` to 5, and persists via `readingPositionProvider`
   - `toggleVerse(VerseRef(1, 5, 3))` adds/removes from `selectedVersesProvider` correctly
   - `applyHighlight(Color.red)` on a verse with no existing highlight inserts one; on a verse already highlighted red removes it (toggle behavior)
   - `applyHighlight(Color.green)` on a verse highlighted red replaces the highlight
   - `clearSelection()` empties `selectedVersesProvider` and sets `compareOpenProvider` to false
   - Navigation clamping: navigating to a non-existent book/clamped chapter works correctly
   - Translation switch preserves book/chapter when valid, clamps when invalid

2. **BibleDataModule** — unit tests against both the real `AppDatabase` (using an in-memory Drift executor for integration tests) and an in-memory fake adapter. Verify:
   - `getVersesForChapter` returns verses in verse-number order
   - `getHighlightsForChapter` returns correct highlights keyed by verse
   - `insertHighlight` followed by `getHighlightsForChapter` returns the inserted highlight
   - `deleteHighlightsForVerse` removes the highlight

3. **Existing pure-function tests continue to pass** — `book_name_utils_test.dart`, `scripture_format_test.dart`, `chapter_navigation_test.dart`, `devotional_body_parser_test.dart`, `scripture_resolver_test.dart` are unaffected and remain as regression guards.

### Prior art in the codebase

The existing tests in `test/core/utils/` and `test/features/*/` follow the same pattern: isolate pure functions, mock what they depend on, assert on return values. `ReaderSession` tests extend this pattern to stateful modules by injecting the adapter and observing provider state changes through a test-specific Riverpod container.

### Widget tests (future, out of scope for this spec)

Once `ReaderSession` is testable, widget tests for `ReaderPageDesktop` become feasible: the page can be tested with a fake `ReaderSession` adapter, removing the need for full Flutter binding setup for most scenarios.

## Out of Scope

- Moving `reader_provider.dart` into `core/` (Candidate 5 from the architecture review) — this is a separate deepening opportunity that can be done incrementally after `ReaderSession` is in place.
- Abstracting `StorageService` / `SharedPreferences` into a `PersistenceAdapter` (Candidate 3) — notables are not part of the reader module's scope.
- Removing the dead `ReadingPositions` Drift table — this happens as part of the `BibleDataModule` cleanup but is not a user-facing change.
- Testing `ReaderPageDesktop` as a Flutter widget — deferred to a future spec.
- Restructuring the cross-feature import from `rhapsody_screen.dart` → `reader_provider.dart` beyond what falls out naturally from the `ReaderSession` extraction.
- Adding new features (e.g., text search within the reader, parallel chapter comparison) — purely architectural deepening.

## Further Notes

### Why ReaderSession and not just extracting methods from the page?

Extracting methods from `_ReaderPageState` would improve code organization but would not create a deep module — the interface would still be as complex as the implementation because callers (the page, the content widget, the action panel) would each need to know about the same scattered concerns. A deep module has a small interface that hides complexity; extracting methods without a seam does not achieve that.

### The deletion test

If `ReaderSession` were deleted, the six responsibilities it consolidates would reappear spread across `ReaderPageDesktop`, `_ReaderContentState`, and various provider classes. The complexity would not vanish — it would scatter. This confirms the module earns its keep.

### What stays shallow

`TranslationRepository` (the current class) is replaced by `BibleDataModule`. Its current form is a pass-through over `AppDatabase` — deleting it would just move the DB calls back to the pages. `BibleDataModule` is the deep version: same responsibility, small interface, hidden Drift details.

### The two-adapters rule

The `BibleDataModule` seam has two adapters: the real one wrapping `AppDatabase` (prod), and an in-memory fake (tests). This justifies the seam per the "one adapter = hypothetical, two = real" rule.

### Relationship to Candidate 2

This spec subsumes Candidate 2 (deepen the Bible data-access module). The `BibleDataModule` adapter created here is the deepened form of `TranslationRepository`. The two candidates are combined because the data-access module is the natural home for the reader's database calls, and consolidating them there serves both the reader and all other screens that bypass the repository.
