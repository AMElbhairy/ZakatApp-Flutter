import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart'
    hide
        Transaction,
        Saving,
        PendingTransaction,
        FinancialPlan,
        RecurringTransaction,
        MerchantRule,
        MerchantConfirmation,
        CorrectionFeedback;
import 'package:zakatapp_flutter/data/local/daos/investments_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/financial_plans_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/pending_transactions_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/recurring_transactions_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/savings_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/correction_feedback_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/merchant_confirmations_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/merchant_rules_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_metadata_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_queue_dao.dart';
import 'package:zakatapp_flutter/data/repositories/local_correction_feedback_repository.dart';
import 'package:zakatapp_flutter/data/local/daos/transactions_dao.dart';
import 'package:zakatapp_flutter/data/repositories/local_financial_plans_repository.dart';
import 'package:zakatapp_flutter/data/repositories/local_investments_repository.dart';
import 'package:zakatapp_flutter/data/repositories/local_merchant_confirmations_repository.dart';
import 'package:zakatapp_flutter/data/repositories/local_merchant_rules_repository.dart';
import 'package:zakatapp_flutter/data/repositories/local_pending_transactions_repository.dart';
import 'package:zakatapp_flutter/data/repositories/local_recurring_transactions_repository.dart';
import 'package:zakatapp_flutter/data/repositories/local_savings_repository.dart';
import 'package:zakatapp_flutter/data/repositories/local_transactions_repository.dart';
import 'package:zakatapp_flutter/data/sync/pull_sync_manager.dart';
import 'package:zakatapp_flutter/models/correction_feedback.dart';
import 'package:zakatapp_flutter/models/financial_plan.dart';
import 'package:zakatapp_flutter/models/investment_asset.dart';
import 'package:zakatapp_flutter/models/merchant_confirmation.dart';
import 'package:zakatapp_flutter/models/merchant_rule.dart';
import 'package:zakatapp_flutter/models/pending_transaction.dart';
import 'package:zakatapp_flutter/models/recurring_transaction.dart';
import 'package:zakatapp_flutter/models/saving.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/services/firestore_sync_manager.dart';

class _FakeFirestoreSyncManager implements FirestoreSyncManager {
  FirestoreCollectionDelta<Transaction> txDelta =
      const FirestoreCollectionDelta(items: [], cursor: '');
  FirestoreDeletedIdsDelta txDeletedDelta = const FirestoreDeletedIdsDelta(
    ids: [],
    cursor: '',
  );
  FirestoreCollectionDelta<Saving> savDelta = const FirestoreCollectionDelta(
    items: [],
    cursor: '',
  );
  FirestoreDeletedIdsDelta savDeletedDelta = const FirestoreDeletedIdsDelta(
    ids: [],
    cursor: '',
  );
  FirestoreCollectionDelta<InvestmentAsset> invDelta =
      const FirestoreCollectionDelta(items: [], cursor: '');
  FirestoreDeletedIdsDelta invDeletedDelta = const FirestoreDeletedIdsDelta(
    ids: [],
    cursor: '',
  );
  FirestoreCollectionDelta<FinancialPlan> planDelta =
      const FirestoreCollectionDelta(items: [], cursor: '');
  FirestoreDeletedIdsDelta planDeletedDelta = const FirestoreDeletedIdsDelta(
    ids: [],
    cursor: '',
  );
  FirestoreCollectionDelta<RecurringTransaction> recurringDelta =
      const FirestoreCollectionDelta(items: [], cursor: '');
  FirestoreDeletedIdsDelta recurringDeletedDelta =
      const FirestoreDeletedIdsDelta(ids: [], cursor: '');
  FirestoreCollectionDelta<PendingTransaction> pendingDelta =
      const FirestoreCollectionDelta(items: [], cursor: '');
  FirestoreDeletedIdsDelta pendingDeletedDelta = const FirestoreDeletedIdsDelta(
    ids: [],
    cursor: '',
  );
  FirestoreCollectionDelta<MerchantRule> merchantRulesDelta =
      const FirestoreCollectionDelta(items: [], cursor: '');
  FirestoreDeletedIdsDelta merchantRulesDeletedDelta =
      const FirestoreDeletedIdsDelta(ids: [], cursor: '');
  FirestoreCollectionDelta<MerchantConfirmation> merchantConfirmationsDelta =
      const FirestoreCollectionDelta(items: [], cursor: '');
  FirestoreDeletedIdsDelta merchantConfirmationsDeletedDelta =
      const FirestoreDeletedIdsDelta(ids: [], cursor: '');
  FirestoreCollectionDelta<CorrectionFeedback> correctionFeedbackDelta =
      const FirestoreCollectionDelta(items: [], cursor: '');
  FirestoreDeletedIdsDelta correctionFeedbackDeletedDelta =
      const FirestoreDeletedIdsDelta(ids: [], cursor: '');

