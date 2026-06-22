import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/app_settings_table.dart';
import 'tables/correction_feedback_table.dart';
import 'tables/financial_plans_table.dart';
import 'tables/merchant_rules_table.dart';
import 'tables/merchant_confirmations_table.dart';
import 'tables/investments_table.dart';
import 'tables/migration_state_table.dart';
import 'tables/pending_transactions_table.dart';
import 'tables/recurring_transactions_table.dart';
import 'tables/savings_table.dart';
import 'tables/sync_metadata_table.dart';
import 'tables/sync_queue_table.dart';
import 'tables/transactions_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: <Type>[
    Transactions,
    Savings,
    Investments,
    PendingTransactions,
    RecurringTransactions,
    AppSettings,
    FinancialPlans,
    MerchantRules,
    MerchantConfirmations,
    CorrectionFeedbacks,
    SyncMetadata,
    SyncQueue,
    MigrationState,
  ],
  daos: <Type>[],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({String? userId, QueryExecutor? executor})
    : userId = userId?.trim().isEmpty == true ? null : userId?.trim(),
      super(executor ?? _openConnection(userId));

  final String? userId;

  String get fileName =>
      userId == null ? 'zakat_app.sqlite' : 'zakatapp_$userId.sqlite';

  static String fileNameForUser(String? userId) {
    final String cleanUserId = userId == null || userId.trim().isEmpty
        ? ''
        : userId.trim();
    return cleanUserId.isEmpty
        ? 'zakat_app.sqlite'
        : 'zakatapp_$cleanUserId.sqlite';
  }

  static Future<void> deleteDatabaseFiles({String? userId}) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final Set<String> filenames = <String>{
      fileNameForUser(null),
      if ((userId ?? '').trim().isNotEmpty) fileNameForUser(userId),
    };
    for (final String name in filenames) {
      final File file = File(p.join(directory.path, name));
      await _deleteFileArtifacts(file);
    }
  }

  Future<String?> resolveDatabasePath() async {
    try {
      final Directory directory = await getApplicationDocumentsDirectory();
      return p.join(directory.path, fileName);
    } catch (_) {
      return null;
    }
  }

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) async {
      await migrator.createAll();
      await _createIndexes();
    },
    onUpgrade: (Migrator migrator, int from, int to) async {
      if (from < 2) {
        await migrator.createTable(recurringTransactions);
      }
      if (from < 3) {
        await migrator.createTable(merchantRules);
      }
      if (from < 4) {
        await migrator.createTable(merchantConfirmations);
      }
      if (from < 5) {
        await migrator.createTable(correctionFeedbacks);
      }
      if (from < 6) {
        await migrator.addColumn(investments, investments.yearlyGrowthRateText);
      }
      await _createIndexes();
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
    },
  );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_updated_at '
      'ON transactions(updated_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_deleted_at '
      'ON transactions(deleted_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_date '
      'ON transactions(date);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_category '
      'ON transactions(category);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_savings_updated_at '
      'ON savings(updated_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_savings_deleted_at '
      'ON savings(deleted_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_investments_updated_at '
      'ON investments(updated_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_investments_deleted_at '
      'ON investments(deleted_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pending_transactions_updated_at '
      'ON pending_transactions(updated_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pending_transactions_deleted_at '
      'ON pending_transactions(deleted_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_recurring_transactions_updated_at '
      'ON recurring_transactions(updated_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_recurring_transactions_deleted_at '
      'ON recurring_transactions(deleted_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_financial_plans_updated_at '
      'ON financial_plans(updated_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_financial_plans_deleted_at '
      'ON financial_plans(deleted_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_merchant_rules_updated_at '
      'ON merchant_rules(updated_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_merchant_rules_deleted_at '
      'ON merchant_rules(deleted_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_merchant_confirmations_updated_at '
      'ON merchant_confirmations(updated_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_merchant_confirmations_deleted_at '
      'ON merchant_confirmations(deleted_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_correction_feedback_updated_at '
      'ON correction_feedbacks(updated_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_correction_feedback_deleted_at '
      'ON correction_feedbacks(deleted_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_available_at '
      'ON sync_queue(available_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_priority_available '
      'ON sync_queue(priority DESC, available_at ASC, id ASC);',
    );
  }
}

LazyDatabase _openConnection(String? userId) {
  return LazyDatabase(() async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String cleanUserId = userId == null || userId.trim().isEmpty
        ? ''
        : userId.trim();
    final String filename = cleanUserId.isEmpty
        ? 'zakat_app.sqlite'
        : 'zakatapp_$cleanUserId.sqlite';
    final File file = File(p.join(directory.path, filename));
    return NativeDatabase.createInBackground(file);
  });
}

Future<void> _deleteFileArtifacts(File file) async {
  final List<File> candidates = <File>[
    file,
    File('${file.path}-wal'),
    File('${file.path}-shm'),
    File('${file.path}-journal'),
  ];
  for (final File candidate in candidates) {
    try {
      if (await candidate.exists()) {
        await candidate.delete();
      }
    } catch (_) {}
  }
}
