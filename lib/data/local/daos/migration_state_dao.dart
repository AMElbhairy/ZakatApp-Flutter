import 'package:drift/drift.dart';

import '../app_database.dart';

const String jsonToSqliteV1StartedAt = 'json_to_sqlite_v1_started_at';
const String jsonToSqliteV1CompletedAt = 'json_to_sqlite_v1_completed_at';
const String jsonToSqliteV1FailedAt = 'json_to_sqlite_v1_failed_at';
const String jsonToSqliteV1Error = 'json_to_sqlite_v1_error';

class MigrationStateDao extends DatabaseAccessor<AppDatabase> {
  MigrationStateDao(super.db);

  Future<String?> getValue(String key) async {
    final MigrationStateData? row = await (select(
      attachedDatabase.migrationState,
    )..where((tbl) => tbl.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue(String key, String value) {
    return into(attachedDatabase.migrationState).insertOnConflictUpdate(
      MigrationStateCompanion.insert(key: key, value: value),
    );
  }

  Future<void> clearValue(String key) {
    return (delete(
      attachedDatabase.migrationState,
    )..where((tbl) => tbl.key.equals(key))).go();
  }

  Future<bool> hasCompletedJsonToSqliteV1() async {
    final String? completedAt = await getValue(jsonToSqliteV1CompletedAt);
    return completedAt != null && completedAt.trim().isNotEmpty;
  }
}