  @override
  Future<FirestoreCollectionDelta<Transaction>> loadTransactionsSince({
    required String uid,
    required String sinceCursor,
  }) async => txDelta;

  @override
  Future<FirestoreDeletedIdsDelta> loadDeletedTransactionIdsSince({
    required String uid,
    required String sinceCursor,
  }) async => txDeletedDelta;

  @override
  Future<FirestoreCollectionDelta<Saving>> loadSavingsSince({
    required String uid,
    required String sinceCursor,
  }) async => savDelta;

  @override
  Future<FirestoreDeletedIdsDelta> loadDeletedSavingsSince({
    required String uid,
    required String sinceCursor,
  }) async => savDeletedDelta;

  @override
  String savingsCollectionPath(String uid) => 'users/$uid/savings';

  @override
  Future<FirestoreCollectionDelta<InvestmentAsset>> loadInvestmentsSince({
    required String uid,
    required String sinceCursor,
  }) async => invDelta;

  @override
  Future<FirestoreDeletedIdsDelta> loadDeletedInvestmentsSince({
    required String uid,
    required String sinceCursor,
  }) async => invDeletedDelta;

  @override
  Future<FirestoreCollectionDelta<FinancialPlan>> loadFinancialPlansSince({
    required String uid,
    required String sinceCursor,
  }) async => planDelta;

  @override
  Future<FirestoreDeletedIdsDelta> loadDeletedFinancialPlansSince({
    required String uid,
    required String sinceCursor,
  }) async => planDeletedDelta;

  @override
  Future<FirestoreCollectionDelta<RecurringTransaction>>
  loadRecurringTransactionsSince({
    required String uid,
    required String sinceCursor,
  }) async => recurringDelta;

  @override
  Future<FirestoreDeletedIdsDelta> loadDeletedRecurringTransactionsSince({
    required String uid,
    required String sinceCursor,
  }) async => recurringDeletedDelta;

  @override
  Future<FirestoreCollectionDelta<PendingTransaction>> loadCaptureInboxSince({
    required String uid,
    required String sinceCursor,
  }) async => pendingDelta;

  @override
  Future<FirestoreDeletedIdsDelta> loadDeletedCaptureInboxSince({
    required String uid,
    required String sinceCursor,
  }) async => pendingDeletedDelta;

  @override
  Future<FirestoreCollectionDelta<MerchantRule>> loadMerchantRulesSince({
    required String uid,
    required String sinceCursor,
  }) async => merchantRulesDelta;

  @override
  Future<FirestoreDeletedIdsDelta> loadDeletedMerchantRulesSince({
    required String uid,
    required String sinceCursor,
  }) async => merchantRulesDeletedDelta;

  @override
  Future<FirestoreCollectionDelta<MerchantConfirmation>>
  loadMerchantConfirmationsSince({
    required String uid,
    required String sinceCursor,
  }) async => merchantConfirmationsDelta;

  @override
  Future<FirestoreDeletedIdsDelta> loadDeletedMerchantConfirmationsSince({
    required String uid,
    required String sinceCursor,
  }) async => merchantConfirmationsDeletedDelta;

