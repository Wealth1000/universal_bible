import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';

/// Whether the desktop sidebar is collapsed to icons-only.
///
/// Global (not per-window) and persisted across sessions via
/// [StorageService]. Prefs are loaded in main.dart before runApp, so the
/// initial state is read synchronously — no flash of the wrong width.
class SidebarCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() => StorageService().sidebarCollapsed;

  void toggle() {
    state = !state;
    StorageService().saveSidebarCollapsed(state);
  }
}

final sidebarCollapsedProvider =
    NotifierProvider<SidebarCollapsedNotifier, bool>(
      SidebarCollapsedNotifier.new,
    );
