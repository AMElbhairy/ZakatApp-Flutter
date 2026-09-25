import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/market_snapshot.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/backup_restore_service.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

void main() {
  late AppStateController controller;
  late BackupRestoreService service;
  late AppStateRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const LocalStorageService storage = LocalStorageService();
    repository = AppStateRepository(localStorage: storage);
    controller = AppStateController(repository: repository);
    await controller.load();
    service = BackupRestoreService(controller: controller);
  });

  Map<String, dynamic> _stableSnapshot(Map<String, dynamic> json) {
    final Map<String, dynamic> copy = Map<String, dynamic>.from(json);
    copy.remove('lastModifiedAt');
    copy.remove('languagePreference');
    copy.remove('cloudHydrated');
    copy.remove('hasUnsyncedAuthChanges');
    copy.remove('_loadedUserId');
    copy.remove('_restorePromptDismissedUserId');
    return copy;
  }

  test('replace restore persists state', () async {
    final String raw = '''
{"appName":"ZakatApp","schemaVersion":1,"exportedAt":"2026-01-01T00:00:00Z","counts":{},"appState":{"transactions":[{"id":"tx1","date":"2026-01-01"}],"savings":[],"investments":[],"recurringTransactions":[],"financialPlans":[]}}
''';

    await service.restoreReplace(raw, allowWhenLocalDataExists: true);
    expect(controller.state.transactions.length, 1);
    expect(controller.state.transactions.first.id, 'tx1');
  });

  test('merge restore upserts by id', () async {
    await service.restoreReplace(
      '{"appName":"ZakatApp","appState":{"transactions":[{"id":"tx1","description":"old"}],"savings":[],"investments":[],"recurringTransactions":[],"financialPlans":[]}}',
      allowWhenLocalDataExists: true,
    );

    await service.restoreMerge(
      '{"appName":"ZakatApp","appState":{"transactions":[{"id":"tx1","description":"new"},{"id":"tx2","description":"second"}],"savings":[],"investments":[],"recurringTransactions":[],"financialPlans":[]}}',
      allowWhenLocalDataExists: true,
    );

    expect(controller.state.transactions.length, 2);
    expect(
      controller.state.transactions
          .firstWhere((e) => e.id == 'tx1')
          .description,
      'new',
    );
  });

  test('merge restore keeps financial month cycle settings', () async {
    await service.restoreReplace(
      '{"appName":"ZakatApp","appState":{"transactions":[{"id":"tx1","description":"old"}],"savings":[],"investments":[],"recurringTransactions":[],"financialPlans":[],"financialMonthCycle":"calendar","financialMonthStartDay":1}}',
      allowWhenLocalDataExists: true,
    );

    await service.restoreMerge(
      '{"appName":"ZakatApp","appState":{"transactions":[{"id":"tx1","description":"updated"}],"savings":[],"investments":[],"recurringTransactions":[],"financialPlans":[],"financialMonthCycle":"custom","financialMonthStartDay":25}}',
      allowWhenLocalDataExists: true,
    );

    expect(controller.state.financialMonthCycle, 'custom');
    expect(controller.state.financialMonthStartDay, 25);
  });

  test(
    'restoreReplace normalizes language preference so Arabic and English backups persist the same data',
    () async {
      const String englishRaw = '''
{"appName":"ZakatApp","schemaVersion":3,"appState":{"transactions":[{"id":"tx1","date":"2026-01-01","amount":100,"currency":"USD","category":"Salary","description":"salary","createdAt":"2026-01-01T00:00:00.000Z","rolledOver":false}],"savings":[{"id":"sav1","assetType":"cash","dateAcquired":"2026-01-01","amount":50,"remainingAmount":50,"unit":"USD","description":"saving","purchaseCurrency":"USD","purchaseAmount":50,"createdAt":"2026-01-01T00:00:00.000Z"}],"recurringTransactions":[],"investments":[],"financialPlans":[],"pendingTransactions":[],"lastRollover":"","categories":{"income":["Salary"],"expense":[]},"zakatPaidMonths":["2026-01"],"processedExpenseIds":["tx1"],"mainCurrency":"USD","defaultEntryCurrency":"USD","financialMonthCycle":"calendar","financialMonthStartDay":1,"zakatExpenseIds":{"2026-01":"tx1"},"zakatMethod":"hawl","zakatAnnualDate":"","zakatNisabBasis":"gold85","zakatScheduleFilter":"unpaid","marketData":{},"marketHistory":[],"syncHealth":{"lastSuccessAt":"","lastFailureAt":"","lastError":"","pendingWrites":0},"lastModifiedAt":"2026-01-01T00:00:00.000Z","languagePreference":"en","themeMode":"system","aiSettings":{"defaultKeyIndex":0},"biometricLockEnabled":false,"biometricHideWealthEnabled":false,"biometricExportEnabled":false,"biometricRestoreEnabled":false,"biometricAutoLockDelay":"1_minute","merchantRules":{},"merchantAliases":{},"captureAnalytics":{"parsedMessages":0,"autoApprovedMessages":0,"duplicateMessages":0,"ignoredMessages":0,"correctedMessages":0,"learnedRules":0,"autoApprovedRules":0,"capturedFromAppleShortcuts":0,"capturedFromAppleShortcutsAutoApproved":0,"capturedFromAppleShortcutsIgnored":0},"correctionFeedback":[],"merchantConfirmations":[],"smartCaptureEnabled":true,"smartCaptureAutoApproveEnabled":false}}''';
      const String arabicRaw = '''
{"appName":"ZakatApp","schemaVersion":3,"appState":{"transactions":[{"id":"tx1","date":"2026-01-01","amount":100,"currency":"USD","category":"Salary","description":"salary","createdAt":"2026-01-01T00:00:00.000Z","rolledOver":false}],"savings":[{"id":"sav1","assetType":"cash","dateAcquired":"2026-01-01","amount":50,"remainingAmount":50,"unit":"USD","description":"saving","purchaseCurrency":"USD","purchaseAmount":50,"createdAt":"2026-01-01T00:00:00.000Z"}],"recurringTransactions":[],"investments":[],"financialPlans":[],"pendingTransactions":[],"lastRollover":"","categories":{"income":["Salary"],"expense":[]},"zakatPaidMonths":["2026-01"],"processedExpenseIds":["tx1"],"mainCurrency":"USD","defaultEntryCurrency":"USD","financialMonthCycle":"calendar","financialMonthStartDay":1,"zakatExpenseIds":{"2026-01":"tx1"},"zakatMethod":"hawl","zakatAnnualDate":"","zakatNisabBasis":"gold85","zakatScheduleFilter":"unpaid","marketData":{},"marketHistory":[],"syncHealth":{"lastSuccessAt":"","lastFailureAt":"","lastError":"","pendingWrites":0},"lastModifiedAt":"2026-01-01T00:00:00.000Z","languagePreference":"ar","themeMode":"system","aiSettings":{"defaultKeyIndex":0},"biometricLockEnabled":false,"biometricHideWealthEnabled":false,"biometricExportEnabled":false,"biometricRestoreEnabled":false,"biometricAutoLockDelay":"1_minute","merchantRules":{},"merchantAliases":{},"captureAnalytics":{"parsedMessages":0,"autoApprovedMessages":0,"duplicateMessages":0,"ignoredMessages":0,"correctedMessages":0,"learnedRules":0,"autoApprovedRules":0,"capturedFromAppleShortcuts":0,"capturedFromAppleShortcutsAutoApproved":0,"capturedFromAppleShortcutsIgnored":0},"correctionFeedback":[],"merchantConfirmations":[],"smartCaptureEnabled":true,"smartCaptureAutoApproveEnabled":false}}''';

      await service.restoreReplace(
        englishRaw,
        allowWhenLocalDataExists: true,
      );
      final Map<String, dynamic> englishSnapshot = _stableSnapshot(
        controller.state.toJson(),
      );

      controller = AppStateController(repository: repository);
      await controller.load();
      service = BackupRestoreService(controller: controller);
      await service.restoreReplace(
        arabicRaw,
        allowWhenLocalDataExists: true,
      );
      final Map<String, dynamic> arabicSnapshot = _stableSnapshot(
        controller.state.toJson(),
      );

      expect(englishSnapshot, arabicSnapshot);
      expect(controller.state.languagePreference, 'en');
    },
  );

  test('local conflict requires explicit action', () async {
    await service.restoreReplace(
      '{"appName":"ZakatApp","appState":{"transactions":[{"id":"tx1"}],"savings":[],"investments":[],"recurringTransactions":[],"financialPlans":[]}}',
      allowWhenLocalDataExists: true,
    );

    expect(
      () => service.restoreReplace(
        '{"appName":"ZakatApp","appState":{"transactions":[{"id":"tx2"}],"savings":[],"investments":[],"recurringTransactions":[],"financialPlans":[]}}',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'merge restore keeps existing market data when incoming market data is empty',
    () async {
      await controller.updateMarketSnapshot(
        const MarketSnapshot(
          gold24kPricePerGramEgp: 5400,
          silverPricePerGramEgp: 64,
          usdToEgp: 50,
          sarToEgp: 13.3,
          aedToEgp: 13.6,
          kwdToEgp: 160,
          qarToEgp: 13.7,
          eurToEgp: 54,
          gbpToEgp: 63,
          bhdToEgp: 133,
          omrToEgp: 130,
          jodToEgp: 71,
          tryToEgp: 1.5,
          myrToEgp: 10.8,
          pkrToEgp: 0.18,
          idrToEgp: 0.0031,
          lastUpdated: '2026-01-01T00:00:00Z',
        ),
      );

      await service.restoreMerge(
        '{"appName":"ZakatApp","appState":{"transactions":[],"savings":[],"investments":[],"recurringTransactions":[],"financialPlans":[],"marketData":{}}}',
        allowWhenLocalDataExists: true,
      );

      expect(controller.currentMarketSnapshot.usdToEgp, 50);
      expect(
        controller.currentMarketSnapshot.lastUpdated,
        '2026-01-01T00:00:00Z',
      );
    },
  );

  test('merge restore keeps zakat paid state across reloads', () async {
    final AppStateModel initialState = AppStateDefaults.create().copyWith(
      userId: 'user-1',
      zakatPaidMonths: <String>['2026-06'],
      processedExpenseIds: <String>['tx-paid'],
      zakatExpenseIds: <String, dynamic>{'2026-06': 'tx-paid'},
    );
    await repository.saveAppState(initialState, userId: 'user-1');
    controller = AppStateController(repository: repository);
    await controller.loadAuthenticated('user-1');
    service = BackupRestoreService(controller: controller);

    await service.restoreMerge(
      '{"appName":"ZakatApp","appState":{"transactions":[{"id":"tx-incoming","type":"income","date":"2026-06-20","amount":100,"currency":"USD","category":"Salary","description":"incoming","createdAt":"2026-06-20T08:00:00.000Z","rolledOver":false}],"savings":[],"investments":[],"recurringTransactions":[],"financialPlans":[],"zakatPaidMonths":["2026-06"],"processedExpenseIds":["tx-paid"],"zakatExpenseIds":{"2026-06":"tx-paid"}}}',
      allowWhenLocalDataExists: true,
    );

    final AppStateController reloaded = AppStateController(
      repository: AppStateRepository(localStorage: const LocalStorageService()),
    );
    await reloaded.loadAuthenticated('user-1');

    expect(reloaded.state.zakatPaidMonths, <String>['2026-06']);
    expect(reloaded.state.processedExpenseIds, <String>['tx-paid']);
    expect(reloaded.state.zakatExpenseIds, <String, dynamic>{
      '2026-06': 'tx-paid',
    });
  });

  test('cross-account restore throws when allowCrossAccount is false', () async {
    final AppStateModel initialState = AppStateDefaults.create().copyWith(
      userId: 'user-current',
    );
    await repository.saveAppState(initialState, userId: 'user-current');
    controller = AppStateController(repository: repository);
    await controller.loadAuthenticated('user-current');
    service = BackupRestoreService(controller: controller);

    expect(
      () => service.restoreReplace(
        '{"appName":"ZakatApp","userId":"user-other","appState":{"transactions":[{"id":"tx-other"}],"savings":[],"investments":[],"recurringTransactions":[],"financialPlans":[]}}',
        allowWhenLocalDataExists: true,
        allowCrossAccount: false,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('cross-account restore succeeds and adopts current userId when allowCrossAccount is true', () async {
    final AppStateModel initialState = AppStateDefaults.create().copyWith(
      userId: 'user-current',
    );
    await repository.saveAppState(initialState, userId: 'user-current');
    controller = AppStateController(repository: repository);
    await controller.loadAuthenticated('user-current');
    service = BackupRestoreService(controller: controller);

    final RestoreResult result = await service.restoreReplace(
      '{"appName":"ZakatApp","userId":"user-other","appState":{"transactions":[{"id":"tx-other","type":"income","amount":500,"currency":"EGP","date":"2026-01-01","category":"Salary","description":"test","createdAt":"2026-01-01T00:00:00.000Z","rolledOver":false}],"savings":[],"investments":[],"recurringTransactions":[],"financialPlans":[]}}',
      allowWhenLocalDataExists: true,
      allowCrossAccount: true,
    );

    expect(result.mode, 'replace');
    expect(controller.state.userId, 'user-current');
    expect(controller.state.transactions.length, 1);
    expect(controller.state.transactions.first.id, 'tx-other');
  });
}
