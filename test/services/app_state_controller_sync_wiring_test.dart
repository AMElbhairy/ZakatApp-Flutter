import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
import 'package:zakatapp_flutter/data/repositories/local_savings_repository.dart';
import 'package:zakatapp_flutter/data/repositories/local_transactions_repository.dart';
import 'package:zakatapp_flutter/data/sync/local_sync_pipeline.dart';
import 'package:zakatapp_flutter/data/sync/sync_queue_processor.dart';
import 'package:zakatapp_flutter/models/merchant_rule.dart';
import 'package:zakatapp_flutter/models/pending_transaction.dart';
import 'package:zakatapp_flutter/models/saving.dart' as model;
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

class _FakeTransactionsStore implements TransactionsLocalStore {
  final List<model.Transaction> transactions = [];

  @override
  Future<void> deleteTransaction(
    String id, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {}
  @override
  Future<List<model.Transaction>> getActiveTransactions() async => transactions;
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
  }) async {
    transactions.add(transaction);
  }

  @override
  Stream<List<model.Transaction>> watchActiveTransactions() async* {
    yield transactions;
  }
}

class _FakeSavingsStore implements SavingsLocalStore {
  final List<model.Saving> savings = [];

  @override
  Future<void> deleteSaving(
    String id, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {}
  @override
  Future<List<model.Saving>> getActiveSavings() async => savings;
  @override
  Future<void> replaceAllForLocalMirror(Iterable<model.Saving> savings) async {}
  @override
  Future<void> saveSaving(
    model.Saving saving, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {
    savings.add(saving);
  }

  @override
  Stream<List<model.Saving>> watchActiveSavings() async* {
    yield savings;
  }
}

class _FakeLocalSyncPipeline implements LocalSyncPipeline {
  int syncCallCount = 0;
  int pushOnlyCallCount = 0;
  int pullOnlyCallCount = 0;
  int pushThenPullCallCount = 0;
  int queueCountValue = 0;
  bool shouldFail = false;
  bool shouldPullNowValue = false;
  bool hasPullCursorValue = true;
  String? lastPullSuccessAtValue;
  Completer<void>? syncCompleter;

  @override
  bool get syncInProgress => syncCompleter != null;

  @override
  Future<int> queueCount() async => queueCountValue;

  @override
  Future<String?> lastPullSuccessAt() async =>
      lastPullSuccessAtValue;

  @override
  Future<String?> lastPushSuccessAt() async =>
      queueCountValue > 0 ? '2026-06-20T00:00:00Z' : null;

  @override
  Future<bool> hasPullCursor() async => hasPullCursorValue;

  @override
  Future<bool> shouldPullNow() async => shouldPullNowValue;

  @override
  Future<SyncQueueProcessResult> pushOnly(String userId) async {
    syncCallCount++;
    pushOnlyCallCount++;
    if (shouldFail) {
      throw Exception('Pipeline failure');
    }
    return const SyncQueueProcessResult(attempted: 1, succeeded: 1, failed: 0);
  }

  @override
  Future<void> pullOnly(String userId) async {
    syncCallCount++;
    pullOnlyCallCount++;
    if (shouldFail) {
      throw Exception('Pipeline failure');
    }
    if (syncCompleter != null) {
      await syncCompleter!.future;
    }
  }

  @override
  Future<void> pushThenPull(String userId) async {
    syncCallCount++;
    pushThenPullCallCount++;
    pushOnlyCallCount++;
    pullOnlyCallCount++;
    if (shouldFail) {
      throw Exception('Pipeline failure');
    }
  }

  @override
  Future<void> sync(String userId) async {
    syncCallCount++;
    if (shouldFail) {
      throw Exception('Pipeline failure');
    }
    if (syncCompleter != null) {
      await syncCompleter!.future;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppStateRepository repository;
  late _FakeTransactionsStore fakeTxsStore;
  late _FakeSavingsStore fakeSavingsStore;
  late _FakeLocalSyncPipeline fakePipeline;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPreferences.getInstance();
    repository = AppStateRepository(localStorage: const LocalStorageService());
    fakeTxsStore = _FakeTransactionsStore();
    fakeSavingsStore = _FakeSavingsStore();
    fakePipeline = _FakeLocalSyncPipeline();
  });

  test(
    'app start respects recent pull and sign-in does not repeat it',
    () async {
      // Seed the repository so it loads a state with userId populated
      await repository.saveAppState(
        AppStateDefaults.create().copyWith(userId: 'user-1'),
        userId: 'user-1',
      );
      fakePipeline.shouldPullNowValue = true;

      final AppStateController controller = AppStateController(
        repository: repository,
        localTransactionsRepository: fakeTxsStore,
        localSavingsRepository: fakeSavingsStore,
        useSqliteLocalStoreProvider: _StaticGate(true),
        localSyncPipeline: fakePipeline,
      );

      await controller.loadAuthenticated('user-1');
      fakePipeline.shouldPullNowValue = false;
      await controller.attachCurrentUser(
        userId: 'user-1',
        email: 'user@example.com',
        displayName: 'User',
        provider: 'google',
      );

      // Allow all microtasks and timers to settle
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fakePipeline.syncCallCount, 0);
      expect(fakePipeline.pullOnlyCallCount, 0);
      expect(fakePipeline.pushOnlyCallCount, 0);
    },
  );

  test('app resume with empty queue and recent pull does nothing', () async {
    await repository.saveAppState(
      AppStateDefaults.create().copyWith(userId: 'user-1'),
      userId: 'user-1',
    );

    final AppStateController controller = AppStateController(
      repository: repository,
      localTransactionsRepository: fakeTxsStore,
      localSavingsRepository: fakeSavingsStore,
      useSqliteLocalStoreProvider: _StaticGate(true),
      localSyncPipeline: fakePipeline,
    );

    await controller.loadAuthenticated('user-1');
    fakePipeline.syncCallCount = 0;
    fakePipeline.pullOnlyCallCount = 0;
    fakePipeline.pushOnlyCallCount = 0;
    fakePipeline.shouldPullNowValue = false;
    fakePipeline.queueCountValue = 0;
    fakePipeline.lastPullSuccessAtValue = '2026-06-20T00:00:00Z';

    await controller.triggerSyncPipeline(reason: 'app_resume');

    expect(fakePipeline.syncCallCount, 0);
    expect(fakePipeline.pullOnlyCallCount, 0);
    expect(fakePipeline.pushOnlyCallCount, 0);
  });

  test('local repository write schedules debounce push only', () async {
    // Seed the repository so it loads a state with userId populated
    await repository.saveAppState(
      AppStateDefaults.create().copyWith(userId: 'user-1'),
      userId: 'user-1',
    );

    final AppStateController controller = AppStateController(
      repository: repository,
      localTransactionsRepository: fakeTxsStore,
      localSavingsRepository: fakeSavingsStore,
      useSqliteLocalStoreProvider: _StaticGate(true),
      localSyncPipeline: fakePipeline,
      pushDebounceDuration: const Duration(milliseconds: 5),
    );

    // Seed logged in state
    await controller.loadAuthenticated('user-1');

    await Future<void>.delayed(const Duration(milliseconds: 50));
    fakePipeline.syncCallCount = 0; // reset
    fakePipeline.queueCountValue = 1;

    await controller.addTransaction(
      const model.Transaction(
        id: 'tx-1',
        type: 'income',
        date: '2026-06-19',
        amount: 100,
        currency: 'USD',
        category: 'Salary',
        description: 'Monthly pay',
        createdAt: '2026-06-19T08:00:00.000Z',
        rolledOver: false,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(fakePipeline.syncCallCount, 1);
    expect(fakePipeline.pushOnlyCallCount, 1);
    expect(fakePipeline.pullOnlyCallCount, 0);
    expect(fakePipeline.syncInProgress, false);
  });

  test('manual sync always push then pulls', () async {
    await repository.saveAppState(
      AppStateDefaults.create().copyWith(userId: 'user-1'),
      userId: 'user-1',
    );

    final AppStateController controller = AppStateController(
      repository: repository,
      localTransactionsRepository: fakeTxsStore,
      localSavingsRepository: fakeSavingsStore,
      useSqliteLocalStoreProvider: _StaticGate(true),
      localSyncPipeline: fakePipeline,
    );

    await controller.loadAuthenticated('user-1');
    fakePipeline.syncCallCount = 0;
    fakePipeline.pushOnlyCallCount = 0;
    fakePipeline.pullOnlyCallCount = 0;
    fakePipeline.pushThenPullCallCount = 0;
    fakePipeline.shouldPullNowValue = false;
    fakePipeline.queueCountValue = 0;

    await controller.triggerSyncPipeline(reason: 'manual');

    expect(fakePipeline.syncCallCount, 1);
    expect(fakePipeline.pushThenPullCallCount, 1);
    expect(fakePipeline.pushOnlyCallCount, 1);
    expect(fakePipeline.pullOnlyCallCount, 1);
  });

  test('SQLite active does not attach live user settings listener', () async {
    await repository.saveAppState(
      AppStateDefaults.create().copyWith(userId: 'user-1'),
      userId: 'user-1',
    );

    final RecordingFirestoreSyncManager recordingFirestore =
        RecordingFirestoreSyncManager(uid: 'user-1');
    final AppStateController controller = AppStateController(
      repository: repository,
      firestoreSyncManager: recordingFirestore,
      localTransactionsRepository: fakeTxsStore,
      localSavingsRepository: fakeSavingsStore,
      useSqliteLocalStoreProvider: _StaticGate(true),
      localSyncPipeline: fakePipeline,
    );

    await controller.loadAuthenticated('user-1');
    await controller.startLiveFirestoreSync(userId: 'user-1');

    expect(recordingFirestore.userSettingsLoadCalls, 0);
    expect(recordingFirestore.userSettingsWatchCalls, 0);
  });

  test('legacy mode still attaches live user settings listener', () async {
    await repository.saveAppState(
      AppStateDefaults.create().copyWith(userId: 'user-1'),
      userId: 'user-1',
    );

    final RecordingFirestoreSyncManager recordingFirestore =
        RecordingFirestoreSyncManager(uid: 'user-1');
    final AppStateController controller = AppStateController(
      repository: repository,
      firestoreSyncManager: recordingFirestore,
      localTransactionsRepository: fakeTxsStore,
      localSavingsRepository: fakeSavingsStore,
      useSqliteLocalStoreProvider: _StaticGate(false),
      localSyncPipeline: fakePipeline,
    );

    await controller.loadAuthenticated('user-1');
    await controller.startLiveFirestoreSync(userId: 'user-1');

    expect(recordingFirestore.userSettingsLoadCalls, 1);
    expect(recordingFirestore.userSettingsWatchCalls, 1);
  });

  test('manual sync refreshes user settings without attaching listener', () async {
    await repository.saveAppState(
      AppStateDefaults.create().copyWith(userId: 'user-1'),
      userId: 'user-1',
    );

    final RecordingFirestoreSyncManager recordingFirestore =
        RecordingFirestoreSyncManager(uid: 'user-1');
    final AppStateController controller = AppStateController(
      repository: repository,
      firestoreSyncManager: recordingFirestore,
      localTransactionsRepository: fakeTxsStore,
      localSavingsRepository: fakeSavingsStore,
      useSqliteLocalStoreProvider: _StaticGate(true),
      localSyncPipeline: fakePipeline,
    );

    await controller.loadAuthenticated('user-1');
    await controller.startLiveFirestoreSync(userId: 'user-1');
    fakePipeline.syncCallCount = 0;
    fakePipeline.pushThenPullCallCount = 0;
    fakePipeline.pullOnlyCallCount = 0;
    fakePipeline.pushOnlyCallCount = 0;

    await controller.triggerSyncPipeline(reason: 'manual');

    expect(recordingFirestore.userSettingsLoadCalls, 1);
    expect(recordingFirestore.userSettingsWatchCalls, 0);
    expect(fakePipeline.syncCallCount, 1);
    expect(fakePipeline.pushThenPullCallCount, 1);
    expect(fakePipeline.pullOnlyCallCount, 1);
  });

  test(
    'sqlite app open with cursors present does not pull or attach listener',
    () async {
      await repository.saveAppState(
        AppStateDefaults.create().copyWith(userId: 'user-1'),
        userId: 'user-1',
      );

      final RecordingFirestoreSyncManager recordingFirestore =
          RecordingFirestoreSyncManager(uid: 'user-1');
      fakePipeline.shouldPullNowValue = false;
      fakePipeline.queueCountValue = 0;
      fakePipeline.hasPullCursorValue = true;
      fakePipeline.lastPullSuccessAtValue = '2026-06-20T00:00:00Z';

      final AppStateController controller = AppStateController(
        repository: repository,
        firestoreSyncManager: recordingFirestore,
        localTransactionsRepository: fakeTxsStore,
        localSavingsRepository: fakeSavingsStore,
        useSqliteLocalStoreProvider: _StaticGate(true),
        localSyncPipeline: fakePipeline,
      );

      await controller.loadAuthenticated('user-1');
      await controller.startLiveFirestoreSync(userId: 'user-1');

      expect(recordingFirestore.userSettingsLoadCalls, 0);
      expect(recordingFirestore.userSettingsWatchCalls, 0);
      expect(fakePipeline.syncCallCount, 0);
      expect(fakePipeline.pullOnlyCallCount, 0);
      expect(fakePipeline.pushOnlyCallCount, 0);
    },
  );

  test('app start with no cursor triggers a pull even with no queue', () async {
    await repository.saveAppState(
      AppStateDefaults.create().copyWith(userId: 'user-1'),
      userId: 'user-1',
    );

    fakePipeline.shouldPullNowValue = true;
    fakePipeline.queueCountValue = 0;
    fakePipeline.hasPullCursorValue = false;
    fakePipeline.lastPullSuccessAtValue = null;

    final AppStateController controller = AppStateController(
      repository: repository,
      localTransactionsRepository: fakeTxsStore,
      localSavingsRepository: fakeSavingsStore,
      useSqliteLocalStoreProvider: _StaticGate(true),
      localSyncPipeline: fakePipeline,
    );

    await controller.loadAuthenticated('user-1');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    fakePipeline.syncCallCount = 0;
    fakePipeline.pullOnlyCallCount = 0;
    fakePipeline.pushOnlyCallCount = 0;
    fakePipeline.pushThenPullCallCount = 0;

    await controller.triggerSyncPipeline(reason: 'app_start');

    expect(fakePipeline.syncCallCount, 1);
    expect(fakePipeline.pullOnlyCallCount, 1);
    expect(fakePipeline.pushOnlyCallCount, 0);
  });

  test(
    'app start with empty queue and existing cursor skips pull when last pull timestamp is missing',
    () async {
      await repository.saveAppState(
        AppStateDefaults.create().copyWith(userId: 'user-1'),
        userId: 'user-1',
      );

      fakePipeline.shouldPullNowValue = true;
      fakePipeline.queueCountValue = 0;
      fakePipeline.hasPullCursorValue = true;
      fakePipeline.lastPullSuccessAtValue = null;

      final AppStateController controller = AppStateController(
        repository: repository,
        localTransactionsRepository: fakeTxsStore,
        localSavingsRepository: fakeSavingsStore,
        useSqliteLocalStoreProvider: _StaticGate(true),
        localSyncPipeline: fakePipeline,
      );

      await controller.loadAuthenticated('user-1');
      fakePipeline.syncCallCount = 0;
      fakePipeline.pullOnlyCallCount = 0;
      fakePipeline.pushOnlyCallCount = 0;

      await controller.triggerSyncPipeline(reason: 'app_start');

      expect(fakePipeline.syncCallCount, 0);
      expect(fakePipeline.pullOnlyCallCount, 0);
      expect(fakePipeline.pushOnlyCallCount, 0);
    },
  );

  test(
    'pipeline failure does not crash controller or discard local state',
    () async {
      final AppStateController controller = AppStateController(
        repository: repository,
        localTransactionsRepository: fakeTxsStore,
        localSavingsRepository: fakeSavingsStore,
        useSqliteLocalStoreProvider: _StaticGate(true),
        localSyncPipeline: fakePipeline,
      );

      // Seed transaction
      fakeTxsStore.transactions.add(
        const model.Transaction(
          id: 'tx-existing',
          type: 'income',
          date: '2026-06-19',
          amount: 200,
          currency: 'USD',
          category: 'Gift',
          description: 'Birthday gift',
          createdAt: '2026-06-19T08:00:00.000Z',
          rolledOver: false,
        ),
      );

      await controller.loadAuthenticated('user-1');

      fakePipeline.shouldFail = true;

      // Trigger manual sync
      await controller.triggerSyncPipeline();

      // Verify local state was preserved and controller didn't crash
      expect(controller.state.transactions, hasLength(1));
      expect(controller.state.transactions.first.id, 'tx-existing');
    },
  );

  test('login with empty queue does not write to Firestore', () async {
    final recordingFirestore = RecordingFirestoreSyncManager(uid: 'user-1');
    final AppStateController controller = AppStateController(
      repository: repository,
      firestoreSyncManager: recordingFirestore,
      localTransactionsRepository: fakeTxsStore,
      localSavingsRepository: fakeSavingsStore,
      useSqliteLocalStoreProvider: _StaticGate(true),
      localSyncPipeline: fakePipeline,
    );

    await controller.loadAuthenticated('user-1');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(recordingFirestore.transactionSyncCalls, 0);
    expect(recordingFirestore.savingsSyncCalls, 0);
    expect(fakePipeline.pushOnlyCallCount, 0);
  });

  test(
    'manual sensitive sync stays queue-free for collection data after migration',
    () async {
      final recordingFirestore = RecordingFirestoreSyncManager(uid: 'user-1');
      final AppStateController controller = AppStateController(
        repository: repository,
        firestoreSyncManager: recordingFirestore,
      );

      await controller.updateState(
        controller.state.copyWith(
          userId: 'user-1',
          pendingTransactions: const <PendingTransaction>[
            PendingTransaction(
              id: 'capture-1',
              source: PendingTransactionSource.manual,
              rawMessage: 'Card capture',
              createdAt: '2026-06-20T08:00:00.000Z',
              suggestedType: 'expense',
              confidence: 1,
              status: CaptureStatus.pendingReview,
            ),
          ],
          merchantRules: <String, MerchantRule>{
            'coffee shop': const MerchantRule(
              merchantName: 'Coffee Shop',
              categoryId: 'food',
              defaultType: 'expense',
              autoApprove: false,
              usageCount: 1,
              confidence: 1,
              source: 'custom',
              aliases: <String>['coffee shop'],
            ),
          },
        ),
      );

      await controller.syncSensitiveStateToFirestore();

      expect(recordingFirestore.captureInboxSyncCalls, 0);
      expect(recordingFirestore.merchantRulesSyncCalls, 0);
      expect(recordingFirestore.transactionSyncCalls, 0);
      expect(recordingFirestore.savingsSyncCalls, 0);
      expect(recordingFirestore.userSettingsSyncCalls, 0);
    },
  );
}
