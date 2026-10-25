# Universal Bible

An offline-first desktop Bible application built with Flutter. Universal Bible keeps scripture reading, personal study tools, and daily devotionals on your machine — no accounts, no cloud sync, and no network required to read.

The project prioritizes clarity, performance, and long-term maintainability over feature bloat.

---

## What It Does

- **Continuous scripture reading** — scroll seamlessly from chapter to chapter and book to book in a distraction-free layout. The header follows your position as you read, and loaded chapters are trimmed as you go so memory stays bounded during long reading sessions.
- **Multiple translations** — import translations from `.bdat` files and switch between them instantly. All scripture is stored locally in SQLite and available offline.
- **Verse comparison** — select verses and read them side-by-side across every installed translation, in a split pane or full screen.
- **Search** — full-text verse search across a single translation or all installed translations at once, with results badged by translation and matches highlighted inline.
- **Study tools** — verse highlighting, bookmarks, and verse-attached notes. Your reading position is remembered per translation, so you return exactly where you left off.
- **Daily devotionals** — Rhapsody of Realities devotionals with readable formatting and tappable scripture references that resolve to the passage in your own translations.
- **Comfort options** — red-letter words of Christ, light/dark/system themes, adjustable font size and zoom, inline verse numbers, and full or canonical book names.

### Privacy

All scripture, notes, highlights, bookmarks, and reading positions are stored in a local database on your device. There are no user accounts and no data leaves your machine. The only network usage is fetching devotional content from a public Supabase endpoint (using a publishable key — no authentication involved).

---

## Platform & Tech Stack

| Area | Choice |
| --- | --- |
| **Framework** | Flutter (desktop) |
| **Targets** | Linux, Windows |
| **State management** | Riverpod |
| **Navigation** | go_router |
| **Local database** | Drift (SQLite) |
| **Preferences** | SharedPreferences |
| **Devotional content** | Supabase (public content, publishable key only) |

---

## Project Structure

```
lib/
├── core/                  # Shared providers, utils, routing, app shell, design tokens
│   ├── database/          # Drift database, tables, DAOs (via lib/database)
│   └── providers/         # Database, translation repo, reading settings
├── database/              # Schema: translations, verses, notes, highlights,
│                          # bookmarks, reading positions
├── features/
│   ├── bible/             # Reader, chapter navigation, selection, compare view
│   ├── rhapsody/          # Daily devotional: fetch, parse, scripture resolution
│   ├── search/            # Multi-translation verse search
│   ├── settings/          # Appearance, reading, and data preferences
│   └── translation_manager/ # Import, inspect, and remove translations
└── main.dart
```

Translation data is imported from `.bdat` files (parsed on a background isolate), with verses indexed by `book × 1,000,000 + chapter × 1,000 + verse` for fast chapter lookups.

---

## Getting Started

### Prerequisites

- **Flutter** — stable channel (SDK constraint as defined in `pubspec.yaml`)
- **Dart** — 3.x
- **Platform SDK** — Linux GTK development libraries, or the Windows SDK

### Setup

1. Clone the repository and install dependencies:

   ```sh
   flutter pub get
   ```

2. Create a `.env` file in the repository root with the Supabase credentials used for devotional content:

   ```
   SUPABASE_URL=...
   SUPABASE_PUBLISHABLE_KEY=...
   ```

   These keys are public by design (publishable key, no auth). `.env` is git-ignored; see `.env.example`.

   > The app requires this file at startup (Supabase initializes at boot for devotional content). Everything else — reading, study tools, search — runs fully offline once a translation is installed.

3. Run the app:

   ```sh
   flutter run -d linux    # or -d windows
   ```

4. Import a `.bdat` translation from **Settings → Manage Translations** and start reading.

### Development

```sh
flutter analyze   # Static analysis (kept clean)
flutter test      # Unit tests: book-name parsing, chapter navigation,
                  # scripture formatting, reference parsing, devotional parsing
```

---

## Design Principles

- **Offline-first** — no reading or study functionality depends on network access
- **Local data ownership** — everything the app stores stays on your device
- **Minimal but complete** — focused feature set, no bloat
- **Modular architecture** — feature-first layout with shared code in `core/`
- **Measured performance** — bounded memory in continuous reading, background-isolate imports, single-query highlight loads

---

## License

Private / personal use. See repository or author for terms.
