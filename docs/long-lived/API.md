# API

Concise surface reference for services, repositories, providers, and routes.
Feed this to Aider as `--read` when editing code that touches these.

## AppDatabase — `lib/database/app_database.dart`

Drift, `schemaVersion 1`. Tables: `translations`, `verses` (indexed on translationId+bookNumber+chapter), `notes`, `highlights`, `bookmarks`, `reading_positions`.

```dart
// Translations
Future<void> upsertTranslation(TranslationsCompanion t);      // insertOnConflictUpdate
Future<Translation?> getTranslation(String id);
Future<List<Translation>> getInstalledTranslations();         // installed == true

// Verses
Future<void> insertVerse(VersesCompanion v);
Future<void> insertVerses(List<VersesCompanion> vs);          // batch
Future<List<Verse>> getVersesForChapter(String translationId, int bookNumber, int chapter); // ordered
Future<Map<int, String>> getVerseMap(String translationId);   // verseId -> text, whole translation

// Notes / Highlights / Bookmarks
Future<void> insertNote(NotesCompanion n);
Future<List<Note>> getNotesForVerse(String tId, int book, int chapter, int verse);
Future<void> insertHighlight(...); Future<void> deleteHighlight(String id);
Future<List<Highlight>> getHighlightsForVerse(...);
Future<void> insertBookmark(...); Future<void> deleteBookmark(String id);
Future<List<Bookmark>> getBookmarksForTranslation(String tId);

// Reading position
Future<void> upsertReadingPosition(ReadingPositionsCompanion c);
Future<ReadingPosition?> getReadingPosition(String translationId);
```

## TranslationRepository — `lib/features/bible/data/repositories/translation_repository.dart`

```dart
TranslationRepository(AppDatabase db);
Future<List<Translation>> getInstalled();
Future<Translation?> get(String id);
Future<void> importFromFile(String filePath);       // parse .bdat -> copy -> insert verses -> metadata
Future<void> downloadAndImport(String translationId);
// NOTE: no delete() yet (TODO — translation_manager_page.dart:150)
```

## TranslationDownloadService — `lib/services/download_service.dart`

```dart
TranslationDownloadService(SupabaseClient client);
Future<List<String>> listAvailableTranslations();   // *.bdat names in public 'Bibles' bucket
Future<String> download(String fileName);           // -> <baseDir>/downloads/<fileName>
```

## SyncService — `lib/services/sync_service.dart` (DISABLED — not wired in main.dart)

```dart
SyncService({required AppDatabase local, required SupabaseBibleRepository remote});
Future<void> syncAll();  // translations + notes implemented (pull-only);
                         // highlights/bookmarks/readingPositions are TODO stubs
```

## SupabaseBibleRepository — `lib/services/supabase/bible_repository.dart`

All methods scoped to `auth.currentUser!.id` — **throws if unauthenticated**.

```dart
upsertTranslation({id, name, languageCode, version, description?, filePath?});
fetchUserTranslations();
upsertNote({id?, translationId, bookNumber, chapter, verse, content});  // UUIDv4 if id null
deleteNote(id);  fetchNotesSince(DateTime since);
upsertHighlight(...); deleteHighlight(id);
upsertBookmark(...);  deleteBookmark(id);
upsertReadingPosition({translationId, bookNumber, chapter, scrollOffset?});
fetchReadingPosition(translationId);
```

## StorageService — `lib/core/services/storage_service.dart`

Manual singleton: `StorageService()`.

```dart
Future<void> init();                       // load base dir from prefs or ~/Documents/universal_bible
Future<void> setBaseDirectory(String p);   // setting only — does NOT move files
Future<void> ensureSubDirs();
String get baseDir; databasePath; translationsDir; downloadsDir; logsDir;
```

## Riverpod providers

| Provider | Type | File | Exposes |
|---|---|---|---|
| `currentTranslationProvider` | `NotifierProvider<_, String?>` | `features/bible/domain/reader_provider.dart` | active translation id, `.set(id)` |
| `currentBookProvider` | `NotifierProvider<_, int?>` | same | current book number |
| `currentChapterProvider` | `NotifierProvider<_, int?>` | same | current chapter |
| `preserveOriginalBookNamesProvider` | `NotifierProvider<_, bool>` | `features/settings/domain/book_name_settings_provider.dart` | book-name preference, persists to prefs |
| `databaseProvider` | `Provider<AppDatabase>` | `core/providers/database_provider.dart` | AppDatabase instance |
| `syncStatusProvider` | `NotifierProvider<_, SyncStatus>` | `core/providers/sync_status_provider.dart` | `{idle, syncing, success, error}` |
| `supabaseClientProvider` | `Provider<SupabaseClient>` | `core/providers/supabase_provider.dart` | Supabase client |
| `authStateProvider` | `StreamProvider<AuthState>` | same | auth changes |
| `themeProvider` / `themeDataProvider` | Notifier / Provider | `core/themes/theme_provider.dart` | ⚠️ duplicated in `core/providers/theme_provider.dart`; app.dart uses the `core/themes/` one |
| `fontSizeProvider` | `NotifierProvider<_, double>` | `features/settings/presention/pages/settings_page.dart` | reader font size (note: "presention" typo is the real path) |
| `_translationRepoProvider` | private `Provider<TranslationRepository>` | ⚠️ copy-pasted in 5 files (router + both readers + settings + translation manager) | |

## Routes — `lib/core/routing/app_router.dart`

Redirect at `/`: installed translations exist → `/reader`, else → `/welcome`.

| Path | Page |
|---|---|
| `/welcome` | WelcomePage |
| `/login` | LoginPage |
| `/reader` | ReaderPageDesktop |
| `reader_mobile` ⚠️ (missing leading `/`) | ReaderPageMobile |
| `/translations` | TranslationManagerPage |
| `/settings` | SettingsPage |

Documented in ROUTES.md but **not implemented yet**: `/search`, `/bookmarks`, `/notes`, `/about`, `/downloads`, `/profile`, `/reader/:book/:chapter/:verse` deep links.

## Supabase remote tables

`bible_translations`, `bible_notes`, `bible_highlights`, `bible_bookmarks`, `bible_reading_positions` — all with `user_id` RLS scoping. Storage bucket: `Bibles` (public, holds `.bdat` files). Schema files: `supabase/` at project root.

---

*Update this file whenever a public method, provider, or route is added/changed.*
