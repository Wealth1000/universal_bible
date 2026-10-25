import 'package:drift/drift.dart';

class Highlights extends Table {
  TextColumn get id => text()();
  TextColumn get translationId => text()();
  IntColumn get bookNumber => integer()();
  IntColumn get chapter => integer()();
  IntColumn get verse => integer()();
  TextColumn get color => text()(); // e.g. 'yellow', 'green'
  DateTimeColumn get createdAt => dateTime()();
}