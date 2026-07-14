import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SyncStatus { idle, syncing, success, error }

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => SyncStatus.idle;

  void setStatus(SyncStatus status) => state = status;
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(SyncStatusNotifier.new);