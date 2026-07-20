import '../repositories/local_financial_operations_repository.dart';
import '../repositories/local_app_settings_repository.dart';
import '../repositories/local_correction_feedback_repository.dart';
import '../repositories/local_investments_repository.dart';
import '../repositories/local_financial_plans_repository.dart';
import '../repositories/local_merchant_rules_repository.dart';
import '../repositories/local_merchant_confirmations_repository.dart';
import '../repositories/local_pending_transactions_repository.dart';
import '../repositories/local_recurring_transactions_repository.dart';
import '../repositories/local_sync_repository.dart';
import '../repositories/local_savings_repository.dart';
import '../repositories/local_transactions_repository.dart';
import 'app_database.dart';
import 'daos/app_settings_dao.dart';
import 'daos/correction_feedback_dao.dart';
import 'daos/investments_dao.dart';
import 'daos/financial_plans_dao.dart';
import 'daos/migration_state_dao.dart';
import 'daos/merchant_confirmations_dao.dart';
import 'daos/merchant_rules_dao.dart';
import 'daos/pending_transactions_dao.dart';
import 'daos/recurring_transactions_dao.dart';
import 'daos/savings_dao.dart';
import 'daos/sync_metadata_dao.dart';
import 'daos/sync_queue_dao.dart';
import 'daos/transactions_dao.dart';
import 'migration/json_to_sqlite_migrator.dart';

abstract class UseSqliteLocalStoreProvider {
  Future<bool> prepareForRead({String? userId});
}

class MigrationBackedUseSqliteLocalStoreProvider
    implements UseSqliteLocalStoreProvider {
  factory MigrationBackedUseSqliteLocalStoreProvider({
    required JsonToSqliteMigrator migrator,
  }) {
    return MigrationBackedUseSqliteLocalStoreProvider._(migrator);
  }

  MigrationBackedUseSqliteLocalStoreProvider._(this._migrator);

  final JsonToSqliteMigrator _migrator;

  @override
  Future<bool> prepareForRead({String? userId}) async {
    if (await _migrator.shouldUseSqlite()) {
      return true;
    }
    final bool migrated = await _migrator.migrateIfNeeded(userId: userId);
    if (!migrated) {
      return false;
    }
    return _migrator.shouldUseSqlite();
  }
}

AppDatabase localDatabaseProvider() => AppDatabase();

MigrationStateDao migrationStateProvider(AppDatabase database) {
  return MigrationStateDao(database);
}

SyncMetadataDao syncMetadataProvider(AppDatabase database) {
  return SyncMetadataDao(database);
}

SyncQueueDao syncQueueProvider(AppDatabase database) {
  return SyncQueueDao(database);
}

LocalAppSettingsRepository localAppSettingsRepositoryProvider(
  AppDatabase database,
) {
  return LocalAppSettingsRepository(appSettingsDao: AppSettingsDao(database));
}

LocalFinancialPlansRepository localFinancialPlansRepositoryProvider(
  AppDatabase database,
) {
  return LocalFinancialPlansRepository(
    financialPlansDao: FinancialPlansDao(database),
    syncQueueDao: SyncQueueDao(database),
  );
}

LocalInvestmentsRepository localInvestmentsRepositoryProvider(
  AppDatabase database,
) {
  return LocalInvestmentsRepository(
    investmentsDao: InvestmentsDao(database),
    syncQueueDao: SyncQueueDao(database),
  );
}

LocalMerchantRulesRepository localMerchantRulesRepositoryProvider(
  AppDatabase database,
) {
  return LocalMerchantRulesRepository(
    merchantRulesDao: MerchantRulesDao(database),
    syncQueueDao: SyncQueueDao(database),
  );
}

LocalMerchantConfirmationsRepository
localMerchantConfirmationsRepositoryProvider(AppDatabase database) {
  return LocalMerchantConfirmationsRepository(
    merchantConfirmationsDao: MerchantConfirmationsDao(database),
    syncQueueDao: SyncQueueDao(database),
  );
}

LocalPendingTransactionsRepository localPendingTransactionsRepositoryProvider(
  AppDatabase database,
) {
  return LocalPendingTransactionsRepository(
    pendingTransactionsDao: PendingTransactionsDao(database),
    syncQueueDao: SyncQueueDao(database),
  );
}

LocalCorrectionFeedbackRepository localCorrectionFeedbackRepositoryProvider(
  AppDatabase database,
) {
  return LocalCorrectionFeedbackRepository(
    correctionFeedbackDao: CorrectionFeedbackDao(database),
    syncQueueDao: SyncQueueDao(database),
  );
}

LocalRecurringTransactionsRepository
localRecurringTransactionsRepositoryProvider(AppDatabase database) {
  return LocalRecurringTransactionsRepository(
    recurringTransactionsDao: RecurringTransactionsDao(database),
    syncQueueDao: SyncQueueDao(database),
  );
}

LocalTransactionsRepository localTransactionsRepositoryProvider(
  AppDatabase database,
) {
  return LocalTransactionsRepository(
    transactionsDao: TransactionsDao(database),
    syncQueueDao: SyncQueueDao(database),
  );
}

LocalSavingsRepository localSavingsRepositoryProvider(AppDatabase database) {
  return LocalSavingsRepository(
    savingsDao: SavingsDao(database),
    syncQueueDao: SyncQueueDao(database),
  );
}

LocalFinancialOperationsRepository localFinancialOperationsRepositoryProvider(
  AppDatabase database,
) {
  return LocalFinancialOperationsRepository(database: database);
}

LocalSyncRepository localSyncRepositoryProvider(AppDatabase database) {
  return LocalSyncRepository(syncMetadataDao: SyncMetadataDao(database));
}

UseSqliteLocalStoreProvider useSqliteLocalStoreProvider(
  JsonToSqliteMigrator migrator,
) {
  return MigrationBackedUseSqliteLocalStoreProvider(migrator: migrator);
}