  @override
  Future<FirestoreCollectionDelta<CorrectionFeedback>>
  loadCorrectionFeedbackSince({
    required String uid,
    required String sinceCursor,
  }) async => correctionFeedbackDelta;

  @override
  Future<FirestoreDeletedIdsDelta> loadDeletedCorrectionFeedbackSince({
    required String uid,
    required String sinceCursor,
  }) async => correctionFeedbackDeletedDelta;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase database;
  late SyncMetadataDao syncMetadataDao;
  late SyncQueueDao syncQueueDao;
  late LocalTransactionsRepository transactionsRepository;
  late LocalSavingsRepository savingsRepository;
  late LocalInvestmentsRepository investmentsRepository;
  late LocalFinancialPlansRepository financialPlansRepository;
  late LocalRecurringTransactionsRepository recurringTransactionsRepository;
  late LocalPendingTransactionsRepository pendingTransactionsRepository;
  late LocalMerchantRulesRepository merchantRulesRepository;
  late LocalMerchantConfirmationsRepository merchantConfirmationsRepository;
  late LocalCorrectionFeedbackRepository correctionFeedbackRepository;
  late _FakeFirestoreSyncManager fakeFirestore;
  late PullSyncManager pullSyncManager;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    syncMetadataDao = SyncMetadataDao(database);
    syncQueueDao = SyncQueueDao(database);
    transactionsRepository = LocalTransactionsRepository(
      transactionsDao: TransactionsDao(database),
      syncQueueDao: syncQueueDao,
    );
    savingsRepository = LocalSavingsRepository(
      savingsDao: SavingsDao(database),
      syncQueueDao: syncQueueDao,
    );
    investmentsRepository = LocalInvestmentsRepository(
      investmentsDao: InvestmentsDao(database),
      syncQueueDao: syncQueueDao,
    );
    financialPlansRepository = LocalFinancialPlansRepository(
      financialPlansDao: FinancialPlansDao(database),
      syncQueueDao: syncQueueDao,
    );
    recurringTransactionsRepository = LocalRecurringTransactionsRepository(
      recurringTransactionsDao: RecurringTransactionsDao(database),
      syncQueueDao: syncQueueDao,
    );
    pendingTransactionsRepository = LocalPendingTransactionsRepository(
      pendingTransactionsDao: PendingTransactionsDao(database),
      syncQueueDao: syncQueueDao,
    );
    merchantRulesRepository = LocalMerchantRulesRepository(
      merchantRulesDao: MerchantRulesDao(database),
      syncQueueDao: syncQueueDao,
    );
    merchantConfirmationsRepository = LocalMerchantConfirmationsRepository(
      merchantConfirmationsDao: MerchantConfirmationsDao(database),
      syncQueueDao: syncQueueDao,
    );
    correctionFeedbackRepository = LocalCorrectionFeedbackRepository(
      correctionFeedbackDao: CorrectionFeedbackDao(database),
      syncQueueDao: syncQueueDao,
    );
    fakeFirestore = _FakeFirestoreSyncManager();
    pullSyncManager = PullSyncManager(
      firestoreSyncManager: fakeFirestore,
      syncMetadataDao: syncMetadataDao,
      transactionsRepository: transactionsRepository,
      savingsRepository: savingsRepository,
      financialPlansRepository: financialPlansRepository,
      investmentsRepository: investmentsRepository,
      recurringTransactionsRepository: recurringTransactionsRepository,
      pendingTransactionsRepository: pendingTransactionsRepository,
      merchantRulesRepository: merchantRulesRepository,
      merchantConfirmationsRepository: merchantConfirmationsRepository,
      correctionFeedbackRepository: correctionFeedbackRepository,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'pullSync applies remote transaction upsert, advances cursor, and does NOT enqueue sync_queue row',
    () async {
      final Transaction tx = Transaction(
        id: 'tx-remote-1',
        type: 'income',
        date: '2026-06-19',
        amount: 150.0,
        currency: 'USD',
        category: 'Salary',
        description: 'Remote deposit',
        createdAt: '2026-06-19T08:00:00.000Z',
        rolledOver: false,
      );

      fakeFirestore.txDelta = FirestoreCollectionDelta(
        items: [tx],
        cursor: '2026-06-19T09:00:00.000Z',
      );

      await pullSyncManager.pullSync('user123');

      // Verify it is inserted into the local DB
      final List<Transaction> localTxs = await transactionsRepository
          .getActiveTransactions();
      expect(localTxs, hasLength(1));
      expect(localTxs.first.id, 'tx-remote-1');
      expect(localTxs.first.amount, 150.0);

      // Verify cursor was advanced in metadata
      final String? cursor = await syncMetadataDao.getCursor('transactions');
      expect(cursor, '2026-06-19T09:00:00.000Z');

      // Verify it did NOT enqueue anything in the sync queue
      final queue = await syncQueueDao.loadReadyBatch();
      expect(queue, isEmpty);
    },
  );

