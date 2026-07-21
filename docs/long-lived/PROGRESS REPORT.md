# 🚀 Bible Project – Progress Report

**Current version:** 1.0.0 — **MVP complete** (2026-07-21; sync is post-MVP)
**Newest work logs are at the bottom of this file.**

---

*Original report below (2026-07-14, v0.2.1 — first offline milestone):*

---

**Date:** 2026-07-14  
**Version:** 0.2.1 (Hotfix: Multi‑file import support)  
**Milestone:** First successful translation import & offline reading

---

## 📌 Overview

We have successfully built the **core offline‑first Bible app** for Linux, Windows, and Android. The app can:

- Import **one or more** `.bdat` Bible translation packages at once
- Store them in a local SQLite database (Drift)
- Read and navigate Scripture (books/chapters)
- Manage translations (list, activate, delete)
- Customise appearance (theme, font size)
- Persist settings across sessions

All screens follow the **design system** and **screen map** defined in the project documentation.

---

## ✅ Completed Phases

### 1. Project Foundation
- **Flutter project** created with Linux, Windows, Android support.
- **Folder structure** aligned with feature‑based architecture (`core`, `features`, `database`, `services`).
- **Dependencies** added: `supabase_flutter`, `drift`, `riverpod`, `go_router`, `shared_preferences`, `file_picker`, `path_provider`, `uuid`, `flutter_dotenv`, etc.
- **State management**: Riverpod (Notifier API) – `StateProvider` migrated to `Notifier`.
- **Theming**: Light/Dark/System with instant switching and persistence (`SharedPreferences`).
- **Storage**: `StorageService` – all app data stored in `~/Documents/universal_bible/`.

### 2. Routing & Navigation
- **GoRouter** with declarative routes:
  - `/welcome` – intro screen
  - `/login` – placeholder (authentication not yet implemented)
  - `/reader` – main Bible reader
  - `/translations` – translation manager
  - `/settings` – app settings
- **Redirect logic**: On app start, if no translation is installed, redirect to `/welcome`; otherwise go directly to `/reader`.
- **Responsive navigation**:
  - Desktop → Navigation Rail
  - Mobile → Bottom Navigation Bar

### 3. Database (Drift + SQLite)
- Tables created:
  - `translations` – metadata (name, language, version, bookMap, chapterCounts, file path)
  - `verses` – verse text with foreign key to translation
  - `notes` (placeholder), `highlights` (placeholder), `bookmarks` (placeholder), `reading_positions` (placeholder)
- **Primary key** fixed on `translations.id` to enable upsert.
- **Indexes** for fast chapter retrieval.
- **DAO methods**: `getInstalledTranslations()`, `getVersesForChapter()`, `insertVerses()`, `upsertTranslation()`, etc.

### 4. Bible Translation Import
- **`.bdat` file parser**: `BibleBdat.fromJson()` (reused from existing project).
- **Import logic**:
  - User selects **one or more** `.bdat` files via `file_picker` with `allowMultiple: true`.
  - Each file is validated, copied to `~/Documents/universal_bible/translations/`, and its verses inserted into the database.
  - Metadata (bookMap, chapter counts) stored as JSON in `translations`.
- **Chapter counts** are computed during import and stored for fast navigation.
- **Error handling**:
  - Individual file failures are caught and logged, not interrupting the import of other files.
  - Summary snackbar shows success/failure counts.
  - Full stack traces printed to console for debugging.

### 5. Screens

#### Welcome Screen
- App logo, title, tagline.
- Buttons: `Sign In` (placeholder) and `Continue Offline`.
- Import link (navigates to Translation Manager).

#### Bible Reader (Desktop & Mobile)
- **Desktop**: Navigation Rail + centered reading column.
- **Mobile**: Bottom Navigation Bar + full‑width reading.
- **App Bar**: Book selector, Chapter selector, Translation switcher.
- **Verses**: Displayed with verse numbers, selectable text, long‑press context menu (placeholder).
- **Reading position** (book, chapter, scroll offset) – to be implemented.

#### Translation Manager
- Lists installed translations with active state.
- **Import** button (FAB) opens file picker with **multi‑select** support.
- **Activate** sets current translation and navigates to Reader.
- **Delete** with confirmation dialog.
- Empty state with import prompt.

