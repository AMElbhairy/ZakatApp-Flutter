import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/daos/investments_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_queue_dao.dart';
import 'package:zakatapp_flutter/data/repositories/local_investments_repository.dart';
import 'package:zakatapp_flutter/models/investment_asset.dart' as model;

void main() {
  late AppDatabase database;
  late LocalInvestmentsRepository repository;

  const investment = model.InvestmentAsset(
    id: 'inv1',
    investmentType: 'real_estate',
    assetSubtype: 'apartment',
    ownershipType: 'fully_owned',
    valuationMode: 'net_fair',
    currency: 'USD',
    originalPrice: 100000,
    totalInterest: 0,
    totalPayable: 100000,
    paidAmount: 100000,
    remainingAmount: 0,
    installmentPlan: <Map<String, dynamic>>[],
    valuationDate: '2026-06-18',
    marketValue: 120000,
    marketValueDate: '2026-06-18',
    valuationSource: 'manual',
    loanBalance: 0,
    loanAsOfDate: '2026-06-18',
    paidAmountToDate: 100000,
    ownershipSharePct: 100,
    country: 'US',
    location: 'NY',
    inflationRateAnnual: 3,
    estimatedCurrentValue: 120000,
    description: 'Investment',
    noZakat: true,
    createdAt: '2026-06-18T08:00:00.000Z',
  );

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    repository = LocalInvestmentsRepository(
      investmentsDao: InvestmentsDao(database),
      syncQueueDao: SyncQueueDao(database),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('saveInvestment writes local row and enqueues sync item', () async {
    await repository.saveInvestment(
      investment,
      now: '2026-06-19T09:00:00.000Z',
    );

    final rows = await database.select(database.investments).get();
    final queue = await database.select(database.syncQueue).get();

    expect(rows, hasLength(1));
    expect(rows.single.updatedAt, '2026-06-19T09:00:00.000Z');
    expect(rows.single.id, 'inv1');
    expect(queue, hasLength(1));
    expect(queue.single.collectionName, 'investments');
    expect(queue.single.operation, 'upsert');
    expect(queue.single.recordId, 'inv1');
  });

  test('importInvestment writes local row without queue', () async {
    await repository.importInvestment(
      investment,
      updatedAt: '2026-06-19T09:00:00.000Z',
    );

    expect(await database.select(database.investments).get(), hasLength(1));
  });

  test('deleteInvestment writes tombstone and enqueues delete', () async {
    await repository.saveInvestment(
      investment,
      now: '2026-06-19T09:00:00.000Z',
    );
    await database.delete(database.syncQueue).go();

    await repository.deleteInvestment('inv1', now: '2026-06-19T10:00:00.000Z');

    final rows = await database.select(database.investments).get();
    final queue = await database.select(database.syncQueue).get();

    expect(rows.single.deletedAt, '2026-06-19T10:00:00.000Z');
    expect(queue, hasLength(1));
    expect(queue.single.collectionName, 'investments');
    expect(queue.single.operation, 'delete');
    expect(queue.single.recordId, 'inv1');
  });

  test('applyRemoteDeleteInvestment writes tombstone without queue', () async {
    await repository.importInvestment(
      investment,
      updatedAt: '2026-06-19T09:00:00.000Z',
    );
    await repository.applyRemoteDeleteInvestment(
      'inv1',
      deletedAt: '2026-06-19T10:00:00.000Z',
    );

    final rows = await database.select(database.investments).get();

    expect(rows.single.deletedAt, '2026-06-19T10:00:00.000Z');
  });

  test('saveInvestment preserves yearlyGrowthRate', () async {
    final investmentWithGrowth = model.InvestmentAsset(
      id: 'inv2',
      investmentType: 'real_estate',
      assetSubtype: 'apartment',
      ownershipType: 'fully_owned',
      valuationMode: 'net_fair',
      currency: 'USD',
      originalPrice: 100000,
      totalInterest: 0,
      totalPayable: 100000,
      paidAmount: 100000,
      remainingAmount: 0,
      installmentPlan: <Map<String, dynamic>>[],
      valuationDate: '2026-06-18',
      marketValue: 120000,
      marketValueDate: '2026-06-18',
      valuationSource: 'manual',
      loanBalance: 0,
      loanAsOfDate: '2026-06-18',
      paidAmountToDate: 100000,
      ownershipSharePct: 100,
      country: 'US',
      location: 'NY',
      inflationRateAnnual: 3,
      estimatedCurrentValue: 120000,
      description: 'Investment',
      noZakat: true,
      createdAt: '2026-06-18T08:00:00.000Z',
      yearlyGrowthRate: 8.5,
    );

    await repository.saveInvestment(
      investmentWithGrowth,
      now: '2026-06-19T09:00:00.000Z',
    );

    final active = await repository.getActiveInvestments();
    final savedAsset = active.firstWhere((element) => element.id == 'inv2');

    expect(savedAsset.yearlyGrowthRate, 8.5);
  });
}
