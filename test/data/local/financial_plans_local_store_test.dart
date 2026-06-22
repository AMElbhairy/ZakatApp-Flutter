import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart' as db;
import 'package:zakatapp_flutter/data/local/daos/financial_plans_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_queue_dao.dart';
import 'package:zakatapp_flutter/data/local/mappers/financial_plan_mapper.dart';
import 'package:zakatapp_flutter/data/repositories/local_financial_plans_repository.dart';
import 'package:zakatapp_flutter/models/financial_plan.dart' as model;

model.FinancialPlan _plan({required String id, bool isActive = true}) {
  return model.FinancialPlan(
    id: id,
    name: 'Plan $id',
    startDate: '2026-06-01',
    projectionCurrency: 'USD',
    startingBalance: 1200.5,
    startingBalanceDate: '2026-06-01',
    startingBalanceMode: 'manual',
    snapshotWealthCurrency: 'USD',
    startingAssetBreakdown: <String, double>{'cash': 1200.5},
    monthlyIncome: 4000,
    monthlyExpenses: 2500,
    includeInstallments: true,
    includeZakat: false,
    durationYears: 2,
    createdAt: '2026-06-19T08:00:00.000Z',
    isActive: isActive,
    startingAssets: 5000,
    startingLiabilities: 1000,
    startingNetWorth: 4000,
    startingNisabSnapshot: 4500,
    startingGoldPriceSnapshot: 3000,
    startingFxSnapshot: <String, double>{'USD': 1},
  );
}

void main() {
  late db.AppDatabase database;
  late FinancialPlansDao dao;
  late LocalFinancialPlansRepository repository;
  late FinancialPlanMapper mapper;

  setUp(() {
    database = db.AppDatabase(executor: NativeDatabase.memory());
    mapper = const FinancialPlanMapper();
    dao = FinancialPlansDao(database, mapper: mapper);
    repository = LocalFinancialPlansRepository(
      financialPlansDao: dao,
      syncQueueDao: SyncQueueDao(database),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('mapper round trips locked schema fields', () async {
    final model.FinancialPlan original = _plan(id: 'plan-1');
    await dao.upsertFinancialPlanRow(
      original,
      updatedAt: '2026-06-19T09:00:00.000Z',
    );
    final db.FinancialPlan row = await (database.select(
      database.financialPlans,
    )..where((tbl) => tbl.id.equals(original.id))).getSingle();
    final model.FinancialPlan restored = mapper.fromRow(row);
    expect(restored.id, original.id);
    expect(restored.startingAssetBreakdown, original.startingAssetBreakdown);
    expect(restored.startingFxSnapshot, original.startingFxSnapshot);
  });

  test(
    'repository saves, loads, soft deletes, and enqueues financial plans',
    () async {
      final model.FinancialPlan active = _plan(id: 'plan-active');
      final model.FinancialPlan inactive = _plan(
        id: 'plan-inactive',
        isActive: false,
      );

      await repository.importFinancialPlans(<model.FinancialPlan>[
        active,
        inactive,
      ]);
      final List<model.FinancialPlan> loaded = await repository
          .getActiveFinancialPlans();

      expect(loaded, hasLength(2));
      expect(loaded.first.id, 'plan-active');

      await repository.saveFinancialPlan(
        _plan(id: 'plan-updated'),
        now: '2026-06-19T09:00:00.000Z',
      );
      var queue = await database.select(database.syncQueue).get();
      expect(queue, hasLength(1));
      expect(queue.single.collectionName, 'financial_plans');
      expect(queue.single.operation, 'upsert');
      expect(queue.single.recordId, 'plan-updated');

      await database.delete(database.syncQueue).go();
      await repository.deleteFinancialPlan('plan-active');
      queue = await database.select(database.syncQueue).get();
      final List<model.FinancialPlan> afterDelete = await repository
          .getActiveFinancialPlans();
      expect(afterDelete, hasLength(2));
      expect(
        afterDelete.map((model.FinancialPlan plan) => plan.id),
        containsAll(<String>['plan-inactive', 'plan-updated']),
      );
      expect(queue, hasLength(1));
      expect(queue.single.collectionName, 'financial_plans');
      expect(queue.single.operation, 'delete');
      expect(queue.single.recordId, 'plan-active');
    },
  );

  test('replaceAllForLocalMirror overwrites snapshot', () async {
    await repository.importFinancialPlans(<model.FinancialPlan>[
      _plan(id: 'old'),
    ]);

    await repository.replaceAllForLocalMirror(<model.FinancialPlan>[
      _plan(id: 'new'),
    ]);

    final List<model.FinancialPlan> loaded = await repository
        .getActiveFinancialPlans();
    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'new');
  });
}
