# Changelog

Newest at the top. Dates are work-log dates from PROGRESS REPORT.md.

## 2026-07-22

- **Reader continuous scroll — center-anchored, no teleport**: the desktop reader's `ListView` was replaced with a center-anchored `CustomScrollView`. Loading a previous chapter used to `jumpTo` the scroll offset forward by the inserted content's height to keep the viewport steady (a post-frame flicker on slower prepends); now above-anchor chapters render in a reverse sliver that grows into negative scroll space away from a fixed anchor, so upward loading never shifts what's on screen. Prev-load now triggers on scroll-up direction + a 1500px top buffer (was a bare `pixels <= 100` check).

## 2026-07-21 — v1.0.0 (MVP complete)

- **Version bumped to 1.0.0** (`AppInfo.version`). Owner declared the MVP complete: offline reading, import, search, bookmarks, notes, highlights, compare, settings, theming. Sync (Supabase) intentionally NOT included — remains disabled skeleton, post-MVP.
- **Non-blocking translation import with progress UI**: `.bdat` parsing (file read + jsonDecode + verse math) moved to a background isolate (`compute` → top-level `_parseBdatFile` returning plain-data `ParsedBdat`), so the UI no longer freezes during bulk imports. Translation Manager shows a progress card (overall bar + per-file pending/importing/done/failed rows); the installed list refreshes after **each** file so already-imported translations can be activated and read while the rest load; with nothing installed, the first success becomes active immediately. Success snackbar dropped (toast policy — the list is the confirmation); card stays visible on failure.
- **Sidebar simplified to icons-only**: the expand/collapse state was removed entirely — the rail is always 56px icons-with-tooltips (the UI is self-explanatory). `sidebar_provider.dart` deleted; `sidebar.collapsed` pref removed from StorageService. Supersedes §4's collapsible design.

## 2026-07-21

- **UI overhaul — "calm study"** (docs/UI_OVERHAUL.md): design tokens (`core/design/app_tokens.dart`) + rebuilt theme — warm paper/charcoal surfaces, single deep-ink accent, Literata for scripture/display + Inter for UI chrome. Reader: 680px measure, quiet top bar, ink accent-bar selection, caps chapter header. All hardcoded colors (#2E434C, #FFFDE7, Colors.green/red/orange) replaced by tokens; duplicate theme provider removed.
- **Search, Bookmarks, Notes screens** (pre-overhaul, deliberately plain): live LIKE search over the active translation with match highlighting and jump-to-chapter; bookmarks list with previews and single-tap removal; notes list with edit-in-place and confirmed delete. Sidebar items wired (`/bookmarks`, `/notes` routes added).
- **Fix:** compare pane no longer closes instantly on open (tree restructure was recreating reader state and clearing the selection).
- **Settings actually wired to the reader**: font-size slider and verse-numbers toggle now live-update verse rendering; Default Translation is a fallback only (reading position wins) and no longer hijacks the active translation; fake "Clear Cache" tile removed; version now sourced from `AppInfo` (**0.6.40-beta**) in Settings and Welcome.
- **§6 Compare panel (desktop)**: split view (reader 60% / comparison 40%) showing the selected verse(s) in every installed translation, alphabetical, live-updating with the selection; × keeps the selection, deselect-all closes. **Full-screen compare** at routed `/compare` with back navigation.
- **§5 Verse selection action panel (desktop)**: floating toolbar on verse selection — highlight presets (R/G/B) + custom shade-grid color picker, Bookmark, Note, Copy, Share (copy-fallback with toast), Compare stub (§6), clear-selection. Highlights persist to Drift (`#AARRGGBB`) and render on verses; same-color re-apply toggles off. Selection state hoisted to `selectedVersesProvider`.
- Snackbars limited to non-visible effects (bookmark/note/copy/share); highlight actions show no toast.
- **§7 Search icon** in the reader header (desktop + mobile AppBar).
- Desktop verse action overlay driven by verse **tap** (non-contiguous multi-verse selection), not mouse text-selection.
- ORIENT.md added (session bootstrap doc).

## 2026-07-20

- **§4 Collapsible desktop sidebar** (icons-only collapsed state, tooltips, persisted globally).
- Translations moved off the sidebar → managed from Settings ("Manage Translations" tile); Translation Manager gained a back arrow.
- App logo changed.

## 2026-07-18

- **Reading-position persistence**: reader reopens at last centered translation + book + chapter (`reading_position.*` SharedPreferences keys, debounced saves, scroll-centered chapter tracking).
- **§2 Translation pill** with adaptive grid dropdown; switching translations preserves book/chapter.
- **§1 Chapter indicator** unified & scroll-accurate (`visibleChapterProvider`); **§3** book/chapter dropdowns positioned adjacent with active-item highlight.

## 2026-07-15

- Scripture formatting pipeline (`scripture_format.dart`): HTML stripping, entity decoding, **red-letter words of Christ** via sentinel markers.
- Reader selection-flicker fix (cached verses Future); continuous cross-verse text selection via one `SelectionArea` per chapter.
- Literata as the bundled scripture typeface.

## 2026-07-14 — v0.2.1

- First working offline milestone: multi-file `.bdat` import, Drift/SQLite storage, reader with book/chapter navigation, translation manager, settings (theme, font size), welcome flow, go_router shell. Supabase sync skeleton (disabled).
