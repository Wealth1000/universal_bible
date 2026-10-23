import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_bible/core/providers/database_provider.dart';
import 'package:universal_bible/features/bible/data/bible_data_module.dart';
import 'package:universal_bible/features/bible/domain/reader_session.dart';

/// Single shared BibleDataModule provider. Previously this was
/// copy-pasted as a private provider in five files.
final bibleDataModuleProvider = Provider<BibleDataModule>((ref) {
  final db = ref.watch(databaseProvider);
  return BibleDataModule(db);
});

/// The reader session: owns all domain state mutations for the bible reader.
final readerSessionProvider = Provider<ReaderSession>((ref) {
  return ReaderSession(
    ref: ref,
    bibleData: ref.watch(bibleDataModuleProvider),
  );
});
