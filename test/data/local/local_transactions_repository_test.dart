import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_queue_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/transactions_dao.dart';
import 'package:zakatapp_flutter/data/repositories/local_transactions_repository.dart';
import 'package:zakatapp_flutter/models/transaction.dart' as model;

void main() {
  late AppDatabase database;
  late LocalTransactionsRepository repository;
  late SyncQueueDao syncQueueDao;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    syncQueueDao = SyncQueueDao(database);
    repository = LocalTransactionsRepository(
      transactionsDao: TransactionsDao(database),
      syncQueueDao: syncQueueDao,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('saveTransaction writes local row and enqueues upsert', () async {
    const transaction = model.Transaction(
      id: 'tx1',
      type: 'income',
      date: '2026-06-19',
      amount: 100,
      currency: 'USD',
      category: 'Salary',
      description: 'Saved',
      createdAt: '2026-06-19T08:00:00.000Z',
      rolledOver: false,
    );

    await repository.saveTransaction(
      transaction,
      now: '2026-06-19T09:00:00.000Z',
      deviceId: 'device-1',
    );

    final rows = await database.select(database.transactions).get();
    final queue = await syncQueueDao.loadReadyBatch();

    expect(rows, hasLength(1));
    expect(rows.single.id, 'tx1');
    expect(rows.single.updatedAt, '2026-06-19T09:00:00.000Z');
    expect(queue, hasLength(1));
    expect(queue.single.dedupeKey, 'transactions:tx1');
    expect(jsonDecode(queue.single.payloadJson!)['id'], 'tx1');
  });

  test('importTransaction writes local row without queue', () async {
    const transaction = model.Transaction(
      id: 'tx-import',
      type: 'expense',
      date: '2026-06-19',
      amount: 20,
      currency: 'USD',
      category: 'Food',
      description: 'Imported',
      createdAt: '2026-06-19T08:00:00.000Z',
      rolledOver: false,
    );

    await repository.importTransaction(
      transaction,
      updatedAt: '2026-06-19T09:00:00.000Z',
    );

    final rows = await database.select(database.transactions).get();
    final queue = await syncQueueDao.loadReadyBatch();

    expect(rows, hasLength(1));
    expect(rows.single.id, 'tx-import');
    expect(queue, isEmpty);
  });

  test(
    'saveTransaction updates the existing queue row for the same id',
    () async {
      const transaction = model.Transaction(
        id: 'tx-dedupe',
        type: 'income',
        date: '2026-06-19',
        amount: 100,
        currency: 'USD',
        category: 'Salary',
        description: 'Initial',
        createdAt: '2026-06-19T08:00:00.000Z',
        rolledOver: false,
      );
      const updatedTransaction = model.Transaction(
        id: 'tx-dedupe',
        type: 'income',
        date: '2026-06-19',
        amount: 150,
        currency: 'USD',
        category: 'Salary',
        description: 'Updated',
        createdAt: '2026-06-19T09:00:00.000Z',
        rolledOver: false,
      );

      await repository.saveTransaction(
        transaction,
        now: '2026-06-19T09:00:00.000Z',
      );
      await repository.saveTransaction(
        updatedTransaction,
        now: '2026-06-19T10:00:00.000Z',
      );

      final rows = await database.select(database.transactions).get();
      final queue = await syncQueueDao.loadReadyBatch();

      expect(rows, hasLength(1));
      expect(queue, hasLength(1));
      expect(queue.single.operation, 'upsert');
      expect(jsonDecode(queue.single.payloadJson!)['amount'], 150);
    },
  );

  test(
    'deleteTransaction updates the existing queue row for the same id',
    () async {
      const transaction = model.Transaction(
        id: 'tx-delete',
        type: 'expense',
        date: '2026-06-19',
        amount: 25,
        currency: 'USD',
        category: 'Food',
        description: 'Delete me',
        createdAt: '2026-06-19T08:00:00.000Z',
        rolledOver: false,
      );

      await repository.saveTransaction(
        transaction,
        now: '2026-06-19T09:00:00.000Z',
      );
      await repository.deleteTransaction(
        'tx-delete',
        now: '2026-06-19T10:00:00.000Z',
      );

      final rows = await database.select(database.transactions).get();
      final queue = await syncQueueDao.loadReadyBatch();

      expect(rows, hasLength(1));
      expect(queue, hasLength(1));
      expect(queue.single.operation, 'delete');
    },
  );
}
