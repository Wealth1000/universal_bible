## Current objective
Two features, in order (user-specified):
1. Cross-session reading-position persistence — reader reopens at the last
   centered chapter (and translation) from the previous session.
2. §2 of PLANNED_FEATURES.md — translation pill with grid dropdown.
   Switching translation via the grid must keep the current book/chapter
   (change translation component of the persisted key only, never reset
   book/chapter).

## Key discoveries
- Reader state = three app-scoped Riverpod Notifiers in
  lib/features/bible/domain/reader_provider.dart:
  currentTranslationProvider (String?), currentBookProvider (int?),
  currentChapterProvider (int?). All start null; nothing is persisted today.
- Defaults are applied in `_loadBooks()` in BOTH reader pages
  (reader_page_desktop.dart ~line 88-151, reader_page_mobile.dart ~line
  89-153): null translation → `translations.first`, null book/chapter →
  first book / first chapter. This null-fallback is the restore injection
  point — persisted values only fill nulls, so in-session state wins.
- The visually-centered chapter is already tracked: `_updateVisibleChapter`
  in `_ReaderContentState` (desktop, ~line 631) and `_ReaderScrollState`
  (mobile, ~line 727) walks `_chapterHeaderKeys` and writes
  `visibleChapterProvider`. It knows `_chapters[i].book` too — this is the
  natural save hook for "last chapter centered", incl. continuous-mode
  cross-book drift which never passes through `_goTo`.
- Both readers key content on ValueKey
  '$translationId|$book|$chapter|$continuousReading' and cache the verses
  future on the same key — so changing ONLY the translation already
  reloads verses at the same book/chapter. The pill needs no reload logic.
- Persistence precedent: continuous_reading_provider.dart self-loads from
  SharedPreferences in build() (async). StorageService (singleton,
  lib/core/services/storage_service.dart) inits SharedPreferences in
  main.dart BEFORE runApp — so a sync getter on StorageService can hand
  the persisted position to a provider's build() with no async gap.
- Translation pill TODO stubs already exist: desktop
  `onTranslationTap: () { // TODO: Show translation switcher }`
  (reader_page_desktop.dart ~296) with the pill-ish TextButton in _TopBar
  (~517-533); mobile `_showTranslationPicker()` TODO (~364).
- Installed translations come from translationRepoProvider
  (lib/core/providers/translation_repo_provider.dart) →
  `getInstalled()` returns List<Translation> with .id (abbrev, uppercase)
  and .name (full name) — exactly what the grid cells need.
- Mobile `_updateChapterCounts()` (~156) clamps chapter to the book map if
  missing — keep; it only fires when the chapter truly doesn't exist in
  the newly selected translation.
- settings_page.dart and translation_manager_page.dart also set
  currentTranslationProvider (lines 512 / 76,165) — they also don't touch
  book/chapter, consistent with the "switch keeps position" rule.

## Files expected to touch
- lib/core/services/storage_service.dart          (Batch 1: keys + save/load)
- lib/core/providers/database_provider.dart        (Batch 1: ReadingPosition + provider)
- lib/features/bible/presentation/pages/reader_page_desktop.dart (Batches 2-4)
- lib/features/bible/presentation/pages/reader_page_mobile.dart  (Batches 2-4)
- lib/features/bible/presentation/widgets/translation_grid.dart  (Batch 4, NEW)
- docs/PLANNED_FEATURES.md, docs/long-lived/PROGRESS REPORT.md   (Batch 5)

## Conventions to follow
- SharedPreferences via StorageService singleton (user explicitly asked for
  the key in the storage service + a provider in database_provider.dart).
- Notifier (not AsyncNotifier) pattern, matching reader_provider.dart /
  continuous_reading_provider.dart.
- Mobile pickers are modal bottom sheets with the active item highlighted
  (see _showBookPicker / _showChapterPicker); desktop uses inline
  dropdowns/overlays in _TopBar.
- Widgets folder: lib/features/bible/presentation/widgets/ (new — pages/
  exists; mirror the feature-folder layout).

## Constraints / watch out for
- The user runs `flutter analyze` themselves — this environment has a pub
  dependency conflict (flutter_native_splash vs pinned meta) that makes
  analyze fail here. Do not try to fix the config.
- Scroll listener fires every frame — persistence writes MUST be debounced
  (Timer in the notifier, ~400 ms) and state-compared to avoid churn.
- Restore must validate persisted book/chapter against the loaded book map
  (a different translation may lack that book/chapter) and fall back to
  existing defaults, never crash.
- Grid dropdown is a Wrap/adaptive box, NOT a fixed-column GridView (spec).
- Grid tap handler must write currentTranslationProvider +
  saveTranslationOnly() ONLY — never book/chapter.
- Batched delivery: Batch 1 persistence layer → 2 restore → 3 save hooks →
  4 pill/grid → 5 docs. Progress report updated per batch.

## Expected outcome
- Close app at Genesis 20 [NLT] → relaunch → reader at Genesis 20 [NLT].
- Continuous-scroll into a chapter (no tap) also persists it.
- Pill top-right shows active translation id; tap → adaptive grid of
  installed translations, active highlighted; tap cell → translation
  switches, book/chapter unchanged (1 Kings 5 NKJV → NLT stays 1 Kings 5);
  tap-outside closes; single translation → install-more prompt.
- flutter analyze stays green (user-run).
