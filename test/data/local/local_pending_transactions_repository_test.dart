import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart'
    hide PendingTransaction;
import 'package:zakatapp_flutter/data/local/daos/pending_transactions_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_queue_dao.dart';
import 'package:zakatapp_flutter/data/repositories/local_pending_transactions_repository.dart';
import 'package:zakatapp_flutter/models/pending_transaction.dart' as model;

void main() {
  late AppDatabase database;
  late LocalPendingTransactionsRepository repository;

  const pending = model.PendingTransaction(
    id: 'pt1',
    source: 'manual',
    rawMessage: 'message',
    createdAt: '2026-06-19T08:00:00.000Z',
    suggestedType: 'expense',
    suggestedAmount: 10.5,
    suggestedCurrency: 'USD',
    confidence: 0.9,
    status: model.CaptureStatus.pendingReview,
  );

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    repository = LocalPendingTransactionsRepository(
      pendingTransactionsDao: PendingTransactionsDao(database),
      syncQueueDao: SyncQueueDao(database),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'savePendingTransaction writes local row and enqueues sync item',
    () async {
      await repository.savePendingTransaction(
        pending,
        now: '2026-06-19T09:00:00.000Z',
      );

      final rows = await database.select(database.pendingTransactions).get();
      final queue = await database.select(database.syncQueue).get();

      expect(rows, hasLength(1));
      expect(rows.single.updatedAt, '2026-06-19T09:00:00.000Z');
      expect(rows.single.id, 'pt1');
      expect(queue, hasLength(1));
      expect(queue.single.collectionName, 'pending_transactions');
      expect(queue.single.operation, 'upsert');
      expect(queue.single.recordId, 'pt1');
    },
  );

  test('importPendingTransaction writes local row without queue', () async {
    await repository.importPendingTransaction(
      pending,
      updatedAt: '2026-06-19T09:00:00.000Z',
    );

    expect(
      await database.select(database.pendingTransactions).get(),
      hasLength(1),
    );
  });

  test(
    'deletePendingTransaction writes tombstone and enqueues delete',
    () async {
      await repository.savePendingTransaction(
        pending,
        now: '2026-06-19T09:00:00.000Z',
      );
      await database.delete(database.syncQueue).go();

      await repository.deletePendingTransaction(
        'pt1',
        now: '2026-06-19T10:00:00.000Z',
      );

      final rows = await database.select(database.pendingTransactions).get();
      final queue = await database.select(database.syncQueue).get();
      expect(rows.single.deletedAt, '2026-06-19T10:00:00.000Z');
      expect(queue, hasLength(1));
      expect(queue.single.collectionName, 'pending_transactions');
      expect(queue.single.operation, 'delete');
      expect(queue.single.recordId, 'pt1');
    },
  );

  test(
    'applyRemoteDeletePendingTransaction writes tombstone without queue',
    () async {
      await repository.importPendingTransaction(
        pending,
        updatedAt: '2026-06-19T09:00:00.000Z',
      );
      await repository.applyRemoteDeletePendingTransaction(
        'pt1',
        deletedAt: '2026-06-19T10:00:00.000Z',
      );

      final rows = await database.select(database.pendingTransactions).get();
      expect(rows.single.deletedAt, '2026-06-19T10:00:00.000Z');
    },
  );
}
