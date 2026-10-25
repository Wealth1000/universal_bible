import 'package:drift/drift.dart';

class ReadingPositions extends Table {
  TextColumn get translationId => text()();
  IntColumn get bookNumber => integer()();
  IntColumn get chapter => integer()();
  RealColumn get scrollOffset => real()();  // changed from DoubleColumn
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {translationId};
}