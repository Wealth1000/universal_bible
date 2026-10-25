import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_bible/core/services/storage_service.dart';
import 'package:universal_bible/database/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

/// The reading position the reader should restore to (translation + book +
/// chapter). Backed by StorageService/SharedPreferences so it survives
/// app restarts.
class ReadingPosition {
  final String translationId;
  final int book;
  final int chapter;

  const ReadingPosition({
    required this.translationId,
    required this.book,
    required this.chapter,
  });
}

class ReadingPositionNotifier extends Notifier<ReadingPosition?> {
  Timer? _debounce;

  @override
  ReadingPosition? build() {
    ref.onDispose(() => _debounce?.cancel());
    final record = StorageService().lastReadingPosition;
    if (record == null) return null;
    return ReadingPosition(
      translationId: record.translationId,
      book: record.book,
      chapter: record.chapter,
    );
  }

  /// Saves the position. The prefs write is debounced because the reader's
  /// scroll listener calls this every frame while scrolling.
  void save(ReadingPosition position) {
    final current = state;
    if (current != null &&
        current.translationId == position.translationId &&
        current.book == position.book &&
        current.chapter == position.chapter) {
      return;
    }
    state = position;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      StorageService().saveReadingPosition(
        translationId: position.translationId,
        book: position.book,
        chapter: position.chapter,
      );
    });
  }

  /// Updates only the translation component — used when switching
  /// translations from the pill grid, so the reader stays at the same
  /// book/chapter.
  void saveTranslationOnly(String translationId) {
    // Cancel any pending debounced save: it carries the OLD translation id
    // and would overwrite this switch when its timer fired.
    _debounce?.cancel();
    final current = state;
    if (current != null) {
      state = ReadingPosition(
        translationId: translationId,
        book: current.book,
        chapter: current.chapter,
      );
      StorageService().saveReadingPosition(
        translationId: translationId,
        book: current.book,
        chapter: current.chapter,
      );
    } else {
      StorageService().saveReadingTranslation(translationId);
    }
  }
}

final readingPositionProvider =
    NotifierProvider<ReadingPositionNotifier, ReadingPosition?>(
      ReadingPositionNotifier.new,
    );
