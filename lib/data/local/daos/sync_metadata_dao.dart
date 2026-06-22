import 'package:drift/drift.dart';

import '../app_database.dart';

const String lastSyncSuccessAtKey = 'last_sync_success_at';
const String lastPushSuccessAtKey = 'last_push_success_at';
const String lastPullSuccessAtKey = 'last_pull_success_at';

String syncCursorKeyFor(String collection) => '${collection}_cursor';
String syncDeletedCursorKeyFor(String collection) =>
    '${collection}_deleted_cursor';

class SyncMetadataDao extends DatabaseAccessor<AppDatabase> {
  SyncMetadataDao(super.db);

  Future<String?> getValue(String key) async {
    final SyncMetadataData? row = await (select(
      attachedDatabase.syncMetadata,
    )..where((tbl) => tbl.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue(String key, String value) {
    return into(attachedDatabase.syncMetadata).insertOnConflictUpdate(
      SyncMetadataCompanion(
        key: Value<String>(key),
        value: Value<String>(value),
      ),
    );
  }

  Future<String?> getCursor(String collection) {
    return getValue(syncCursorKeyFor(collection));
  }

  Future<void> setCursor(String collection, String value) {
    return setValue(syncCursorKeyFor(collection), value);
  }

  Future<String?> getDeletedCursor(String collection) {
    return getValue(syncDeletedCursorKeyFor(collection));
  }

  Future<void> setDeletedCursor(String collection, String value) {
    return setValue(syncDeletedCursorKeyFor(collection), value);
  }

  Future<String?> getLastPushSuccessAt() {
    return getValue(lastPushSuccessAtKey);
  }

  Future<void> setLastPushSuccessAt(String value) {
    return setValue(lastPushSuccessAtKey, value);
  }

  Future<String?> getLastPullSuccessAt() {
    return getValue(lastPullSuccessAtKey);
  }

  Future<void> setLastPullSuccessAt(String value) {
    return setValue(lastPullSuccessAtKey, value);
  }
}
