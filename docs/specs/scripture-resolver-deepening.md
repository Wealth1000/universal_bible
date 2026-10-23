# Spec: Deepen the ScriptureResolver Module

## Problem Statement

`scripture_resolver.dart` mixes a clean, well-tested pure parser (`parseScriptureReference`) with a 60-line untestable `FutureProvider.family` (`scripturePassageProvider`) that reaches into four Riverpod providers directly. It also imports `features/bible/domain/reader_provider.dart`, violating the feature-isolation rule. The resolution pipeline (translation selection cascade, JSON decoding, book-indexing, verse-range filtering) is scattered across the provider body and impossible to unit-test without mocking the entire Riverpod dependency graph.

## Solution

Introduce a `ScriptureResolver` deep module in the rhapsody feature. Its interface accepts a `BibleDataModule` adapter and a reference string, returning a `ResolvedPassage`. The pure parser stays exported. The resolution pipeline becomes a private method on the module, testable by passing a fake `BibleDataModule`. The cross-feature import from rhapsody → bible is eliminated because the resolver no longer touches `reader_provider.dart` directly — it receives the translation ID through its interface or the adapter.

## User Stories

1. As a devotional reader, I want to tap a scripture reference and see the actual verse text from my installed translation, so that I can read the passage without leaving the devotional.
2. As a devotional reader, I want the resolved passage to use my current reading translation (or fall back to my default, last position, or first installed), so that the passage matches what I'm used to reading.
3. As a devotional reader, I want references like "Proverbs 22:6" and "2 Timothy 3:14-15" to resolve correctly, including multi-verse ranges and whole-chapter references like "Psalm 83", so that any reading-plan reference works.
4. As a devotional reader, I want trailing translation codes like "NIV" to be ignored so they don't confuse the parser, so that "Psalm 23 NIV" resolves to Psalm 23.
5. As a devotional reader, I want the passage to show a helpful error message when the reference can't be parsed, the book isn't in my translation, or the chapter has no verses, so that I understand why it didn't resolve.
6. As a devotional reader, I want an "Open in reader" button after viewing a resolved passage, so that I can continue reading in the main Bible tab.
7. As a developer, I want the scripture resolution logic to be unit-testable without Flutter bindings, so that I can verify edge cases (typos, missing books, empty chapters) reliably.
8. As a developer, I want the rhapsody feature to not import from the bible feature, so that the feature-isolation rule is enforced.

## Implementation Decisions

### The seam

The seam is between `ScriptureResolver` (application layer, rhapsody feature) and `BibleDataModule` (data layer, bible feature). `ScriptureResolver` accepts a `BibleDataModule` in its constructor. It never imports `reader_provider.dart`, `database_provider.dart`, or `translation_repo_provider.dart`.

### Module interface

```dart
class ScriptureResolver {
  ScriptureResolver({required this.bibleData});

  final BibleDataModule bibleData;

  /// Pure parser — exported, tested, unchanged from current implementation.
  ParsedReference? parse(String raw);

  /// Resolves a reference string to a passage. Uses the provided translation
  /// if given, otherwise runs the cascade (current → default → persisted → first).
  Future<ResolvedPassage> resolve(String reference, {String? forcedTranslationId});
}
```

### Translation selection cascade

The current `_resolveTranslationId` reads four Riverpod providers in sequence. After deepening, `resolve()` accepts an optional `forcedTranslationId`. The view (the reveal sheet) provides it from `ref.read(currentTranslationProvider)` if available. If the view doesn't have a translation context, the resolver falls back to the cascade through `BibleDataModule.getInstalledTranslations()`.

The cascade order stays the same:
1. `forcedTranslationId` (passed by caller)
2. First installed translation (from `bibleData.getInstalledTranslations()`)

This simplifies the cascade to two steps instead of four, because the resolver no longer needs to know about `defaultTranslationProvider` or `readingPositionProvider` — those are concerns of the reader page, not the resolver.

Wait — the cascade is important for the reveal sheet to work correctly. Let me reconsider. The reveal sheet could accept the translation ID from its parent context. Or the resolver could accept a `String? currentTranslationId` parameter from the caller. The caller (the reveal sheet) has access to `currentTranslationProvider` via Riverpod. So:

```dart
// In the reveal sheet:
final currentTrans = ref.read(currentTranslationProvider);
final passage = await ref.read(scriptureResolverProvider).resolve(reference, forcedTranslationId: currentTrans);
```

