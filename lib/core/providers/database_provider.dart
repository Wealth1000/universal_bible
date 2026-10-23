import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_bible/core/persistence/persistence_adapter.dart';
import 'package:universal_bible/database/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

/// The reading position the reader should restore to (translation + book +
/// chapter). Backed by [PersistenceAdapter] so it survives app restarts.
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
  static const _keyTranslation = 'reading_position.translation';
  static const _keyBook = 'reading_position.book';
  static const _keyChapter = 'reading_position.chapter';

  Timer? _debounce;

  ReadingPositionNotifier(this._persistence);
  final PersistenceAdapter _persistence;

  @override
  ReadingPosition? build() {
    ref.onDispose(() => _debounce?.cancel());
    _load();
    return null;
  }

  Future<void> _load() async {
    final translationId = await _persistence.getString(_keyTranslation);
    final book = await _persistence.getInt(_keyBook);
    final chapter = await _persistence.getInt(_keyChapter);
    if (ref.mounted && translationId != null && book != null && chapter != null) {
      state = ReadingPosition(
        translationId: translationId,
        book: book,
        chapter: chapter,
      );
    }
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
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      await _persistence.setString(_keyTranslation, position.translationId);
      await _persistence.setInt(_keyBook, position.book);
      await _persistence.setInt(_keyChapter, position.chapter);
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
      _persistence.setString(_keyTranslation, translationId);
      _persistence.setInt(_keyBook, current.book);
      _persistence.setInt(_keyChapter, current.chapter);
    } else {
      _persistence.setString(_keyTranslation, translationId);
    }
  }
}

final readingPositionProvider =
    NotifierProvider<ReadingPositionNotifier, ReadingPosition?>(
      () => ReadingPositionNotifier(SharedPreferencesPersistenceAdapter()),
    );