#### Settings Screen
- **Appearance**: Theme toggle (Light/Dark/System), font size slider.
- **Reading**: Default translation dropdown, show/hide verse numbers.
- **Data & Storage**: Display storage path, clear cache placeholder.
- **About**: Version, License, Credits (placeholders).

### 6. Offline‑First & Synchronisation (Skeleton)
- **SyncService** and **SupabaseBibleRepository** created.
- Currently disabled (commented out) to avoid startup errors.
- Planned: auth‑driven sync after login.

### 7. Design System Compliance
- All screens use **design tokens** (colors, spacing, typography) defined in `DESIGN SYSTEM.md`.
- Theming adapts to system preference.
- Minimalist, content‑first UI.

---

## 🧪 Testing

- **Import** of one or more `.bdat` files succeeds; multiple files are imported in sequence.
- **Navigation** between screens works.
- **Theme** switching persists.
- **Font size** slider updates and saves.
- **Desktop and mobile** layouts are responsive.

---

## 🐛 Known Issues / TODOs

- [ ] **Reading position** is not yet saved – currently starts at Genesis 1:1 each time.
- [ ] **Search** screen not implemented.
- [ ] **Bookmarks** screen not implemented.
- [ ] **Notes** screen not implemented.
- [ ] **Highlights** screen not implemented.
- [ ] **Authentication** not implemented – sync is disabled.
- [ ] **Version** displayed in Settings is hardcoded.
- [ ] **Clear Cache** is a placeholder.
- [ ] **Verse selection** context menu actions are stubs.
- [ ] **Next Chapter** button in Reader is a stub.
- [ ] **Translation switcher** in Reader is a placeholder.
- [ ] **Desktop shell** – navigation rail, top bar, etc. – needs to be reused across screens (currently duplicated).

---

