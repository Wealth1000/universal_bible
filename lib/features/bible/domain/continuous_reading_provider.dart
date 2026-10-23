import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_bible/core/persistence/persistence_adapter.dart';

/// Whether the reader keeps loading the next chapter inline as the user
/// scrolls past the end of the current one (crossing book boundaries:
/// Genesis 50 flows into Exodus 1).
///
/// Self-loads from [PersistenceAdapter] so the reader gets the persisted
/// value even if the toggle was never opened this session.
class ContinuousReadingNotifier extends Notifier<bool> {
  static const _prefsKey = 'continuousReading';

  ContinuousReadingNotifier(this._persistence);
  final PersistenceAdapter _persistence;

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final value = await _persistence.getBool(_prefsKey) ?? false;
    if (ref.mounted && value != state) state = value;
  }

  Future<void> set(bool value) async {
    state = value;
    await _persistence.setBool(_prefsKey, value);
  }
}

final continuousReadingProvider =
    NotifierProvider<ContinuousReadingNotifier, bool>(
      () => ContinuousReadingNotifier(SharedPreferencesPersistenceAdapter()),
    );
