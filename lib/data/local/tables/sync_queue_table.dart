import 'package:drift/drift.dart';

class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get collectionName => text().named('collection_name')();
  TextColumn get recordId => text().named('record_id')();
  TextColumn get operation => text()();
  TextColumn get payloadJson => text().named('payload_json').nullable()();
  TextColumn get createdAt => text().named('created_at')();
  TextColumn get availableAt => text().named('available_at')();
  IntColumn get attemptCount =>
      integer().named('attempt_count').withDefault(const Constant(0))();
  TextColumn get lastError => text().named('last_error').nullable()();
  TextColumn get dedupeKey => text().named('dedupe_key').unique()();
  IntColumn get priority =>
      integer().withDefault(const Constant(0))();
  TextColumn get deviceId => text().named('device_id').nullable()();
}
