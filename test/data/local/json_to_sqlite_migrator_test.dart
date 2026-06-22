import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart'
    hide FinancialPlan,
         RecurringTransaction,
         MerchantRule,
         MerchantConfirmation,
         CorrectionFeedback;
import 'package:zakatapp_flutter/data/local/daos/app_settings_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/migration_state_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_queue_dao.dart';
import 'package:zakatapp_flutter/data/local/migration/json_to_sqlite_migrator.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/capture_analytics.dart';
import 'package:zakatapp_flutter/models/correction_feedback.dart';
import 'package:zakatapp_flutter/models/financial_plan.dart';
import 'package:zakatapp_flutter/models/investment_asset.dart';
import 'package:zakatapp_flutter/models/merchant_confirmation.dart';
import 'package:zakatapp_flutter/models/merchant_rule.dart';
import 'package:zakatapp_flutter/models/pending_transaction.dart' as model_pending;
import 'package:zakatapp_flutter/models/recurring_transaction.dart';
import 'package:zakatapp_flutter/models/saving.dart' as model_saving;
import 'package:zakatapp_flutter/models/transaction.dart' as model_transaction;
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

class _CountingRepository extends AppStateRepository {
  _CountingRepository(this.state)
    : super(localStorage: const LocalStorageService());

  final AppStateModel state;
  int loadCount = 0;

  @override
  Future<AppStateModel> loadAppState({String? userId}) async {
    loadCount += 1;
    return state;
  }
}

class _ThrowingRepository extends AppStateRepository {
  _ThrowingRepository() : super(localStorage: const LocalStorageService());

  @override
  Future<AppStateModel> loadAppState({String? userId}) {
    throw StateError('migration failed');
  }
}