  test(
    'pullSync writes transaction cursors even when no docs are returned',
    () async {
      fakeFirestore.txDelta = const FirestoreCollectionDelta<Transaction>(
        items: <Transaction>[],
        cursor: '',
      );
      fakeFirestore.txDeletedDelta = const FirestoreDeletedIdsDelta(
        ids: <String>[],
        cursor: '',
      );

      await pullSyncManager.pullSync('user123');

      final String? cursor = await syncMetadataDao.getCursor('transactions');
      final String? deletedCursor = await syncMetadataDao.getDeletedCursor(
        'transactions',
      );
      final String? rawDeletedCursor = await syncMetadataDao.getValue(
        'transactions_deleted_cursor',
      );

      expect(cursor, isNotNull);
      expect(cursor, isNotEmpty);
      expect(DateTime.tryParse(cursor!), isNotNull);
      expect(deletedCursor, isNotNull);
      expect(deletedCursor, isNotEmpty);
      expect(rawDeletedCursor, deletedCursor);
      expect(await syncQueueDao.loadReadyBatch(), isEmpty);
    },
  );

  test(
    'pullSync applies remote transaction delete and advances deleted cursor',
    () async {
      // First, let's insert a transaction locally
      final Transaction tx = Transaction(
        id: 'tx-remote-1',
        type: 'income',
        date: '2026-06-19',
        amount: 150.0,
        currency: 'USD',
        category: 'Salary',
        description: 'Remote deposit',
        createdAt: '2026-06-19T08:00:00.000Z',
        rolledOver: false,
      );
      await transactionsRepository.applyRemoteUpsertTransaction(
        tx,
        updatedAt: '2026-06-19T08:00:00.000Z',
      );

      fakeFirestore.txDeletedDelta = const FirestoreDeletedIdsDelta(
        ids: ['tx-remote-1'],
        cursor: '2026-06-19T10:00:00.000Z',
      );

      await pullSyncManager.pullSync('user123');

      // Verify it was tombstoned locally
      final List<Transaction> localTxs = await transactionsRepository
          .getActiveTransactions();
      expect(localTxs, isEmpty);

      // Verify cursor was advanced
      final String? deletedCursor = await syncMetadataDao.getDeletedCursor(
        'transactions',
      );
      expect(deletedCursor, '2026-06-19T10:00:00.000Z');
      expect(
        await syncMetadataDao.getValue('transactions_deleted_cursor'),
        '2026-06-19T10:00:00.000Z',
      );

      // Verify it did NOT enqueue anything
      final queue = await syncQueueDao.loadReadyBatch();
      expect(queue, isEmpty);
    },
  );

