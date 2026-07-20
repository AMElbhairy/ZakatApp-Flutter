import 'package:drift/drift.dart';

import '../app_database.dart';

class SyncQueueDao extends DatabaseAccessor<AppDatabase> {
  SyncQueueDao(super.db);

  Future<int> enqueue({
    required String collectionName,
    required String recordId,
    required String operation,
    String? payloadJson,
    required String createdAt,
    required String availableAt,
    required String dedupeKey,
    int priority = 0,
    String? deviceId,
  }) async {
    return into(attachedDatabase.syncQueue).insert(
      SyncQueueCompanion.insert(
        collectionName: collectionName,
        recordId: recordId,
        operation: operation,
        createdAt: createdAt,
        availableAt: availableAt,
        dedupeKey: dedupeKey,
        payloadJson: Value<String?>(payloadJson),
        priority: Value<int>(priority),
        deviceId: Value<String?>(deviceId),
      ),
      onConflict: DoUpdate((_) {
        return SyncQueueCompanion(
          operation: Value<String>(operation),
          payloadJson: Value<String?>(payloadJson),
          availableAt: Value<String>(availableAt),
          lastError: const Value<String?>(null),
          priority: Value<int>(priority),
          deviceId: Value<String?>(deviceId),
        );
      }, target: <Column<Object>>[attachedDatabase.syncQueue.dedupeKey]),
    );
  }

  Future<List<SyncQueueData>> loadReadyBatch({String? now, int limit = 25}) {
    final query = select(attachedDatabase.syncQueue);
    if (now != null) {
      query.where((tbl) => tbl.availableAt.isSmallerOrEqualValue(now));
    }
    return (query
          ..orderBy([
            (tbl) => OrderingTerm.desc(attachedDatabase.syncQueue.priority),
            (tbl) => OrderingTerm.asc(attachedDatabase.syncQueue.availableAt),
            (tbl) => OrderingTerm.asc(attachedDatabase.syncQueue.id),
          ])
          ..limit(limit))
        .get();
  }

  Future<int> countQueued() {
    return (select(
      attachedDatabase.syncQueue,
    )).get().then((rows) => rows.length);
  }

  Future<void> deleteQueueRows(List<int> ids) async {
    if (ids.isEmpty) return;
    await (delete(
      attachedDatabase.syncQueue,
    )..where((tbl) => tbl.id.isIn(ids))).go();
  }

  Future<void> updateQueueRetry({
    required int id,
    required int attemptCount,
    required String availableAt,
    required String? lastError,
  }) async {
    await (update(
      attachedDatabase.syncQueue,
    )..where((tbl) => tbl.id.equals(id))).write(
      SyncQueueCompanion(
        attemptCount: Value<int>(attemptCount),
        availableAt: Value<String>(availableAt),
        lastError: Value<String?>(lastError),
      ),
    );
  }
}
