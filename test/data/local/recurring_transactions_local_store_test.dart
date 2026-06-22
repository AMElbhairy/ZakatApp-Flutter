import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart' as db;
import 'package:zakatapp_flutter/data/local/daos/recurring_transactions_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_queue_dao.dart';
import 'package:zakatapp_flutter/data/local/mappers/recurring_transaction_mapper.dart';
import 'package:zakatapp_flutter/data/repositories/local_recurring_transactions_repository.dart';
import 'package:zakatapp_flutter/models/recurring_transaction.dart' as model;

model.RecurringTransaction _recurring({
  required String id,
  bool enabled = true,
}) {
  return model.RecurringTransaction(
    id: id,
    name: 'Recurring $id',
    type: 'expense',
    amount: 125.75,
    currency: 'USD',
    category: 'Bills',
    description: 'Monthly bill',
    dayOfMonth: 15,
    frequency: 'monthly',
    lastProcessed: '2026-06-01',
    enabled: enabled,
    skipMonth: '2026-07',
    createdAt: '2026-06-19T08:00:00.000Z',
  );
}

void main() {
  late db.AppDatabase database;
  late RecurringTransactionsDao dao;
  late LocalRecurringTransactionsRepository repository;
  late RecurringTransactionMapper mapper;

  setUp(() {
    database = db.AppDatabase(executor: NativeDatabase.memory());
    mapper = const RecurringTransactionMapper();
    dao = RecurringTransactionsDao(database, mapper: mapper);
    repository = LocalRecurringTransactionsRepository(
      recurringTransactionsDao: dao,
      syncQueueDao: SyncQueueDao(database),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('mapper round trips recurring transaction rows', () async {
    final model.RecurringTransaction original = _recurring(id: 'rt-1');
    await dao.upsertRecurringTransactionRow(
      original,
      updatedAt: '2026-06-19T09:00:00.000Z',
    );
    final db.RecurringTransaction row = await (database.select(
      database.recurringTransactions,
    )..where((tbl) => tbl.id.equals(original.id))).getSingle();
    final model.RecurringTransaction restored = mapper.fromRow(row);

    expect(restored.id, original.id);
    expect(restored.amount, original.amount);
    expect(restored.skipMonth, original.skipMonth);
  });

  test(
    'repository saves, loads, soft deletes and enqueues recurring transactions',
    () async {
      final model.RecurringTransaction active = _recurring(id: 'active');
      final model.RecurringTransaction inactive = _recurring(
        id: 'inactive',
        enabled: false,
      );

      await repository.importRecurringTransactions(<model.RecurringTransaction>[
        active,
        inactive,
      ]);
      final List<model.RecurringTransaction> loaded = await repository
          .getActiveRecurringTransactions();

      expect(loaded, hasLength(2));
      expect(loaded.first.id, 'active');

      await repository.saveRecurringTransaction(
        _recurring(id: 'queued'),
        now: '2026-06-19T09:00:00.000Z',
      );
      var queue = await database.select(database.syncQueue).get();
      expect(queue, hasLength(1));
      expect(queue.single.collectionName, 'recurring_transactions');
      expect(queue.single.operation, 'upsert');
      expect(queue.single.recordId, 'queued');

      await database.delete(database.syncQueue).go();
      await repository.deleteRecurringTransaction('active');
      queue = await database.select(database.syncQueue).get();
      final List<model.RecurringTransaction> afterDelete = await repository
          .getActiveRecurringTransactions();
      expect(afterDelete, hasLength(2));
      expect(
        afterDelete.map((model.RecurringTransaction item) => item.id),
        containsAll(<String>['inactive', 'queued']),
      );
      expect(queue, hasLength(1));
      expect(queue.single.collectionName, 'recurring_transactions');
      expect(queue.single.operation, 'delete');
      expect(queue.single.recordId, 'active');
    },
  );

  test('replaceAllForLocalMirror overwrites recurring snapshot', () async {
    await repository.importRecurringTransactions(<model.RecurringTransaction>[
      _recurring(id: 'old'),
    ]);

    await repository.replaceAllForLocalMirror(<model.RecurringTransaction>[
      _recurring(id: 'new'),
    ]);

    final List<model.RecurringTransaction> loaded = await repository
        .getActiveRecurringTransactions();
    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'new');
  });
}
