import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:universal_bible/core/services/storage_service.dart';
import 'package:universal_bible/core/utils/book_name_utils.dart';
import '../../../../database/app_database.dart';
import '../models/bible_bdat.dart'; // we'll define this
import '../../../../services/download_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Plain-data result of parsing a .bdat file. Built on a background isolate
/// (see [_parseBdatFile]) so it must only contain sendable types.
class ParsedBdat {
  final String id;
  final String name;
  final String language;
  final int version;
  final String? description;
  final int fileSizeBytes;

  /// Each entry: [book, chapter, verse, text-index-into-texts]... kept as
  /// parallel lists to avoid per-verse object overhead across the isolate
  /// boundary.
  final List<int> bookNumbers;
  final List<int> chapters;
  final List<int> verses;
  final List<String> texts;

  final String bookMapJson;
  final String bookDisplayNamesJson;
  final String bookChapterCountsJson;

  ParsedBdat({
    required this.id,
    required this.name,
    required this.language,
    required this.version,
    required this.description,
    required this.fileSizeBytes,
    required this.bookNumbers,
    required this.chapters,
    required this.verses,
    required this.texts,
    required this.bookMapJson,
    required this.bookDisplayNamesJson,
    required this.bookChapterCountsJson,
  });
}

/// Recursively converts all map keys to strings for JSON encoding.
Map<String, dynamic> _convertMapKeysToString(Map<dynamic, dynamic> map) {
  return map.map((key, value) {
    final stringKey = key.toString();
    if (value is Map) {
      return MapEntry(stringKey, _convertMapKeysToString(value));
    } else if (value is List) {
      return MapEntry(
        stringKey,
        value.map((e) {
          if (e is Map) return _convertMapKeysToString(e);
          return e;
        }).toList(),
      );
    } else {
      return MapEntry(stringKey, value);
    }
  });
}

/// Top-level so it can run via [compute]. Does the expensive work: file read,
/// jsonDecode of a whole Bible, and verse-id math — off the UI isolate.
Future<ParsedBdat> _parseBdatFile(String filePath) async {
  final file = File(filePath);
  final jsonStr = await file.readAsString();
  final data = jsonDecode(jsonStr) as Map<String, dynamic>;
  final bdat = BibleBdat.fromJson(data);

  final id =
      bdat.info['abbreviation']?.toUpperCase() ??
      p.basenameWithoutExtension(filePath).toUpperCase();
  final name = bdat.info['name'] ?? id;
  final language = bdat.info['language'] ?? 'en';
  final version = int.tryParse(bdat.info['version'] ?? '1') ?? 1;

  final bookNumbers = <int>[];
  final chapters = <int>[];
  final verses = <int>[];
  final texts = <String>[];
  final bookChapters = <int, Map<int, int>>{};

  bdat.text.forEach((verseIdStr, text) {
    final verseId = int.tryParse(verseIdStr);
    if (verseId == null) return;
    final book = verseId ~/ 1_000_000;
    final remainder = verseId % 1_000_000;
    final chapter = remainder ~/ 1_000;
    final verse = remainder % 1_000;

    bookChapters
        .putIfAbsent(book, () => {})
        .update(chapter, (count) => count + 1, ifAbsent: () => 1);

    bookNumbers.add(book);
    chapters.add(chapter);
    verses.add(verse);
    texts.add(text);
  });

  // Generate display names for each book key
  final displayNames = <String, String>{};
  for (final key in bdat.bookMap.keys) {
    displayNames[key] = cleanBookName(key);
  }

  return ParsedBdat(
    id: id,
    name: name,
    language: language,
    version: version,
    description: bdat.info['description'],
    fileSizeBytes: await file.length(),
    bookNumbers: bookNumbers,
    chapters: chapters,
    verses: verses,
    texts: texts,
    bookMapJson: jsonEncode(_convertMapKeysToString(bdat.bookMap)),
    bookDisplayNamesJson: jsonEncode(displayNames),
    bookChapterCountsJson: jsonEncode(_convertMapKeysToString(bookChapters)),
  );
}

class TranslationRepository {
  final AppDatabase db;

  TranslationRepository(this.db);

  /// Get all installed translations
  Future<List<Translation>> getInstalled() => db.getInstalledTranslations();

  /// Get a single translation by id
  Future<Translation?> get(String id) => db.getTranslation(id);

  /// Import a .bdat file from a local file path. Parsing runs on a
  /// background isolate so the UI stays responsive during bulk imports.
  Future<void> importFromFile(String filePath) async {
    final parsed = await compute(_parseBdatFile, filePath);

    final storage = StorageService();
    final destDir = storage.translationsDir;
    await Directory(destDir).create(recursive: true);
    final destPath = p.join(destDir, '${parsed.id}.bdat');
    await File(filePath).copy(destPath);

    final companions = <VersesCompanion>[
      for (var i = 0; i < parsed.texts.length; i++)
        VersesCompanion(
          translationId: Value(parsed.id),
          bookNumber: Value(parsed.bookNumbers[i]),
          chapter: Value(parsed.chapters[i]),
          verse: Value(parsed.verses[i]),
          verseText: Value(parsed.texts[i]),
        ),
    ];

    await db.insertVerses(companions);

    final companion = TranslationsCompanion(
      name: Value(parsed.name),
      languageCode: Value(parsed.language),
      version: Value(parsed.version),
      description: Value(parsed.description),
      installed: const Value(true),
      installedSizeBytes: Value(parsed.fileSizeBytes),
      installedAt: Value(DateTime.now()),
      bookMapJson: Value(parsed.bookMapJson),
      bookDisplayNamesJson: Value(parsed.bookDisplayNamesJson),
      bookChapterCountsJson: Value(parsed.bookChapterCountsJson),
      filePath: Value(destPath),
    );

    // Check if translation already exists
    final existing = await db.getTranslation(parsed.id);
    if (existing != null) {
      // Update existing
      await (db.update(
        db.translations,
      )..where((t) => t.id.equals(parsed.id))).write(companion);
    } else {
      // Insert new
      await db
          .into(db.translations)
          .insert(companion.copyWith(id: Value(parsed.id)));
    }
  }

  final downloadService = TranslationDownloadService(Supabase.instance.client);

  Future<void> downloadAndImport(String translationId) async {
    final fileName = '$translationId.bdat'; // or use the actual file name
    final localPath = await downloadService.download(fileName);
    await importFromFile(localPath);
  }
}
