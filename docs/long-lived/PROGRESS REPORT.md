# 🚀 Bible Project – Progress Report

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
