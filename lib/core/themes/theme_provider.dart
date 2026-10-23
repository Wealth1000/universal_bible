import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_bible/core/persistence/persistence_adapter.dart';
import 'app_theme.dart';

/// Theme mode with persistence (self-loading, same pattern as the reading
/// settings providers). The duplicate provider that used to live at
/// core/providers/theme_provider.dart was removed in the UI overhaul —
/// its persistence moved here.
class ThemeNotifier extends Notifier<ThemeMode> {
  static const _prefsKey = 'themeMode';

  ThemeNotifier(this._persistence);
  final PersistenceAdapter _persistence;

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final index = await _persistence.getInt(_prefsKey);
    if (ref.mounted && index != null &&
        index >= 0 &&
        index < ThemeMode.values.length &&
        ThemeMode.values[index] != state) {
      state = ThemeMode.values[index];
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    await _persistence.setInt(_prefsKey, mode.index);
  }
}

final themeProvider =
    NotifierProvider<ThemeNotifier, ThemeMode>(() => ThemeNotifier(SharedPreferencesPersistenceAdapter()));

final themeDataProvider = Provider<ThemeData>((ref) {
  final mode = ref.watch(themeProvider);
  switch (mode) {
    case ThemeMode.light:
      return AppTheme.light();
    case ThemeMode.dark:
      return AppTheme.dark();
    default:
      return AppTheme.light();
  }
});
