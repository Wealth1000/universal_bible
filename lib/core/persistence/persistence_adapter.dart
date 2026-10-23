import 'package:shared_preferences/shared_preferences.dart';

/// Abstract seam between notifiers and persistent storage.
///
/// Implementations:
/// - [SharedPreferencesPersistenceAdapter] — production, delegates to
///   [SharedPreferences].
/// - [InMemoryPersistenceAdapter] — tests, uses an in-memory map.
abstract class PersistenceAdapter {
  Future<String?> getString(String key);
  Future<bool?> getBool(String key);
  Future<int?> getInt(String key);
  Future<void> setString(String key, String value);
  Future<void> setBool(String key, bool value);
  Future<void> setInt(String key, int value);
}

/// Production adapter that wraps [SharedPreferences].
///
/// Lazily initializes [SharedPreferences.getInstance()] on the first method
/// call to match the existing behavior of the notifiers.
class SharedPreferencesPersistenceAdapter implements PersistenceAdapter {
  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<String?> getString(String key) async {
    final prefs = await _ensurePrefs();
    return prefs.getString(key);
  }

  @override
  Future<bool?> getBool(String key) async {
    final prefs = await _ensurePrefs();
    return prefs.getBool(key);
  }

  @override
  Future<int?> getInt(String key) async {
    final prefs = await _ensurePrefs();
    return prefs.getInt(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(key, value);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    final prefs = await _ensurePrefs();
    await prefs.setBool(key, value);
  }

  @override
  Future<void> setInt(String key, int value) async {
    final prefs = await _ensurePrefs();
    await prefs.setInt(key, value);
  }
}

/// In-memory adapter for tests. No Flutter binding required.
class InMemoryPersistenceAdapter implements PersistenceAdapter {
  final Map<String, Object?> _data = {};

  @override
  Future<String?> getString(String key) async => _data[key] as String?;

  @override
  Future<bool?> getBool(String key) async => _data[key] as bool?;

  @override
  Future<int?> getInt(String key) async => _data[key] as int?;

  @override
  Future<void> setString(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> setBool(String key, bool value) async {
    _data[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) async {
    _data[key] = value;
  }
}