  test(
    'pullSync applies remote investment upsert, advances cursor, and does NOT enqueue sync_queue row',
    () async {
      final InvestmentAsset investment = InvestmentAsset(
        id: 'inv-remote-1',
        investmentType: 'company_shares',
        assetSubtype: 'equity',
        ownershipType: 'fully_owned',
        valuationMode: 'net_fair',
        currency: 'USD',
        originalPrice: 5000,
        totalInterest: 0,
        totalPayable: 5000,
        paidAmount: 5000,
        remainingAmount: 0,
        installmentPlan: const <Map<String, dynamic>>[],
        valuationDate: '2026-06-19',
        marketValue: 7500,
        marketValueDate: '2026-06-19',
        valuationSource: 'manual',
        loanBalance: 0,
        loanAsOfDate: '2026-06-19',
        paidAmountToDate: 5000,
        ownershipSharePct: 100,
        country: 'US',
        location: 'Remote',
        inflationRateAnnual: 0,
        estimatedCurrentValue: 7500,
        description: 'Remote investment',
        noZakat: false,
        createdAt: '2026-06-19T08:00:00.000Z',
      );

      fakeFirestore.invDelta = FirestoreCollectionDelta(
        items: [investment],
        cursor: '2026-06-19T09:30:00.000Z',
      );

      await pullSyncManager.pullSync('user123');

      final List<InvestmentAsset> localInvestments = await investmentsRepository
          .getActiveInvestments();
      expect(localInvestments, hasLength(1));
      expect(localInvestments.first.id, 'inv-remote-1');
      expect(localInvestments.first.marketValue, 7500);

      final String? cursor = await syncMetadataDao.getCursor('investments');
      expect(cursor, '2026-06-19T09:30:00.000Z');

      final queue = await syncQueueDao.loadReadyBatch();
      expect(queue, isEmpty);
    },
  );

  test(
    'pullSync applies remote investment delete and advances deleted cursor',
    () async {
      final InvestmentAsset investment = InvestmentAsset(
        id: 'inv-remote-1',
        investmentType: 'company_shares',
        assetSubtype: 'equity',
        ownershipType: 'fully_owned',
        valuationMode: 'net_fair',
        currency: 'USD',
        originalPrice: 5000,
        totalInterest: 0,
        totalPayable: 5000,
        paidAmount: 5000,
        remainingAmount: 0,
        installmentPlan: const <Map<String, dynamic>>[],
        valuationDate: '2026-06-19',
        marketValue: 7500,
        marketValueDate: '2026-06-19',
        valuationSource: 'manual',
        loanBalance: 0,
        loanAsOfDate: '2026-06-19',
        paidAmountToDate: 5000,
        ownershipSharePct: 100,
        country: 'US',
        location: 'Remote',
        inflationRateAnnual: 0,
        estimatedCurrentValue: 7500,
        description: 'Remote investment',
        noZakat: false,
        createdAt: '2026-06-19T08:00:00.000Z',
      );
      await investmentsRepository.applyRemoteUpsertInvestment(
        investment,
        updatedAt: '2026-06-19T08:00:00.000Z',
      );

      fakeFirestore.invDeletedDelta = const FirestoreDeletedIdsDelta(
        ids: ['inv-remote-1'],
        cursor: '2026-06-19T10:00:00.000Z',
      );

      await pullSyncManager.pullSync('user123');

      final List<InvestmentAsset> localInvestments = await investmentsRepository
          .getActiveInvestments();
      expect(localInvestments, isEmpty);

      final String? deletedCursor = await syncMetadataDao.getDeletedCursor(
        'investments',
      );
      expect(deletedCursor, '2026-06-19T10:00:00.000Z');

      final queue = await syncQueueDao.loadReadyBatch();
      expect(queue, isEmpty);
    },
  );

  test(
    'pullSync applies remote pending transaction upsert, advances cursor, and does NOT enqueue sync_queue row',
    () async {
      final PendingTransaction pending = PendingTransaction(
        id: 'pt-remote-1',
        source: PendingTransactionSource.manual,
        rawMessage: 'message',
        createdAt: '2026-06-19T08:00:00.000Z',
        suggestedType: 'expense',
        suggestedAmount: 10.5,
        suggestedCurrency: 'USD',
        confidence: 0.9,
        status: CaptureStatus.pendingReview,
      );

      fakeFirestore.pendingDelta = FirestoreCollectionDelta(
        items: [pending],
        cursor: '2026-06-19T09:30:00.000Z',
      );

      await pullSyncManager.pullSync('user123');

      final List<PendingTransaction> localPending =
          await pendingTransactionsRepository.getActivePendingTransactions();
      expect(localPending, hasLength(1));
      expect(localPending.first.id, 'pt-remote-1');

      final String? cursor = await syncMetadataDao.getCursor(
        'pending_transactions',
      );
      expect(cursor, '2026-06-19T09:30:00.000Z');

      final queue = await syncQueueDao.loadReadyBatch();
      expect(queue, isEmpty);
    },
  );