## 📦 Build & Run

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run -d linux   # or windows, android
```

---

## 🎯 Next Milestone

**Phase 3 – Study Tools**  
- Implement **Notes**, **Highlights**, **Bookmarks** with local persistence.
- Add **Verse context menu** (Highlight, Bookmark, Add Note, Copy).
- Extend **Reader** with verse selection and quick actions.
- Start **Search** functionality (local search over verses).

---

## 👥 Contributors

- **You** – architecture, design, and implementation.
- **AI Assistant** – code generation, debugging, and documentation.

---

## 📚 Documentation

All project documents (SRS, Architecture, Design System, Screen Map, Routes, Timeline) are available in the `/docs` folder.

---

## 🔨 Work Log – 2026-07-15 (Scripture Formatting & Reader Fixes)

### Batch 1: Scripture formatting utility ✅
- Created `lib/core/utils/scripture_format.dart`:
  - Ported the proven reference code verbatim: `convertIsusSpansToJTags()` (converts `<span class='Isus'>` → `<J>` tags) and `normalizeResolvedScriptureText()` (strips HTML tags — `<br>`, `<p>`, `<li>`, `<i>`, `<span>`, etc. — decodes HTML entities, normalises whitespace, drops quote-only lines).
  - Added sentinel constants `wordsOfChristOpenMarker` / `wordsOfChristCloseMarker` (Unicode private-use chars U+E000/U+E001) so the words-of-Christ distinction survives the generic tag strip.
  - Added `buildScriptureSpans()` — splits normalised text on the sentinels and returns `TextSpan`s with red-letter styling for words of Christ.
  - Added `wordsOfChristColorFor(Brightness)` — theme-aware red (deep red on light, lighter red on dark).

### Batch 2: Desktop Reader – formatting + selection flicker fix ✅
- `reader_page_desktop.dart`:
  - **Formatting**: every verse is now passed through `normalizeResolvedScriptureText(..., preserveWordsOfChrist: true)` and rendered with `buildScriptureSpans()` — HTML tags/entities are gone and words of Christ render in red (red-letter edition).
  - **Flicker root cause fixed**: the verses `Future` was recreated inside `build()` on *every* `setState`, so any selection-driven rebuild made `FutureBuilder` re-enter its loading state → reader flickered and the selection was destroyed. The future is now cached in state (`_ensureVersesFuture`) and only recreated when `(translation, book, chapter)` actually changes.
  - **Cross-verse selection**: replaced per-verse `SelectableText` (isolated selection islands) with a single `SelectionArea` wrapping the whole chapter — text selection now flows continuously across verses.
  - Selection FAB callback is guarded to only `setState` when the selected text actually changes (no rebuild churn during drag).
  - Verse tap still toggles the per-verse highlight.

### Batch 3: Mobile Reader – formatting + selection flicker fix ✅
- `reader_page_mobile.dart`:
  - **Formatting**: same treatment as desktop — verses normalised via `normalizeResolvedScriptureText(..., preserveWordsOfChrist: true)` and rendered with `buildScriptureSpans()` (red-letter support).
  - **Flicker fix**: same future-caching fix as desktop (`_ensureVersesFuture`) — verse taps / context-menu `setState` calls no longer recreate the verses future, so the reader no longer flickers back to the loading spinner.
  - **Text selection**: chapter verse list wrapped in a single `SelectionArea`, so long-press text selection works and flows continuously across verses. Verse tap / long-press context-menu behaviour is unchanged.

### Batch 4: Literata as default reader font ✅
- Replaced `fontFamily: 'Source Serif 4'` (never bundled) with `fontFamily: 'Literata'` in both `reader_page_desktop.dart` and `reader_page_mobile.dart`.
- Literata regular + italic are already in `assets/fonts/` and declared in `pubspec.yaml`, so scripture text now renders in a real, bundled serif face on every platform.

### Summary of this work log
The reader now renders **clean, formatted scripture**: raw `.bdat` HTML (`<br>`, `<p>`, `<i>`, `<span>`, entities) is normalised by the proven `normalizeResolvedScriptureText()` pipeline (ported verbatim from the reference project) in the new `lib/core/utils/scripture_format.dart`, with **red-letter words of Christ** preserved via `<span class='Isus'>` → `<J>` → sentinel conversion and rendered through `buildScriptureSpans()`. The **selection flicker bug is fixed** on both desktop and mobile — its root cause was the verses `Future` being recreated on every rebuild, forcing `FutureBuilder` back into its loading state; the future is now cached per `(translation, book, chapter)`. Per-verse `SelectableText` islands were replaced with a single `SelectionArea` per chapter, so **text selection flows continuously across verses** without interruption, and the desktop selection FAB only rebuilds when the selection actually changes. Finally, the reader's default typeface is now **Literata** (regular + italic, bundled in assets), replacing the unbundled 'Source Serif 4'.

---

## 🏁 Conclusion

We have a **solid, working offline Bible reader** with translation management and customisation. The foundation is stable, and we are ready to add study features and synchronisation. The first successful import marks a key milestone. 🎉
---

## 🔨 Work Log – 2026-07-18 (Reading-Position Persistence + Translation Pill)

Plan: docs/PLAN.md · Discovery: docs/CONTEXT.md

### Batch 1: Persistence layer (StorageService keys + readingPositionProvider) — ✅
- `StorageService`: `reading_position.translation/book/chapter` SharedPreferences keys, `saveReadingPosition()`, `saveReadingTranslation()` (translation component only), sync `lastReadingPosition` getter (`ReadingPositionRecord`).
- `database_provider.dart`: `ReadingPosition` value class + `readingPositionProvider`; `save()` debounced 400 ms (scroll fires per frame) with no-op guard; `saveTranslationOnly()` cancels any pending debounced save (it carries the old translation id) and writes through immediately, preserving book/chapter.

### Batch 2: Restore on startup — ✅
- Both reader pages' `_loadBooks()`: translation resolution is now `in-session value ?? persisted (if still installed) ?? translations.first`; the null-defaults for book/chapter use the persisted position when it is valid in the loaded book map (book exists AND chapter present in its chapterCounts), falling back to first book / first chapter otherwise. Persisted chapter is only applied together with the persisted book (never mixed with a different in-session book). Mobile re-derives `_chapterCounts` from the effective (possibly restored) book.

### Batch 3: Save on navigation & scroll — ✅
- Both pages: `_persistPosition(book, chapter)` helper; called from `_goTo`, the desktop chapter dropdown handler, and the mobile chapter-picker sheet.
- `_updateVisibleChapter` (both scroll widgets) now persists the visually-centered chapter's `(book, chapter)` alongside `visibleChapterProvider` — continuous-mode reading and cross-book drift are persisted without any tap navigation. Debounce lives in the notifier, so the per-frame listener stays cheap.
- Mobile `_updateChapterCounts` clamp also persists the clamped position (restore can never point at a chapter the translation lacks).

### Batch 4: §2 Translation pill + adaptive grid dropdown — ✅
- New shared widget `lib/features/bible/presentation/widgets/translation_grid.dart`:
  - `TranslationGrid` — adaptive `Wrap` of content-sized cells (abbreviation large/bold + full name small secondary), active translation highlighted (primaryContainer bg + primary border), each cell a focusable `InkWell` with `Semantics(button: true)`. Data from `translationRepoProvider.getInstalled()`.
  - ≤1 installed translation → single cell plus an "Install more translations" prompt navigating to `/translations`.
  - Tap handler sets `currentTranslationProvider` + `readingPositionProvider.saveTranslationOnly()` ONLY — book/chapter untouched, so 1 Kings 5 [NKJV] → NLT stays at 1 Kings 5.
  - `showTranslationGridDropdown()` — desktop anchored overlay below the pill (transparent-barrier dialog positioned from the pill's RenderBox; tap-outside dismisses). `showTranslationGridSheet()` — mobile modal bottom sheet (retained; mobile route itself remains disabled per DECISIONS.md).
- Desktop `_TopBar`: translation `TextButton` is now the pill (StadiumBorder, primaryContainer colors, expand-more icon) with semantic label "Active translation: [full name]. Tap to switch." (full name threaded from `_loadBooks()`); the old `onTranslationTap` TODO now opens the anchored grid via `_translationPillKey`.
- Content is keyed on `'$translationId|$book|$chapter|...'`, so switching translation reloads verses at the same book/chapter with no extra reload logic; `_loadBooks()` clamps only when the new translation genuinely lacks the current book/chapter.
- Fixed `ReadingPosition` ambiguous-import analyzer errors in both reader pages: `app_database.dart` (Drift row class of the same name) is now imported with `hide ReadingPosition`, so the value class from `core/providers/database_provider.dart` resolves unambiguously.

### Batch 5: Docs close-out — ✅
- PLANNED_FEATURES.md: §2 marked ✅ Done, header status updated, note added about the reading-position persistence addition and the pill preserving book/chapter.
- This work log finalized (all batches ✅).

---

## 🔨 Work Log – 2026-07-20 (§4 Collapsible Sidebar, Desktop)

Q4 answered by owner: collapsed state is **global** (not per-window).

### §4: Collapsible desktop sidebar — ✅
- `StorageService`: `sidebar.collapsed` SharedPreferences key, `sidebarCollapsed` sync getter (defaults to expanded; prefs load before runApp) + `saveSidebarCollapsed()`.
- New `lib/core/providers/sidebar_provider.dart`: `sidebarCollapsedProvider` (`Notifier<bool>`) — builds synchronously from StorageService (no flash of the wrong width on startup) and `toggle()` persists write-through.
- `app_shell.dart` `_Sidebar` → `ConsumerWidget`:
  - Chevron toggle button in the rail header (below the logo), visible in both states; tooltip "Collapse sidebar" / "Expand sidebar"; flips direction with state.
  - **Collapsed:** `minWidth: 56`, `labelType: none` (icons only), every destination icon wrapped in a `Tooltip` with its label to compensate for the hidden text.
  - **Expanded:** unchanged 80px rail with always-visible labels.
  - Content area already sits in an `Expanded` next to the rail, so it fills the freed space automatically. No animation (v1, per spec and PROJECT RULES §10).
- Docs: PLANNED_FEATURES.md §4 marked ✅ (Q4 → global); SCREEN MAP.md "Optional Collapsible Sidebar" note replaced with the implemented behaviour.

---

## 🔨 Work Log – 2026-07-20 (Translations moved off the sidebar → Settings)

Owner decision: Translations is not a primary destination — it is managed
from Settings.

- `app_shell.dart`: removed the Translations item from `_mainItems` (desktop rail; the mobile bottom bar never had it). The `/translations` route keeps the **Settings** rail item highlighted, since that is where the user came from.
- `settings_page.dart`: new "Manage Translations" tile in the **Reading** section (below Default Translation) → `context.go('/translations')`; download icon to distinguish it from the Default Translation tile.
- `translation_manager_page.dart`: AppBar now has an explicit back arrow to `/settings` (the page lost its sidebar entry, so it needs a way out; other entry points — welcome page, reader empty-state, §2 grid "install more" — keep working since the route is unchanged).
- Docs: ROUTES.md desktop nav list + SCREEN MAP.md primary-navigation tree and desktop rail list updated — Translations is now documented as a secondary screen reached from Settings.

---

## 🔨 Work Log – 2026-07-21 (§7 Search Icon + Desktop Tap-Selection Fix)

### §7: Search icon in reader header — ✅
- Desktop `_TopBar`: search `IconButton` (tooltip "Search") left of the translation pill → `context.go('/search')`.
- Mobile AppBar `actions`: same icon before the overflow menu (mobile route itself remains disabled per DECISIONS.md).
- PLANNED_FEATURES.md §7 marked ✅ Done.

### Desktop verse-action overlay now driven by verse TAP, not text selection — ✅
- Previously tapping a verse only highlighted it, while mouse text-selection (SelectionArea `onSelectionChanged`) was what showed the "Add Note" FAB — backwards per owner preference.
- `_ReaderContentState` now owns the selection set (`_selectedVerseKeys`, keyed `book|chapter|verse` — supports non-contiguous, cross-chapter selection, groundwork for §5). `_VerseTile` became stateless; tap toggles membership and reports the joined selected verses (with references, normalized text) up via `onVersesSelected` (renamed from `onTextSelected`).
- FAB shows while ≥1 verse selected; deselecting all hides it. SelectionArea kept for plain copy but no longer drives the overlay.

---

## 🔨 Work Log – 2026-07-21 (§5 Verse Selection Action Panel, Desktop)

Owner answers: same-color re-apply = toggle off / different color replaces; note = one row per selected verse (same content); Share = copy + "Copied for sharing" toast (no plugin, pub frozen); custom picker = preset shade grid (no dependency).

### Batch 1: Domain + DB — ✅
- `reader_provider.dart`: `VerseRef` value class (book/chapter/verse, value equality); `selectedVersesProvider` (`Notifier<Set<VerseRef>>`, `toggle()`/`clear()`) — selection hoisted out of `_ReaderContentState` so §5 panel and future §6 compare share it; `highlightsVersionProvider` (int counter) bumped after highlight writes so content re-fetches.
- `app_database.dart`: new DAOs `getHighlightsForChapter()` and `deleteHighlightsForVerse()`.
- `_ReaderContentState`: `_selectedVerseKeys` removed; render checks watch `selectedVersesProvider`, `_toggleVerse` goes through the notifier (joined-text report to the page unchanged). Content recreation (nav/translation switch) clears the selection post-frame, mirroring old local-state behavior.

### Batch 2: Panel widget + wiring — ✅
- New `lib/features/bible/presentation/widgets/verse_action_panel.dart`:
  - `VerseActionPanel` — floating Material card: R/G/B swatches + custom-picker slot | Save/Note/Copy/Share | Compare | ×. Tooltips + `Semantics(button:true)` throughout.
  - Preset constants `kHighlightRed/Green/Blue` (0x66 alpha), `highlightColorToHex`/`highlightColorFromHex` (`#AARRGGBB`).
  - `showHighlightColorPickerDialog()` — 18 material hues × 3 shades in a Wrap grid; returns color at 0.4 alpha. Zero new dependencies.
