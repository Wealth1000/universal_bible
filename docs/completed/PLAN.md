# Plan: Reading-Position Persistence + §2 Translation Pill (Grid Dropdown)

**Goal (two features, strictly in this order):**

1. **Reading-position persistence** — a cross-session persistence key that
   stores the last translation + book + chapter the reader was centered on.
   Closing the app at Genesis 20 [NLT] and reopening lands the reader back
   at Genesis 20 [NLT].
2. **§2 Translation Pill** — pill in the reader header showing the active
   translation abbreviation; tapping opens an adaptive **grid** dropdown of
   installed translations. Switching translations changes the translation
   **only** — the reader stays at the same book/chapter (1 Kings 5 [NKJV]
   → switch to NLT → 1 Kings 5 [NLT]). It must NOT reset the persistence
   key's book/chapter.

See docs/CONTEXT.md for discovery notes.

---

## Architecture decisions

- **Where the key lives:** `StorageService` (SharedPreferences), per user
  instruction. Keys:
  - `reading_position.translation` (String)
  - `reading_position.book` (int)
  - `reading_position.chapter` (int)
- **Provider:** a `ReadingPosition` value class + `readingPositionProvider`
  in `lib/core/providers/database_provider.dart` (per user instruction),
  wrapping StorageService load/save. Save is fire-and-forget and
  **debounced** (the scroll listener fires per frame).
- **Restore point:** `_loadBooks()` in both reader pages currently defaults
  to `translations.first` / first book / first chapter when the reader
  providers are null (fresh app start). That null-fallback is exactly where
  the persisted position slots in: persisted value (validated) → else
  current defaults. Restoring only fills *null* providers, so in-session
  navigation is never overridden.
- **Save points:** every navigation write to `currentBookProvider` /
  `currentChapterProvider` (`_goTo`, chapter dropdown/pickers), plus the
  existing scroll listener `_updateVisibleChapter` which already resolves
  the visually-centered chapter (this is what "last chapter centered when
  the reader was last used" means — in continuous mode the centered
  chapter, not the navigation intent, is what gets persisted).
- **Translation switch must NOT reset position:** the grid's tap handler
  sets `currentTranslationProvider` and updates ONLY the translation
  component of the persisted key (`saveTranslationOnly`). It never touches
  book/chapter providers or persisted book/chapter. Existing danger spot
  (mobile): `_updateChapterCounts()` clamps the chapter when the new book
  map genuinely lacks it — that clamp stays (correctness), and if it fires
  it re-saves the clamped position.
- Both readers key their content widget on
  `'$translationId|$book|$chapter|$continuousReading'`, so switching the
  translation reloads verses at the same book/chapter automatically — no
  new reload logic needed.

---

## Batches

### Batch 1 — Persistence layer (no behaviour change yet)

**Files:** `lib/core/services/storage_service.dart`,
`lib/core/providers/database_provider.dart`

1. `storage_service.dart`:
   - Key constants (`reading_position.*` above).
   - `Future<void> saveReadingPosition({required String translationId, required int book, required int chapter})`.
   - `Future<void> saveReadingTranslation(String translationId)` — updates
     the translation component ONLY (used by the pill switch).
   - `ReadingPositionRecord? get lastReadingPosition` — sync read (prefs
     are loaded by `StorageService.init()` in main.dart before runApp);
     returns null when never saved (first run).
2. `database_provider.dart`:
   - `ReadingPosition` value class (translationId, book, chapter).
   - `readingPositionProvider` —
     `NotifierProvider<ReadingPositionNotifier, ReadingPosition?>`:
     - `build()` → `StorageService().lastReadingPosition`.
     - `save(ReadingPosition)` — updates state immediately, persists via
       StorageService after a 400 ms debounce (Timer).
     - `saveTranslationOnly(String id)` — updates translation component,
       preserves book/chapter.

### Batch 2 — Restore on startup (both reader pages)

**Files:** `reader_page_desktop.dart`, `reader_page_mobile.dart`

In `_loadBooks()` in both pages:

1. Translation pick becomes: `currentTransId ?? persisted.translationId
   (if still installed) ?? translations.first.id`.
2. Book/chapter null-fallback block: try `persisted.book` /
   `persisted.chapter` **validated against the loaded book map** (book
   exists in `books`; chapter in its `chapterCounts`) before falling back
   to first book / first chapter. Invalid persisted refs (translation
   lacks that book/chapter) fall through to existing defaults — no crash.

