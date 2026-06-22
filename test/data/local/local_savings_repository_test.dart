import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/daos/savings_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_queue_dao.dart';
import 'package:zakatapp_flutter/data/repositories/local_savings_repository.dart';
import 'package:zakatapp_flutter/models/saving.dart' as model;

void main() {
  late AppDatabase database;
  late LocalSavingsRepository repository;
  late SyncQueueDao syncQueueDao;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    syncQueueDao = SyncQueueDao(database);
    repository = LocalSavingsRepository(
      savingsDao: SavingsDao(database),
      syncQueueDao: syncQueueDao,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('saveSaving writes local row and enqueues upsert', () async {
    const saving = model.Saving(
      id: 'sv1',
      assetType: 'cash',
      dateAcquired: '2026-06-19',
      amount: 250,
      remainingAmount: 200,
      unit: 'USD',
      description: 'Saved',
      purchaseCurrency: 'USD',
      purchaseAmount: 250,
      createdAt: '2026-06-19T08:00:00.000Z',
    );

    await repository.saveSaving(
      saving,
      now: '2026-06-19T09:00:00.000Z',
      deviceId: 'device-1',
    );

    final rows = await database.select(database.savings).get();
    final queue = await syncQueueDao.loadReadyBatch();

    expect(rows, hasLength(1));
    expect(rows.single.id, 'sv1');
    expect(rows.single.updatedAt, '2026-06-19T09:00:00.000Z');
    expect(queue, hasLength(1));
    expect(queue.single.dedupeKey, 'savings:sv1');
    expect(jsonDecode(queue.single.payloadJson!)['id'], 'sv1');
  });

  test('importSaving writes local row without queue', () async {
    const saving = model.Saving(
      id: 'sv-import',
      assetType: 'cash',
      dateAcquired: '2026-06-19',
      amount: 250,
      remainingAmount: 200,
      unit: 'USD',
      description: 'Imported',
      purchaseCurrency: 'USD',
      purchaseAmount: 250,
      createdAt: '2026-06-19T08:00:00.000Z',
    );

    await repository.importSaving(
      saving,
      updatedAt: '2026-06-19T09:00:00.000Z',
    );

    final rows = await database.select(database.savings).get();
    final queue = await syncQueueDao.loadReadyBatch();

    expect(rows, hasLength(1));
    expect(rows.single.id, 'sv-import');
    expect(queue, isEmpty);
  });

  test('saveSaving updates the existing queue row for the same id', () async {
    const saving = model.Saving(
      id: 'sv-dedupe',
      assetType: 'cash',
      dateAcquired: '2026-06-19',
      amount: 250,
      remainingAmount: 200,
      unit: 'USD',
      description: 'Initial',
      purchaseCurrency: 'USD',
      purchaseAmount: 250,
      createdAt: '2026-06-19T08:00:00.000Z',
    );
    const updatedSaving = model.Saving(
      id: 'sv-dedupe',
      assetType: 'cash',
      dateAcquired: '2026-06-19',
      amount: 300,
      remainingAmount: 275,
      unit: 'USD',
      description: 'Updated',
      purchaseCurrency: 'USD',
      purchaseAmount: 300,
      createdAt: '2026-06-19T09:00:00.000Z',
    );

    await repository.saveSaving(saving, now: '2026-06-19T09:00:00.000Z');
    await repository.saveSaving(updatedSaving, now: '2026-06-19T10:00:00.000Z');

    final rows = await database.select(database.savings).get();
    final queue = await syncQueueDao.loadReadyBatch();

    expect(rows, hasLength(1));
    expect(queue, hasLength(1));
    expect(queue.single.operation, 'upsert');
    expect(jsonDecode(queue.single.payloadJson!)['amount'], 300);
  });

  test('deleteSaving updates the existing queue row for the same id', () async {
    const saving = model.Saving(
      id: 'sv-delete',
      assetType: 'cash',
      dateAcquired: '2026-06-19',
      amount: 250,
      remainingAmount: 200,
      unit: 'USD',
      description: 'Delete me',
      purchaseCurrency: 'USD',
      purchaseAmount: 250,
      createdAt: '2026-06-19T08:00:00.000Z',
    );

    await repository.saveSaving(saving, now: '2026-06-19T09:00:00.000Z');
    await repository.deleteSaving('sv-delete', now: '2026-06-19T10:00:00.000Z');

    final rows = await database.select(database.savings).get();
    final queue = await syncQueueDao.loadReadyBatch();

    expect(rows, hasLength(1));
    expect(queue, hasLength(1));
    expect(queue.single.operation, 'delete');
  });
}
