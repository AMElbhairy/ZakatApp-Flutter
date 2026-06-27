import 'package:drift/drift.dart';

class CorrectionFeedbacks extends Table {
  TextColumn get id => text()();
  TextColumn get fieldName => text().named('field_name')();
  TextColumn get originalValue => text().named('original_value')();
  TextColumn get correctedValue => text().named('corrected_value')();
  TextColumn get createdAt => text().named('created_at')();
  TextColumn get updatedAt => text().named('updated_at')();
  TextColumn get deletedAt => text().named('deleted_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
