# DECISIONS

Why things are the way they are. Small models rely on this — keep it current.
Format: **Decision** → rationale. Newest at the bottom of each section.

UNTIL FURTHER NOTICE, MOBILE specific data shall not be developed. this goes accross screens and providers and whatever. ergo, this app is a desktop app until further notice.

## Architecture

- **Offline-first, "Local First → Sync Later."** Reading must never require internet. Local Drift/SQLite is the source of truth; every write goes local → UI → (future) queued background sync.
- **Drift (SQLite) for local persistence.** Full local copy of translations + user data. `LazyDatabase` over `NativeDatabase` at `StorageService().databasePath` because the base dir is user-configurable and loads async.
- **Supabase is the entire backend.** Postgres tables (`bible_*`), Storage bucket `Bibles` for `.bdat` distribution, Supabase Auth. Auth exists *only* to enable sync — the app is fully usable anonymous/offline.
- **Sync conflict strategy: Last Write Wins (initial).** Simplicity first; merge logic deferred.
- **Sync is intentionally disabled right now** (commented out in `main.dart`) to avoid startup errors pre-auth. It will be wired as auth-driven after login. ⚠️ Known hazard: `_syncTranslations` as written would clobber local `installed`/`bookMapJson` metadata — fix before enabling.
- **Feature-based folder structure** (`core/` + `features/{auth,bible,settings,translation_manager}` with data/domain/presentation). Features must not import each other; shared code goes in `core/`.

## State & routing

- **Riverpod 3 with the Notifier API only.** `StateProvider` was deliberately migrated away from. One state-management solution, no exceptions.
- **go_router with an async redirect at `/`.** Startup logic: any installed translation → `/reader`, else `/welcome`. Deep links (`/reader/:book/:chapter/:verse`) documented in ROUTES.md but not implemented yet.

## Data format

- **`.bdat` is JSON** (despite the name), parsed via `BibleBdat.fromJson` (reused from a prior project). Import pipeline: parse → copy file to `translationsDir` → batch-insert verses → precompute chapter counts + display names → upsert translation row.
- **Format support must stay expandable** — a parser/adapter per format, never hardcode the app to `.bdat`.
- **Verses are denormalized in one `verses` table** with index `(translationId, bookNumber, chapter)`. Reading a chapter must feel instantaneous.
- **Chapter counts and display names are precomputed at import** and stored as JSON blobs on the translation row, so navigation UI never scans the verses table.

## UI