  test(
    'pullSync applies remote pending transaction delete and advances deleted cursor',
    () async {
      final PendingTransaction pending = PendingTransaction(
        id: 'pt-remote-1',
        source: PendingTransactionSource.manual,
        rawMessage: 'message',
        createdAt: '2026-06-19T08:00:00.000Z',
        suggestedType: 'expense',
        suggestedAmount: 10.5,
        suggestedCurrency: 'USD',
        confidence: 0.9,
        status: CaptureStatus.pendingReview,
      );
      await pendingTransactionsRepository.applyRemoteUpsertPendingTransaction(
        pending,
        updatedAt: '2026-06-19T08:00:00.000Z',
      );

      fakeFirestore.pendingDeletedDelta = const FirestoreDeletedIdsDelta(
        ids: ['pt-remote-1'],
        cursor: '2026-06-19T10:00:00.000Z',
      );

      await pullSyncManager.pullSync('user123');

      final List<PendingTransaction> localPending =
          await pendingTransactionsRepository.getActivePendingTransactions();
      expect(localPending, isEmpty);

      final String? deletedCursor = await syncMetadataDao.getDeletedCursor(
        'pending_transactions',
      );
      expect(deletedCursor, '2026-06-19T10:00:00.000Z');
      expect(
        await syncMetadataDao.getValue('pending_transactions_deleted_cursor'),
        '2026-06-19T10:00:00.000Z',
      );

      final queue = await syncQueueDao.loadReadyBatch();
      expect(queue, isEmpty);
    },
  );

  test(
    'pullSync applies remote merchant rule upsert, advances cursor, and does NOT enqueue sync_queue row',
    () async {
      final MerchantRule rule = MerchantRule(
        merchantName: 'Coffee Shop',
        categoryId: 'Food',
        defaultType: 'expense',
        autoApprove: true,
        usageCount: 4,
        confidence: 0.82,
        lastUsed: '2026-06-19T08:00:00.000Z',
        source: 'custom',
        aliases: const <String>['Cafe'],
        enabled: true,
        isBuiltinOverride: false,
      );

      fakeFirestore.merchantRulesDelta = FirestoreCollectionDelta(
        items: <MerchantRule>[rule],
        cursor: '2026-06-19T09:50:00.000Z',
      );

      await pullSyncManager.pullSync('user123');

      final Map<String, MerchantRule> localRules = await merchantRulesRepository
          .getActiveMerchantRules();
      expect(localRules, hasLength(1));
      expect(localRules.values.single.merchantName, 'Coffee Shop');

      final String? cursor = await syncMetadataDao.getCursor('merchant_rules');
      expect(cursor, '2026-06-19T09:50:00.000Z');

      expect(await syncQueueDao.loadReadyBatch(), isEmpty);
    },
  );

  test(
    'pullSync applies remote merchant confirmation delete and advances deleted cursor',
    () async {
      final MerchantConfirmation confirmation = MerchantConfirmation(
        merchantName: 'Coffee Shop',
        categoryId: 'Food',
        confirmations: 3,
        corrections: 1,
      );
      await merchantConfirmationsRepository
          .applyRemoteUpsertMerchantConfirmation(
            confirmation,
            updatedAt: '2026-06-19T08:00:00.000Z',
          );

      fakeFirestore.merchantConfirmationsDeletedDelta =
          const FirestoreDeletedIdsDelta(
            ids: <String>['coffee shop|food'],
            cursor: '2026-06-19T10:05:00.000Z',
          );

      await pullSyncManager.pullSync('user123');

      final List<MerchantConfirmation> localConfirmations =
          await merchantConfirmationsRepository
              .getActiveMerchantConfirmations();
      expect(localConfirmations, isEmpty);

      final String? deletedCursor = await syncMetadataDao.getDeletedCursor(
        'merchant_confirmations',
      );
      expect(deletedCursor, '2026-06-19T10:05:00.000Z');

      expect(await syncQueueDao.loadReadyBatch(), isEmpty);
    },
  );

