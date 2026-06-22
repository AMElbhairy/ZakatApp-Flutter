import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_queue_dao.dart';

void main() {
  late AppDatabase database;
  late SyncQueueDao dao;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    dao = SyncQueueDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('duplicate upsert collapses by dedupe key', () async {
    await dao.enqueue(
      collectionName: 'transactions',
      recordId: 'abc123',
      operation: 'upsert',
      payloadJson: '{"amount":"10"}',
      createdAt: '2026-06-19T10:00:00.000Z',
      availableAt: '2026-06-19T10:00:00.000Z',
      dedupeKey: 'transactions:abc123',
    );
    await dao.enqueue(
      collectionName: 'transactions',
      recordId: 'abc123',
      operation: 'upsert',
      payloadJson: '{"amount":"11"}',
      createdAt: '2026-06-19T10:01:00.000Z',
      availableAt: '2026-06-19T10:01:00.000Z',
      dedupeKey: 'transactions:abc123',
    );

    final rows = await dao.loadReadyBatch();

    expect(rows, hasLength(1));
    expect(rows.single.operation, 'upsert');
    expect(rows.single.payloadJson, '{"amount":"11"}');
  });

  test('delete overrides previous upsert', () async {
    await dao.enqueue(
      collectionName: 'transactions',
      recordId: 'abc123',
      operation: 'upsert',
      payloadJson: '{"amount":"10"}',
      createdAt: '2026-06-19T10:00:00.000Z',
      availableAt: '2026-06-19T10:00:00.000Z',
      dedupeKey: 'transactions:abc123',
    );
    await dao.enqueue(
      collectionName: 'transactions',
      recordId: 'abc123',
      operation: 'delete',
      createdAt: '2026-06-19T10:02:00.000Z',
      availableAt: '2026-06-19T10:02:00.000Z',
      dedupeKey: 'transactions:abc123',
    );

    final rows = await dao.loadReadyBatch();

    expect(rows, hasLength(1));
    expect(rows.single.operation, 'delete');
    expect(rows.single.payloadJson, isNull);
  });
}