- **Bundled fonts, no runtime fetch.** Literata (scripture, replaced the never-bundled 'Source Serif 4'), Inter, JetBrains Mono — offline-safe.
- **Separate desktop (NavigationRail) and mobile (BottomNavigationBar) reader pages.** Known debt: desktop shell is duplicated across screens and needs extraction into a shared scaffold.
- **Red-letter rendering via Unicode private-use sentinels** (U+E000/E001) because they survive HTML stripping; converting `<span class='Isus'>` → styled spans directly would couple the parser to the renderer.
- **Reader perf (2026-07-15):** verses Future is cached per (translation, book, chapter) instead of recreated in `build()` — fixes selection-destroying flicker; one `SelectionArea` per chapter (not per-verse `SelectableText`) — enables continuous cross-verse selection.
- **flutter_native_splash** for Android/iOS only, colors match design-system surfaces (#F8F9FA / #121212).
- **Reading position persists in SharedPreferences, not Drift (2026-07-18).** `reading_position.*` keys in `StorageService` + `readingPositionProvider` (`database_provider.dart`); prefs load sync before runApp so restore has no async gap. The Drift `reading_positions` table stays for future sync. Saves are debounced 400 ms (scroll listener fires per frame). ⚠️ Naming hazard: the Drift row class is also called `ReadingPosition` — reader pages import `app_database.dart` with `hide ReadingPosition`.
- **Translation switching never touches book/chapter (2026-07-18).** The §2 pill grid (`translation_grid.dart`) sets `currentTranslationProvider` + `saveTranslationOnly()` only; reader content keyed on `'$translationId|$book|$chapter|…'` reloads verses in place. `_loadBooks()` clamps only when the new translation genuinely lacks the current book/chapter.
- **§5 verse action panel (2026-07-21, desktop).** Verse selection hoisted from local `_ReaderContentState` state into `selectedVersesProvider` (`Set<VerseRef>`, `reader_provider.dart`) so the panel and the upcoming §6 compare panel share it; content recreation clears it. Highlight colors stored in `highlights.color` as `#AARRGGBB` hex (presets soft red/green/blue at 0x66 alpha, per Q1→R,G,B); semantics: same color on an all-same-color selection = toggle off, else replace (one color per verse). Highlight repaint via `highlightsVersionProvider` bump → `_ReaderContentState._reloadHighlights()`. **Share = copy-to-clipboard + toast** (no share plugin — Linux support poor and pub deps are frozen); **custom picker = material shade-grid dialog** (no new dependency). Notes save one row per selected verse, same content.
- **Toasts only for non-visible effects (2026-07-21, owner).** Snackbars confirm only actions whose result isn't visible in the reader (bookmark, note, copy/share). Highlights get no toast — the colored verses are the feedback, and a snackbar would cover the bottom-center action panel. Remaining toasts are floating, 360px, ~2s.
- **§6 compare panel (2026-07-21, desktop).** `compareOpenProvider` (bool) + pane rendered iff `compareOpen && selection.isNotEmpty` — comparison is live-updating; deselect-all (or the action panel ×, or content recreation) closes it, while the pane's own × keeps the selection. Translation blocks alphabetical by abbreviation (Q3), missing verses show an italic "Not available" line; new `getVerse()` DAO. Shared `CompareColumn` widget serves both the 60/40 split view and the routed full-screen `/compare` page (`ComparePageDesktop`), which derives book names itself from the active translation's bookMap and is reached via `context.push` so back restores the split view.
- **Reading settings live in `core/providers/reading_settings_provider.dart` (2026-07-21).** `fontSizeProvider`, `showVerseNumbersProvider`, `defaultTranslationProvider` — self-loading Notifiers over SharedPreferences (same pattern as `preserveOriginalBookNamesProvider`), moved out of the settings page so the reader can watch them without cross-feature imports. Reader wiring: verse font size + verse-number visibility live-update. **Default Translation is a fallback only** — reading-position persistence wins; the default seeds fresh installs/cleared positions (resolution: in-session ?? persisted ?? default ?? first). Selecting a default does NOT switch the active translation.
- **App version is a constant in `core/app_info.dart` (2026-07-21).** `AppInfo.version` (currently **1.0.0**) is the single source shown in Settings and Welcome; bump on release. Reading from pubspec (package_info_plus) deferred until pub deps can change. The fake "Clear Cache" settings tile (hardcoded 42.5 MB, did nothing) was removed — there is no app cache to clear.
- **Sidebar is permanently icons-only (2026-07-21, owner).** The §4 expand/collapse state was removed — the shell is small enough that tooltips suffice; the UI is self-explanatory. `sidebar_provider.dart` and the `sidebar.collapsed` pref deleted.
- **Translation import parses on a background isolate (2026-07-21).** `importFromFile` runs file read + jsonDecode + verse-id math via `compute` (top-level `_parseBdatFile` → plain-data `ParsedBdat`); only the Drift write happens on the main isolate. Batch imports stay sequential (DB write is the serial part) but the Translation Manager refreshes its list after each file and shows a per-file progress card, so imported translations are readable while later ones load.
- **MVP declared complete at v1.0.0 (2026-07-21, owner).** Scope: offline reading, .bdat import, search, bookmarks, notes, highlights, compare, settings, theming, "calm study" UI. **Sync is explicitly out of MVP** — the Supabase skeleton stays disabled; it is the headline post-MVP feature.
- **Continuous reader uses a center-anchored `CustomScrollView` (2026-07-22).** The old `ListView` compensated for prepended (previous) chapters by measuring the inserted height and `jumpTo`-ing the scroll offset in a post-frame callback — a visible teleport on slow prepends. Now `reader_page_desktop.dart` splits chapters at `_centerIndex` into a reverse (above-anchor) `SliverList` and a forward one keyed by `_centerKey`; prepending increments `_centerIndex` so above-anchor content grows into negative scroll space away from a fixed viewport, eliminating the jump. Upward loading (`_maybeLoadPrev`) is gated on `userScrollDirection == forward` + a 1500px `extentBefore` buffer to stop re-prepending when scrolling down past the top.

## Storage & config

- **User data lives in a visible folder** (default `~/Documents/universal_bible/`) — "user data belongs to the user." Base dir changeable in settings; changing it does not migrate existing files (known limitation).
- **`.env` via flutter_dotenv, bundled as an asset.** Ships only `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY` (publishable key is safe to bundle). Loaded in `main()` before `Supabase.initialize`.

## Platforms

- **Targets now: Linux, Windows, Android.** macOS/iOS/Web later. Desktop-first personal-use app.

## Known debt (decided to defer, not forgotten)

- ~~Duplicate theme provider files~~ — fixed 2026-07-21 (UI overhaul Batch 1); only `core/themes/theme_provider.dart` remains.
- ~~Private `_translationRepoProvider` copy-pasted in 5 files~~ — fixed: a single shared `core/providers/translation_repo_provider.dart` (`translationRepoProvider`) is now the only definition; no private copies remain.
- `features/settings/presention/` directory is a typo ("presention") — rename when convenient.
- `reader_mobile` route lacks a leading slash in `app_router.dart`.
- ~~Welcome page hardcodes "Version 2.4.0"~~ — fixed 2026-07-21; version now comes from `AppInfo`.

---

*Rule: after any cloud-AI consultation or significant design choice, add the outcome here immediately.*
