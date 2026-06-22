import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/daos/savings_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_queue_dao.dart';
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
import 'package:zakatapp_flutter/data/repositories/local_savings_repository.dart';
import 'package:zakatapp_flutter/models/saving.dart' as model;
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

class _ThrowingSavingsRepository implements SavingsLocalStore {
  _ThrowingSavingsRepository(this.seed);
  final List<model.Saving> seed;

  @override
  Future<void> deleteSaving(
    String id, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) => throw StateError('sqlite delete failed');

  @override
  Future<List<model.Saving>> getActiveSavings() async => seed;

  @override
  Future<void> replaceAllForLocalMirror(Iterable<model.Saving> savings) async {}

  @override
  Future<void> saveSaving(
    model.Saving saving, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) => throw StateError('sqlite save failed');

  @override
  Stream<List<model.Saving>> watchActiveSavings() async* {
    yield seed;
  }
}

Future<AppStateController> _makeController({
  required SavingsLocalStore localStore,
  required bool useSqlite,
  Map<String, Object>? initialValues,
}) async {
  SharedPreferences.setMockInitialValues(initialValues ?? <String, Object>{});
  const localStorage = LocalStorageService();
  final repository = AppStateRepository(localStorage: localStorage);
  final controller = AppStateController(
    repository: repository,
    localSavingsRepository: localStore,
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
      final localRepository = LocalSavingsRepository(
        savingsDao: SavingsDao(database),
        syncQueueDao: syncQueueDao,
      );
      final controller = await _makeController(
        localStore: localRepository,
        useSqlite: true,
      );

      const saving = model.Saving(
        id: 'sv1',
        assetType: 'cash',
        dateAcquired: '2026-06-19',
        amount: 250,
        remainingAmount: 250,
        unit: 'USD',
        description: 'saved',
        purchaseCurrency: 'USD',
        purchaseAmount: 250,
        createdAt: '2026-06-19T08:00:00.000Z',
      );

      await controller.addSaving(saving);

      final rows = await database.select(database.savings).get();
      final queue = await syncQueueDao.loadReadyBatch();

      expect(rows.single.id, 'sv1');
      expect(queue.single.operation, 'upsert');
      expect(controller.state.savings.single.id, 'sv1');
      expect(
        jsonDecode(
          (await const LocalStorageService().loadString('zakatAppData'))!,
        )['savings'][0]['id'],
        'sv1',
      );

      await database.close();
    },
  );

  test('SQLite mode delete tombstones row and enqueues delete', () async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    final syncQueueDao = SyncQueueDao(database);
    final localRepository = LocalSavingsRepository(
      savingsDao: SavingsDao(database),
      syncQueueDao: syncQueueDao,
    );
    await localRepository.importSaving(
      const model.Saving(
        id: 'sv1',
        assetType: 'cash',
        dateAcquired: '2026-06-19',
        amount: 250,
        remainingAmount: 250,
        unit: 'USD',
        description: 'saved',
        purchaseCurrency: 'USD',
        purchaseAmount: 250,
        createdAt: '2026-06-19T08:00:00.000Z',
      ),
      updatedAt: '2026-06-19T08:00:00.000Z',
    );
    final controller = await _makeController(
      localStore: localRepository,
      useSqlite: true,
    );

    await controller.deleteSaving('sv1');

    final rows = await database.select(database.savings).get();
    final queue = await syncQueueDao.loadReadyBatch();

    expect(rows.single.deletedAt, isNotNull);
    expect(queue.single.operation, 'delete');
    expect(controller.state.savings, isEmpty);

    await database.close();
  });

  test('saving edit does not trigger full-list Firestore sync', () async {
    final recordingFirestore = RecordingFirestoreSyncManager(uid: 'user-1');
    final controller = AppStateController(
      repository: AppStateRepository(localStorage: const LocalStorageService()),
      firestoreSyncManager: recordingFirestore,
      useSqliteLocalStoreProvider: _StaticGate(false),
    );

    await controller.updateState(
      controller.state.copyWith(
        userId: 'user-1',
        savings: <model.Saving>[
          const model.Saving(
            id: 'sv-edit',
            assetType: 'cash',
            dateAcquired: '2026-06-19',
            amount: 250,
            remainingAmount: 250,
            unit: 'USD',
            description: 'original',
            purchaseCurrency: 'USD',
            purchaseAmount: 250,
            createdAt: '2026-06-19T08:00:00.000Z',
          ),
        ],
      ),
    );

    await controller.startLiveFirestoreSync(userId: 'user-1');
    recordingFirestore.savingsSyncCalls = 0;

    await controller.updateSaving(
      const model.Saving(
        id: 'sv-edit',
        assetType: 'cash',
        dateAcquired: '2026-06-19',
        amount: 300,
        remainingAmount: 300,
        unit: 'USD',
        description: 'updated',
        purchaseCurrency: 'USD',
        purchaseAmount: 300,
        createdAt: '2026-06-19T09:00:00.000Z',
      ),
    );

    expect(recordingFirestore.savingsSyncCalls, 0);
  });

  test('SQLite saving write failure falls back to JSON path', () async {
    final controller = await _makeController(
      localStore: _ThrowingSavingsRepository(const <model.Saving>[]),
      useSqlite: true,
    );

    await controller.addSaving(
      const model.Saving(
        id: 'sv-fallback',
        assetType: 'cash',
        dateAcquired: '2026-06-19',
        amount: 100,
        remainingAmount: 100,
        unit: 'USD',
        description: 'fallback',
        purchaseCurrency: 'USD',
        purchaseAmount: 100,
        createdAt: '2026-06-19T08:00:00.000Z',
      ),
    );

    expect(controller.state.savings.single.id, 'sv-fallback');
    expect(
      jsonDecode(
        (await const LocalStorageService().loadString('zakatAppData'))!,
      )['savings'][0]['id'],
      'sv-fallback',
    );
  });

  test('JSON mode saving save and delete remain unchanged', () async {
    final controller = await _makeController(
      localStore: _ThrowingSavingsRepository(const <model.Saving>[]),
      useSqlite: false,
    );

    await controller.addSaving(
      const model.Saving(
        id: 'json-saving',
        assetType: 'cash',
        dateAcquired: '2026-06-19',
        amount: 100,
        remainingAmount: 100,
        unit: 'USD',
        description: 'json',
        purchaseCurrency: 'USD',
        purchaseAmount: 100,
        createdAt: '2026-06-19T08:00:00.000Z',
      ),
    );
    expect(controller.state.savings.single.id, 'json-saving');

    await controller.deleteSaving('json-saving');
    expect(controller.state.savings, isEmpty);
  });
}
