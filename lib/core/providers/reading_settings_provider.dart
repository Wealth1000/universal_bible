import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reading settings shared by the settings page and the reader.
///
/// Lives in core/ (not features/settings) because features must not import
/// each other. Self-loads from SharedPreferences (same pattern as
/// PreserveOriginalBookNamesNotifier) so the reader gets persisted values
/// even if the settings page was never opened. Keys match the ones the
/// settings page has always written, so existing prefs carry over.

class FontSizeNotifier extends Notifier<double> {
  static const _prefsKey = 'fontSize';

  @override
  double build() {
    _load();
    return 18.0;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getDouble(_prefsKey) ?? 18.0;
    if (value != state) state = value;
  }

  Future<void> set(double value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKey, value);
  }
}

final fontSizeProvider = NotifierProvider<FontSizeNotifier, double>(
  FontSizeNotifier.new,
);

class ShowVerseNumbersNotifier extends Notifier<bool> {
  static const _prefsKey = 'showVerseNumbers';

  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_prefsKey) ?? true;
    if (value != state) state = value;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }
}

final showVerseNumbersProvider =
    NotifierProvider<ShowVerseNumbersNotifier, bool>(
      ShowVerseNumbersNotifier.new,
    );

/// Default translation id — a FALLBACK only: the reader opens in the
/// last-used translation (reading-position persistence); this seeds fresh
/// installs / cleared positions. Null = no default set.
class DefaultTranslationNotifier extends Notifier<String?> {
  static const _prefsKey = 'defaultTranslation';

  @override
  String? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefsKey);
    if (value != state) state = value;
  }

  Future<void> set(String id) async {
    state = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, id);
  }
}

final defaultTranslationProvider =
    NotifierProvider<DefaultTranslationNotifier, String?>(
      DefaultTranslationNotifier.new,
    );
