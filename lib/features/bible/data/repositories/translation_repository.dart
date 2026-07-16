import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:universal_bible/core/services/storage_service.dart';
import 'package:universal_bible/core/utils/book_name_utils.dart';
import '../../../../database/app_database.dart';
import '../models/bible_bdat.dart'; // we'll define this
import '../../../../services/download_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TranslationRepository {
  final AppDatabase db;

  TranslationRepository(this.db);

  /// Get all installed translations
  Future<List<Translation>> getInstalled() => db.getInstalledTranslations();

  /// Get a single translation by id
  Future<Translation?> get(String id) => db.getTranslation(id);

  /// Import a .bdat file from a local file path
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

  Future<void> importFromFile(String filePath) async {
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

    final storage = StorageService();
    final destDir = storage.translationsDir;
    await Directory(destDir).create(recursive: true);
    final destPath = p.join(destDir, '$id.bdat');
    await file.copy(destPath);

    final companions = <VersesCompanion>[];
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

      companions.add(
        VersesCompanion(
          translationId: Value(id),
          bookNumber: Value(book),
          chapter: Value(chapter),
          verse: Value(verse),
          verseText: Value(text),
        ),
      );
    });

    await db.insertVerses(companions);

    // Convert both maps to have string keys
    final bookMapJson = jsonEncode(_convertMapKeysToString(bdat.bookMap));
    final bookChaptersJson = jsonEncode(_convertMapKeysToString(bookChapters));
    //Generate Display names for each book key
    final displayNames = <String, String>{};
    for (final key in bdat.bookMap.keys) {
      displayNames[key] = cleanBookName(key);
    }
    // Check if translation already exists
    final existing = await db.getTranslation(id);
    if (existing != null) {
      // Update existing
      await (db.update(db.translations)..where((t) => t.id.equals(id))).write(
        TranslationsCompanion(
          name: Value(name),
          languageCode: Value(language),
          version: Value(version),
          description: Value(bdat.info['description']),
          installed: Value(true),
          installedSizeBytes: Value(await file.length()),
          installedAt: Value(DateTime.now()),
          bookMapJson: Value(bookMapJson),
          bookDisplayNamesJson: Value(jsonEncode(displayNames)),
          bookChapterCountsJson: Value(bookChaptersJson),
          filePath: Value(destPath),
        ),
      );
    } else {
      // Insert new
      await db
          .into(db.translations)
          .insert(
            TranslationsCompanion(
              id: Value(id),
              name: Value(name),
              languageCode: Value(language),
              version: Value(version),
              description: Value(bdat.info['description']),
              installed: Value(true),
              installedSizeBytes: Value(await file.length()),
              installedAt: Value(DateTime.now()),
              bookMapJson: Value(bookMapJson),
              bookDisplayNamesJson: Value(jsonEncode(displayNames)),
              bookChapterCountsJson: Value(bookChaptersJson),
              filePath: Value(destPath),
            ),
          );
    }
  }

  final downloadService = TranslationDownloadService(Supabase.instance.client);

  Future<void> downloadAndImport(String translationId) async {
    final fileName = '$translationId.bdat'; // or use the actual file name
    final localPath = await downloadService.download(fileName);
    await importFromFile(localPath);
  }
}