  test(
    'pullSync applies remote correction feedback upsert, advances cursor, and does NOT enqueue sync_queue row',
    () async {
      final CorrectionFeedback feedback = CorrectionFeedback(
        id: 'fb-remote-1',
        fieldName: 'category',
        originalValue: 'Food',
        correctedValue: 'Bills',
        createdAt: '2026-06-19T08:00:00.000Z',
      );

      fakeFirestore.correctionFeedbackDelta = FirestoreCollectionDelta(
        items: <CorrectionFeedback>[feedback],
        cursor: '2026-06-19T09:55:00.000Z',
      );

      await pullSyncManager.pullSync('user123');

      final List<CorrectionFeedback> localFeedback =
          await correctionFeedbackRepository.getActiveCorrectionFeedback();
      expect(localFeedback, hasLength(1));
      expect(localFeedback.first.id, 'fb-remote-1');

      final String? cursor = await syncMetadataDao.getCursor(
        'correction_feedback',
      );
      expect(cursor, '2026-06-19T09:55:00.000Z');

      expect(await syncQueueDao.loadReadyBatch(), isEmpty);
    },
  );

  test(
    'pullSync applies remote financial plan upsert, advances cursor, and does NOT enqueue sync_queue row',
    () async {
      final FinancialPlan plan = FinancialPlan(
        id: 'plan-remote-1',
        name: 'Remote Plan',
        startDate: '2026-06-01',
        projectionCurrency: 'USD',
        startingBalance: 2000,
        startingBalanceDate: '2026-06-01',
        startingBalanceMode: 'manual',
        snapshotWealthCurrency: 'USD',
        startingAssetBreakdown: const <String, double>{'cash': 2000},
        monthlyIncome: 4000,
        monthlyExpenses: 1500,
        includeInstallments: true,
        includeZakat: true,
        durationYears: 1,
        createdAt: '2026-06-19T08:00:00.000Z',
        isActive: true,
        startingAssets: 2000,
        startingLiabilities: 0,
        startingNetWorth: 2000,
        startingNisabSnapshot: 0,
        startingGoldPriceSnapshot: 0,
        startingFxSnapshot: const <String, double>{},
      );

      fakeFirestore.planDelta = FirestoreCollectionDelta(
        items: [plan],
        cursor: '2026-06-19T09:40:00.000Z',
      );

      await pullSyncManager.pullSync('user123');

      final List<FinancialPlan> localPlans = await financialPlansRepository
          .getActiveFinancialPlans();
      expect(localPlans, hasLength(1));
      expect(localPlans.first.id, 'plan-remote-1');

      final String? cursor = await syncMetadataDao.getCursor('financial_plans');
      expect(cursor, '2026-06-19T09:40:00.000Z');

      final queue = await syncQueueDao.loadReadyBatch();
      expect(queue, isEmpty);
    },
  );

