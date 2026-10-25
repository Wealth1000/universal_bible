import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the reader keeps loading the next chapter inline as the user
/// scrolls past the end of the current one (crossing book boundaries:
/// Genesis 50 flows into Exodus 1).
///
/// Self-loads from SharedPreferences so the reader gets the persisted value
/// even if the toggle was never opened this session.
class ContinuousReadingNotifier extends Notifier<bool> {
  static const _prefsKey = 'continuousReading';

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

final continuousReadingProvider =
    NotifierProvider<ContinuousReadingNotifier, bool>(
      ContinuousReadingNotifier.new,
    );
