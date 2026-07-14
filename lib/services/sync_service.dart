import 'package:drift/drift.dart'; // For Value
import '../database/app_database.dart';
import 'supabase/bible_repository.dart';
import 'package:flutter/foundation.dart';

class SyncService {
  final AppDatabase local;
  final SupabaseBibleRepository remote;

  SyncService({required this.local, required this.remote});

  Future<void> syncAll() async {
    await _syncTranslations();
    await _syncNotes();
    await _syncHighlights();      // now defined below
    await _syncBookmarks();       // now defined below
    await _syncReadingPositions(); // now defined below
  }

  // ------------------------------------------------
  // Translations sync
  // ------------------------------------------------
  Future<void> _syncTranslations() async {
  final remoteTranslations = await remote.fetchUserTranslations();
  for (final json in remoteTranslations) {
    await local.upsertTranslation(TranslationsCompanion(
      id: Value(json['id'] as String),
      name: Value(json['name'] as String),
      languageCode: Value(json['language_code'] as String),
      version: Value(json['version'] as int),
      description: Value(json['description'] as String?),
      installed: Value(false),
      installedSizeBytes: Value(null),
      installedAt: Value(null),
      bookMapJson: Value('{}'),
      filePath: Value(null),
    ));
  }
}

  // ------------------------------------------------
  // Notes sync
  // ------------------------------------------------
  Future<void> _syncNotes() async {
    final remoteNotes = await remote.fetchNotesSince(DateTime(1970));
    for (final json in remoteNotes) {
      await local.insertNote(NotesCompanion(
        id: Value(json['id'] as String),
        translationId: Value(json['translation_id'] as String),
        bookNumber: Value(json['book_number'] as int),
        chapter: Value(json['chapter'] as int),
        verse: Value(json['verse'] as int),
        content: Value(json['content'] as String),
        createdAt: Value(DateTime.parse(json['created_at'] as String)),
        updatedAt: Value(DateTime.parse(json['updated_at'] as String)),
      ));
    }
  }

  // ------------------------------------------------
  // Highlights sync (stub – implement later)
  // ------------------------------------------------
  Future<void> _syncHighlights() async {
    // TODO: Implement highlights sync
    debugPrint('📝 Highlights sync placeholder');
  }

  // ------------------------------------------------
  // Bookmarks sync (stub – implement later)
  // ------------------------------------------------
  Future<void> _syncBookmarks() async {
    // TODO: Implement bookmarks sync
    debugPrint('📑 Bookmarks sync placeholder');
  }

  // ------------------------------------------------
  // Reading positions sync (stub – implement later)
  // ------------------------------------------------
  Future<void> _syncReadingPositions() async {
    // TODO: Implement reading positions sync
    debugPrint('📍 Reading positions sync placeholder');
  }

  // ------------------------------------------------
  // Full sync (we'll implement incremental sync later)
  // ------------------------------------------------
}