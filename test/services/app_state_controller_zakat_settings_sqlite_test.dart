import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart'
    hide
        Transaction,
        Saving,
        PendingTransaction,
        Investment,
        FinancialPlan,
        RecurringTransaction,
        MerchantRule,
        MerchantConfirmation,
        CorrectionFeedback;
import 'package:zakatapp_flutter/data/local/daos/app_settings_dao.dart';
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/backup_service.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

class _AlwaysSqliteProvider implements UseSqliteLocalStoreProvider {
  @override
  Future<bool> prepareForRead({String? userId}) async => true;
}

Future<AppStateController> _makeController({
  required AppDatabase database,
  required Map<String, Object> initialValues,
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final controller = AppStateController(
    repository: AppStateRepository(localStorage: const LocalStorageService()),
    database: database,
    useSqliteLocalStoreProvider: _AlwaysSqliteProvider(),
  );
  await controller.load();
  return controller;
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'JSON backup paid months migrate into SQLite settings and survive reload',
    () async {
      final controller1 = await _makeController(
        database: database,
        initialValues: <String, Object>{
          'zakatAppData':
              '{"transactions":[],"savings":[],"recurringTransactions":[],"investments":[],"financialPlans":[],"pendingTransactions":[],"lastRollover":"","categories":{"income":[],"expense":[]},"zakatPaidMonths":["2026-06"],"processedExpenseIds":["tx-paid"],"mainCurrency":"USD","defaultEntryCurrency":"USD","zakatExpenseIds":{"2026-06":"tx-paid"},"zakatMethod":"annual","zakatAnnualDate":"09-01","zakatNisabBasis":"silver595","zakatScheduleFilter":"paid","marketData":{},"marketHistory":[],"syncHealth":{"lastSuccessAt":"","lastFailureAt":"","lastError":"","pendingWrites":0},"lastModifiedAt":"","languagePreference":"en","themeMode":"system","biometricLockEnabled":false,"biometricHideWealthEnabled":false,"biometricExportEnabled":false,"biometricRestoreEnabled":false,"biometricAutoLockDelay":"1_minute","merchantRules":{},"merchantAliases":{},"captureAnalytics":{"parsedMessages":0,"autoApprovedMessages":0,"duplicateMessages":0,"ignoredMessages":0,"correctedMessages":0,"learnedRules":0,"autoApprovedRules":0,"capturedFromAppleShortcuts":0,"capturedFromAppleShortcutsAutoApproved":0,"capturedFromAppleShortcutsIgnored":0},"correctionFeedback":[],"merchantConfirmations":[],"smartCaptureEnabled":true,"smartCaptureAutoApproveEnabled":false}',
        },
      );

      expect(controller1.state.zakatPaidMonths, <String>['2026-06']);
      expect(
        await AppSettingsDao(
          database,
        ).getJson<List<String>>('zakat_paid_months'),
        <String>['2026-06'],
      );

      final controller2 = await _makeController(
        database: database,
        initialValues: <String, Object>{
          'zakatAppData':
              '{"transactions":[],"savings":[],"recurringTransactions":[],"investments":[],"financialPlans":[],"pendingTransactions":[],"lastRollover":"","categories":{"income":[],"expense":[]},"zakatPaidMonths":[],"processedExpenseIds":[],"mainCurrency":"USD","defaultEntryCurrency":"USD","zakatExpenseIds":{},"zakatMethod":"hawl","zakatAnnualDate":"","zakatNisabBasis":"gold85","zakatScheduleFilter":"unpaid","marketData":{},"marketHistory":[],"syncHealth":{"lastSuccessAt":"","lastFailureAt":"","lastError":"","pendingWrites":0},"lastModifiedAt":"","languagePreference":"en","themeMode":"system","biometricLockEnabled":false,"biometricHideWealthEnabled":false,"biometricExportEnabled":false,"biometricRestoreEnabled":false,"biometricAutoLockDelay":"1_minute","merchantRules":{},"merchantAliases":{},"captureAnalytics":{"parsedMessages":0,"autoApprovedMessages":0,"duplicateMessages":0,"ignoredMessages":0,"correctedMessages":0,"learnedRules":0,"autoApprovedRules":0,"capturedFromAppleShortcuts":0,"capturedFromAppleShortcutsAutoApproved":0,"capturedFromAppleShortcutsIgnored":0},"correctionFeedback":[],"merchantConfirmations":[],"smartCaptureEnabled":true,"smartCaptureAutoApproveEnabled":false}',
        },
      );

      expect(controller2.state.zakatPaidMonths, <String>['2026-06']);
      expect(controller2.state.zakatMethod, 'annual');
      expect(controller2.state.zakatScheduleFilter, 'paid');
    },
  );

  test(
    'missing SQLite setting preserves JSON fallback and writes it once',
    () async {
      final controller = await _makeController(
        database: database,
        initialValues: <String, Object>{
          'zakatAppData':
              '{"transactions":[],"savings":[],"recurringTransactions":[],"investments":[],"financialPlans":[],"pendingTransactions":[],"lastRollover":"","categories":{"income":[],"expense":[]},"zakatPaidMonths":["2026-06"],"processedExpenseIds":["tx-paid"],"mainCurrency":"USD","defaultEntryCurrency":"USD","zakatExpenseIds":{"2026-06":"tx-paid"},"zakatMethod":"hawl","zakatAnnualDate":"","zakatNisabBasis":"gold85","zakatScheduleFilter":"unpaid","marketData":{},"marketHistory":[],"syncHealth":{"lastSuccessAt":"","lastFailureAt":"","lastError":"","pendingWrites":0},"lastModifiedAt":"","languagePreference":"en","themeMode":"system","biometricLockEnabled":false,"biometricHideWealthEnabled":false,"biometricExportEnabled":false,"biometricRestoreEnabled":false,"biometricAutoLockDelay":"1_minute","merchantRules":{},"merchantAliases":{},"captureAnalytics":{"parsedMessages":0,"autoApprovedMessages":0,"duplicateMessages":0,"ignoredMessages":0,"correctedMessages":0,"learnedRules":0,"autoApprovedRules":0,"capturedFromAppleShortcuts":0,"capturedFromAppleShortcutsAutoApproved":0,"capturedFromAppleShortcutsIgnored":0},"correctionFeedback":[],"merchantConfirmations":[],"smartCaptureEnabled":true,"smartCaptureAutoApproveEnabled":false}',
        },
      );

      expect(controller.state.zakatPaidMonths, <String>['2026-06']);
      expect(
        await AppSettingsDao(
          database,
        ).getJson<List<String>>('zakat_paid_months'),
        <String>['2026-06'],
      );
    },
  );

  test(
    'paid month toggle updates SQLite settings and JSON compatibility',
    () async {
      final controller = await _makeController(
        database: database,
        initialValues: <String, Object>{
          'zakatAppData':
              '{"transactions":[],"savings":[],"recurringTransactions":[],"investments":[],"financialPlans":[],"pendingTransactions":[],"lastRollover":"","categories":{"income":[],"expense":[]},"zakatPaidMonths":[],"processedExpenseIds":[],"mainCurrency":"USD","defaultEntryCurrency":"USD","zakatExpenseIds":{},"zakatMethod":"hawl","zakatAnnualDate":"","zakatNisabBasis":"gold85","zakatScheduleFilter":"unpaid","marketData":{},"marketHistory":[],"syncHealth":{"lastSuccessAt":"","lastFailureAt":"","lastError":"","pendingWrites":0},"lastModifiedAt":"","languagePreference":"en","themeMode":"system","biometricLockEnabled":false,"biometricHideWealthEnabled":false,"biometricExportEnabled":false,"biometricRestoreEnabled":false,"biometricAutoLockDelay":"1_minute","merchantRules":{},"merchantAliases":{},"captureAnalytics":{"parsedMessages":0,"autoApprovedMessages":0,"duplicateMessages":0,"ignoredMessages":0,"correctedMessages":0,"learnedRules":0,"autoApprovedRules":0,"capturedFromAppleShortcuts":0,"capturedFromAppleShortcutsAutoApproved":0,"capturedFromAppleShortcutsIgnored":0},"correctionFeedback":[],"merchantConfirmations":[],"smartCaptureEnabled":true,"smartCaptureAutoApproveEnabled":false}',
        },
      );

      await controller.updateState(
        controller.state.copyWith(zakatPaidMonths: <String>['2026-06']),
      );

      expect(
        await AppSettingsDao(
          database,
        ).getJson<List<String>>('zakat_paid_months'),
        <String>['2026-06'],
      );

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString('zakatAppData');
      expect(raw, isNotNull);
      expect(raw!, contains('"zakatPaidMonths":["2026-06"]'));
    },
  );

  test(
    'runtime persistence keeps full collections while backup export remains full-fidelity',
    () async {
      final controller = await _makeController(
        database: database,
        initialValues: <String, Object>{
          'zakatAppData':
              '{"transactions":[],"savings":[],"recurringTransactions":[],"investments":[],"financialPlans":[],"pendingTransactions":[],"lastRollover":"","categories":{"income":[],"expense":[]},"zakatPaidMonths":[],"processedExpenseIds":[],"mainCurrency":"USD","defaultEntryCurrency":"USD","zakatExpenseIds":{},"zakatMethod":"hawl","zakatAnnualDate":"","zakatNisabBasis":"gold85","zakatScheduleFilter":"unpaid","marketData":{},"marketHistory":[],"syncHealth":{"lastSuccessAt":"","lastFailureAt":"","lastError":"","pendingWrites":0},"lastModifiedAt":"","languagePreference":"en","themeMode":"system","biometricLockEnabled":false,"biometricHideWealthEnabled":false,"biometricExportEnabled":false,"biometricRestoreEnabled":false,"biometricAutoLockDelay":"1_minute","merchantRules":{},"merchantAliases":{},"captureAnalytics":{"parsedMessages":0,"autoApprovedMessages":0,"duplicateMessages":0,"ignoredMessages":0,"correctedMessages":0,"learnedRules":0,"autoApprovedRules":0,"capturedFromAppleShortcuts":0,"capturedFromAppleShortcutsAutoApproved":0,"capturedFromAppleShortcutsIgnored":0},"correctionFeedback":[],"merchantConfirmations":[],"smartCaptureEnabled":true,"smartCaptureAutoApproveEnabled":false}',
        },
      );

      // Create a transaction and add it to the state
      final tx = Transaction(
        id: 'tx-123',
        type: 'expense',
        date: '2026-06-20',
        amount: 100.0,
        currency: 'USD',
        category: 'Zakat',
        description: 'Zakat Payment',
        createdAt: '2026-06-20T11:20:00Z',
        rolledOver: false,
      );

      await controller.addTransaction(tx);

      // Verify runtime persistence in SharedPreferences keeps the full transactions list
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString('zakatAppData');
      expect(raw, isNotNull);
      expect(raw!, contains('"transactions":[{"id":"tx-123"'));
      expect(raw, isNot(contains('"transactions":[]')));

      // Verify state.toJson() has the transaction (full-fidelity in-memory state)
      final stateJson = controller.state.toJson();
      final List<dynamic> txs = stateJson['transactions'] as List<dynamic>;
      expect(txs.length, 1);
      expect(txs.first['id'], 'tx-123');

      // Verify BackupService.exportBackup contains the transaction (full-fidelity backup export)
      final String backupStr = BackupService.exportBackup(
        controller.state.toJson(),
        userId: 'test-user',
        provider: 'local',
        email: 'test@example.com',
      );
      expect(backupStr, contains('"id":"tx-123"')); // Present in backup!

      // Setup AI settings with keys in state
      final Map<String, dynamic> aiSettings = <String, dynamic>{
        'keys': <String>['api-key-1', 'api-key-2'],
        'model': 'gemini-1.5-flash',
      };
      await controller.updateState(
        controller.state.copyWith(aiSettings: aiSettings),
      );

      // Verify AI keys are still sanitized from runtime JSON fallback in SharedPreferences
      final String? raw2 = prefs.getString('zakatAppData');
      expect(raw2, isNotNull);
      expect(raw2!, isNot(contains('api-key-1')));

      // Verify raw keys are stripped from BackupService.exportBackup
      final String backupStr2 = BackupService.exportBackup(
        controller.state.toJson(),
        userId: 'test-user',
        provider: 'local',
        email: 'test@example.com',
      );
      expect(backupStr2, isNot(contains('api-key-1')));
    },
  );
}
