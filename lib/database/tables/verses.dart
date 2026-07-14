import 'package:drift/drift.dart';

@TableIndex(name: 'translation_book_chapter', columns: {#translationId, #bookNumber, #chapter})
class Verses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get translationId => text()();
  IntColumn get bookNumber => integer()();
  IntColumn get chapter => integer()();
  IntColumn get verse => integer()();
  TextColumn get verseText => text()();
}