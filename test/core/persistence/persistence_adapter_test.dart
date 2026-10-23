import 'package:flutter_test/flutter_test.dart';
import 'package:universal_bible/core/persistence/persistence_adapter.dart';

void main() {
  group('InMemoryPersistenceAdapter', () {
    late InMemoryPersistenceAdapter adapter;

    setUp(() {
      adapter = InMemoryPersistenceAdapter();
    });

    test('setString / getString round-trip', () async {
      await adapter.setString('key', 'hello');
      expect(await adapter.getString('key'), 'hello');
    });

    test('setInt / getInt round-trip', () async {
      await adapter.setInt('key', 42);
      expect(await adapter.getInt('key'), 42);
    });

    test('setBool / getBool round-trip', () async {
      await adapter.setBool('key', true);
      expect(await adapter.getBool('key'), isTrue);
      await adapter.setBool('key', false);
      expect(await adapter.getBool('key'), isFalse);
    });

    test('missing keys return null', () async {
      expect(await adapter.getString('nope'), isNull);
      expect(await adapter.getInt('nope'), isNull);
      expect(await adapter.getBool('nope'), isNull);
    });

    test('overwriting a key works', () async {
      await adapter.setString('k', 'first');
      await adapter.setString('k', 'second');
      expect(await adapter.getString('k'), 'second');
    });
  });

  group('SharedPreferencesPersistenceAdapter', () {
    // Production adapter requires Flutter binding; tested implicitly
    // through the notifier integration tests.
    test('class can be instantiated', () {
      expect(SharedPreferencesPersistenceAdapter(), isA<PersistenceAdapter>());
    });
  });
}
