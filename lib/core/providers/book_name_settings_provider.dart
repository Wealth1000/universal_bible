import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_bible/core/persistence/persistence_adapter.dart';

/// Whether book names should keep the translation's original full titles
/// ("The First Book of Moses called Genesis") instead of the short
/// canonical names ("Genesis").
///
/// Self-loads from [PersistenceAdapter] so readers get the persisted value
/// even if the settings page was never opened.
class PreserveOriginalBookNamesNotifier extends Notifier<bool> {
  static const _prefsKey = 'preserveOriginalBookNames';

  PreserveOriginalBookNamesNotifier(this._persistence);
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

final preserveOriginalBookNamesProvider =
    NotifierProvider<PreserveOriginalBookNamesNotifier, bool>(
      () => PreserveOriginalBookNamesNotifier(SharedPreferencesPersistenceAdapter()),
    );
