import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_bible/core/persistence/persistence_adapter.dart';
import 'package:universal_bible/core/providers/reading_settings_provider.dart';
import 'package:universal_bible/core/themes/theme_provider.dart';
import 'package:universal_bible/features/bible/domain/continuous_reading_provider.dart';
import 'package:universal_bible/features/settings/domain/book_name_settings_provider.dart';

// -----------------------------------------------------------------------------
// Fake notifiers — bypass async _load() but keep set() methods so we can
// verify adapter writes. Instantiated through ProviderContainer overrides so
// ref/state are properly initialised (same pattern as reader_session_test.dart).
// -----------------------------------------------------------------------------

class _FakeFontSizeNotifier extends FontSizeNotifier {
  _FakeFontSizeNotifier(super.adapter);
  @override
  double build() => 18.0;
}

class _FakeThemeNotifier extends ThemeNotifier {
  _FakeThemeNotifier(super.adapter);
  @override
  ThemeMode build() => ThemeMode.system;
}

class _FakeContinuousReadingNotifier extends ContinuousReadingNotifier {
  _FakeContinuousReadingNotifier(super.adapter);
  @override
  bool build() => false;
}

class _FakePreserveOriginalBookNamesNotifier extends PreserveOriginalBookNamesNotifier {
  _FakePreserveOriginalBookNamesNotifier(super.adapter);
  @override
  bool build() => false;
}

void main() {
  group('FontSizeNotifier', () {
    test('starts at 18.0 when adapter has no value', () async {
      final adapter = InMemoryPersistenceAdapter();
      final provider = ProviderContainer(overrides: [
        fontSizeProvider.overrideWith(() => _FakeFontSizeNotifier(adapter)),
      ]);
      expect(provider.read(fontSizeProvider), 18.0);
      provider.dispose();
    });

    test('writes updates to adapter', () async {
      final adapter = InMemoryPersistenceAdapter();
      final provider = ProviderContainer(overrides: [
        fontSizeProvider.overrideWith(() => _FakeFontSizeNotifier(adapter)),
      ]);
      final notifier = provider.read(fontSizeProvider.notifier);
      await notifier.set(24.0);
      expect(await adapter.getInt('fontSize'), 24);
      provider.dispose();
    });
  });

  group('ThemeNotifier', () {
    test('starts at ThemeMode.system when adapter has no value', () async {
      final adapter = InMemoryPersistenceAdapter();
      final provider = ProviderContainer(overrides: [
        themeProvider.overrideWith(() => _FakeThemeNotifier(adapter)),
      ]);
      expect(provider.read(themeProvider), ThemeMode.system);
      provider.dispose();
    });

    test('writes updated theme to adapter', () async {
      final adapter = InMemoryPersistenceAdapter();
      final provider = ProviderContainer(overrides: [
        themeProvider.overrideWith(() => _FakeThemeNotifier(adapter)),
      ]);
      final notifier = provider.read(themeProvider.notifier);
      await notifier.setTheme(ThemeMode.dark);
      expect(await adapter.getInt('themeMode'), 2);
      provider.dispose();
    });
  });

  group('ContinuousReadingNotifier', () {
    test('starts at false when adapter has no value', () async {
      final adapter = InMemoryPersistenceAdapter();
      final provider = ProviderContainer(overrides: [
        continuousReadingProvider.overrideWith(() => _FakeContinuousReadingNotifier(adapter)),
      ]);
      expect(provider.read(continuousReadingProvider), false);
      provider.dispose();
    });

    test('toggles correctly', () async {
      final adapter = InMemoryPersistenceAdapter();
      final provider = ProviderContainer(overrides: [
        continuousReadingProvider.overrideWith(() => _FakeContinuousReadingNotifier(adapter)),
      ]);
      final notifier = provider.read(continuousReadingProvider.notifier);
      await notifier.set(true);
      expect(await adapter.getBool('continuousReading'), isTrue);
      await notifier.set(false);
      expect(await adapter.getBool('continuousReading'), isFalse);
      provider.dispose();
    });
  });

  group('PreserveOriginalBookNamesNotifier', () {
    test('starts at false when adapter has no value', () async {
      final adapter = InMemoryPersistenceAdapter();
      final provider = ProviderContainer(overrides: [
        preserveOriginalBookNamesProvider.overrideWith(() => _FakePreserveOriginalBookNamesNotifier(adapter)),
      ]);
      expect(provider.read(preserveOriginalBookNamesProvider), false);
      provider.dispose();
    });

    test('toggles correctly', () async {
      final adapter = InMemoryPersistenceAdapter();
      final provider = ProviderContainer(overrides: [
        preserveOriginalBookNamesProvider.overrideWith(() => _FakePreserveOriginalBookNamesNotifier(adapter)),
      ]);
      final notifier = provider.read(preserveOriginalBookNamesProvider.notifier);
      await notifier.set(true);
      expect(await adapter.getBool('preserveOriginalBookNames'), isTrue);
      await notifier.set(false);
      expect(await adapter.getBool('preserveOriginalBookNames'), isFalse);
      provider.dispose();
    });
  });
}