### Batch 3 — Save on navigation & scroll (both reader pages)

**Files:** `reader_page_desktop.dart`, `reader_page_mobile.dart`

1. Navigation writes: `_goTo` and the chapter dropdown/picker handlers
   call `readingPositionProvider.notifier.save(...)` after setting the
   reader providers.
2. Scroll: `_updateVisibleChapter` (in `_ReaderContentState` desktop and
   `_ReaderScrollState` mobile) already identifies the centered chapter's
   index `i` — it also knows `_chapters[i].book`. Extend it to save
   `(book, chapter)` of that centered header through the debounced
   notifier (covers continuous-mode reading incl. cross-book drift, which
   never goes through `_goTo`).
3. Mobile `_updateChapterCounts` clamp: when it clamps, save the clamped
   position too.

### Batch 4 — §2 Translation Pill + grid dropdown

**Files:** NEW
`lib/features/bible/presentation/widgets/translation_grid.dart`,
`reader_page_desktop.dart`, `reader_page_mobile.dart`

1. New shared widget file:
   - `TranslationGrid` — a `Wrap` of content-sized cells (spec says box /
     adaptive, NOT fixed columns): abbreviation (id) large + bold, full
     name small secondary. Active translation highlighted
     (primaryContainer background + primary border). Each cell an
     `InkWell` with `Semantics(button: true, label: ...)`.
   - Data: `translationRepoProvider.getInstalled()` (FutureBuilder inside
     the widget so both surfaces share it).
   - ≤1 installed translation → the single cell plus an "Install more
     translations" prompt that navigates `/translations`.
   - `onSelected(String id)` callback → caller sets
     `currentTranslationProvider` + `saveTranslationOnly(id)` + closes.
     **No writes to book/chapter providers.**
   - Desktop presentation: anchored overlay below-right of the header
     (aligned so the grid's top-right meets the pill's bottom-left edge,
     per spec "anchored below-left of the pill"), dismissed on
     tap-outside — implemented with `showDialog` + `CustomSingleChildLayout`
     positioned from the pill's RenderBox, or a `MenuAnchor`; pick
     whichever needs no new dependency.
   - Mobile presentation: `showModalBottomSheet` wrapping the same grid
     (per §3 note pattern: mobile pickers are bottom sheets).
2. Desktop `_TopBar`: the existing translation `TextButton` becomes the
   pill (StadiumBorder, keeps primaryContainer colors); the
   `onTranslationTap` TODO in `_ReaderPageState` opens the anchored grid.
   Pill gets semantic label "Active translation: <name>. Tap to switch."
3. Mobile: `_showTranslationPicker()` TODO → bottom-sheet grid. The AppBar
   translation label already serves as the tappable pill; add the same
   semantic label.

### Batch 5 — Documentation close-out

1. `docs/PLANNED_FEATURES.md`: mark §2 "✅ Done"; note the
   reading-position persistence addition.
2. `docs/long-lived/PROGRESS REPORT.md`: per-batch ✅ work log.

---

## Design-Fork Questions (pre-answered)

1. Persist the verse too? → Not in v1. The user's contract is
   chapter-level ("reader should be at Genesis 20"). Verse-level
   restore-scroll needs per-verse keys + ensureVisible and is easy to add
   later; keys are namespaced so adding `reading_position.verse` is
   non-breaking.
2. Where does restore happen — router redirect or reader? → Reader
   `_loadBooks()`. It's the single place both pages already resolve
   defaults, and it has the book map needed for validation.
3. What if the persisted translation was uninstalled? → Fall back to
   `translations.first`, but keep persisted book/chapter if the fallback
   translation has them.

## Verification (user runs analyze — see CONTEXT.md constraint)

1. `flutter analyze` on all touched files → green (user-run).
2. Manual: read to Genesis 20 → close app → relaunch → reader at
   Genesis 20, same translation.
3. Manual: 1 Kings 5 [NKJV] → pill → tap NLT → reader shows 1 Kings 5
   [NLT]; relaunch → still 1 Kings 5 [NLT].
4. Manual: continuous-scroll from Genesis 19 into 20 (no tap navigation)
   → relaunch → Genesis 20.
5. Manual: first run (no key) → defaults to first book/chapter as today.
6. Manual: single installed translation → pill grid shows install prompt.
7. Manual: tap-outside closes the grid; active translation highlighted.
