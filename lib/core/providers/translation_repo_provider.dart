import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_bible/core/providers/database_provider.dart';
import 'package:universal_bible/features/bible/data/repositories/translation_repository.dart';

/// Single shared TranslationRepository provider. Previously this was
/// copy-pasted as a private provider in five files.
final translationRepoProvider = Provider<TranslationRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TranslationRepository(db);
});
