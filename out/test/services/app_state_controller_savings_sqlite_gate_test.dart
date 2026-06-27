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

class _FakeGate implements UseSqliteLocalStoreProvider {
  _FakeGate(this.value);
  final bool value;
  @override
  Future<bool> prepareForRead({String? userId}) async => value;
}

class _FakeSavingsLocalStore implements SavingsLocalStore {
  _FakeSavingsLocalStore({required this.savings, this.shouldThrow = false});

  final List<model.Saving> savings;
  final bool shouldThrow;

  @override
  Future<List<model.Saving>> getActiveSavings() async {
    if (shouldThrow) throw StateError('sqlite savings failed');
    return savings;
  }

  @override
  Future<void> replaceAllForLocalMirror(Iterable<model.Saving> savings) async {}

  @override
  Future<void> saveSaving(
    model.Saving saving, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {
    savings.removeWhere((model.Saving item) => item.id == saving.id);
    savings.add(saving);
  }

  @override
  Future<void> deleteSaving(
    String id, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {
    savings.removeWhere((model.Saving item) => item.id == id);
  }

  @override
  Stream<List<model.Saving>> watchActiveSavings() async* {
    yield savings;
  }
}

Future<AppStateController> _makeController({
  required Map<String, Object> initialValues,
  required bool useSqlite,
  required List<model.Saving> sqliteSavings,
  bool sqliteShouldThrow = false,
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  const localStorage = LocalStorageService();
  final repository = AppStateRepository(localStorage: localStorage);
  final controller = AppStateController(
    repository: repository,
    localSavingsRepository: _FakeSavingsLocalStore(
      savings: sqliteSavings,
      shouldThrow: sqliteShouldThrow,
    ),
    useSqliteLocalStoreProvider: _FakeGate(useSqlite),
  );
  await controller.load();
  return controller;
}

void main() {
  test('migration incomplete reads JSON savings', () async {
    final controller = await _makeController(
      initialValues: <String, Object>{
        'zakatAppData':
            '{"transactions":[],"savings":[{"id":"json-saving","assetType":"cash","dateAcquired":"2026-06-19","amount":100,"remainingAmount":100,"unit":"USD","description":"json","purchaseCurrency":"USD","purchaseAmount":100,"createdAt":"2026-06-19T08:00:00.000Z"}],"recurringTransactions":[],"investments":[],"financialPlans":[],"pendingTransactions":[],"lastRollover":"","categories":{"income":[],"expense":[]},"zakatPaidMonths":[],"processedExpenseIds":[],"mainCurrency":"USD","defaultEntryCurrency":"USD","zakatExpenseIds":{},"zakatMethod":"hawl","zakatAnnualDate":"","zakatNisabBasis":"gold85","zakatScheduleFilter":"unpaid","marketData":{},"marketHistory":[],"syncHealth":{"lastSuccessAt":"","lastFailureAt":"","lastError":"","pendingWrites":0},"lastModifiedAt":"","languagePreference":"en","themeMode":"system","biometricLockEnabled":false,"biometricHideWealthEnabled":false,"biometricExportEnabled":false,"biometricRestoreEnabled":false,"biometricAutoLockDelay":"1_minute","merchantRules":{},"merchantAliases":{},"captureAnalytics":{"parsedMessages":0,"autoApprovedMessages":0,"duplicateMessages":0,"ignoredMessages":0,"correctedMessages":0,"learnedRules":0,"autoApprovedRules":0,"capturedFromAppleShortcuts":0,"capturedFromAppleShortcutsAutoApproved":0,"capturedFromAppleShortcutsIgnored":0},"correctionFeedback":[],"merchantConfirmations":[],"smartCaptureEnabled":true,"smartCaptureAutoApproveEnabled":false}',
      },
      useSqlite: false,
      sqliteSavings: const <model.Saving>[
        model.Saving(
          id: 'sqlite-saving',
          assetType: 'cash',
          dateAcquired: '2026-06-19',
          amount: 200,
          remainingAmount: 200,
          unit: 'USD',
          description: 'sqlite',
          purchaseCurrency: 'USD',
          purchaseAmount: 200,
          createdAt: '2026-06-19T08:00:00.000Z',
        ),
      ],
    );

    expect(controller.state.savings.single.id, 'json-saving');
  });

  test('migration complete reads SQLite savings', () async {
    final controller = await _makeController(
      initialValues: <String, Object>{
        'zakatAppData':
            '{"transactions":[],"savings":[{"id":"json-saving","assetType":"cash","dateAcquired":"2026-06-19","amount":100,"remainingAmount":100,"unit":"USD","description":"json","purchaseCurrency":"USD","purchaseAmount":100,"createdAt":"2026-06-19T08:00:00.000Z"}],"recurringTransactions":[],"investments":[],"financialPlans":[],"pendingTransactions":[],"lastRollover":"","categories":{"income":[],"expense":[]},"zakatPaidMonths":[],"processedExpenseIds":[],"mainCurrency":"USD","defaultEntryCurrency":"USD","zakatExpenseIds":{},"zakatMethod":"hawl","zakatAnnualDate":"","zakatNisabBasis":"gold85","zakatScheduleFilter":"unpaid","marketData":{},"marketHistory":[],"syncHealth":{"lastSuccessAt":"","lastFailureAt":"","lastError":"","pendingWrites":0},"lastModifiedAt":"","languagePreference":"en","themeMode":"system","biometricLockEnabled":false,"biometricHideWealthEnabled":false,"biometricExportEnabled":false,"biometricRestoreEnabled":false,"biometricAutoLockDelay":"1_minute","merchantRules":{},"merchantAliases":{},"captureAnalytics":{"parsedMessages":0,"autoApprovedMessages":0,"duplicateMessages":0,"ignoredMessages":0,"correctedMessages":0,"learnedRules":0,"autoApprovedRules":0,"capturedFromAppleShortcuts":0,"capturedFromAppleShortcutsAutoApproved":0,"capturedFromAppleShortcutsIgnored":0},"correctionFeedback":[],"merchantConfirmations":[],"smartCaptureEnabled":true,"smartCaptureAutoApproveEnabled":false}',
      },
      useSqlite: true,
      sqliteSavings: const <model.Saving>[
        model.Saving(
          id: 'sqlite-saving',
          assetType: 'cash',
          dateAcquired: '2026-06-19',
          amount: 200,
          remainingAmount: 200,
          unit: 'USD',
          description: 'sqlite',
          purchaseCurrency: 'USD',
          purchaseAmount: 200,
          createdAt: '2026-06-19T08:00:00.000Z',
        ),
      ],
    );

    expect(controller.state.savings.single.id, 'sqlite-saving');
  });

  test('SQLite savings read failure falls back to JSON', () async {
    final controller = await _makeController(
      initialValues: <String, Object>{
        'zakatAppData':
            '{"transactions":[],"savings":[{"id":"json-saving","assetType":"cash","dateAcquired":"2026-06-19","amount":100,"remainingAmount":100,"unit":"USD","description":"json","purchaseCurrency":"USD","purchaseAmount":100,"createdAt":"2026-06-19T08:00:00.000Z"}],"recurringTransactions":[],"investments":[],"financialPlans":[],"pendingTransactions":[],"lastRollover":"","categories":{"income":[],"expense":[]},"zakatPaidMonths":[],"processedExpenseIds":[],"mainCurrency":"USD","defaultEntryCurrency":"USD","zakatExpenseIds":{},"zakatMethod":"hawl","zakatAnnualDate":"","zakatNisabBasis":"gold85","zakatScheduleFilter":"unpaid","marketData":{},"marketHistory":[],"syncHealth":{"lastSuccessAt":"","lastFailureAt":"","lastError":"","pendingWrites":0},"lastModifiedAt":"","languagePreference":"en","themeMode":"system","biometricLockEnabled":false,"biometricHideWealthEnabled":false,"biometricExportEnabled":false,"biometricRestoreEnabled":false,"biometricAutoLockDelay":"1_minute","merchantRules":{},"merchantAliases":{},"captureAnalytics":{"parsedMessages":0,"autoApprovedMessages":0,"duplicateMessages":0,"ignoredMessages":0,"correctedMessages":0,"learnedRules":0,"autoApprovedRules":0,"capturedFromAppleShortcuts":0,"capturedFromAppleShortcutsAutoApproved":0,"capturedFromAppleShortcutsIgnored":0},"correctionFeedback":[],"merchantConfirmations":[],"smartCaptureEnabled":true,"smartCaptureAutoApproveEnabled":false}',
      },
      useSqlite: true,
      sqliteSavings: const <model.Saving>[],
      sqliteShouldThrow: true,
    );

    expect(controller.state.savings.single.id, 'json-saving');
  });

  test('deleted_at savings do not appear in SQLite UI read path', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData':
          '{"transactions":[],"savings":[],"recurringTransactions":[],"investments":[],"financialPlans":[],"pendingTransactions":[],"lastRollover":"","categories":{"income":[],"expense":[]},"zakatPaidMonths":[],"processedExpenseIds":[],"mainCurrency":"USD","defaultEntryCurrency":"USD","zakatExpenseIds":{},"zakatMethod":"hawl","zakatAnnualDate":"","zakatNisabBasis":"gold85","zakatScheduleFilter":"unpaid","marketData":{},"marketHistory":[],"syncHealth":{"lastSuccessAt":"","lastFailureAt":"","lastError":"","pendingWrites":0},"lastModifiedAt":"","languagePreference":"en","themeMode":"system","biometricLockEnabled":false,"biometricHideWealthEnabled":false,"biometricExportEnabled":false,"biometricRestoreEnabled":false,"biometricAutoLockDelay":"1_minute","merchantRules":{},"merchantAliases":{},"captureAnalytics":{"parsedMessages":0,"autoApprovedMessages":0,"duplicateMessages":0,"ignoredMessages":0,"correctedMessages":0,"learnedRules":0,"autoApprovedRules":0,"capturedFromAppleShortcuts":0,"capturedFromAppleShortcutsAutoApproved":0,"capturedFromAppleShortcutsIgnored":0},"correctionFeedback":[],"merchantConfirmations":[],"smartCaptureEnabled":true,"smartCaptureAutoApproveEnabled":false}',
    });
    const localStorage = LocalStorageService();
    final appRepository = AppStateRepository(localStorage: localStorage);
    final database = AppDatabase(executor: NativeDatabase.memory());
    final localRepository = LocalSavingsRepository(
      savingsDao: SavingsDao(database),
      syncQueueDao: SyncQueueDao(database),
    );
    await localRepository.importSaving(
      const model.Saving(
        id: 'active-saving',
        assetType: 'cash',
        dateAcquired: '2026-06-19',
        amount: 100,
        remainingAmount: 100,
        unit: 'USD',
        description: 'active',
        purchaseCurrency: 'USD',
        purchaseAmount: 100,
        createdAt: '2026-06-19T08:00:00.000Z',
      ),
      updatedAt: '2026-06-19T09:00:00.000Z',
    );
    await localRepository.importSaving(
      const model.Saving(
        id: 'deleted-saving',
        assetType: 'cash',
        dateAcquired: '2026-06-19',
        amount: 50,
        remainingAmount: 50,
        unit: 'USD',
        description: 'deleted',
        purchaseCurrency: 'USD',
        purchaseAmount: 50,
        createdAt: '2026-06-19T08:00:00.000Z',
      ),
      updatedAt: '2026-06-19T10:00:00.000Z',
      deletedAt: '2026-06-19T10:00:00.000Z',
    );
    final controller = AppStateController(
      repository: appRepository,
      localSavingsRepository: localRepository,
      useSqliteLocalStoreProvider: _FakeGate(true),
    );
    await controller.load();

    expect(controller.state.savings.map((model.Saving s) => s.id), [
      'active-saving',
    ]);

    await database.close();
  });
}
