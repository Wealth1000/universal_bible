import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_bible/core/themes/app_theme.dart';

// --- Theme Mode Notifier (with persistence) ---
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'themeMode';

  @override
  ThemeMode build() {
    // Load saved theme mode on startup
    return _loadThemeMode();
  }

  ThemeMode _loadThemeMode() {
    // You can load synchronously; SharedPreferences is async, so we need to handle it
    // For simplicity, we use a sync fallback and load async later.
    // A better approach is to initialize SharedPreferences in main and use it here.
    // We'll use a default value and update later.
    return ThemeMode.system;
  }

  // Call this after SharedPreferences is initialized to load saved value
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key) ?? 0;
    final mode = ThemeMode.values[index];
    if (mode != state) {
      state = mode;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, mode.index);
  }
}

final themeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// --- Theme Data Provider (derived from themeProvider) ---
final themeDataProvider = Provider<ThemeData>((ref) {
  final mode = ref.watch(themeProvider);
  switch (mode) {
    case ThemeMode.light:
      return AppTheme.light();
    case ThemeMode.dark:
      return AppTheme.dark();
    case ThemeMode.system:
      // You can also check system brightness via MediaQuery, but here we return light as fallback.
      // For a full implementation, you'd use a WidgetsBinding observer.
      return AppTheme.light();
  }
});