- `_ReaderPageState`: stub FAB replaced by the panel at `FloatingActionButtonLocation.centerFloat`, shown while ≥1 verse selected; × clears selection + hides panel.

### Batch 3: Actions — ✅
- **Highlight**: `_applyHighlight(color)` — if every selected verse already carries exactly this color → delete (toggle off); else delete existing + insert new rows (uuid, now). Bumps `highlightsVersionProvider`; `_ReaderContentState._reloadHighlights()` refreshes `_highlightsByVerse` (also run on initial load and lazy next/prev chapter loads). `_VerseTile` gained `highlightColor` — highlight bg renders when not selected; when selected, selection tint wins with a border in the highlight color.
- **Bookmark**: one `Bookmarks` row per selected verse (label null) + toast.
- **Note**: dialog (multiline TextField, Cancel/Save) → one `Notes` row per selected verse, same content + toast.
- **Copy / Share**: `Clipboard.setData` with the "Book C:V text" lines already built by the selection reporter; distinct toasts.
- **Compare**: stub toast + `// TODO(§6)`.

### Batch 4: Docs — ✅
- PLANNED_FEATURES.md §5 marked ✅ (desktop) with implementation notes; DECISIONS.md entry (selection provider, hex format, toggle semantics, share fallback, picker choice); this work log.

