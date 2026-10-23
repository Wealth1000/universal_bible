import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_bible/core/utils/book_name_utils.dart';
import 'package:universal_bible/database/app_database.dart';
import 'package:universal_bible/features/bible/data/bible_data_module.dart';
import 'package:universal_bible/features/bible/domain/reader_provider.dart';
import 'package:uuid/uuid.dart';

// Test database that accepts a custom executor (for in-memory use)
AppDatabase _makeDb() {
  final executor = NativeDatabase.memory();
  return AppDatabase(executor);
}

void main() {
  late BibleDataModule module;
  late AppDatabase db;

  setUp(() {
    db = _makeDb();
    module = BibleDataModule(db);
  });

  // --- Helper to seed a translation with verses ---

  Future<void> seedTranslation({
    required String id,
    required List<Map<String, dynamic>> verses,
  }) async {
    final bookMapJson = jsonEncode(<String, int>{'genesis': 1});
    final displayNames = <String, String>{};
    for (final key in const ['genesis']) {
      displayNames[key] = cleanBookName(key);
    }
    final displayNamesJson = jsonEncode(displayNames);
    final chapterCountsJson = '{"1":{"1":3,"2":5}}';

    await db.into(db.translations).insert(
      TranslationsCompanion.insert(
        id: id,
        name: id,
        languageCode: 'en',
        version: 1,
        installed: true,
        bookMapJson: bookMapJson,
        bookDisplayNamesJson: Value(displayNamesJson),
        bookChapterCountsJson: Value(chapterCountsJson),
      ),
    );

    for (final v in verses) {
      await db.insertVerse(
        VersesCompanion.insert(
          translationId: v['translationId'] as String,
          bookNumber: v['bookNumber'] as int,
          chapter: v['chapter'] as int,
          verse: v['verse'] as int,
          verseText: v['verseText'] as String,
        ),
      );
    }
  }

  group('getChapterData', () {
    test('returns verses in verse order with highlights merged', () async {
      await seedTranslation(
        id: 'TEST',
        verses: [
          {'translationId': 'TEST', 'bookNumber': 1, 'chapter': 1, 'verse': 1, 'verseText': 'verse one'},
          {'translationId': 'TEST', 'bookNumber': 1, 'chapter': 1, 'verse': 2, 'verseText': 'verse two'},
          {'translationId': 'TEST', 'bookNumber': 1, 'chapter': 1, 'verse': 3, 'verseText': 'verse three'},
        ],
      );

      await db.insertHighlight(
        HighlightsCompanion.insert(
          id: 'h1',
          translationId: 'TEST',
          bookNumber: 1,
          chapter: 1,
          verse: 1,
          color: 'yellow',
          createdAt: DateTime(2024, 1, 1),
        ),
      );
      await db.insertHighlight(
        HighlightsCompanion.insert(
          id: 'h2',
          translationId: 'TEST',
          bookNumber: 1,
          chapter: 1,
          verse: 3,
          color: 'green',
          createdAt: DateTime(2024, 1, 2),
        ),
      );

      final data = await module.getChapterData('TEST', 1, 1);

      expect(data.translationId, 'TEST');
      expect(data.bookNumber, 1);
      expect(data.chapter, 1);
      expect(data.verses.length, 3);
      expect(data.verses[0].verseText, 'verse one');
      expect(data.verses[1].verseText, 'verse two');
      expect(data.verses[2].verseText, 'verse three');
      expect(data.highlightsByVerse.length, 2);
      expect(data.highlightsByVerse[const VerseRef(1, 1, 1)]?.color, 'yellow');
      expect(data.highlightsByVerse[const VerseRef(1, 1, 3)]?.color, 'green');
      expect(data.highlightsByVerse.containsKey(const VerseRef(1, 1, 2)), isFalse);
    });

    test('returns empty highlights map when none exist', () async {
      await seedTranslation(
        id: 'TEST2',
        verses: [
          {'translationId': 'TEST2', 'bookNumber': 1, 'chapter': 1, 'verse': 1, 'verseText': 'hello'},
        ],
      );

      final data = await module.getChapterData('TEST2', 1, 1);
      expect(data.verses.length, 1);
      expect(data.highlightsByVerse, isEmpty);
    });
  });

  group('saveHighlight + getChapterData round-trip', () {
    test('persists highlight and it appears in chapter data', () async {
      await seedTranslation(
        id: 'RT',
        verses: [
          {'translationId': 'RT', 'bookNumber': 1, 'chapter': 1, 'verse': 5, 'verseText': 'test verse'},
        ],
      );

      await module.saveHighlight(
        id: const Uuid().v4(),
        translationId: 'RT',
        bookNumber: 1,
        chapter: 1,
        verse: 5,
        color: 'blue',
        createdAt: DateTime(2024, 6, 1),
      );

      final data = await module.getChapterData('RT', 1, 1);
      expect(
        data.highlightsByVerse.containsKey(const VerseRef(1, 1, 5)),
        isTrue,
      );
      expect(data.highlightsByVerse[const VerseRef(1, 1, 5)]?.color, 'blue');
    });
  });

  group('deleteHighlightsForVerse', () {
    test('removes existing highlights', () async {
      await seedTranslation(
        id: 'DH',
        verses: [
          {'translationId': 'DH', 'bookNumber': 2, 'chapter': 3, 'verse': 4, 'verseText': 'x'},
        ],
      );

      await db.insertHighlight(
        HighlightsCompanion.insert(
          id: 'h1',
          translationId: 'DH',
          bookNumber: 2,
          chapter: 3,
          verse: 4,
          color: 'red',
          createdAt: DateTime.now(),
        ),
      );

      await module.deleteHighlightsForVerse('DH', 2, 3, 4);

      final data = await module.getChapterData('DH', 2, 3);
      expect(data.highlightsByVerse, isEmpty);
    });
  });

  group('getBookInfo', () {
    test('decodes JSON correctly', () async {
      await seedTranslation(
        id: 'BI',
        verses: [],
      );

      final result = await module.getBookInfo('BI');

      expect(result.bookMap, {'genesis': 1});
      expect(result.chapterCounts[1]![1], 3);
      expect(result.chapterCounts[1]![2], 5);
      expect(result.displayNames[1], 'Genesis');
    });

    test('handles missing optional JSON fields', () async {
      // Seed without bookDisplayNamesJson or bookChapterCountsJson
      await db.into(db.translations).insert(
        TranslationsCompanion.insert(
          id: 'BI2',
          name: 'BI2',
          languageCode: 'en',
          version: 1,
          installed: true,
          bookMapJson: '{}',
        ),
      );

      final result = await module.getBookInfo('BI2');
      expect(result.bookMap, isEmpty);
      expect(result.chapterCounts, isEmpty);
      expect(result.displayNames, isEmpty);
    });

    test('returns empty result for unknown translation', () async {
      final result = await module.getBookInfo('NONEXISTENT');
      expect(result.bookMap, isEmpty);
      expect(result.chapterCounts, isEmpty);
      expect(result.displayNames, isEmpty);
    });
  });

  group('searchVerses', () {
    test('returns results ordered by book, chapter, verse', () async {
      await seedTranslation(
        id: 'SV',
        verses: [
          {'translationId': 'SV', 'bookNumber': 1, 'chapter': 2, 'verse': 1, 'verseText': 'alpha second'},
          {'translationId': 'SV', 'bookNumber': 1, 'chapter': 1, 'verse': 5, 'verseText': 'alpha first'},
          {'translationId': 'SV', 'bookNumber': 2, 'chapter': 1, 'verse': 1, 'verseText': 'beta first'},
        ],
      );

      final results = await module.searchVerses('SV', 'alpha');
      expect(results.length, 2);
      expect(results[0].bookNumber, 1);
      expect(results[0].chapter, 1);
      expect(results[1].bookNumber, 1);
      expect(results[1].chapter, 2);
    });

    test('returns empty list for no match', () async {
      await seedTranslation(
        id: 'SV2',
        verses: [
          {'translationId': 'SV2', 'bookNumber': 1, 'chapter': 1, 'verse': 1, 'verseText': 'hello'},
        ],
      );

      final results = await module.searchVerses('SV2', 'zzzznotfound');
      expect(results, isEmpty);
    });
  });

  group('insertBookmark + getBookmarks', () {
    test('persists and retrieves bookmarks ordered by createdAt desc', () async {
      final id1 = const Uuid().v4();
      final id2 = const Uuid().v4();

      await module.insertBookmark(
        id: id1,
        translationId: 'BM',
        bookNumber: 1,
        chapter: 1,
        verse: 1,
        createdAt: DateTime(2024, 1, 1),
      );
      await module.insertBookmark(
        id: id2,
        translationId: 'BM',
        bookNumber: 1,
        chapter: 2,
        verse: 1,
        createdAt: DateTime(2024, 2, 1),
      );

      final bookmarks = await module.getBookmarks('BM');
      expect(bookmarks.length, 2);
      expect(bookmarks[0].id, id2);
      expect(bookmarks[1].id, id1);
    });

    test('deleteBookmark removes the bookmark', () async {
      final id = const Uuid().v4();
      await module.insertBookmark(
        id: id,
        translationId: 'BM2',
        bookNumber: 1,
        chapter: 1,
        verse: 1,
        createdAt: DateTime.now(),
      );
      await module.deleteBookmark(id);

      final bookmarks = await module.getBookmarks('BM2');
      expect(bookmarks, isEmpty);
    });
  });

  group('insertNote + getNotes', () {
    test('persists and retrieves notes ordered by updatedAt desc', () async {
      final id1 = const Uuid().v4();
      final id2 = const Uuid().v4();
      final now = DateTime.now();

      await module.insertNote(
        id: id1,
        translationId: 'NT',
        bookNumber: 1,
        chapter: 1,
        verse: 1,
        content: 'note one',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      );
      await module.insertNote(
        id: id2,
        translationId: 'NT',
        bookNumber: 1,
        chapter: 1,
        verse: 2,
        content: 'note two',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      );

      final notes = await module.getNotes('NT');
      expect(notes.length, 2);
      expect(notes[0].id, id2);
      expect(notes[1].id, id1);
    });

    test('deleteNote removes the note', () async {
      final id = const Uuid().v4();
      await module.insertNote(
        id: id,
        translationId: 'NT2',
        bookNumber: 1,
        chapter: 1,
        verse: 1,
        content: 'to delete',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await module.deleteNote(id);

      final notes = await module.getNotes('NT2');
      expect(notes, isEmpty);
    });
  });

  group('getVerse', () {
    test('returns a verse when it exists', () async {
      await seedTranslation(
        id: 'GV',
        verses: [
          {'translationId': 'GV', 'bookNumber': 1, 'chapter': 1, 'verse': 1, 'verseText': 'in the beginning'},
        ],
      );

      final verse = await module.getVerse('GV', 1, 1, 1);
      expect(verse, isNotNull);
      expect(verse!.verseText, 'in the beginning');
    });

    test('returns null when verse does not exist', () async {
      await seedTranslation(
        id: 'GV2',
        verses: [],
      );

      final verse = await module.getVerse('GV2', 1, 1, 1);
      expect(verse, isNull);
    });
  });

  group('getInstalledTranslations / getTranslation', () {
    test('getInstalledTranslations returns only installed translations', () async {
      await db.into(db.translations).insert(
        TranslationsCompanion.insert(
          id: 'INST1',
          name: 'Inst1',
          languageCode: 'en',
          version: 1,
          installed: true,
          bookMapJson: '{}',
        ),
      );
      await db.into(db.translations).insert(
        TranslationsCompanion.insert(
          id: 'UNINST1',
          name: 'Uninst1',
          languageCode: 'en',
          version: 1,
          installed: false,
          bookMapJson: '{}',
        ),
      );

      final installed = await module.getInstalledTranslations();
      expect(installed.length, 1);
      expect(installed[0].id, 'INST1');
    });

    test('getTranslation returns null for unknown id', () async {
      final trans = await module.getTranslation('UNKNOWN');
      expect(trans, isNull);
    });
  });
}
