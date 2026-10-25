import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Rhapsody text-zoom multiplier. Multiplies every text-size value used in
/// the Rhapsody reading column (title, body, confession, chips, labels) so
/// the user can scale the whole reading view uniformly.
///
/// Kept Rhapsody-scoped (per project rule that features must not import each
/// other) and independent of the bible's `fontSizeProvider` — users may want
/// a different reading size for scripture vs. devotional text.
///
/// Self-loads from SharedPreferences using the same pattern as
/// `FontSizeNotifier` in `core/providers/reading_settings_provider.dart`.
class RhapsodyZoomNotifier extends Notifier<double> {
  static const _prefsKey = 'rhapsodyZoom';

  /// Inclusive lower bound. 0.85x is still comfortable for users with smaller
  /// devices; lower values would compromise the type hierarchy.
  static const double minZoom = 0.85;

  /// Inclusive upper bound. 1.6x covers a 320% effective range vs. 0.85x and
  /// is plenty for accessibility while still fitting the desktop reading
  /// column without overflow.
  static const double maxZoom = 3.5;

  /// Default for fresh installs and cleared prefs.
  static const double defaultZoom = 1.0;

  @override
  double build() {
    _load();
    return defaultZoom;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_prefsKey) ?? defaultZoom;
    final clamped = stored.clamp(minZoom, maxZoom);
    if (clamped != state) state = clamped;
  }

  Future<void> set(double value) async {
    final clamped = value.clamp(minZoom, maxZoom);
    if (clamped == state) return;
    state = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKey, clamped);
  }

  /// Convenience for +/- buttons around the slider.
  Future<void> increment([double step = 0.05]) => set(state + step);

  Future<void> decrement([double step = 0.05]) => set(state - step);

  Future<void> reset() => set(defaultZoom);
}

final rhapsodyZoomProvider = NotifierProvider<RhapsodyZoomNotifier, double>(
  RhapsodyZoomNotifier.new,
);
