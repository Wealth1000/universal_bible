import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether book names should keep the translation's original full titles
/// ("The First Book of Moses called Genesis") instead of the short
/// canonical names ("Genesis").
///
/// Self-loads from SharedPreferences so readers get the persisted value
/// even if the settings page was never opened.
class PreserveOriginalBookNamesNotifier extends Notifier<bool> {
  static const _prefsKey = 'preserveOriginalBookNames';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_prefsKey) ?? false;
    if (value != state) state = value;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }
}

final preserveOriginalBookNamesProvider =
    NotifierProvider<PreserveOriginalBookNamesNotifier, bool>(
      PreserveOriginalBookNamesNotifier.new,
    );
