import 'package:drift/drift.dart';

class Notes extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get translationId => text()();
  IntColumn get bookNumber => integer()();
  IntColumn get chapter => integer()();
  IntColumn get verse => integer()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}