import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_bible/core/utils/book_name_utils.dart';
import 'package:universal_bible/database/app_database.dart';
import 'package:universal_bible/features/bible/data/bible_data_module.dart';
import 'package:universal_bible/features/rhapsody/application/scripture_resolver.dart';

// Test database that accepts a custom executor (for in-memory use)
AppDatabase _makeDb() {
  final executor = NativeDatabase.memory();
  return AppDatabase(executor);
}

Future<void> _seedTranslation({
  required AppDatabase db,
  required String id,
  required List<Map<String, dynamic>> verses,
}) async {
  final bookMapJson = jsonEncode(<String, int>{
    'genesis': 1,
    'psalms': 19,
    'proverbs': 31,
    '2timothy': 4,
  });
  final displayNames = <String, String>{};
  for (final key in const [
    'genesis',
    'psalms',
    'proverbs',
    '2timothy',
  ]) {
    displayNames[key] = cleanBookName(key);
  }
  final displayNamesJson = jsonEncode(displayNames);
  final chapterCountsJson =
      '{"1":{"1":5,"2":3},"19":{"23":6},"31":{"6":1},"4":{"14":2}}';

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

void main() {
  group('parseScriptureReference', () {
    test('book + chapter + single verse', () {
      final r = parseScriptureReference('Proverbs 22:6')!;
      expect(r, isNotNull);
      expect(r.bookName, 'Proverbs');
      expect(r.chapter, 22);
      expect(r.startVerse, 6);
      expect(r.endVerse, isNull);
    });

    test('verse range with hyphen', () {
      final r = parseScriptureReference('2 Timothy 3:14-15')!;
      expect(r.bookName, '2 Timothy');
      expect(r.chapter, 3);
      expect(r.startVerse, 14);
      expect(r.endVerse, 15);
    });

    test('verse range with en-dash and spaced operands', () {
      final r = parseScriptureReference('2 Timothy 3:14 – 15')!;
      expect(r.startVerse, 14);
      expect(r.endVerse, 15);
    });

    test('book + chapter only means the whole chapter', () {
      final r = parseScriptureReference('Psalm 83')!;
      expect(r.chapter, 83);
      expect(r.startVerse, isNull);
      expect(r.endVerse, isNull);
    });

    test('trailing translation code is stripped', () {
      final r = parseScriptureReference('2 Timothy 3:14-15 NIV')!;
      expect(r.bookName, '2 Timothy');
      expect(r.startVerse, 14);
      expect(r.endVerse, 15);
    });

    test('leading-ordinal book names keep their ordinal', () {
      final r = parseScriptureReference('1 Samuel 2')!;
      expect(r.bookName, '1 Samuel');
      expect(r.chapter, 2);
    });

    test('non-references are rejected', () {
      expect(parseScriptureReference('not a reference'), isNull);
      expect(parseScriptureReference(''), isNull);
      expect(parseScriptureReference('   '), isNull);
      expect(parseScriptureReference('Genesis'), isNull); // no chapter
    });
  });

  group('normalizeBookKey', () {
    test('canonicalises short names', () {
      expect(normalizeBookKey('Psalm'), 'psalms');
      expect(normalizeBookKey('Genesis'), 'genesis');
    });

    test('canonicalises long titles to numbered-book keys', () {
      expect(
        normalizeBookKey(
          'The First Epistle of Paul the Apostle to the Corinthians',
        ),
        '1corinthians',
      );
    });

    test('canonicalises the galations source typo', () {
      expect(normalizeBookKey('galations'), 'galatians');
    });

    test('strips non-alphanumerics', () {
      expect(normalizeBookKey('Song of Solomon'), 'songofsolomon');
    });
  });

  group('ScriptureResolver.resolve', () {
    late AppDatabase db;
    late BibleDataModule bibleData;
    late ScriptureResolver resolver;

    setUp(() {
      db = _makeDb();
      bibleData = BibleDataModule(db);
      resolver = ScriptureResolver(bibleData: bibleData);
    });

    test('valid reference resolves to ok with correct verse text', () async {
      await _seedTranslation(
        db: db,
        id: 'TEST',
        verses: [
          {'translationId': 'TEST', 'bookNumber': 31, 'chapter': 22, 'verse': 6, 'verseText': 'Train up a child'},
        ],
      );

      final result = await resolver.resolve('Proverbs 22:6', forcedTranslationId: 'TEST');

      expect(result.status, PassageStatus.ok);
      expect(result.translationId, 'TEST');
      expect(result.bookNumber, 31);
      expect(result.chapter, 22);
      expect(result.verses.length, 1);
      expect(result.verses[0].verse, 6);
      expect(result.verses[0].text, 'Train up a child');
    });

    test('unparseable reference returns unparseable', () async {
      await _seedTranslation(db: db, id: 'T1', verses: []);

      final result = await resolver.resolve('xyz', forcedTranslationId: 'T1');

      expect(result.status, PassageStatus.unparseable);
    });

    test('book not found returns bookNotFound', () async {
      await _seedTranslation(db: db, id: 'T2', verses: []);

      final result = await resolver.resolve('NonExistentBook 1:1', forcedTranslationId: 'T2');

      expect(result.status, PassageStatus.bookNotFound);
    });

    test('chapter with no verses returns noVerses', () async {
      await _seedTranslation(db: db, id: 'T3', verses: []);

      final result = await resolver.resolve('Genesis 99', forcedTranslationId: 'T3');

      expect(result.status, PassageStatus.noVerses);
      expect(result.bookNumber, 1);
      expect(result.chapter, 99);
    });

    test('no translation installed returns noTranslation', () async {
      // No translations seeded — getInstalledTranslations returns empty
      final result = await resolver.resolve('Genesis 1:1');

      expect(result.status, PassageStatus.noTranslation);
    });

    test('multi-verse range returns all verses in range', () async {
      await _seedTranslation(
        db: db,
        id: 'T4',
        verses: [
          {'translationId': 'T4', 'bookNumber': 19, 'chapter': 23, 'verse': 1, 'verseText': 'The LORD is my shepherd'},
          {'translationId': 'T4', 'bookNumber': 19, 'chapter': 23, 'verse': 2, 'verseText': 'He maketh me to lie down'},
          {'translationId': 'T4', 'bookNumber': 19, 'chapter': 23, 'verse': 3, 'verseText': 'He restoreth my soul'},
        ],
      );

      final result = await resolver.resolve('Psalm 23:1-3', forcedTranslationId: 'T4');

      expect(result.status, PassageStatus.ok);
      expect(result.verses.length, 3);
      expect(result.verses[0].verse, 1);
      expect(result.verses[1].verse, 2);
      expect(result.verses[2].verse, 3);
    });

    test('whole chapter returns all verses', () async {
      await _seedTranslation(
        db: db,
        id: 'T5',
        verses: [
          {'translationId': 'T5', 'bookNumber': 1, 'chapter': 1, 'verse': 1, 'verseText': 'verse one'},
          {'translationId': 'T5', 'bookNumber': 1, 'chapter': 1, 'verse': 2, 'verseText': 'verse two'},
          {'translationId': 'T5', 'bookNumber': 1, 'chapter': 1, 'verse': 3, 'verseText': 'verse three'},
        ],
      );

      final result = await resolver.resolve('Genesis 1', forcedTranslationId: 'T5');

      expect(result.status, PassageStatus.ok);
      expect(result.verses.length, 3);
      expect(result.verses[0].verse, 1);
      expect(result.verses[1].verse, 2);
      expect(result.verses[2].verse, 3);
    });

    test('trailing translation code is stripped before parsing', () async {
      await _seedTranslation(
        db: db,
        id: 'T6',
        verses: [
          {'translationId': 'T6', 'bookNumber': 19, 'chapter': 23, 'verse': 1, 'verseText': 'The LORD is my shepherd'},
        ],
      );

      final result = await resolver.resolve('Psalm 23 NIV', forcedTranslationId: 'T6');

      expect(result.status, PassageStatus.ok);
      expect(result.verses.length, 1);
      expect(result.verses[0].text, 'The LORD is my shepherd');
    });

    test('falls back to first installed translation when no forced ID', () async {
      await _seedTranslation(
        db: db,
        id: 'AUTO',
        verses: [
          {'translationId': 'AUTO', 'bookNumber': 1, 'chapter': 1, 'verse': 1, 'verseText': 'auto verse'},
        ],
      );

      final result = await resolver.resolve('Genesis 1:1');

      expect(result.status, PassageStatus.ok);
      expect(result.translationId, 'AUTO');
    });

    test('single verse reference returns exactly one verse', () async {
      await _seedTranslation(
        db: db,
        id: 'T7',
        verses: [
          {'translationId': 'T7', 'bookNumber': 1, 'chapter': 1, 'verse': 1, 'verseText': 'beginning'},
          {'translationId': 'T7', 'bookNumber': 1, 'chapter': 1, 'verse': 2, 'verseText': 'second'},
          {'translationId': 'T7', 'bookNumber': 1, 'chapter': 1, 'verse': 3, 'verseText': 'third'},
        ],
      );

      final result = await resolver.resolve('Genesis 1:2', forcedTranslationId: 'T7');

      expect(result.status, PassageStatus.ok);
      expect(result.verses.length, 1);
      expect(result.verses[0].verse, 2);
      expect(result.verses[0].text, 'second');
    });

    test('verse range with end verse specified', () async {
      await _seedTranslation(
        db: db,
        id: 'T8',
        verses: [
          {'translationId': 'T8', 'bookNumber': 4, 'chapter': 14, 'verse': 14, 'verseText': 'keep what you have'},
          {'translationId': 'T8', 'bookNumber': 4, 'chapter': 14, 'verse': 15, 'verseText': 'do not lose your crown'},
          {'translationId': 'T8', 'bookNumber': 4, 'chapter': 14, 'verse': 16, 'verseText': 'outside verse'},
        ],
      );

      final result = await resolver.resolve('2 Timothy 14:14-15', forcedTranslationId: 'T8');

      expect(result.status, PassageStatus.ok);
      expect(result.verses.length, 2);
      expect(result.verses[0].verse, 14);
      expect(result.verses[1].verse, 15);
    });
  });
}
