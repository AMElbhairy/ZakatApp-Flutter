import '../../../models/app_state.dart';
import '../../../repositories/app_state_repository.dart';
import '../../repositories/local_app_settings_repository.dart';
import '../../repositories/local_correction_feedback_repository.dart';
import '../../repositories/local_investments_repository.dart';
import '../../repositories/local_financial_plans_repository.dart';
import '../../repositories/local_merchant_rules_repository.dart';
import '../../repositories/local_merchant_confirmations_repository.dart';
import '../../repositories/local_pending_transactions_repository.dart';
import '../../repositories/local_recurring_transactions_repository.dart';
import '../../repositories/local_savings_repository.dart';
import '../../repositories/local_transactions_repository.dart';
import '../app_database.dart';
import '../daos/app_settings_dao.dart';
import '../daos/correction_feedback_dao.dart';
import '../daos/financial_plans_dao.dart';
import '../daos/investments_dao.dart';
import '../daos/migration_state_dao.dart';
import '../daos/merchant_confirmations_dao.dart';
import '../daos/merchant_rules_dao.dart';
import '../daos/pending_transactions_dao.dart';
import '../daos/recurring_transactions_dao.dart';
import '../daos/savings_dao.dart';
import '../daos/sync_queue_dao.dart';
import '../daos/transactions_dao.dart';

class JsonToSqliteMigrator {
  JsonToSqliteMigrator({
    required this.database,
    required this.migrationStateDao,
    required this.legacyRepository,
    TransactionsDao? transactionsDao,
    SavingsDao? savingsDao,
    SyncQueueDao? syncQueueDao,
    PendingTransactionsDao? pendingTransactionsDao,
    InvestmentsDao? investmentsDao,
    AppSettingsDao? appSettingsDao,
    LocalAppSettingsRepository? appSettingsRepository,
    FinancialPlansDao? financialPlansDao,
    LocalFinancialPlansRepository? financialPlansRepository,
    MerchantRulesDao? merchantRulesDao,
    LocalMerchantRulesRepository? merchantRulesRepository,
    MerchantConfirmationsDao? merchantConfirmationsDao,
    LocalMerchantConfirmationsRepository? merchantConfirmationsRepository,
    CorrectionFeedbackDao? correctionFeedbackDao,
    LocalCorrectionFeedbackRepository? correctionFeedbackRepository,
    RecurringTransactionsDao? recurringTransactionsDao,
    LocalRecurringTransactionsRepository? recurringTransactionsRepository,
    LocalTransactionsRepository? transactionsRepository,
    LocalSavingsRepository? savingsRepository,
    LocalPendingTransactionsRepository? pendingTransactionsRepository,
    LocalInvestmentsRepository? investmentsRepository,
  }) : _pendingTransactionsRepository =
           pendingTransactionsRepository ??
           LocalPendingTransactionsRepository(
             pendingTransactionsDao:
                 pendingTransactionsDao ?? PendingTransactionsDao(database),
             syncQueueDao: syncQueueDao ?? SyncQueueDao(database),
           ),
       _investmentsRepository =
           investmentsRepository ??
           LocalInvestmentsRepository(
             investmentsDao: investmentsDao ?? InvestmentsDao(database),
             syncQueueDao: syncQueueDao ?? SyncQueueDao(database),
           ),
       _appSettingsRepository =
           appSettingsRepository ??
           LocalAppSettingsRepository(
             appSettingsDao: appSettingsDao ?? AppSettingsDao(database),
           ),
       _financialPlansRepository =
           financialPlansRepository ??
           LocalFinancialPlansRepository(
             financialPlansDao:
                 financialPlansDao ?? FinancialPlansDao(database),
             syncQueueDao: syncQueueDao ?? SyncQueueDao(database),
           ),
       _merchantRulesRepository =
           merchantRulesRepository ??
           LocalMerchantRulesRepository(
             merchantRulesDao: merchantRulesDao ?? MerchantRulesDao(database),
             syncQueueDao: syncQueueDao ?? SyncQueueDao(database),
           ),
       _merchantConfirmationsRepository =
           merchantConfirmationsRepository ??
           LocalMerchantConfirmationsRepository(
             merchantConfirmationsDao:
                 merchantConfirmationsDao ?? MerchantConfirmationsDao(database),
             syncQueueDao: syncQueueDao ?? SyncQueueDao(database),
           ),
       _correctionFeedbackRepository =
           correctionFeedbackRepository ??
           LocalCorrectionFeedbackRepository(
             correctionFeedbackDao:
                 correctionFeedbackDao ?? CorrectionFeedbackDao(database),
             syncQueueDao: syncQueueDao ?? SyncQueueDao(database),
           ),
       _recurringTransactionsRepository =
           recurringTransactionsRepository ??
           LocalRecurringTransactionsRepository(
             recurringTransactionsDao:
                 recurringTransactionsDao ?? RecurringTransactionsDao(database),
             syncQueueDao: syncQueueDao ?? SyncQueueDao(database),
           ),
       _transactionsRepository =
           transactionsRepository ??
           LocalTransactionsRepository(
             transactionsDao: transactionsDao ?? TransactionsDao(database),
             syncQueueDao: syncQueueDao ?? SyncQueueDao(database),
           ),
       _savingsRepository =
           savingsRepository ??
           LocalSavingsRepository(
             savingsDao: savingsDao ?? SavingsDao(database),
             syncQueueDao: syncQueueDao ?? SyncQueueDao(database),
           );

