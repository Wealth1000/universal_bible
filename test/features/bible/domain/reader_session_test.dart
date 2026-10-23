import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_bible/core/persistence/persistence_adapter.dart';
import 'package:universal_bible/core/providers/database_provider.dart';
import 'package:universal_bible/core/providers/reading_settings_provider.dart';
import 'package:universal_bible/database/app_database.dart';
import 'package:universal_bible/features/bible/data/bible_data_module.dart';
import 'package:universal_bible/features/bible/domain/chapter_navigation.dart';
import 'package:universal_bible/features/bible/domain/continuous_reading_provider.dart';
import 'package:universal_bible/features/bible/domain/reader_provider.dart';
import 'package:universal_bible/features/bible/domain/reader_session.dart';
import 'package:universal_bible/features/bible/domain/reader_session_provider.dart';
import 'package:universal_bible/features/settings/domain/book_name_settings_provider.dart';

// -----------------------------------------------------------------------------
// Fake BibleDataModule — in-memory implementation for unit testing.
// -----------------------------------------------------------------------------

/// Minimal test notifiers that bypass SharedPreferences/StorageService.
class _FakeReadingPositionNotifier extends ReadingPositionNotifier {
  _FakeReadingPositionNotifier() : super(_NoOpAdapter());
  @override
  ReadingPosition? build() => null;
}

class _FakePreserveOriginalNotifier extends PreserveOriginalBookNamesNotifier {
  _FakePreserveOriginalNotifier() : super(_NoOpAdapter());
  @override
  bool build() => false;
}

class _FakeContinuousReadingNotifier extends ContinuousReadingNotifier {
  _FakeContinuousReadingNotifier() : super(_NoOpAdapter());
  @override
  bool build() => false;
}

class _FakeDefaultTranslationNotifier extends DefaultTranslationNotifier {
  _FakeDefaultTranslationNotifier() : super(_NoOpAdapter());
  @override
  String? build() => null;
}

/// A do-nothing adapter so the fake notifiers can be instantiated without
/// real SharedPreferences.
class _NoOpAdapter implements PersistenceAdapter {
  @override Future<String?> getString(String key) async => null;
  @override Future<bool?> getBool(String key) async => null;
  @override Future<int?> getInt(String key) async => null;
  @override Future<void> setString(String key, String value) async {}
  @override Future<void> setBool(String key, bool value) async {}
  @override Future<void> setInt(String key, int value) async {}
}

class FakeBibleDataModule extends BibleDataModule {
  final Map<String, List<Verse>> _verses = {};
  final Map<String, List<Highlight>> _highlights = {};
  final Map<String, BookInfoResult> _bookInfos = {};

  FakeBibleDataModule() : super(AppDatabase(NativeDatabase.memory()));

  void addVerse(
    String translationId,
    int book,
    int chapter,
    int verse,
    String text,
  ) {
    final key = '$translationId|$book|$chapter';
    _verses.putIfAbsent(key, () => []);
    _verses[key]!.add(
      Verse(
        id: _verses[key]!.length + 1,
        translationId: translationId,
        bookNumber: book,
        chapter: chapter,
        verse: verse,
        verseText: text,
      ),
    );
  }

  void addHighlight(
    String translationId,
    int book,
    int chapter,
    int verse,
    String color,
  ) {
    final key = '$translationId|$book|$chapter';
    _highlights.putIfAbsent(key, () => []);
    _highlights[key]!.add(
      Highlight(
        id: '$book$chapter$verse',
        translationId: translationId,
        bookNumber: book,
        chapter: chapter,
        verse: verse,
        color: color,
        createdAt: DateTime.now(),
      ),
    );
  }

  void setBookInfo(String translationId, BookInfoResult result) {
    _bookInfos[translationId] = result;
  }

  @override
  Future<ChapterData> getChapterData(
    String translationId,
    int bookNumber,
    int chapter,
  ) async {
    final key = '$translationId|$bookNumber|$chapter';
    final verses = _verses[key] ?? [];
    final highlights = _highlights[key] ?? [];
    final highlightsByVerse = <VerseRef, Highlight>{};
    for (final h in highlights) {
      highlightsByVerse[VerseRef(h.bookNumber, h.chapter, h.verse)] = h;
    }
    return ChapterData(
      translationId: translationId,
      bookNumber: bookNumber,
      chapter: chapter,
      verses: verses,
      highlightsByVerse: highlightsByVerse,
    );
  }

  @override
  Future<BookInfoResult> getBookInfo(String translationId) async {
    return _bookInfos[translationId] ?? const BookInfoResult(
      bookMap: {},
      chapterCounts: {},
      displayNames: {},
    );
  }

  @override
  Future<void> saveHighlight({
    required String id,
    required String translationId,
    required int bookNumber,
    required int chapter,
    required int verse,
    required String color,
    required DateTime createdAt,
  }) async {
    final key = '$translationId|$bookNumber|$chapter';
    _highlights.putIfAbsent(key, () => []);
    _highlights[key]!.removeWhere(
      (h) => h.bookNumber == bookNumber && h.chapter == chapter && h.verse == verse,
    );
    _highlights[key]!.add(
      Highlight(
        id: id,
        translationId: translationId,
        bookNumber: bookNumber,
        chapter: chapter,
        verse: verse,
        color: color,
        createdAt: createdAt,
      ),
    );
  }

  @override
  Future<void> deleteHighlightsForVerse(
    String translationId,
    int book,
    int chapter,
    int verse,
  ) async {
    final key = '$translationId|$book|$chapter';
    _highlights[key] ??= [];
    _highlights[key]!.removeWhere((h) => h.verse == verse);
  }

