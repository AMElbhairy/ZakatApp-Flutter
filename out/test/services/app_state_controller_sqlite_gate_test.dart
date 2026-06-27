import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_queue_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/transactions_dao.dart';
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
import 'package:zakatapp_flutter/data/repositories/local_transactions_repository.dart';
import 'package:zakatapp_flutter/models/transaction.dart' as model;
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

class _FakeUseSqliteLocalStoreProvider implements UseSqliteLocalStoreProvider {
  _FakeUseSqliteLocalStoreProvider(this.value);

  final bool value;

  @override
  Future<bool> prepareForRead({String? userId}) async => value;
}

class _FakeTransactionsLocalStore implements TransactionsLocalStore {
  _FakeTransactionsLocalStore({
    required this.transactions,
    this.shouldThrow = false,
  });

  final List<model.Transaction> transactions;
  final bool shouldThrow;
  int saveCalls = 0;
  int deleteCalls = 0;

  void _upsert(model.Transaction transaction) {
    transactions.removeWhere((model.Transaction tx) => tx.id == transaction.id);
    transactions.add(transaction);
  }

  @override
  Future<List<model.Transaction>> getActiveTransactions() async {
    if (shouldThrow) {
      throw StateError('sqlite failed');
    }
    return transactions;
  }

  @override
  Future<void> replaceAllForLocalMirror(
    Iterable<model.Transaction> transactions,
  ) async {}

  @override
  Stream<List<model.Transaction>> watchActiveTransactions() async* {
    yield transactions;
  }

