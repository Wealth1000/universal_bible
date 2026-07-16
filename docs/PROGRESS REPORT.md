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