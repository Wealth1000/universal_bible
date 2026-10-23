# Spec: Abstract the Persistence Seam

## Problem Statement

Seven Riverpod notifiers (`ReadingPositionNotifier`, `FontSizeNotifier`, `ShowVerseNumbersNotifier`, `DefaultTranslationNotifier`, `ContinuousReadingNotifier`, `ThemeNotifier`, `PreserveOriginalBookNamesNotifier`) all call `StorageService()` or `SharedPreferences.getInstance()` directly inside their `build()` and `set()` methods. This makes every notifier untestable without the Flutter binding and prevents swapping in a test persistence layer. The singleton pattern also means tests share state across the process.

## Solution

Introduce a `PersistenceAdapter` interface at the seam between notifiers and storage. The prod adapter wraps `StorageService` / `SharedPreferences`. The test adapter uses an in-memory map. Notifiers accept the adapter via constructor injection (Riverpod `Family` provider or explicit constructor param). All notifiers share the same interface — one seam, seven callers.

## User Stories

1. As a developer, I want to test a notifier with an in-memory persistence layer, so that I can verify state transitions without Flutter bindings.
2. As a developer, I want all persistence logic centralized in one adapter, so that key names and formats are defined in a single place.
3. As an app user, I want my reading position to persist across app restarts, so that I can resume where I left off.
4. As an app user, I want my font-size preference to persist, so that I don't have to re-set it every time I open the app.
5. As an app user, I want my theme preference to persist, so that the app remembers my dark/light choice.
6. As an app user, I want my continuous-reading preference to persist, so that the reader opens in my preferred mode.
7. As an app user, I want my verse-number display preference to persist, so that I don't have to re-toggle it.
8. As an app user, I want my default translation to persist, so that fresh installs open in my preferred translation.
9. As an app user, I want my book-name formatting preference to persist, so that my chosen format sticks across sessions.
10. As a developer, I want notifiers to be instantiable without any Flutter or platform dependency, so that they can be unit-tested in isolation.

## Implementation Decisions

### The seam

A new interface `PersistenceAdapter` in `lib/core/persistence/persistence_adapter.dart`:

```dart
abstract class PersistenceAdapter {
  Future<String?> getString(String key);
  Future<bool?> getBool(String key);
  Future<int?> getInt(String key);
  Future<void> setString(String key, String value);
  Future<void> setBool(String key, bool value);
  Future<void> setInt(String key, int value);
}
```

Two adapters implement it:
- **`SharedPreferencesPersistenceAdapter`** — wraps `StorageService()._prefs` (or calls `SharedPreferences.getInstance()` lazily on first access)
- **`InMemoryPersistenceAdapter`** — a plain `Map<String, dynamic>` for tests

### Notifier refactoring

Each notifier is refactored to accept a `PersistenceAdapter` in its constructor:

```dart
class FontSizeNotifier extends Notifier<double> {
  FontSizeNotifier(this._persistence);
  final PersistenceAdapter _persistence;
  // ... build() and set() use _persistence instead of SharedPreferences.getInstance()
}
```

Riverpod providers use a `Family` or a shared provider for the adapter:

```dart
final persistenceAdapterProvider = Provider<PersistenceAdapter>((ref) {
  return SharedPreferencesPersistenceAdapter();
});

final fontSizeProvider = NotifierProvider.family<FontSizeNotifier, double, PersistenceAdapter>(
  (ref, adapter) => FontSizeNotifier(adapter),
);
```

Or more simply, since all notifiers share the same adapter, provide it once and have each notifier take it:

```dart
final fontSizeProvider = NotifierProvider<FontSizeNotifier, double>(
  () => FontSizeNotifier(StorageServicePersistenceAdapter()),
);
```

The `StorageServicePersistenceAdapter` is a thin wrapper around `StorageService()._prefs`. For tests, pass an `InMemoryPersistenceAdapter` directly.

### Key management

All persistence key strings move from individual notifiers into the adapter or a central constants file. This eliminates the duplication where each notifier hard-codes its own key.

### ReadingPositionNotifier special case

`ReadingPositionNotifier` currently creates a `ReadingPosition` from `StorageService().lastReadingPosition` in its `build()`. After this change, it reads from the `PersistenceAdapter` directly. The `ReadingPosition` model stays in `core/providers/database_provider.dart` — it's a domain type, not a persistence detail.

### Files changed

| File | Action |
|---|---|
| `lib/core/persistence/persistence_adapter.dart` | **Create** — interface + two implementations |
| `lib/core/providers/reading_settings_provider.dart` | Refactor — inject adapter |
| `lib/core/themes/theme_provider.dart` | Refactor — inject adapter |
| `lib/features/bible/domain/continuous_reading_provider.dart` | Refactor — inject adapter |
| `lib/features/settings/domain/book_name_settings_provider.dart` | Refactor — inject adapter |
| `lib/core/providers/database_provider.dart` | Refactor — inject adapter into `ReadingPositionNotifier` |
| `test/core/persistence/` | **Create** — tests for both adapters |
| `test/core/providers/` | **Create** — notifier tests with in-memory adapter |

## Testing Decisions

### What makes a good test

Tests verify that a notifier reads its initial value from the adapter and writes updates back through it — no Flutter binding, no SharedPreferences, no StorageService. A test creates an `InMemoryPersistenceAdapter`, injects it into the notifier, asserts on provider state, calls `set()`, and asserts the adapter received the right key/value.

### Which modules will be tested

- `PersistenceAdapter` (both implementations) — basic get/set round-trip
- Each notifier — initial value from adapter, update persistence, correct key names

### Prior art

The existing `book_name_utils_test.dart` and `scripture_format_test.dart` follow the same pattern: pure functions tested in isolation with no framework dependencies. This extends the pattern to stateful notifiers by injecting the adapter.

## Out of Scope

- Migrating `StorageService` itself to be provided through Riverpod (it's a singleton today and the notifiers are the only consumers; making it a provider is a larger restructuring)
- Adding new persistence keys
- Testing the Flutter widget tree — this spec only addresses unit-testability of notifiers
- Removing the `ReadingPositions` Drift table (already done in the BibleDataModule spec)

## Further Notes

- The `SharedPreferencesPersistenceAdapter` lazily initializes `SharedPreferences.getInstance()` on first access (not on construction) to match the current behavior of the notifiers.
- The `InMemoryPersistenceAdapter` uses a `Map<String, Object>` internally. `getBool`, `getInt`, `getString` all work correctly with type-safe casting.
- This spec does NOT touch `TranslationRepository` or `BibleDataModule` — those were handled in separate deepening specs.