  final AppDatabase database;
  final MigrationStateDao migrationStateDao;
  final AppStateRepository legacyRepository;
  final LocalPendingTransactionsRepository _pendingTransactionsRepository;
  final LocalInvestmentsRepository _investmentsRepository;
  final LocalAppSettingsRepository _appSettingsRepository;
  final LocalFinancialPlansRepository _financialPlansRepository;
  final LocalMerchantRulesRepository _merchantRulesRepository;
  final LocalMerchantConfirmationsRepository _merchantConfirmationsRepository;
  final LocalCorrectionFeedbackRepository _correctionFeedbackRepository;
  final LocalRecurringTransactionsRepository _recurringTransactionsRepository;
  final LocalTransactionsRepository _transactionsRepository;
  final LocalSavingsRepository _savingsRepository;

  Future<bool> shouldUseSqlite() {
    return migrationStateDao.hasCompletedJsonToSqliteV1();
  }

  Future<bool> migrateIfNeeded({String? userId}) async {
    if (await migrationStateDao.hasCompletedJsonToSqliteV1()) {
      return true;
    }

    final String startedAt = DateTime.now().toUtc().toIso8601String();
    await migrationStateDao.setValue(jsonToSqliteV1StartedAt, startedAt);
    await migrationStateDao.clearValue(jsonToSqliteV1FailedAt);
    await migrationStateDao.clearValue(jsonToSqliteV1Error);

    try {
      final AppStateModel legacyState = await legacyRepository.loadAppState(
        userId: userId,
      );
      await database.transaction(() async {
        await _transactionsRepository.importTransactions(
          legacyState.transactions,
        );
        await _savingsRepository.importSavings(legacyState.savings);
        await _appSettingsRepository.importSettings(
          _allAppSettingsPayload(legacyState),
        );
        await _financialPlansRepository.importFinancialPlans(
          legacyState.financialPlans,
        );
        await _merchantRulesRepository.importMerchantRules(
          legacyState.merchantRules.values,
        );
        await _merchantConfirmationsRepository.importMerchantConfirmations(
          legacyState.merchantConfirmations,
        );
        await _correctionFeedbackRepository.importCorrectionFeedback(
          legacyState.correctionFeedback,
        );
        await _recurringTransactionsRepository.importRecurringTransactions(
          legacyState.recurringTransactions,
        );
        await _pendingTransactionsRepository.importPendingTransactions(
          legacyState.pendingTransactions,
        );
        await _investmentsRepository.importInvestments(legacyState.investments);
      });
      final String completedAt = DateTime.now().toUtc().toIso8601String();
      await migrationStateDao.setValue(jsonToSqliteV1CompletedAt, completedAt);
      return true;
    } catch (error) {
      final String failedAt = DateTime.now().toUtc().toIso8601String();
      await migrationStateDao.setValue(jsonToSqliteV1FailedAt, failedAt);
      await migrationStateDao.setValue(jsonToSqliteV1Error, error.toString());
      return false;
    }
  }

  Map<String, dynamic> _allAppSettingsPayload(AppStateModel state) {
    return <String, dynamic>{
      'zakat_paid_months': state.zakatPaidMonths,
      'zakat_expense_ids': state.zakatExpenseIds,
      'processed_expense_ids': state.processedExpenseIds,
      'zakat_method': state.zakatMethod,
      'zakat_annual_date': state.zakatAnnualDate,
      'zakat_nisab_basis': state.zakatNisabBasis,
      'zakat_schedule_filter': state.zakatScheduleFilter,
      'main_currency': state.mainCurrency,
      'default_entry_currency': state.defaultEntryCurrency,
      'language_preference': state.languagePreference,
      'theme_mode': state.themeMode,
      'biometric_lock_enabled': state.biometricLockEnabled,
      'biometric_hide_wealth_enabled': state.biometricHideWealthEnabled,
      'biometric_export_enabled': state.biometricExportEnabled,
      'biometric_restore_enabled': state.biometricRestoreEnabled,
      'biometric_auto_lock_delay': state.biometricAutoLockDelay,
      'smart_capture_enabled': state.smartCaptureEnabled,
      'smart_capture_auto_approve_enabled': state.smartCaptureAutoApproveEnabled,
      'categories': state.categories.toJson(),
      'last_rollover': state.lastRollover,
      'merchant_aliases': state.merchantAliases,
      'capture_analytics': state.captureAnalytics.toJson(),
      'market_data': state.marketData,
      'market_history': state.marketHistory,
      'sync_health': state.syncHealth.toJson(),
      if (state.aiSettings != null)
        'ai_settings': _sanitizeAiSettingsForSync(state.aiSettings!),
      if (state.restorePromptDismissedUserId != null)
        'restore_prompt_dismissed_user_id': state.restorePromptDismissedUserId,
    };
  }

  Map<String, dynamic> _sanitizeAiSettingsForSync(Map<String, dynamic> aiSettings) {
    final Map<String, dynamic> copy = Map<String, dynamic>.from(aiSettings);
    copy.remove('keys');
    return copy;
  }
}
