# GLOSSARY

Domain terms for universal_bible. Feed this to the AI so it doesn't guess.

## File format & data model

- **BDAT / `.bdat` file** — A Bible translation package. Despite the name it is **JSON, not binary** (read with `readAsString` + `jsonDecode`). Distributed via the public Supabase Storage bucket `Bibles`, or imported from local files via file_picker.
- **BibleBdat** — In-memory model of a parsed `.bdat` (`lib/features/bible/data/models/bible_bdat.dart`). Fields: `text` (verseId→verse text, may contain raw HTML), `footnotes`, `titles`, `bookMap`, `info` (abbreviation, name, language, version, description). `fromJson` is lenient — tolerates missing sections.
- **verseId** — Integer encoding of a verse location: `book*1_000_000 + chapter*1_000 + verse`. Decode: `book = id ~/ 1000000`, `chapter = (id % 1000000) ~/ 1000`, `verse = id % 1000`. Used as string keys in `BibleBdat.text`.
- **Translation** — A Bible version/edition (e.g. KJV). Row in the Drift `translations` table keyed by `id` (uppercase abbreviation). Carries `installed` flag, `filePath`, and three JSON blobs: `bookMapJson`, `bookDisplayNamesJson`, `bookChapterCountsJson`.
- **Installed translation** — A translation whose verses were imported into the local `verses` table and whose `.bdat` was copied to `<baseDir>/translations/<ID>.bdat`; `installed=true`.
- **bookMap** — Map from raw book key (concatenated lowercase title, e.g. `"thefirstbookofmosescalledgenesis"`) to book number. Comes from the `.bdat`, stored as `bookMapJson`.
- **bookChapterCounts** — Map `bookNumber → {chapter: verseCount}`, computed at import, stored as `bookChapterCountsJson` so navigation never has to query the verses table.

## Book names

- **Book name cleaning** — Raw `.bdat` book keys are full concatenated titles. `lib/core/utils/book_name_utils.dart` segments them: `cleanBookName` → short canonical ("1 Corinthians"), `preserveBookName` → reconstructed original title. Display names are precomputed at import.
- **preserveOriginalBookNames** — User setting (SharedPreferences key `preserveOriginalBookNames`, default false): original full titles vs short canonical names. Exposed by `preserveOriginalBookNamesProvider`.

## User data

- **Reading position** — Per-translation "where I left off": `(translationId PK, bookNumber, chapter, scrollOffset, updatedAt)`. **Not yet wired** — reader always starts at Genesis 1:1.
- **Highlight** — Per-verse colored marker (`color` is a string like `'yellow'`). UI actions still stubs.
- **Bookmark** — Saved verse reference with optional label. UI actions still stubs.
- **Note** — Free-text note on a verse (UUID id, content, createdAt/updatedAt).

## Sync

- **Sync** — Local-first: Drift DB is source of truth; `SyncService` pulls remote → local. Only translations metadata + notes implemented; highlights/bookmarks/reading-positions are TODO stubs. **Currently disabled** (wiring commented out in `main.dart`).
- **SyncStatus** — enum `{idle, syncing, success, error}` via `syncStatusProvider`.
- Remote tables are prefixed `bible_`: `bible_translations`, `bible_notes`, `bible_highlights`, `bible_bookmarks`, `bible_reading_positions`. All queries filter by `user_id`.

## Rendering

- **Words of Christ / red-letter** — `.bdat` text marks Jesus' words with `<span class='Isus'>`. `scripture_format.dart` converts these → `<J>` tags → Unicode private-use sentinels (U+E000/U+E001) that survive HTML stripping; `buildScriptureSpans()` renders them theme-aware red.
- **Scripture normalization** — `normalizeResolvedScriptureText()` strips raw HTML (`<br>`, `<p>`, `<i>`, `<span>`, entities) from `.bdat` text before rendering.

## Storage & screens

- **Base directory** — User-configurable root for all app data (default `~/Documents/universal_bible/`), managed by the `StorageService` singleton. Contains `bible_app.db`, `translations/`, `downloads/`, `logs/`. Changing it does NOT move existing files.
- **Translation Manager** — Screen at `/translations`: list installed translations, import (multi-file picker), activate, delete (repo delete is TODO).
- **Current translation/book/chapter** — Reader session state: three nullable Notifier providers in `reader_provider.dart`. Not persisted.
