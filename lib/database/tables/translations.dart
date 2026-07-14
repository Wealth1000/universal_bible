import 'package:drift/drift.dart';

class Translations extends Table {
  TextColumn get id => text()(); // e.g. 'KJV', 'ESV'
  TextColumn get name => text()();
  TextColumn get languageCode => text()();
  IntColumn get version => integer()();
  TextColumn get description => text().nullable()();
  BoolColumn get installed => boolean()();
  IntColumn get installedSizeBytes => integer().nullable()();
  DateTimeColumn get installedAt => dateTime().nullable()();
  TextColumn get bookMapJson => text()(); // JSON of bookMap
  TextColumn get filePath => text().nullable()(); // path to .bdat file
  TextColumn get bookChapterCountsJson => text().nullable()();//JSON map of book number -> {chapterNumber: verseCount}

  @override
  Set<Column> get primaryKey => {id};
}