# ORIENT — read me first (AI session bootstrap)

Fast orientation for future sessions. Facts here were verified 2026-07-21;
trust code over this doc when they disagree.

## What this is

**universal_bible** — offline-first Flutter Bible reader, **v1.0.0 — MVP
complete (2026-07-21)**. Desktop-first (Linux/Windows; Android target
exists but **mobile development is paused per DECISIONS.md** — the
`/reader_mobile` route is commented out in `app_router.dart`;
`ReaderPageDesktop` is the live reader). Local Drift/SQLite is the source
of truth; Supabase backend + sync exists as skeleton but is **disabled**
(commented out in `main.dart`) — sync is the headline post-MVP feature.

## Read in this order

1. `docs/long-lived/DECISIONS.md` — why things are the way they are. The
   single most useful doc. Keep it updated after design choices.
2. `docs/long-lived/PROGRESS REPORT.md` — tail of file = latest work logs.
3. `docs/long-lived/CHANGELOG.md` — release history (v1.0.0 at top).
4. `docs/long-lived/API.md` + `GLOSSARY.md` — provider/service surface and
   domain terms (verseId encoding, .bdat, book maps).
5. `docs/completed/` — finished feature specs (PLANNED_FEATURES.md,
   UI_OVERHAUL.md). Historical; all sections shipped.

⚠️ Long-lived docs drift: API.md's routes table predates `/search`; the
prescriptive UI in SCREEN MAP / DESIGN SYSTEM / UI_UX does **not** match
the actual app UI — the shipped "calm study" overhaul
(docs/completed/UI_OVERHAUL.md) is the design authority until DESIGN
SYSTEM.md is backfilled.

## State of the project — v1.0.0, MVP complete (2026-07-21)

Everything in the PLANNED_FEATURES queue shipped: §1–§3 reader nav
polish, §5 verse action panel (highlights/bookmark/note/copy/share), §6
compare (split + full-screen `/compare`), §7 search; plus search/
bookmarks/notes screens, reading-position persistence, the "calm study"
UI overhaul, and non-blocking bulk translation import with per-file
progress. §4's collapsible sidebar was later **simplified to permanent
icons-only** (owner, 2026-07-21) — no collapse state, no
sidebar_provider.

**Not in MVP / next up:** Supabase sync (skeleton disabled in main.dart);
mobile-specific UI (paused). No active feature queue — new work starts
from owner requests.

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
  `AppShell` (fixed icons-only rail on desktop, tooltips).
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
  `docs/long-lived/PROGRESS REPORT.md` + a CHANGELOG entry. Update
  DECISIONS.md after significant choices.
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