  @override
  Future<void> saveTransaction(
    model.Transaction transaction, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {
    saveCalls += 1;
    _upsert(transaction);
  }

  @override
  Future<void> deleteTransaction(
    String id, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {
    deleteCalls += 1;
    transactions.removeWhere((model.Transaction tx) => tx.id == id);
  }
}

void main() {
  Future<AppStateController> makeController({
    required Map<String, Object> initialValues,
    required bool useSqlite,
    required List<model.Transaction> sqliteTransactions,
    bool sqliteShouldThrow = false,
  }) async {
    SharedPreferences.setMockInitialValues(initialValues);
    const localStorage = LocalStorageService();
    final repository = AppStateRepository(localStorage: localStorage);
    final controller = AppStateController(
      repository: repository,
      localTransactionsRepository: _FakeTransactionsLocalStore(
        transactions: sqliteTransactions,
        shouldThrow: sqliteShouldThrow,
      ),
      useSqliteLocalStoreProvider: _FakeUseSqliteLocalStoreProvider(useSqlite),
    );
    await controller.load();
    return controller;
  }

  test('migration incomplete reads old JSON transactions', () async {
    final controller = await makeController(
      initialValues: <String, Object>{
        'zakatAppData':
            '{"transactions":[{"id":"json-tx","type":"income","date":"2026-06-19","amount":100,"currency":"USD","category":"Salary","description":"json","createdAt":"2026-06-19T08:00:00.000Z","rolledOver":false}],"savings":[],"recurringTransactions":[],"investments":[],"financialPlans":[],"pendingTransactions":[],"lastRollover":"","categories":{"income":[],"expense":[]},"zakatPaidMonths":[],"processedExpenseIds":[],"mainCurrency":"USD","defaultEntryCurrency":"USD","zakatExpenseIds":{},"zakatMethod":"hawl","zakatAnnualDate":"","zakatNisabBasis":"gold85","zakatScheduleFilter":"unpaid","marketData":{},"marketHistory":[],"syncHealth":{"lastSuccessAt":"","lastFailureAt":"","lastError":"","pendingWrites":0},"lastModifiedAt":"","languagePreference":"en","themeMode":"system","biometricLockEnabled":false,"biometricHideWealthEnabled":false,"biometricExportEnabled":false,"biometricRestoreEnabled":false,"biometricAutoLockDelay":"1_minute","merchantRules":{},"merchantAliases":{},"captureAnalytics":{"parsedMessages":0,"autoApprovedMessages":0,"duplicateMessages":0,"ignoredMessages":0,"correctedMessages":0,"learnedRules":0,"autoApprovedRules":0,"capturedFromAppleShortcuts":0,"capturedFromAppleShortcutsAutoApproved":0,"capturedFromAppleShortcutsIgnored":0},"correctionFeedback":[],"merchantConfirmations":[],"smartCaptureEnabled":true,"smartCaptureAutoApproveEnabled":false}',
      },
      useSqlite: false,
      sqliteTransactions: const <model.Transaction>[
        model.Transaction(
          id: 'sqlite-tx',
          type: 'income',
          date: '2026-06-19',
          amount: 200,
          currency: 'USD',
          category: 'Salary',
          description: 'sqlite',
          createdAt: '2026-06-19T08:00:00.000Z',
          rolledOver: false,
        ),
      ],
    );

    expect(controller.state.transactions, hasLength(1));
    expect(controller.state.transactions.single.id, 'json-tx');
  });

  test('migration complete reads SQLite transactions', () async {
    final controller = await makeController(
      initialValues: <String, Object>{
        'zakatAppData':
            '{"transactions":[{"id":"json-tx","type":"income","date":"2026-06-19","amount":100,"currency":"USD","category":"Salary","description":"json","createdAt":"2026-06-19T08:00:00.000Z","rolledOver":false}],"savings":[],"recurringTransactions":[],"investments":[],"financialPlans":[],"pendingTransactions":[],"lastRollover":"","categories":{"income":[],"expense":[]},"zakatPaidMonths":[],"processedExpenseIds":[],"mainCurrency":"USD","defaultEntryCurrency":"USD","zakatExpenseIds":{},"zakatMethod":"hawl","zakatAnnualDate":"","zakatNisabBasis":"gold85","zakatScheduleFilter":"unpaid","marketData":{},"marketHistory":[],"syncHealth":{"lastSuccessAt":"","lastFailureAt":"","lastError":"","pendingWrites":0},"lastModifiedAt":"","languagePreference":"en","themeMode":"system","biometricLockEnabled":false,"biometricHideWealthEnabled":false,"biometricExportEnabled":false,"biometricRestoreEnabled":false,"biometricAutoLockDelay":"1_minute","merchantRules":{},"merchantAliases":{},"captureAnalytics":{"parsedMessages":0,"autoApprovedMessages":0,"duplicateMessages":0,"ignoredMessages":0,"correctedMessages":0,"learnedRules":0,"autoApprovedRules":0,"capturedFromAppleShortcuts":0,"capturedFromAppleShortcutsAutoApproved":0,"capturedFromAppleShortcutsIgnored":0},"correctionFeedback":[],"merchantConfirmations":[],"smartCaptureEnabled":true,"smartCaptureAutoApproveEnabled":false}',
      },
      useSqlite: true,
      sqliteTransactions: const <model.Transaction>[
        model.Transaction(
          id: 'sqlite-tx',
          type: 'income',
          date: '2026-06-19',
          amount: 200,
          currency: 'USD',
          category: 'Salary',
          description: 'sqlite',
          createdAt: '2026-06-19T08:00:00.000Z',
          rolledOver: false,
        ),
      ],
    );

    expect(controller.state.transactions, hasLength(1));
    expect(controller.state.transactions.single.id, 'sqlite-tx');
  });

  test('SQLite read failure falls back to old JSON transactions', () async {
    final controller = await makeController(
      initialValues: <String, Object>{
        'zakatAppData':
            '{"transactions":[{"id":"json-tx","type":"income","date":"2026-06-19","amount":100,"currency":"USD","category":"Salary","description":"json","createdAt":"2026-06-19T08:00:00.000Z","rolledOver":false}],"savings":[],"recurringTransactions":[],"investments":[],"financialPlans":[],"pendingTransactions":[],"lastRollover":"","categories":{"income":[],"expense":[]},"zakatPaidMonths":[],"processedExpenseIds":[],"mainCurrency":"USD","defaultEntryCurrency":"USD","zakatExpenseIds":{},"zakatMethod":"hawl","zakatAnnualDate":"","zakatNisabBasis":"gold85","zakatScheduleFilter":"unpaid","marketData":{},"marketHistory":[],"syncHealth":{"lastSuccessAt":"","lastFailureAt":"","lastError":"","pendingWrites":0},"lastModifiedAt":"","languagePreference":"en","themeMode":"system","biometricLockEnabled":false,"biometricHideWealthEnabled":false,"biometricExportEnabled":false,"biometricRestoreEnabled":false,"biometricAutoLockDelay":"1_minute","merchantRules":{},"merchantAliases":{},"captureAnalytics":{"parsedMessages":0,"autoApprovedMessages":0,"duplicateMessages":0,"ignoredMessages":0,"correctedMessages":0,"learnedRules":0,"autoApprovedRules":0,"capturedFromAppleShortcuts":0,"capturedFromAppleShortcutsAutoApproved":0,"capturedFromAppleShortcutsIgnored":0},"correctionFeedback":[],"merchantConfirmations":[],"smartCaptureEnabled":true,"smartCaptureAutoApproveEnabled":false}',
      },
      useSqlite: true,
      sqliteTransactions: const <model.Transaction>[],
      sqliteShouldThrow: true,
    );

    expect(controller.state.transactions, hasLength(1));
    expect(controller.state.transactions.single.id, 'json-tx');
  });

  test('deleted_at rows do not appear in SQLite UI read path', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData':
          '{"transactions":[],"savings":[],"recurringTransactions":[],"investments":[],"financialPlans":[],"pendingTransactions":[],"lastRollover":"","categories":{"income":[],"expense":[]},"zakatPaidMonths":[],"processedExpenseIds":[],"mainCurrency":"USD","defaultEntryCurrency":"USD","zakatExpenseIds":{},"zakatMethod":"hawl","zakatAnnualDate":"","zakatNisabBasis":"gold85","zakatScheduleFilter":"unpaid","marketData":{},"marketHistory":[],"syncHealth":{"lastSuccessAt":"","lastFailureAt":"","lastError":"","pendingWrites":0},"lastModifiedAt":"","languagePreference":"en","themeMode":"system","biometricLockEnabled":false,"biometricHideWealthEnabled":false,"biometricExportEnabled":false,"biometricRestoreEnabled":false,"biometricAutoLockDelay":"1_minute","merchantRules":{},"merchantAliases":{},"captureAnalytics":{"parsedMessages":0,"autoApprovedMessages":0,"duplicateMessages":0,"ignoredMessages":0,"correctedMessages":0,"learnedRules":0,"autoApprovedRules":0,"capturedFromAppleShortcuts":0,"capturedFromAppleShortcutsAutoApproved":0,"capturedFromAppleShortcutsIgnored":0},"correctionFeedback":[],"merchantConfirmations":[],"smartCaptureEnabled":true,"smartCaptureAutoApproveEnabled":false}',
    });
    const localStorage = LocalStorageService();
    final appRepository = AppStateRepository(localStorage: localStorage);
    final database = AppDatabase(executor: NativeDatabase.memory());
    final localRepository = LocalTransactionsRepository(
      transactionsDao: TransactionsDao(database),
      syncQueueDao: SyncQueueDao(database),
    );
    await localRepository.importTransaction(
      const model.Transaction(
        id: 'active-sqlite-tx',
        type: 'income',
        date: '2026-06-19',
        amount: 100,
        currency: 'USD',
        category: 'Salary',
        description: 'active',
        createdAt: '2026-06-19T08:00:00.000Z',
        rolledOver: false,
      ),
      updatedAt: '2026-06-19T09:00:00.000Z',
    );
    await localRepository.importTransaction(
      const model.Transaction(
        id: 'deleted-sqlite-tx',
        type: 'expense',
        date: '2026-06-18',
        amount: 10,
        currency: 'USD',
        category: 'Food',
        description: 'deleted',
        createdAt: '2026-06-18T08:00:00.000Z',
        rolledOver: false,
      ),
      updatedAt: '2026-06-19T10:00:00.000Z',
      deletedAt: '2026-06-19T10:00:00.000Z',
    );
    final controller = AppStateController(
      repository: appRepository,
      localTransactionsRepository: localRepository,
      useSqliteLocalStoreProvider: _FakeUseSqliteLocalStoreProvider(true),
    );
    await controller.load();

    expect(controller.state.transactions.map((model.Transaction tx) => tx.id), [
      'active-sqlite-tx',
    ]);

    await database.close();
  });
}