This keeps the resolver testable (pass `null` for `forcedTranslationId` to test the fallback) and eliminates the provider reads from inside the resolver.

### Book-index caching

Currently the resolver rebuilds the canonical book-name → number index from `bookMapJson` on every call. After deepening, the resolver can cache this index per-translation for the lifetime of the resolver instance. `BibleDataModule.getBookInfo(translationId)` already decodes the JSON, so the resolver uses that instead of doing raw JSON manipulation.

### Provider registration

```dart
// rhapsody_providers.dart or new file
final scriptureResolverProvider = Provider<ScriptureResolver>((ref) {
  final bibleData = ref.watch(bibleDataModuleProvider);
  return ScriptureResolver(bibleData: bibleData);
});
```

### What moves

| Current location | Responsibility | New home |
|---|---|---|
| `scripture_resolver.dart` `_resolveTranslationId()` | Translation cascade | Removed — caller passes translation ID |
| `scripture_resolver.dart` `scripturePassageProvider` | Async resolution pipeline | `ScriptureResolver.resolve()` method |
| `scripture_resolver.dart` book-index JSON decoding | Canonical key building | `ScriptureResolver._buildBookIndex()` private |
| `scripture_resolver.dart` verse-range filtering | Narrow chapter to requested range | `ScriptureResolver.resolve()` internal |
| `scripture_reference_reveal.dart` `_PassageBody._openInReader` | Navigate to resolved passage | Unchanged — still uses Riverpod providers |

### What stays

- `parseScriptureReference()` — pure, exported, unchanged
- `normalizeBookKey()` — pure, exported, unchanged
- `ParsedReference`, `ResolvedPassage`, `PassageVerse`, `PassageStatus` — domain types, unchanged
- `_ScriptureRevealSheet` — presentational, unchanged except it now uses `scriptureResolverProvider` instead of `scripturePassageProvider`
- `ScriptureRefChip` — presentational, unchanged

### Files changed

| File | Action |
|---|---|
| `lib/features/rhapsody/application/scripture_resolver.dart` | **Refactor** — extract `ScriptureResolver` class, keep pure parser exported, remove `scripturePassageProvider` |
| `lib/features/rhapsody/presentation/widgets/scripture_reference_reveal.dart` | **Refactor** — use `scriptureResolverProvider` instead of `scripturePassageProvider` |
| `lib/features/rhapsody/application/rhapsody_providers.dart` | Add `scriptureResolverProvider` |
| `test/features/rhapsody/application/scripture_resolver_test.dart` | **Create** — test parser + resolver with fake `BibleDataModule` |

## Testing Decisions

### What makes a good test

Tests verify the external behavior of `ScriptureResolver`: parsing accuracy, resolution outcomes for various statuses (ok, unparseable, bookNotFound, noVerses, noTranslation), and the verse-range narrowing logic. Tests use a fake `BibleDataModule` that returns controlled data — no Flutter, no database, no providers.

### Which modules will be tested

- `ScriptureResolver.parse()` — pure function, existing tests in `scripture_resolver_test.dart` stay and cover this
- `ScriptureResolver.resolve()` — new tests with `FakeBibleDataModule` covering all `PassageStatus` outcomes

### Prior art

`test/features/rhapsody/application/scripture_resolver_test.dart` already tests `parseScriptureReference` and `normalizeBookKey`. The new resolver tests extend this pattern with a fake data module, similar to `test/features/bible/data/bible_data_module_test.dart`.

## Out of Scope

- Changing the reveal sheet UI or behavior
- Adding new reference formats beyond what the parser already supports
- Making the resolver cache-aware across translations (caching is per-resolver-instance)
- Testing the Flutter widget tree for the reveal sheet
- Removing the `rhapsodyDailyEntryProvider` placeholder (separate concern)

## Further Notes

- The `bibleDataModuleProvider` is already registered in `lib/features/bible/domain/reader_session_provider.dart`. The rhapsody feature imports it from there. This is a deliberate cross-feature dependency on the data layer only — the rhapsody feature depends on `BibleDataModule` (data), not on `reader_provider.dart` (domain).
- The `ParsedReference` and `ResolvedPassage` types stay in `scripture_resolver.dart` since they're part of the resolver's domain, not the bible feature's domain.
- The "Open in reader" action in the reveal sheet still uses `currentTranslationProvider`, `currentBookProvider`, `currentChapterProvider` from the bible domain — this is acceptable because the view layer can access any provider; the seam is about the *module*, not the view.