---

## 🔨 Work Log – 2026-07-21 (§6 Compare Panel + Full-Screen Compare, Desktop)

Owner answers this session: comparison **live-updates** with selection changes; **empty selection closes the pane**. Owner addition delivered: "open full screen" → routed screen with back navigation.

### Batch 1: Provider + DAO + CompareColumn — ✅
- `reader_provider.dart`: `compareOpenProvider` (`Notifier<bool>`).
- `app_database.dart`: `getVerse(translationId, book, chapter, verse)` → `Verse?`.
- New `lib/features/bible/presentation/widgets/compare_column.dart`: `CompareColumn(refs, bookNameFor, onClose?, onExpand?)` — installed translations sorted alphabetically by abbreviation (Q3), per-block "ABBR → Full Name" header, each selected verse as reference label + red-letter-preserving text (`normalizeResolvedScriptureText` + `buildScriptureSpans`), `Divider` between blocks; missing verse → italic "Not available in this translation."; ≤1 installed → "Install more translations" → `/translations`. Future cached keyed on the refs so it re-fetches only when the selection changes (live updates without flicker). Read-only per spec.

### Batch 2: Reader split view — ✅
- `_ReaderPageState.build()`: reader column wrapped in a `Row` when compare is visible — reader `flex: 6`, 1px divider, `CompareColumn` `flex: 4`. Pane rendered iff `compareOpen && selection.isNotEmpty` → deselecting all verses closes it; the pane's × closes it but keeps the selection (per §6 spec); the action panel's ×/content recreation also reset `compareOpenProvider` so it can't surprise-reopen.
- Compare button in the §5 panel now sets `compareOpenProvider` (stub toast removed).
- `bookNameFor` threaded from the reader's loaded `_books` (translation-independent labels).