  @override
  Future<void> insertBookmark({
    required String id,
    required String translationId,
    required int bookNumber,
    required int chapter,
    required int verse,
    required DateTime createdAt,
  }) async {}

  @override
  Future<void> insertNote({
    required String id,
    required String translationId,
    required int bookNumber,
    required int chapter,
    required int verse,
    required String content,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) async {}
}

// -----------------------------------------------------------------------------
// Tests
// -----------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderSession', () {
    late ProviderContainer container;
    late FakeBibleDataModule fake;
    late ReaderSession session;

    setUp(() {
      fake = FakeBibleDataModule();
      container = ProviderContainer(
        overrides: [
          bibleDataModuleProvider.overrideWith((ref) => fake),
          readingPositionProvider.overrideWith(() => _FakeReadingPositionNotifier()),
          preserveOriginalBookNamesProvider.overrideWith(
            () => _FakePreserveOriginalNotifier(),
          ),
          continuousReadingProvider.overrideWith(
            () => _FakeContinuousReadingNotifier(),
          ),
          defaultTranslationProvider.overrideWith(
            () => _FakeDefaultTranslationNotifier(),
          ),
        ],
      );
      container.read(currentTranslationProvider.notifier).set('TEST');
      container.read(currentBookProvider.notifier).set(1);
      container.read(currentChapterProvider.notifier).set(1);
      session = container.read(readerSessionProvider);
    });

    tearDown(() => container.dispose());

    test('navigateTo updates providers and persists', () {
      fake.setBookInfo(
        'TEST',
        const BookInfoResult(
          bookMap: {'genesis': 1},
          chapterCounts: {1: {1: 5, 2: 3}},
          displayNames: {1: 'Genesis'},
        ),
      );
      session.reloadBooks();

      session.navigateTo(const ChapterRef(1, 2));

      expect(container.read(currentBookProvider), 1);
      expect(container.read(currentChapterProvider), 2);
      expect(container.read(readingPositionProvider)?.book, 1);
      expect(container.read(readingPositionProvider)?.chapter, 2);
    });

    test('toggleVerse adds then removes from selection', () {
      final verse = const VerseRef(1, 1, 1);

      expect(container.read(selectedVersesProvider), isEmpty);

      final afterAdd = session.toggleVerse(verse);
      expect(afterAdd, contains(verse));

      final afterRemove = session.toggleVerse(verse);
      expect(afterRemove, isNot(contains(verse)));
    });

    test('applyHighlight on empty selection is no-op', () async {
      await session.applyHighlight(const Color(0xFFFF0000));
      expect(container.read(highlightsVersionProvider), 0);
    });

    test('applyHighlight on verse without highlight inserts', () async {
      fake.addVerse('TEST', 1, 1, 1, 'in the beginning');
      fake.setBookInfo(
        'TEST',
        const BookInfoResult(
          bookMap: {'genesis': 1},
          chapterCounts: {1: {1: 1}},
          displayNames: {1: 'Genesis'},
        ),
      );
      session.reloadBooks();
      session.toggleVerse(const VerseRef(1, 1, 1));

      await session.applyHighlight(const Color(0xFFFF0000));

      final data = await fake.getChapterData('TEST', 1, 1);
      expect(
        data.highlightsByVerse.containsKey(const VerseRef(1, 1, 1)),
        isTrue,
      );
      expect(data.highlightsByVerse[const VerseRef(1, 1, 1)]?.color, '#FFFF0000');
      expect(container.read(highlightsVersionProvider), 1);
    });

    test('applyHighlight re-applies same color removes (toggle)', () async {
      fake.addVerse('TEST', 1, 1, 1, 'in the beginning');
      fake.addHighlight('TEST', 1, 1, 1, '#FFFF0000');
      fake.setBookInfo(
        'TEST',
        const BookInfoResult(
          bookMap: {'genesis': 1},
          chapterCounts: {1: {1: 1}},
          displayNames: {1: 'Genesis'},
        ),
      );
      session.reloadBooks();
      session.toggleVerse(const VerseRef(1, 1, 1));

      await session.applyHighlight(const Color(0xFFFF0000));

      final data = await fake.getChapterData('TEST', 1, 1);
      expect(
        data.highlightsByVerse.containsKey(const VerseRef(1, 1, 1)),
        isFalse,
      );
    });

    test('clearSelection empties selection and closes compare', () {
      session.toggleVerse(const VerseRef(1, 1, 1));
      session.openCompare();

      expect(container.read(selectedVersesProvider), isNotEmpty);
      expect(container.read(compareOpenProvider), isTrue);

      session.clearSelection();

      expect(container.read(selectedVersesProvider), isEmpty);
      expect(container.read(compareOpenProvider), isFalse);
    });

    test('preloadNext at end of Bible returns null', () async {
      fake.setBookInfo(
        'TEST',
        const BookInfoResult(
          bookMap: {'genesis': 1, 'exodus': 2},
          chapterCounts: {1: {1: 5}, 2: {1: 3}},
          displayNames: {1: 'Genesis', 2: 'Exodus'},
        ),
      );
      session.reloadBooks();

      final result = await session.preloadNext(2, 1);
      expect(result, isNull);
    });

    test('preloadPrev at start of Bible returns null', () async {
      fake.setBookInfo(
        'TEST',
        const BookInfoResult(
          bookMap: {'genesis': 1, 'exodus': 2},
          chapterCounts: {1: {1: 5}, 2: {1: 3}},
          displayNames: {1: 'Genesis', 2: 'Exodus'},
        ),
      );
      session.reloadBooks();

      final result = await session.preloadPrev(1, 1);
      expect(result, isNull);
    });
  });
}
