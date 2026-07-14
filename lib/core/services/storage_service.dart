import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyBaseDir = 'base_directory';

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