### Batch 3: Full-screen route — ✅
- New `lib/features/bible/presentation/pages/compare_page_desktop.dart`: `ComparePageDesktop` — AppBar back arrow (`context.pop()`), title "Compare — N verses", centered ≤800px `CompareColumn` (no ×/expand). Derives book number → display name itself from the active translation's bookMap + `formatBookName(preserveOriginal: …)` (can't receive reader state through a route).
- `app_router.dart`: `/compare` route inside the ShellRoute (rail stays visible; falls back to Reader rail highlight). Opened with `context.push` from the pane's expand icon so back restores the reader with split view + selection intact.

### Batch 4: Docs — ✅
- PLANNED_FEATURES.md §6 marked ✅ (desktop) + header status; DECISIONS.md §6 entry (state model, live-update, alphabetical order, missing-verse line, push-routed full screen); CHANGELOG.md entry; this work log.

---

## 🔨 Work Log – 2026-07-21 (Settings wiring fixes + AppInfo)

Owner-reported bugs: settings not wired to the reader; fake "Clear Cache" tile; wrong hardcoded versions (settings said 1.0.42-stable, welcome said 2.4.0).

- **New `lib/core/app_info.dart`** — `AppInfo.version = '0.6.40-beta'`, single source for the version string; shown in Settings About and the Welcome page (both hardcoded strings removed). Pubspec-derived version deferred until pub deps can change.
- **New `lib/core/providers/reading_settings_provider.dart`** — `fontSizeProvider`, `showVerseNumbersProvider`, `defaultTranslationProvider` as self-loading SharedPreferences Notifiers (moved out of settings_page.dart so the reader can use them without a cross-feature import; same prefs keys, existing values carry over).
- **Reader wiring**: `_VerseTile` now takes `fontSize` + `showVerseNumber` from the providers — font-size slider and verse-numbers toggle live-update the reader.
- **Default Translation semantics fixed** (owner: fallback only): the settings tile no longer hijacks `currentTranslationProvider`; it saves `defaultTranslation` only. Reader `_loadBooks()` resolution is now in-session ?? persisted position ?? default ?? first installed. Tile subtitle explains the fallback role.
- **"Clear Cache" removed** — it faked success (500 ms delay + green snackbar, hardcoded "42.5 MB") and there is no cache to clear.
- settings_page.dart internal cleanup: dropped `_prefs`/`_isLoading`/`_version` state and the save helpers; everything reads/writes through providers.

