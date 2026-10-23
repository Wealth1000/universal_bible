# Spec: Extract Cross-Cutting Concerns to Core

## Problem Statement

The feature-isolation rule ("features must not import each other") is violated in two places:
1. Five bible presentation pages import `features/settings/domain/book_name_settings_provider.dart` (`reader_page_desktop.dart`, `compare_page_desktop.dart`, `bookmarks_page_desktop.dart`, `notes_page_desktop.dart`, `search_page_desktop.dart`).
2. Three rhapsody files import `features/bible/domain/reader_provider.dart` (`rhapsody_screen.dart`, `scripture_reference_reveal.dart`, `scripture_resolver.dart`).

These imports exist because the settings provider and the bible reader provider are effectively cross-cutting infrastructure — they're needed by code outside their declaring feature. Treating them as feature-local code forces every consumer to reach across features, breaking the isolation guarantee.

## Solution

Move the two cross-cutting concerns into `lib/core/` as genuine cross-cutting infrastructure:

1. **`PreserveOriginalBookNamesNotifier`** → move to `lib/core/providers/book_name_settings_provider.dart`
2. **Reader domain notifiers** (`CurrentTranslationNotifier`, `CurrentBookNotifier`, `CurrentChapterNotifier`, `VisibleLocationNotifier`, `SelectedVersesNotifier`, `CompareOpenNotifier`, `HighlightsVersionNotifier`, `VerseRef`) → stay in `lib/features/bible/domain/reader_provider.dart` but create a re-export or move to `lib/core/providers/reader_state_provider.dart`

For item 2, the rhapsody feature only uses `currentTranslationProvider`, `currentBookProvider`, and `currentChapterProvider` (for navigation after resolving a passage). Rather than moving all seven notifiers, introduce a minimal `lib/core/providers/reader_navigation_provider.dart` that exports only the three navigation notifiers. The rhapsody feature imports from `core/` instead of `features/bible/domain/`.

## User Stories

1. As a developer, I want the feature-isolation rule to be enforceable, so that adding a new feature doesn't require touching existing features' domain code.
2. As a developer, I want cross-cutting settings to live in `core/`, so that any feature can access them without creating a dependency chain.
3. As a developer, I want the rhapsody feature to not depend on the bible feature's domain, so that the two features can be developed and tested independently.
4. As a reader, I want my book-name formatting preference to apply consistently across all screens (reader, bookmarks, notes, search, compare), so that my choice is respected everywhere.
5. As a devotional reader, I want "Open in reader" to navigate correctly regardless of which feature I'm coming from, so that the navigation feels seamless.

## Implementation Decisions

### Decision 1: Move `PreserveOriginalBookNamesNotifier` to core

**From:** `lib/features/settings/domain/book_name_settings_provider.dart`
**To:** `lib/core/providers/book_name_settings_provider.dart`

The file moves wholesale. The old path gets a re-export for backward compatibility during a transition period (one release cycle), then the re-export is removed.

```dart
// lib/features/settings/domain/book_name_settings_provider.dart (transitional)
export 'package:universal_bible/core/providers/book_name_settings_provider.dart';
```

All five bible presentation files update their import to point to `core/providers/`.

### Decision 2: Create a minimal reader-navigation provider in core

**From:** `lib/features/bible/domain/reader_provider.dart` (all seven notifiers)
**To:** `lib/core/providers/reader_navigation_provider.dart` (three notifiers only)

The new core file exports only what rhapsody needs:
- `currentTranslationProvider`
- `currentBookProvider`
- `currentChapterProvider`

Plus `ChapterRef` from `chapter_navigation.dart` (also move or re-export).

The original `reader_provider.dart` re-exports from core:

```dart
// lib/features/bible/domain/reader_provider.dart (after)
export 'package:universal_bible/core/providers/reader_navigation_provider.dart'
    show currentTranslationProvider, currentBookProvider, currentChapterProvider;
export 'package:universal_bible/features/bible/domain/reader_provider.dart'
    show SelectedVersesNotifier, CompareOpenNotifier, HighlightsVersionNotifier, VerseRef;
// Or: keep everything here and have core import from here (circular — avoid)
```

Actually, a cleaner approach: keep all notifiers in `reader_provider.dart` but have the rhapsody feature import from `core/` via a focused re-export. The rhapsody feature imports `core/providers/reader_navigation_provider.dart` which re-exports only the three navigation providers from the bible domain. This is a one-way dependency: core → bible domain. Wait, that's backwards.

Let me reconsider. The cleanest approach that respects the "features must not import each other" rule:

**Move the three navigation notifiers to `core/`:**
```
lib/core/providers/reader_navigation_provider.dart
  - CurrentTranslationNotifier
  - CurrentBookNotifier
  - CurrentChapterNotifier
  - ChapterRef (from chapter_navigation.dart — also move or keep and re-export)
  - Providers: currentTranslationProvider, currentBookProvider, currentChapterProvider
```

