import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_queue_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/transactions_dao.dart';
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
import 'package:zakatapp_flutter/data/repositories/local_transactions_repository.dart';
import 'package:zakatapp_flutter/models/transaction.dart' as model;
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import '../support/recording_firestore_sync_manager.dart';

class _StaticGate implements UseSqliteLocalStoreProvider {
  _StaticGate(this.value);

  final bool value;

  @override
  Future<bool> prepareForRead({String? userId}) async => value;
}

class _ThrowingTransactionsRepository implements TransactionsLocalStore {
  _ThrowingTransactionsRepository(this.seed);

  final List<model.Transaction> seed;

  @override
  Future<void> deleteTransaction(
    String id, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) {
    throw StateError('sqlite delete failed');
  }

  @override
  Future<List<model.Transaction>> getActiveTransactions() async => seed;

  @override
  Future<void> replaceAllForLocalMirror(
    Iterable<model.Transaction> transactions,
  ) async {}

  @override
  Future<void> saveTransaction(
    model.Transaction transaction, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) {
    throw StateError('sqlite save failed');
  }

  @override
  Stream<List<model.Transaction>> watchActiveTransactions() async* {
    yield seed;
  }
}

Future<AppStateController> _makeController({
  required TransactionsLocalStore localStore,
  required bool useSqlite,
  Map<String, Object>? initialValues,
}) async {
  SharedPreferences.setMockInitialValues(initialValues ?? <String, Object>{});
  const localStorage = LocalStorageService();
  final repository = AppStateRepository(localStorage: localStorage);
  final controller = AppStateController(
    repository: repository,
    localTransactionsRepository: localStore,
    useSqliteLocalStoreProvider: _StaticGate(useSqlite),
  );
  await controller.load();
  return controller;
}

void main() {
  test(
    'SQLite mode save writes through repository and enqueues upsert',
    () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      final syncQueueDao = SyncQueueDao(database);
      final localRepository = LocalTransactionsRepository(
        transactionsDao: TransactionsDao(database),
        syncQueueDao: syncQueueDao,
      );
      final controller = await _makeController(
        localStore: localRepository,
        useSqlite: true,
      );

      const transaction = model.Transaction(
        id: 'tx1',
        type: 'income',
        date: '2026-06-19',
        amount: 100,
        currency: 'USD',
        category: 'Salary',
        description: 'saved',
        createdAt: '2026-06-19T08:00:00.000Z',
        rolledOver: false,
      );

      await controller.addTransaction(transaction);

      final rows = await database.select(database.transactions).get();
      final queue = await syncQueueDao.loadReadyBatch();

      expect(rows, hasLength(1));
      expect(rows.single.id, 'tx1');
      expect(queue, hasLength(1));
      expect(queue.single.operation, 'upsert');
      expect(
        controller.state.transactions.map((model.Transaction tx) => tx.id),
        ['tx1'],
      );
      expect(
        jsonDecode(
          (await const LocalStorageService().loadString('zakatAppData'))!,
        )['transactions'][0]['id'],
        'tx1',
      );

      await database.close();
    },
  );

  test('SQLite mode delete tombstones row and enqueues delete', () async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    final syncQueueDao = SyncQueueDao(database);
    final localRepository = LocalTransactionsRepository(
      transactionsDao: TransactionsDao(database),
      syncQueueDao: syncQueueDao,
    );
    await localRepository.importTransaction(
      const model.Transaction(
        id: 'tx1',
        type: 'income',
        date: '2026-06-19',
        amount: 100,
        currency: 'USD',
        category: 'Salary',
        description: 'saved',
        createdAt: '2026-06-19T08:00:00.000Z',
        rolledOver: false,
      ),
      updatedAt: '2026-06-19T08:00:00.000Z',
    );
    final controller = await _makeController(
      localStore: localRepository,
      useSqlite: true,
    );

    await controller.deleteTransaction('tx1');

    final rows = await database.select(database.transactions).get();
    final queue = await syncQueueDao.loadReadyBatch();

    expect(rows, hasLength(1));
    expect(rows.single.deletedAt, isNotNull);
    expect(queue, hasLength(1));
    expect(queue.single.operation, 'delete');
    expect(controller.state.transactions, isEmpty);

    await database.close();
  });

  test('transaction edit does not trigger full-list Firestore sync', () async {
    final recordingFirestore = RecordingFirestoreSyncManager(uid: 'user-1');
    final controller = AppStateController(
      repository: AppStateRepository(localStorage: const LocalStorageService()),
      firestoreSyncManager: recordingFirestore,
      useSqliteLocalStoreProvider: _StaticGate(false),
    );

    await controller.updateState(
      controller.state.copyWith(
        userId: 'user-1',
        transactions: <model.Transaction>[
          const model.Transaction(
            id: 'tx-edit',
            type: 'income',
            date: '2026-06-19',
            amount: 100,
            currency: 'USD',
            category: 'Salary',
            description: 'original',
            createdAt: '2026-06-19T08:00:00.000Z',
            rolledOver: false,
          ),
        ],
      ),
    );

    await controller.startLiveFirestoreSync(userId: 'user-1');
    recordingFirestore.transactionSyncCalls = 0;

    final model.Transaction updated = const model.Transaction(
      id: 'tx-edit',
      type: 'income',
      date: '2026-06-19',
      amount: 150,
      currency: 'USD',
      category: 'Salary',
      description: 'updated',
      createdAt: '2026-06-19T09:00:00.000Z',
      rolledOver: false,
    );

    await controller.updateTransaction(updated);

    expect(recordingFirestore.transactionSyncCalls, 0);
  });

  test('SQLite write failure falls back to old JSON path', () async {
    final controller = await _makeController(
      localStore: _ThrowingTransactionsRepository(const <model.Transaction>[]),
      useSqlite: true,
    );

    await controller.addTransaction(
      const model.Transaction(
        id: 'tx-fallback',
        type: 'income',
        date: '2026-06-19',
        amount: 100,
        currency: 'USD',
        category: 'Salary',
        description: 'fallback',
        createdAt: '2026-06-19T08:00:00.000Z',
        rolledOver: false,
      ),
    );

    expect(controller.state.transactions, hasLength(1));
    expect(controller.state.transactions.single.id, 'tx-fallback');
    expect(
      jsonDecode(
        (await const LocalStorageService().loadString('zakatAppData'))!,
      )['transactions'][0]['id'],
      'tx-fallback',
    );
  });

  test('JSON mode save and delete remain unchanged', () async {
    final controller = await _makeController(
      localStore: _ThrowingTransactionsRepository(const <model.Transaction>[]),
      useSqlite: false,
    );

    await controller.addTransaction(
      const model.Transaction(
        id: 'json-tx',
        type: 'income',
        date: '2026-06-19',
        amount: 100,
        currency: 'USD',
        category: 'Salary',
        description: 'json',
        createdAt: '2026-06-19T08:00:00.000Z',
        rolledOver: false,
      ),
    );
    expect(controller.state.transactions.single.id, 'json-tx');

    await controller.deleteTransaction('json-tx');
    expect(controller.state.transactions, isEmpty);
  });
}
