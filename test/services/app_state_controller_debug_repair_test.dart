import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zakatapp_flutter/data/local/app_database.dart'
    hide FinancialPlan,
         RecurringTransaction,
         MerchantRule,
         MerchantConfirmation,
         CorrectionFeedback;
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/saving.dart' as model_saving;
import 'package:zakatapp_flutter/models/transaction.dart' as model_transaction;
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';

import '../support/recording_firestore_sync_manager.dart';

class _AllowSqliteProvider implements UseSqliteLocalStoreProvider {
  @override
  Future<bool> prepareForRead({String? userId}) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late AppStateRepository repository;
  late RecordingFirestoreSyncManager firestore;
  late AppStateController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase(executor: NativeDatabase.memory());
    repository = AppStateRepository(localStorage: const LocalStorageService());
    firestore = RecordingFirestoreSyncManager(uid: 'user-1');
    controller = AppStateController(
      repository: repository,
      firestoreSyncManager: firestore,
      database: database,
      useSqliteLocalStoreProvider: _AllowSqliteProvider(),
    );
    await controller.loadAuthenticated('user-1');
  });

  tearDown(() async {
    await database.close();
  });

  test('enqueue all local data queues syncable collections without scanning Firebase', () async {
    final AppStateModel state = AppStateDefaults.create().copyWith(
      userId: 'user-1',
      transactions: <model_transaction.Transaction>[
        const model_transaction.Transaction(
          id: 'tx-1',
          type: 'income',
          date: '2026-06-20',
          amount: 100,
          currency: 'USD',
          category: 'Salary',
          description: 'Salary',
          createdAt: '2026-06-20T00:00:00Z',
          rolledOver: false,
        ),
      ],
      savings: <model_saving.Saving>[
        const model_saving.Saving(
          id: 'sv-1',
          assetType: 'gold',
          dateAcquired: '2026-06-20',
          amount: 10,
          remainingAmount: 10,
          unit: 'g',
          description: 'Gold savings',
          purchaseCurrency: 'USD',
          purchaseAmount: 1000,
          createdAt: '2026-06-20T00:00:00Z',
        ),
      ],
    );
    await controller.updateState(state);

    final int before = await _queueCount(database);
    expect(before, 0);

    await controller.enqueueAllLocalDataForCloudSync();

    final List<dynamic> queueRows = await database.select(database.syncQueue).get();
    expect(queueRows, hasLength(2));
    expect(
      queueRows.map((dynamic row) => row.collectionName).toSet(),
      <String>{'transactions', 'savings'},
    );
  });

  test('force upload all local data processes queued writes', () async {
    final AppStateModel state = AppStateDefaults.create().copyWith(
      userId: 'user-1',
      transactions: <model_transaction.Transaction>[
        const model_transaction.Transaction(
          id: 'tx-1',
          type: 'income',
          date: '2026-06-20',
          amount: 100,
          currency: 'USD',
          category: 'Salary',
          description: 'Salary',
          createdAt: '2026-06-20T00:00:00Z',
          rolledOver: false,
        ),
      ],
      savings: <model_saving.Saving>[
        const model_saving.Saving(
          id: 'sv-1',
          assetType: 'silver',
          dateAcquired: '2026-06-20',
          amount: 10,
          remainingAmount: 10,
          unit: 'g',
          description: 'Silver savings',
          purchaseCurrency: 'USD',
          purchaseAmount: 1000,
          createdAt: '2026-06-20T00:00:00Z',
        ),
      ],
    );
    await controller.updateState(state);

    await controller.forceUploadAllLocalData();

    expect(firestore.transactionSyncCalls, greaterThan(0));
    expect(firestore.savingsSyncCalls, greaterThan(0));
    expect(await _queueCount(database), 0);
  });

  test('enqueue missing Firebase savings only enqueues missing ids', () async {
    final AppStateModel state = AppStateDefaults.create().copyWith(
      userId: 'user-1',
      savings: <model_saving.Saving>[
        const model_saving.Saving(
          id: 'sv-1',
          assetType: 'gold',
          dateAcquired: '2026-06-20',
          amount: 10,
          remainingAmount: 10,
          unit: 'g',
          description: 'Gold savings',
          purchaseCurrency: 'USD',
          purchaseAmount: 1000,
          createdAt: '2026-06-20T00:00:00Z',
        ),
        const model_saving.Saving(
          id: 'sv-2',
          assetType: 'silver',
          dateAcquired: '2026-06-20',
          amount: 20,
          remainingAmount: 20,
          unit: 'g',
          description: 'Silver savings',
          purchaseCurrency: 'USD',
          purchaseAmount: 2000,
          createdAt: '2026-06-20T00:00:00Z',
        ),
      ],
    );
    await controller.updateState(state);

    await firestore.firestore
        .collection('users')
        .doc('user-1')
        .collection('savings')
        .doc('sv-1')
        .set(state.savings.first.toFirestoreJson());

    final int enqueued = await controller.enqueueMissingFirebaseSavings();
    final List<dynamic> queueRows = await database.select(database.syncQueue).get();

    expect(enqueued, 1);
    expect(queueRows, hasLength(1));
    expect(queueRows.single.recordId, 'sv-2');
  });

  test('repair savings cursors resets only savings cursors', () async {
    final AppStateModel state = AppStateDefaults.create().copyWith(
      userId: 'user-1',
      savings: <model_saving.Saving>[
        const model_saving.Saving(
          id: 'sv-1',
          assetType: 'gold',
          dateAcquired: '2026-06-20',
          amount: 10,
          remainingAmount: 10,
          unit: 'g',
          description: 'Gold savings',
          purchaseCurrency: 'USD',
          purchaseAmount: 1000,
          createdAt: '2026-06-20T00:00:00Z',
        ),
      ],
      syncHealth: const SyncHealth(
        lastSuccessAt: '',
        lastFailureAt: '',
        lastError: '',
        pendingWrites: 0,
        transactionsCursor: 'tx-cursor',
        deletedTransactionsCursor: 'tx-deleted',
        savingsCursor: 'savings-cursor',
        deletedSavingsCursor: 'deleted-savings-cursor',
      ),
    );
    await controller.updateState(state);

    await controller.repairSavingsSyncCursors();

    expect(controller.state.syncHealth.savingsCursor, '');
    expect(controller.state.syncHealth.deletedSavingsCursor, '');
    expect(controller.state.syncHealth.transactionsCursor, 'tx-cursor');
    expect(controller.state.syncHealth.deletedTransactionsCursor, 'tx-deleted');
  });
}

Future<int> _queueCount(AppDatabase database) async {
  final List<dynamic> rows = await database.select(database.syncQueue).get();
  return rows.length;
}
