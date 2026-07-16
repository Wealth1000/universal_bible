# DECISIONS

Why things are the way they are. Small models rely on this — keep it current.
Format: **Decision** → rationale. Newest at the bottom of each section.

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

## Storage & config

- **User data lives in a visible folder** (default `~/Documents/universal_bible/`) — "user data belongs to the user." Base dir changeable in settings; changing it does not migrate existing files (known limitation).
- **`.env` via flutter_dotenv, bundled as an asset.** Ships only `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY` (publishable key is safe to bundle). Loaded in `main()` before `Supabase.initialize`.

## Platforms

- **Targets now: Linux, Windows, Android.** macOS/iOS/Web later. Desktop-first personal-use app.

## Known debt (decided to defer, not forgotten)

- Duplicate theme provider files (`lib/core/themes/theme_provider.dart` vs `lib/core/providers/theme_provider.dart`) — consolidate to one.
- Private `_translationRepoProvider` copy-pasted in 5 files — hoist into a shared provider.
- `features/settings/presention/` directory is a typo ("presention") — rename when convenient.
- `reader_mobile` route lacks a leading slash in `app_router.dart`.
- Welcome page hardcodes "Version 2.4.0" — should read from pubspec.

---

*Rule: after any cloud-AI consultation or significant design choice, add the outcome here immediately.*
