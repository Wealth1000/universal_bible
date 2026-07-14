import 'package:drift/drift.dart';

class Bookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get translationId => text()();
  IntColumn get bookNumber => integer()();
  IntColumn get chapter => integer()();
  IntColumn get verse => integer()();
  TextColumn get label => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}