import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_bible/core/persistence/persistence_adapter.dart';

/// Reading settings shared by the settings page and the reader.
///
/// Lives in core/ (not features/settings) because features must not import
/// each other. Self-loads from [PersistenceAdapter] (same pattern as
/// PreserveOriginalBookNamesNotifier) so the reader gets persisted values
/// even if the settings page was never opened. Keys match the ones the
/// settings page has always written, so existing prefs carry over.

class FontSizeNotifier extends Notifier<double> {
  static const _prefsKey = 'fontSize';

  FontSizeNotifier(this._persistence);
  final PersistenceAdapter _persistence;

  @override
  double build() {
    _load();
    return 18.0;
  }

  Future<void> _load() async {
    final raw = await _persistence.getInt(_prefsKey);
    final value = raw?.toDouble() ?? 18.0;
    if (ref.mounted && value != state) state = value;
  }

  Future<void> set(double value) async {
    state = value;
    await _persistence.setInt(_prefsKey, value.toInt());
  }
}

final fontSizeProvider = NotifierProvider<FontSizeNotifier, double>(
  () => FontSizeNotifier(SharedPreferencesPersistenceAdapter()),
);

class ShowVerseNumbersNotifier extends Notifier<bool> {
  static const _prefsKey = 'showVerseNumbers';

  ShowVerseNumbersNotifier(this._persistence);
  final PersistenceAdapter _persistence;

  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final value = await _persistence.getBool(_prefsKey) ?? true;
    if (ref.mounted && value != state) state = value;
  }

  Future<void> set(bool value) async {
    state = value;
    await _persistence.setBool(_prefsKey, value);
  }
}

final showVerseNumbersProvider =
    NotifierProvider<ShowVerseNumbersNotifier, bool>(
      () => ShowVerseNumbersNotifier(SharedPreferencesPersistenceAdapter()),
    );

/// Default translation id — a FALLBACK only: the reader opens in the
/// last-used translation (reading-position persistence); this seeds fresh
/// installs / cleared positions. Null = no default set.
class DefaultTranslationNotifier extends Notifier<String?> {
  static const _prefsKey = 'defaultTranslation';

  DefaultTranslationNotifier(this._persistence);
  final PersistenceAdapter _persistence;

  @override
  String? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final value = await _persistence.getString(_prefsKey);
    if (ref.mounted && value != state) state = value;
  }

  Future<void> set(String id) async {
    state = id;
    await _persistence.setString(_prefsKey, id);
  }
}

final defaultTranslationProvider =
    NotifierProvider<DefaultTranslationNotifier, String?>(
      () => DefaultTranslationNotifier(SharedPreferencesPersistenceAdapter()),
    );
