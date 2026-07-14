import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_bible/core/services/storage_service.dart';

class TranslationDownloadService {
  final SupabaseClient client;

  TranslationDownloadService(this.client);

  /// List available translations from the public "Bibles" bucket
  Future<List<String>> listAvailableTranslations() async {
    final files = await client.storage.from('Bibles').list();
    return files.map((f) => f.name).where((name) => name.endsWith('.bdat')).toList();
  }

  /// Download a .bdat file and return its local path
  Future<String> download(String fileName) async {
    final downloadDir = StorageService().downloadsDir;
    await Directory(downloadDir).create(recursive: true);
    final localPath = p.join(downloadDir, fileName);

    // Download from Supabase Storage
    final bytes = await client.storage.from('Bibles').download(fileName);
    final file = File(localPath);
    await file.writeAsBytes(bytes);
    return localPath;
  }
}