import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SupabaseBibleRepository {
  final SupabaseClient client;

  SupabaseBibleRepository(this.client);

  // ------------------------------------------------
  // Translations
  // ------------------------------------------------
  Future<void> upsertTranslation({
    required String id,
    required String name,
    required String languageCode,
    required int version,
    String? description,
    String? filePath,
  }) async {
    await client.from('bible_translations').upsert({
      'id': id,
      'name': name,
      'language_code': languageCode,
      'version': version,
      'description': description,
      'file_path': filePath,
      'user_id': client.auth.currentUser!.id,
    });
  }

  Future<List<Map<String, dynamic>>> fetchUserTranslations() async {
    final response = await client
        .from('bible_translations')
        .select()
        .eq('user_id', client.auth.currentUser!.id);
    return response;
  }

  // ------------------------------------------------
  // Notes
  // ------------------------------------------------
  Future<void> upsertNote({
    String? id,
    required String translationId,
    required int bookNumber,
    required int chapter,
    required int verse,
    required String content,
  }) async {
    final noteId = id ?? const Uuid().v4();
    await client.from('bible_notes').upsert({
      'id': noteId,
      'user_id': client.auth.currentUser!.id,
      'translation_id': translationId,
      'book_number': bookNumber,
      'chapter': chapter,
      'verse': verse,
      'content': content,
    });
  }

  Future<void> deleteNote(String id) async {
    await client.from('bible_notes').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> fetchNotesSince(DateTime since) async {
    final response = await client
        .from('bible_notes')
        .select()
        .eq('user_id', client.auth.currentUser!.id)
        .gt('updated_at', since.toIso8601String());
    return response;
  }

  // ------------------------------------------------
  // Highlights
  // ------------------------------------------------
  Future<void> upsertHighlight({
    String? id,
    required String translationId,
    required int bookNumber,
    required int chapter,
    required int verse,
    String? color,
  }) async {
    final highlightId = id ?? const Uuid().v4();
    await client.from('bible_highlights').upsert({
      'id': highlightId,
      'user_id': client.auth.currentUser!.id,
      'translation_id': translationId,
      'book_number': bookNumber,
      'chapter': chapter,
      'verse': verse,
      'color': color,
    });
  }

  Future<void> deleteHighlight(String id) async {
    await client.from('bible_highlights').delete().eq('id', id);
  }

  // ------------------------------------------------
  // Bookmarks
  // ------------------------------------------------
  Future<void> upsertBookmark({
    String? id,
    required String translationId,
    required int bookNumber,
    required int chapter,
    required int verse,
    String? label,
  }) async {
    final bookmarkId = id ?? const Uuid().v4();
    await client.from('bible_bookmarks').upsert({
      'id': bookmarkId,
      'user_id': client.auth.currentUser!.id,
      'translation_id': translationId,
      'book_number': bookNumber,
      'chapter': chapter,
      'verse': verse,
      'label': label,
    });
  }

  Future<void> deleteBookmark(String id) async {
    await client.from('bible_bookmarks').delete().eq('id', id);
  }

  // ------------------------------------------------
  // Reading Position
  // ------------------------------------------------
  Future<void> upsertReadingPosition({
    required String translationId,
    required int bookNumber,
    required int chapter,
    double? scrollOffset,
  }) async {
    await client.from('bible_reading_positions').upsert({
      'user_id': client.auth.currentUser!.id,
      'translation_id': translationId,
      'book_number': bookNumber,
      'chapter': chapter,
      'scroll_offset': scrollOffset,
    });
  }

  Future<Map<String, dynamic>?> fetchReadingPosition(String translationId) async {
    final response = await client
        .from('bible_reading_positions')
        .select()
        .eq('user_id', client.auth.currentUser!.id)
        .eq('translation_id', translationId)
        .maybeSingle();
    return response;
  }
}