**Keep the remaining notifiers in `features/bible/domain/reader_provider.dart`:**
```
  - VisibleLocationNotifier
  - SelectedVersesNotifier
  - CompareOpenNotifier
  - HighlightsVersionNotifier
  - VerseRef
  - Providers: visibleLocationProvider, selectedVersesProvider, compareOpenProvider, highlightsVersionProvider
```

**The bible domain file re-exports the core navigation providers for its own use:**
```dart
// lib/features/bible/domain/reader_provider.dart
export 'package:universal_bible/core/providers/reader_navigation_provider.dart'
    show currentTranslationProvider, currentBookProvider, currentChapterProvider;
// ... rest of the bible-domain-only notifiers
```

**Rhapsody imports from core:**
```dart
import 'package:universal_bible/core/providers/reader_navigation_provider.dart';
```

This way:
- `core/` owns the navigation notifiers (they're truly cross-cutting)
- The bible feature can still use them (it re-exports from core)
- The rhapsody feature imports from core, not from the bible feature
- No circular dependencies

### Decision 3: Move `ChapterRef` to core

`ChapterRef` is used by both the bible feature (domain) and the rhapsody feature (via the reveal sheet's "Open in reader" navigation). Move it to `lib/core/navigation/chapter_ref.dart`.

### Files changed

| File | Action |
|---|---|
| `lib/core/providers/book_name_settings_provider.dart` | **Create** — moved from `features/settings/domain/` |
| `lib/core/providers/reader_navigation_provider.dart` | **Create** — three navigation notifiers + ChapterRef |
| `lib/core/navigation/chapter_ref.dart` | **Create** — moved from `features/bible/domain/chapter_navigation.dart` |
| `lib/features/settings/domain/book_name_settings_provider.dart` | **Replace with re-export** (transitional) |
| `lib/features/bible/domain/reader_provider.dart` | **Refactor** — remove the three navigation notifiers, re-export from core |
| `lib/features/bible/domain/chapter_navigation.dart` | Remove `ChapterRef` (now in core), keep `nextChapterRef`, `prevChapterRef`, `bookNameFor` |
| `lib/features/bible/presentation/pages/reader_page_desktop.dart` | Update imports to `core/providers/` |
| `lib/features/bible/presentation/pages/compare_page_desktop.dart` | Update imports to `core/providers/` |
| `lib/features/bible/presentation/pages/bookmarks_page_desktop.dart` | Update imports to `core/providers/` |
| `lib/features/bible/presentation/pages/notes_page_desktop.dart` | Update imports to `core/providers/` |
| `lib/features/search/presentation/pages/search_page_desktop.dart` | Update imports to `core/providers/` |
| `lib/features/rhapsody/presentation/rhapsody_screen.dart` | Update imports to `core/providers/` |
| `lib/features/rhapsody/presentation/widgets/scripture_reference_reveal.dart` | Update imports to `core/providers/` |
| `lib/features/rhapsody/application/scripture_resolver.dart` | Update imports to `core/providers/` (if it still uses any bible domain) |

## Testing Decisions

### What makes a good test

Tests verify that the moved notifiers behave identically after the move — same state transitions, same persistence keys. Since the notifiers are identical in behavior (just relocated), the existing tests should continue to pass with updated import paths. No new behavioral tests are needed.

### Which modules will be tested

- The moved notifiers (`CurrentTranslationNotifier`, `CurrentBookNotifier`, `CurrentChapterNotifier`, `PreserveOriginalBookNamesNotifier`) — existing tests should pass with updated imports
- `ChapterRef` — if it had any tests, they move with it

### Prior art

The existing test structure in `test/features/bible/domain/chapter_navigation_test.dart` and `test/core/utils/` covers the pure functions. The notifiers don't have dedicated tests yet (they're integration-level); this spec doesn't add new tests, just relocates existing ones.

## Out of Scope

- Moving `VisibleLocationNotifier`, `SelectedVersesNotifier`, `CompareOpenNotifier`, `HighlightsVersionNotifier` to core — these are reader-specific and shouldn't be cross-cutting
- Moving `VerseRef` to core — it's a bible-domain concept
- Removing the transitional re-exports in `features/settings/domain/` — that's a follow-up cleanup
- Moving `FontSizeNotifier`, `ShowVerseNumbersNotifier`, `DefaultTranslationNotifier` to core — these are already in `core/providers/reading_settings_provider.dart` and are correctly placed
- Addressing the `rhapsody_screen.dart` → `reader_provider.dart` import beyond what's needed for navigation

## Further Notes

- This spec is the lowest-leverage of the three remaining candidates. It's primarily about maintaining the feature-isolation invariant rather than improving testability or depth.
- The `ChapterRef` move is the most consequential change — it's used by scroll-tracking, navigation, and the reveal sheet. Ensure all call sites are updated.
- After this spec lands, the feature-isolation rule becomes: "features can import from core, but not from each other." This is the intended invariant.
- Combined with the ScriptureResolver spec (Candidate 4), this fully eliminates all cross-feature imports in the codebase.