---

## 🔨 Work Log – 2026-07-21 (BUGFIX: compare pane instantly closed)

- Opening Compare switched the Scaffold body `Column` ↔ `Row`, restructuring the tree → `_ReaderContent` state was recreated → its fresh-content callback cleared the selection (and compare state) → `compareOpen && selection.isNotEmpty` went false → pane closed on arrival (also would have silently lost scroll position).
- Fix (`reader_page_desktop.dart`): body is now always a `Row` with the reader at a stable tree position; the divider + `CompareColumn` are conditionally appended. Reader state (selection, scroll) survives opening/closing compare.

---

## 🔨 Work Log – 2026-07-21 (Search, Bookmarks, Notes screens — pre-overhaul, deliberately plain)

Owner decision: build the missing screens BEFORE the UI overhaul (function-first; overhaul becomes one visual pass over a complete app). Visual polish intentionally minimal.

### Search — ✅
- `app_database.dart`: `searchVerses(translationId, query, {limit: 200})` — case-insensitive LIKE over the active translation, canonical order, capped at 200 (LIKE wildcards stripped from input; no FTS table — ~31k rows is fine for local SQLite).
- `search_page_desktop.dart` rebuilt from stub: autofocus field, 300 ms debounce, ≥3-char minimum, stale-response guard, match text bolded in results, result count / "first 200 — refine" footer. Tap → sets translation/book/chapter providers + persists reading position + `context.go('/reader')` (chapter-level; verse-level scroll doesn't exist yet — overhaul candidate).
- Book names derived from the active translation's bookMap (ComparePageDesktop pattern); falls back to the first installed translation if the reader never ran.

### Bookmarks — ✅
- New `lib/features/bible/presentation/pages/bookmarks_page_desktop.dart`: active translation's bookmarks newest-first with verse-text previews (`getVerse`), tap → jump to chapter (same provider+persist pattern), immediate single-tap delete (UI_UX §13), empty state pointing at the reader's Save action.
- Route `/bookmarks` registered; sidebar item wired (was `route: null` → "coming soon" snackbar).

### Notes — ✅
- `app_database.dart`: `getNotesForTranslation()` (newest-updated first), `updateNoteContent(id, content, updatedAt)`, `deleteNote(id)`.
- New `lib/features/bible/presentation/pages/notes_page_desktop.dart`: note cards (reference + date + content), tap reference → jump to chapter, edit-in-place dialog, delete WITH confirmation (notes carry user-written content, unlike single-tap bookmark removal), empty state.
- Route `/notes` registered; sidebar item wired.

---

## 🔨 Work Log – 2026-07-21 (UI Overhaul — "calm study", per docs/UI_OVERHAUL.md)

Owner chose the "calm study" direction (warm paper surfaces, deep ink accent, Literata for scripture/display + Inter for UI). docs/UI_OVERHAUL.md is the design authority; supersedes DESIGN SYSTEM.md until backfilled.

### Batch 1: Tokens + theme — ✅
- New `lib/core/design/app_tokens.dart`: `AppColorsLight/Dark` + brightness-resolved `AppColors` (paper/chrome/ink/hairline/selectionWash/wordsOfChrist/danger/success), `AppSpacing` (4–64), `AppRadius`, `AppLayout` (reader 680 / content 720 / top bar 56), `AppFonts`, `AppTypography` (display/title/scripture/scriptureRef/uiLabel/uiBody/caption).
- `app_theme.dart` rebuilt: explicit ColorSchemes from tokens (no `fromSeed`); Inter app-wide with Literata opt-in; themed dividers, snackbars (floating, hairline border), dialogs, inputs, buttons (filled=ink stadium; outlined=hairline), slider/switch, tooltips.
- Theme provider deduped: `core/providers/theme_provider.dart` (unused duplicate) DELETED; its SharedPreferences persistence merged into `core/themes/theme_provider.dart` (self-loading, key `themeMode`). Debt item cleared.
- `scripture_format.dart` red-letter → `AppColors.wordsOfChrist` (brick red / soft coral, replacing #B71C1C/#EF5350).

### Batch 2: Shell + reader — ✅
- Rail: ink pill indicator (12% alpha, stadium), ink icons/labels via `caption`, width 84 expanded.
- Reader top bar: 56px chrome surface, no shadow; selectors quiet ink text; translation pill now outlined hairline + ink `scriptureRef` (was filled primaryContainer).
- Chapter header: book name in Literata 34 ink (`display`), "— CHAPTER N —" caps `scriptureRef` (was italic).
- Verse tiles: scripture token (height 1.7); selection = warm `selectionWash` + 2px ink left accent bar (replaces the pale-yellow full-tile fill and the highlight-border special case); verse numbers `scriptureRef` at 60%.
- Reading column constrained to 680px measure.
- Action panel: paperElevated + hairline ring + soft shadow.
- Compare pane sits on chrome surface next to the paper reader.
- Removed the last `0xFF2E434C` light-mode override from the reader (ink primary now comes from the theme).

### Batch 3–5: Satellites + content + peripheral — ✅
- Compare column: block headers "ABBR   Full Name" (ink caps + quiet), refs in `caption`, scripture token at 15.
- Welcome: hardcoded #2E434C/white removed → theme primary/onPrimary.
- Translation manager: all `Colors.green/orange/red` snackbars/actions → `AppColors.success/danger`; active check → ink primary; #2E434C removed.
- Settings: default-translation check → ink primary (was Colors.green).
- Search/bookmarks/notes were already theme-driven; they inherit the new tokens wholesale (inputs, snackbars, dialogs via theme).

### Batch 6: Docs — ✅ (backfill of DESIGN SYSTEM.md deferred until owner signs off on the look)
- This work log + CHANGELOG; UI_OVERHAUL.md remains ACTIVE authority.
- Owner adjustment after review: the 680px reading measure was removed — scripture is full-width (padding 32 only). `AppLayout.readerColumnWidth` token deleted; UI_OVERHAUL.md §2.4 updated.

---

## 🔨 Work Log – 2026-07-21 (v1.0.0 — MVP COMPLETE 🎉)

Owner declared the MVP complete. Sync is knowingly absent (Supabase skeleton stays disabled) and is the headline post-MVP feature. `AppInfo.version` → **1.0.0** (pubspec was already 1.0.0+1).

Final pre-release changes:

### Sidebar simplified — icons-only
- The §4 expand/collapse state removed entirely: rail is always 56px, icons + tooltips (owner: "the UI is explanatory enough"). `_Sidebar` is now a plain StatelessWidget; `core/providers/sidebar_provider.dart` deleted; `sidebar.collapsed` key + getter/setter removed from `StorageService`.

### Non-blocking bulk translation import (last UX fix)
- `TranslationRepository.importFromFile`: parsing (file read + `jsonDecode` of a whole Bible + verse-id math + book-map JSON prep) moved to a background isolate via `compute` → top-level `_parseBdatFile` returning plain-data `ParsedBdat` (parallel int/String lists across the isolate boundary). Main isolate only copies the file and does the Drift writes. Insert/update companion construction deduplicated.
- Translation Manager: batch imports show a **progress card** — overall `Importing N of M…` bar + per-file status rows (pending ⏱ / importing spinner / done ✓ / failed ✗). Imports run sequentially (DB write is the serial part), but the installed list refreshes after **each** file, so imported translations can be activated and read while the rest load. Fresh installs auto-activate the first success immediately.
- Toast policy applied: no success snackbar (the refreshed list/card is the confirmation); on failure the card stays up with failed files marked + one error snackbar. Card is dismissible once the batch ends.

### MVP scope shipped (v1.0.0)
Offline `.bdat` import · Drift/SQLite storage · reader (red-letter, highlights, verse selection/action panel) · compare (split + full-screen) · search · bookmarks · notes · translation manager · settings (theme, font size, verse numbers, default translation) · reading-position persistence · "calm study" design system. **Not in MVP:** sync, mobile-specific UI (paused per DECISIONS.md).
