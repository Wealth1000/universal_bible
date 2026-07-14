import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';

class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void setTheme(ThemeMode mode) => state = mode;
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);

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