void main() {
  late AppDatabase database;
  late MigrationStateDao migrationStateDao;
  late SyncQueueDao syncQueueDao;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase(executor: NativeDatabase.memory());
    migrationStateDao = MigrationStateDao(database);
    syncQueueDao = SyncQueueDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('migration completed should not retry', () async {
    await migrationStateDao.setValue(
      jsonToSqliteV1CompletedAt,
      '2026-06-19T12:00:00.000Z',
    );
    final repository = _CountingRepository(AppStateDefaults.create());
    final migrator = JsonToSqliteMigrator(
      database: database,
      migrationStateDao: migrationStateDao,
      legacyRepository: repository,
    );

    final result = await migrator.migrateIfNeeded();

    expect(result, isTrue);
    expect(repository.loadCount, 0);
  });

  test('migration failure records failed_at and error', () async {
    final migrator = JsonToSqliteMigrator(
      database: database,
      migrationStateDao: migrationStateDao,
      legacyRepository: _ThrowingRepository(),
    );

    final result = await migrator.migrateIfNeeded();

    expect(result, isFalse);
    expect(await migrationStateDao.getValue(jsonToSqliteV1FailedAt), isNotNull);
    expect(
      await migrationStateDao.getValue(jsonToSqliteV1Error),
      contains('migration failed'),
    );
  });

  test('imports transactions savings pending and investments and enqueues sync operations', () async {
    final repository = _CountingRepository(
      const AppStateModel(
        transactions: <model_transaction.Transaction>[
          model_transaction.Transaction(
            id: 'tx1',
            type: 'income',
            date: '2026-06-19',
            amount: 150.75,
            currency: 'USD',
            category: 'Salary',
            description: 'Imported transaction',
            createdAt: '2026-06-19T08:00:00.000Z',
            rolledOver: false,
          ),
        ],
        savings: <model_saving.Saving>[
          model_saving.Saving(
            id: 'sv1',
            assetType: 'cash',
            dateAcquired: '2026-06-18',
            amount: 500,
            remainingAmount: 450,
            unit: 'USD',
            description: 'Imported saving',
            purchaseCurrency: 'USD',
            purchaseAmount: 500,
            createdAt: '2026-06-18T08:00:00.000Z',
          ),
        ],
        recurringTransactions: <RecurringTransaction>[],
        investments: <InvestmentAsset>[
          InvestmentAsset(
            id: 'inv1',
            investmentType: 'real_estate',
            assetSubtype: 'apartment',
            ownershipType: 'fully_owned',
            valuationMode: 'net_fair',
            currency: 'USD',
            originalPrice: 100000,
            totalInterest: 0,
            totalPayable: 100000,
            paidAmount: 100000,
            remainingAmount: 0,
            installmentPlan: <Map<String, dynamic>>[],
            valuationDate: '2026-06-18',
            marketValue: 120000,
            marketValueDate: '2026-06-18',
            valuationSource: 'manual',
            loanBalance: 0,
            loanAsOfDate: '2026-06-18',
            paidAmountToDate: 100000,
            ownershipSharePct: 100,
            country: 'US',
            location: 'NY',
            inflationRateAnnual: 3,
            estimatedCurrentValue: 120000,
            description: 'Imported investment',
            noZakat: true,
            createdAt: '2026-06-18T08:00:00.000Z',
          ),
        ],
        financialPlans: <FinancialPlan>[],
        pendingTransactions: <model_pending.PendingTransaction>[
          model_pending.PendingTransaction(
            id: 'pt1',
            source: 'manual',
            rawMessage: 'Imported pending',
            createdAt: '2026-06-19T07:00:00.000Z',
            suggestedType: 'expense',
            suggestedAmount: 19.5,
            suggestedCurrency: 'USD',
            confidence: 0.9,
            status: model_pending.CaptureStatus.pendingReview,
          ),
        ],
        lastRollover: '',
        categories: AppCategories(income: <String>[], expense: <String>[]),
        zakatPaidMonths: <String>[],
        processedExpenseIds: <String>[],
        mainCurrency: 'USD',
        defaultEntryCurrency: 'USD',
        zakatExpenseIds: <String, dynamic>{},
        zakatMethod: 'hawl',
        zakatAnnualDate: '',
        zakatNisabBasis: 'gold85',
        zakatScheduleFilter: 'unpaid',
        marketData: <String, dynamic>{},
        marketHistory: <Map<String, dynamic>>[],
        syncHealth: SyncHealth(
          lastSuccessAt: '',
          lastFailureAt: '',
          lastError: '',
          pendingWrites: 0,
        ),
        lastModifiedAt: '',
        languagePreference: 'en',
        themeMode: 'system',
        biometricLockEnabled: false,
        biometricHideWealthEnabled: false,
        biometricExportEnabled: false,
        biometricRestoreEnabled: false,
        biometricAutoLockDelay: '1_minute',
        merchantRules: <String, MerchantRule>{},
        merchantAliases: <String, String>{},
        captureAnalytics: CaptureAnalytics(
          parsedMessages: 0,
          autoApprovedMessages: 0,
          duplicateMessages: 0,
          ignoredMessages: 0,
          correctedMessages: 0,
          learnedRules: 0,
          autoApprovedRules: 0,
          capturedFromAppleShortcuts: 0,
          capturedFromAppleShortcutsAutoApproved: 0,
          capturedFromAppleShortcutsIgnored: 0,
        ),
        correctionFeedback: <CorrectionFeedback>[],
        merchantConfirmations: <MerchantConfirmation>[],
        smartCaptureEnabled: true,
        smartCaptureAutoApproveEnabled: false,
      ),
    );
    final migrator = JsonToSqliteMigrator(
      database: database,
      migrationStateDao: migrationStateDao,
      legacyRepository: repository,
    );

    final result = await migrator.migrateIfNeeded();
    final txRows = await database.select(database.transactions).get();
    final savingRows = await database.select(database.savings).get();
    final pendingRows = await database.select(database.pendingTransactions).get();
    final investmentRows = await database.select(database.investments).get();
    final appSettingsRows = await database.select(database.appSettings).get();
    final queueRows = await syncQueueDao.loadReadyBatch();

    expect(result, isTrue);
    expect(txRows, hasLength(1));
    expect(txRows.single.amountText, '150.75');
    expect(savingRows, hasLength(1));
    expect(savingRows.single.remainingAmountText, '450');
    expect(pendingRows, hasLength(1));
    expect(pendingRows.single.suggestedAmountText, '19.5');
    expect(investmentRows, hasLength(1));
    expect(investmentRows.single.originalPriceText, '100000');
    expect(appSettingsRows, hasLength(25));
    expect(
      await AppSettingsDao(database).getJson<List<String>>('zakat_paid_months'),
      <String>[],
    );
    expect(queueRows, hasLength(4));
    expect(await migrationStateDao.hasCompletedJsonToSqliteV1(), isTrue);
  });

  test('migration imports zakat settings into SQLite settings rows', () async {
    final repository = _CountingRepository(
      AppStateModel.fromJson(<String, dynamic>{
        'zakatPaidMonths': <String>['2026-06'],
        'zakatExpenseIds': <String, dynamic>{'2026-06': 'tx-paid'},
        'processedExpenseIds': <String>['tx-paid'],
        'zakatMethod': 'annual',
        'zakatAnnualDate': '09-01',
        'zakatNisabBasis': 'silver595',
        'zakatScheduleFilter': 'paid',
      }),
    );
    final migrator = JsonToSqliteMigrator(
      database: database,
      migrationStateDao: migrationStateDao,
      legacyRepository: repository,
    );

    final result = await migrator.migrateIfNeeded();
    final settings = await AppSettingsDao(database).getAllSettings();

    expect(result, isTrue);
    expect(settings['zakat_paid_months'], <dynamic>['2026-06']);
    expect(
      settings['zakat_expense_ids'],
      <String, dynamic>{'2026-06': 'tx-paid'},
    );
    expect(settings['processed_expense_ids'], <dynamic>['tx-paid']);
    expect(settings['zakat_method'], 'annual');
    expect(settings['zakat_annual_date'], '09-01');
    expect(settings['zakat_nisab_basis'], 'silver595');
    expect(settings['zakat_schedule_filter'], 'paid');
  });

  test('migration imports financial plans into SQLite financial plans table', () async {
    final repository = _CountingRepository(
      AppStateModel.fromJson(<String, dynamic>{
        'financialPlans': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'plan-1',
            'name': 'Plan 1',
            'startDate': '2026-06-01',
            'projectionCurrency': 'USD',
            'startingBalance': 1200.5,
            'startingBalanceDate': '2026-06-01',
            'startingBalanceMode': 'manual',
            'snapshotWealthCurrency': 'USD',
            'startingAssetBreakdown': <String, double>{'cash': 1200.5},
            'monthlyIncome': 4000,
            'monthlyExpenses': 2500,
            'includeInstallments': true,
            'includeZakat': true,
            'durationYears': 2,
            'createdAt': '2026-06-19T08:00:00.000Z',
            'isActive': true,
            'startingAssets': 5000,
            'startingLiabilities': 1000,
            'startingNetWorth': 4000,
            'startingNisabSnapshot': 4500,
            'startingGoldPriceSnapshot': 3000,
            'startingFxSnapshot': <String, double>{'USD': 1},
          },
        ],
      }),
    );
    final migrator = JsonToSqliteMigrator(
      database: database,
      migrationStateDao: migrationStateDao,
      legacyRepository: repository,
    );

    final result = await migrator.migrateIfNeeded();
    final rows = await database.select(database.financialPlans).get();

    expect(result, isTrue);
    expect(rows, hasLength(1));
    expect(rows.single.id, 'plan-1');
    expect(rows.single.startingBalanceText, '1200.5');
    expect(rows.single.startingFxSnapshotJson, contains('"USD":1'));
  });

  test('imports merchant rules into SQLite merchant rules table', () async {
    final repository = _CountingRepository(
      AppStateModel.fromJson(<String, dynamic>{
        'merchantRules': <String, dynamic>{
          'coffee shop': <String, dynamic>{
            'merchantName': 'Coffee Shop',
            'categoryId': 'Food',
            'defaultType': 'expense',
            'autoApprove': true,
            'usageCount': 4,
            'confidence': 0.92,
            'lastUsed': '2026-06-19T08:00:00.000Z',
            'source': 'custom',
            'aliases': <String>['Cafe'],
            'enabled': true,
            'isBuiltinOverride': false,
          },
        },
        'merchantAliases': <String, String>{'cafe': 'Coffee Shop'},
      }),
    );
    final migrator = JsonToSqliteMigrator(
      database: database,
      migrationStateDao: migrationStateDao,
      legacyRepository: repository,
    );

    final result = await migrator.migrateIfNeeded();
    final rows = await database.select(database.merchantRules).get();

    expect(result, isTrue);
    expect(rows, hasLength(1));
    expect(rows.single.id, 'coffee shop');
    expect(rows.single.aliasesJson, '["Cafe"]');
    expect(rows.single.confidenceText, '0.92');
  });

  test('imports merchant confirmations into SQLite merchant confirmations table', () async {
    final repository = _CountingRepository(
      AppStateModel.fromJson(<String, dynamic>{
        'merchantConfirmations': <Map<String, dynamic>>[
          <String, dynamic>{
            'merchantName': 'Coffee Shop',
            'categoryId': 'Food',
            'confirmations': 3,
            'corrections': 1,
          },
        ],
      }),
    );
    final migrator = JsonToSqliteMigrator(
      database: database,
      migrationStateDao: migrationStateDao,
      legacyRepository: repository,
    );

    final result = await migrator.migrateIfNeeded();
    final rows = await database.select(database.merchantConfirmations).get();

    expect(result, isTrue);
    expect(rows, hasLength(1));
    expect(rows.single.id, 'coffee shop|food');
    expect(rows.single.confirmations, 3);
    expect(rows.single.corrections, 1);
  });

  test('imports correction feedback into SQLite correction feedback table', () async {
    final repository = _CountingRepository(
      AppStateModel.fromJson(<String, dynamic>{
        'correctionFeedback': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'fb-1',
            'fieldName': 'category',
            'originalValue': 'Food',
            'correctedValue': 'Bills',
            'createdAt': '2026-06-19T08:00:00.000Z',
          },
        ],
      }),
    );
    final migrator = JsonToSqliteMigrator(
      database: database,
      migrationStateDao: migrationStateDao,
      legacyRepository: repository,
    );

    final result = await migrator.migrateIfNeeded();
    final rows = await database.select(database.correctionFeedbacks).get();

    expect(result, isTrue);
    expect(rows, hasLength(1));
    expect(rows.single.id, 'fb-1');
    expect(rows.single.fieldName, 'category');
    expect(rows.single.createdAt, '2026-06-19T08:00:00.000Z');
  });
}
