# ORIENT — read me first (AI session bootstrap)

Fast orientation for future sessions. Facts here were verified 2026-07-21;
trust code over this doc when they disagree.

## What this is

**universal_bible** — offline-first Flutter Bible reader. Desktop-first
(Linux/Windows; Android target exists but **mobile development is paused
per DECISIONS.md** — the `/reader_mobile` route is commented out in
`app_router.dart`; `ReaderPageDesktop` is the live reader). Local
Drift/SQLite is the source of truth; Supabase backend + sync exists as
skeleton but is **disabled** (commented out in `main.dart`).

## Read in this order

1. `docs/long-lived/DECISIONS.md` — why things are the way they are. The
   single most useful doc. Keep it updated after design choices.
2. `docs/long-lived/PROGRESS REPORT.md` — tail of file = latest work logs.
3. `docs/PLANNED_FEATURES.md` — the current feature queue with per-§ specs
   and owner answers to open questions (Q1–Q5 at bottom).
4. `docs/long-lived/API.md` + `GLOSSARY.md` — provider/service surface and
   domain terms (verseId encoding, .bdat, book maps).
5. `docs/CONTEXT.md` / `docs/PLAN.md` — scratch docs from the *previous*
   task (reading-position persistence + §2 pill, done). Historical.

⚠️ Long-lived docs drift: API.md's routes table predates `/search`; the
prescriptive UI in SCREEN MAP / DESIGN SYSTEM / UI_UX does **not** match
the actual app UI — owner says that's fine, a **UI revamp comes later**.
Don't "fix" UI toward those docs unprompted.

## State of the feature queue (PLANNED_FEATURES.md)

- ✅ §1 chapter indicator, §2 translation pill grid, §3 dropdown
  positioning/highlight, §4 collapsible sidebar, §7 search icon in header.
- ✅ (bonus) cross-session reading-position persistence
  (`reading_position.*` SharedPreferences keys via StorageService,
  `readingPositionProvider` in `core/providers/database_provider.dart`,
  saves debounced 400 ms).
- ⏭️ **Next: §5 verse selection action panel** (highlights R/G/B presets +
  custom picker, bookmark/note/copy/share, Compare entry; mobile = bottom
  sheet per Q2). Groundwork exists: desktop reader already has tap-driven
  multi-verse selection (`_selectedVerseKeys` in `_ReaderContentState`,
  keyed `book|chapter|verse`, non-contiguous OK) with a stub FAB.
- Then **§6 compare panel**, which depends on §5. Owner addition
  (2026-07-21): inside the split-view compare pane there must be an
  **"open full screen" action** — a new routed screen showing just the
  selected verse(s) + all-translation comparison, with normal back
  navigation (see §6 spec in PLANNED_FEATURES.md).

## Codebase mental map

- Reader: `lib/features/bible/presentation/pages/reader_page_desktop.dart`
  (live) / `reader_page_mobile.dart` (kept compiling, not routed).
  Content keyed `'$translationId|$book|$chapter|$continuousReading'` —
  changing only the translation reloads verses in place. `_loadBooks()` is
  where defaults/restore/clamping happen. `_updateVisibleChapter` tracks
  the visually-centered chapter (scroll listener, per frame — debounce any
  persistence in the notifier, never here).
- Reader session state: three nullable Notifiers in
  `features/bible/domain/reader_provider.dart`
  (currentTranslation/Book/Chapter) + `visibleChapterProvider`.
- Riverpod 3 **Notifier API only** (no StateProvider); go_router in
  `core/routing/app_router.dart`; ShellRoute wraps main destinations with
  `AppShell` (collapsible rail on desktop).
- Persistence: prefs via `StorageService` singleton (inits before runApp →
  sync getters are safe in provider `build()`); Drift `AppDatabase` in
  `lib/database/app_database.dart` (⚠️ its `ReadingPosition` row class
  clashes with the prefs value class — readers import it with
  `hide ReadingPosition`).
- Scripture rendering: `core/utils/scripture_format.dart` — HTML
  stripping + red-letter via U+E000/E001 sentinels; book-name cleaning in
  `core/utils/book_name_utils.dart`.
- verseId encoding: `book*1_000_000 + chapter*1_000 + verse`.

## Working agreements / gotchas

- **User runs `flutter analyze` themselves.** This environment has a pub
  conflict (flutter_native_splash vs pinned meta) — analyze/pub fail here;
  don't try to fix the config.
- Batched delivery with a per-batch work-log entry appended to
  `docs/long-lived/PROGRESS REPORT.md`; mark sections ✅ in
  PLANNED_FEATURES.md when done. Update DECISIONS.md after significant
  choices.
- Translation switching must NEVER touch book/chapter (providers or
  persisted key) — `saveTranslationOnly()` exists for this.
- Features must not import each other; shared code → `core/`. Widgets
  folder pattern: `features/<f>/presentation/widgets/`.
- Desktop overlays = anchored dialogs; mobile pickers = bottom sheets;
  active item highlighted.
- Known debt list lives at the bottom of DECISIONS.md (dup theme
  providers, `_translationRepoProvider` ×5, "presention" typo dir, etc.).
  Don't re-discover it; don't fix unprompted.
- Branch `develop`; commit style `feat:/fix:/refactor:/docs:`; commit only
  when asked.
