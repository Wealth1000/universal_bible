import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// The last reading position persisted across sessions.
class ReadingPositionRecord {
  final String translationId;
  final int book;
  final int chapter;

  const ReadingPositionRecord({
    required this.translationId,
    required this.book,
    required this.chapter,
  });
}

class StorageService {
  static const String _keyBaseDir = 'base_directory';
  static const String _keyReadingTranslation = 'reading_position.translation';
  static const String _keyReadingBook = 'reading_position.book';
  static const String _keyReadingChapter = 'reading_position.chapter';

  late final String baseDir;
  late final SharedPreferences _prefs;

  // Singleton pattern – you can also use Riverpod for this.
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  /// Initialize the service: load base directory from prefs or create default.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final savedDir = _prefs.getString(_keyBaseDir);
    if (savedDir != null && await Directory(savedDir).exists()) {
      baseDir = savedDir;
    } else {
      // Default: ~/Documents/universal_bible
      final appDocDir = await getApplicationDocumentsDirectory();
      baseDir = p.join(appDocDir.path, 'universal_bible');
    }
    // Ensure the base directory exists
    await Directory(baseDir).create(recursive: true);
  }

  /// Change the base directory.
  ///
  /// This does NOT move existing files – it only updates the setting.
  /// The app will use the new location from now on.
  Future<void> setBaseDirectory(String newPath) async {
    final dir = Directory(newPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    baseDir = newPath;
    await _prefs.setString(_keyBaseDir, newPath);
  }

  // --- Reading position (cross-session) ---

  /// The last persisted reading position, or null if never saved.
  /// Sync because [init] loads prefs before runApp.
  ReadingPositionRecord? get lastReadingPosition {
    final translationId = _prefs.getString(_keyReadingTranslation);
    final book = _prefs.getInt(_keyReadingBook);
    final chapter = _prefs.getInt(_keyReadingChapter);
    if (translationId == null || book == null || chapter == null) return null;
    return ReadingPositionRecord(
      translationId: translationId,
      book: book,
      chapter: chapter,
    );
  }

  Future<void> saveReadingPosition({
    required String translationId,
    required int book,
    required int chapter,
  }) async {
    await _prefs.setString(_keyReadingTranslation, translationId);
    await _prefs.setInt(_keyReadingBook, book);
    await _prefs.setInt(_keyReadingChapter, chapter);
  }

  /// Updates only the translation component of the reading position.
  /// Book/chapter are left untouched so switching translations does not
  /// reset where the user was reading.
  Future<void> saveReadingTranslation(String translationId) async {
    await _prefs.setString(_keyReadingTranslation, translationId);
  }

  // --- Subdirectories ---

  String get databasePath => p.join(baseDir, 'bible_app.db');

  String get translationsDir => p.join(baseDir, 'translations');

  String get downloadsDir => p.join(baseDir, 'downloads');

  String get logsDir => p.join(baseDir, 'logs');

  /// Ensure subdirectories exist.
  Future<void> ensureSubDirs() async {
    await Directory(translationsDir).create(recursive: true);
    await Directory(downloadsDir).create(recursive: true);
    await Directory(logsDir).create(recursive: true);
  }
}