  test(
    'pullSync applies remote financial plan delete and advances deleted cursor',
    () async {
      final FinancialPlan plan = FinancialPlan(
        id: 'plan-remote-1',
        name: 'Remote Plan',
        startDate: '2026-06-01',
        projectionCurrency: 'USD',
        startingBalance: 2000,
        startingBalanceDate: '2026-06-01',
        startingBalanceMode: 'manual',
        snapshotWealthCurrency: 'USD',
        startingAssetBreakdown: const <String, double>{'cash': 2000},
        monthlyIncome: 4000,
        monthlyExpenses: 1500,
        includeInstallments: true,
        includeZakat: true,
        durationYears: 1,
        createdAt: '2026-06-19T08:00:00.000Z',
        isActive: true,
        startingAssets: 2000,
        startingLiabilities: 0,
        startingNetWorth: 2000,
        startingNisabSnapshot: 0,
        startingGoldPriceSnapshot: 0,
        startingFxSnapshot: const <String, double>{},
      );
      await financialPlansRepository.applyRemoteUpsertFinancialPlan(
        plan,
        updatedAt: '2026-06-19T08:00:00.000Z',
      );

      fakeFirestore.planDeletedDelta = const FirestoreDeletedIdsDelta(
        ids: ['plan-remote-1'],
        cursor: '2026-06-19T10:10:00.000Z',
      );

      await pullSyncManager.pullSync('user123');

      final List<FinancialPlan> localPlans = await financialPlansRepository
          .getActiveFinancialPlans();
      expect(localPlans, isEmpty);

      final String? deletedCursor = await syncMetadataDao.getDeletedCursor(
        'financial_plans',
      );
      expect(deletedCursor, '2026-06-19T10:10:00.000Z');

      final queue = await syncQueueDao.loadReadyBatch();
      expect(queue, isEmpty);
    },
  );

  test(
    'pullSync applies remote recurring transaction upsert, advances cursor, and does NOT enqueue sync_queue row',
    () async {
      final RecurringTransaction recurring = RecurringTransaction(
        id: 'rt-remote-1',
        name: 'Recurring Remote',
        type: 'expense',
        amount: 70,
        currency: 'USD',
        category: 'Bills',
        description: 'Remote recurring',
        dayOfMonth: 5,
        frequency: 'monthly',
        lastProcessed: '2026-06-01',
        enabled: true,
        skipMonth: '',
        createdAt: '2026-06-19T08:00:00.000Z',
      );

      fakeFirestore.recurringDelta = FirestoreCollectionDelta(
        items: [recurring],
        cursor: '2026-06-19T09:50:00.000Z',
      );

      await pullSyncManager.pullSync('user123');

      final List<RecurringTransaction> localRecurring =
          await recurringTransactionsRepository
              .getActiveRecurringTransactions();
      expect(localRecurring, hasLength(1));
      expect(localRecurring.first.id, 'rt-remote-1');

      final String? cursor = await syncMetadataDao.getCursor(
        'recurring_transactions',
      );
      expect(cursor, '2026-06-19T09:50:00.000Z');

      final queue = await syncQueueDao.loadReadyBatch();
      expect(queue, isEmpty);
    },
  );

  test(
    'pullSync applies remote recurring transaction delete and advances deleted cursor',
    () async {
      final RecurringTransaction recurring = RecurringTransaction(
        id: 'rt-remote-1',
        name: 'Recurring Remote',
        type: 'expense',
        amount: 70,
        currency: 'USD',
        category: 'Bills',
        description: 'Remote recurring',
        dayOfMonth: 5,
        frequency: 'monthly',
        lastProcessed: '2026-06-01',
        enabled: true,
        skipMonth: '',
        createdAt: '2026-06-19T08:00:00.000Z',
      );
      await recurringTransactionsRepository
          .applyRemoteUpsertRecurringTransaction(
            recurring,
            updatedAt: '2026-06-19T08:00:00.000Z',
          );

      fakeFirestore.recurringDeletedDelta = const FirestoreDeletedIdsDelta(
        ids: ['rt-remote-1'],
        cursor: '2026-06-19T10:20:00.000Z',
      );

      await pullSyncManager.pullSync('user123');

      final List<RecurringTransaction> localRecurring =
          await recurringTransactionsRepository
              .getActiveRecurringTransactions();
      expect(localRecurring, isEmpty);

      final String? deletedCursor = await syncMetadataDao.getDeletedCursor(
        'recurring_transactions',
      );
      expect(deletedCursor, '2026-06-19T10:20:00.000Z');

      final queue = await syncQueueDao.loadReadyBatch();
      expect(queue, isEmpty);
    },
  );
}
