import 'dart:convert';
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
import 'package:zakatapp_flutter/data/local/daos/sync_queue_dao.dart';
import 'package:zakatapp_flutter/data/sync/sync_queue_processor.dart';
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
  final List<Transaction> syncedTransactions = [];
  final List<String> deletedTransactionIds = [];
  final List<Saving> syncedSavings = [];
  final List<String> deletedSavingIds = [];
  final List<InvestmentAsset> syncedInvestments = [];
  final List<String> deletedInvestmentIds = [];
  final List<PendingTransaction> syncedPendingTransactions = [];
  final List<String> deletedPendingTransactionIds = [];
  final List<FinancialPlan> syncedFinancialPlans = [];
  final List<String> deletedFinancialPlanIds = [];
  final List<RecurringTransaction> syncedRecurringTransactions = [];
  final List<String> deletedRecurringTransactionIds = [];
  final List<MerchantRule> syncedMerchantRules = [];
  final List<String> deletedMerchantRuleIds = [];
  final List<MerchantConfirmation> syncedMerchantConfirmations = [];
  final List<String> deletedMerchantConfirmationIds = [];
  final List<CorrectionFeedback> syncedCorrectionFeedback = [];
  final List<String> deletedCorrectionFeedbackIds = [];
  bool shouldFail = false;

  @override
  Future<void> syncTransactions({
    required String uid,
    required Iterable<Transaction> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    if (shouldFail) throw Exception('Firestore push failed');
    syncedTransactions.addAll(items);
    deletedTransactionIds.addAll(deletedIds);
  }

  @override
  Future<void> syncSavings({
    required String uid,
    required Iterable<Saving> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    if (shouldFail) throw Exception('Firestore push failed');
    syncedSavings.addAll(items);
    deletedSavingIds.addAll(deletedIds);
  }

  @override
  Future<void> syncInvestments({
    required String uid,
    required Iterable<InvestmentAsset> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    if (shouldFail) throw Exception('Firestore push failed');
    syncedInvestments.addAll(items);
    deletedInvestmentIds.addAll(deletedIds);
  }

  @override
  Future<void> syncCaptureInbox({
    required String uid,
    required Iterable<PendingTransaction> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    if (shouldFail) throw Exception('Firestore push failed');
    syncedPendingTransactions.addAll(items);
    deletedPendingTransactionIds.addAll(deletedIds);
  }

  @override
  Future<void> syncFinancialPlans({
    required String uid,
    required Iterable<FinancialPlan> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    if (shouldFail) throw Exception('Firestore push failed');
    syncedFinancialPlans.addAll(items);
    deletedFinancialPlanIds.addAll(deletedIds);
  }

  @override
  Future<void> syncRecurringTransactions({
    required String uid,
    required Iterable<RecurringTransaction> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    if (shouldFail) throw Exception('Firestore push failed');
    syncedRecurringTransactions.addAll(items);
    deletedRecurringTransactionIds.addAll(deletedIds);
  }

  @override
  Future<void> syncMerchantRules({
    required String uid,
    required Iterable<MerchantRule> rules,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    if (shouldFail) throw Exception('Firestore push failed');
    syncedMerchantRules.addAll(rules);
    deletedMerchantRuleIds.addAll(deletedIds);
  }

  @override
  Future<void> syncMerchantConfirmations({
    required String uid,
    required Iterable<MerchantConfirmation> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    if (shouldFail) throw Exception('Firestore push failed');
    syncedMerchantConfirmations.addAll(items);
    deletedMerchantConfirmationIds.addAll(deletedIds);
  }

  @override
  Future<void> syncCorrectionFeedback({
    required String uid,
    required Iterable<CorrectionFeedback> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    if (shouldFail) throw Exception('Firestore push failed');
    syncedCorrectionFeedback.addAll(items);
    deletedCorrectionFeedbackIds.addAll(deletedIds);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase database;
  late SyncQueueDao syncQueueDao;
  late _FakeFirestoreSyncManager fakeFirestore;
  late SyncQueueProcessor processor;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    syncQueueDao = SyncQueueDao(database);
    fakeFirestore = _FakeFirestoreSyncManager();
    processor = SyncQueueProcessor(
      syncQueueDao: syncQueueDao,
      firestoreSyncManager: fakeFirestore,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'successfully processes upsert transaction and deletes queue row',
    () async {
      final Transaction tx = Transaction(
        id: 'tx1',
        type: 'income',
        date: '2026-06-19',
        amount: 100.0,
        currency: 'USD',
        category: 'Salary',
        description: 'Monthly pay',
        createdAt: '2026-06-19T08:00:00.000Z',
        rolledOver: false,
      );

      await syncQueueDao.enqueue(
        collectionName: 'transactions',
        recordId: 'tx1',
        operation: 'upsert',
        payloadJson: jsonEncode(tx.toJson()),
        createdAt: '2026-06-19T08:00:00.000Z',
        availableAt: '2026-06-19T08:00:00.000Z',
        dedupeKey: 'transactions:tx1',
      );

      await processor.processQueue('user123');

      expect(fakeFirestore.syncedTransactions, hasLength(1));
      expect(fakeFirestore.syncedTransactions.first.id, 'tx1');
      expect(fakeFirestore.syncedTransactions.first.amount, 100.0);

      // Verify row was deleted from sync queue
      final remaining = await syncQueueDao.loadReadyBatch();
      expect(remaining, isEmpty);
    },
  );

  test(
    'successfully processes delete transaction and deletes queue row',
    () async {
      await syncQueueDao.enqueue(
        collectionName: 'transactions',
        recordId: 'tx1',
        operation: 'delete',
        payloadJson: null,
        createdAt: '2026-06-19T08:00:00.000Z',
        availableAt: '2026-06-19T08:00:00.000Z',
        dedupeKey: 'transactions:tx1',
      );

      await processor.processQueue('user123');

      expect(fakeFirestore.deletedTransactionIds, contains('tx1'));
      final remaining = await syncQueueDao.loadReadyBatch();
      expect(remaining, isEmpty);
    },
  );

  test('successfully processes upsert saving and deletes queue row', () async {
    final Saving saving = Saving(
      id: 'sv1',
      assetType: 'cash',
      dateAcquired: '2026-06-19',
      amount: 250,
      remainingAmount: 250,
      unit: 'USD',
      description: 'Saved',
      purchaseCurrency: 'USD',
      purchaseAmount: 250,
      createdAt: '2026-06-19T08:00:00.000Z',
    );

    await syncQueueDao.enqueue(
      collectionName: 'savings',
      recordId: 'sv1',
      operation: 'upsert',
      payloadJson: jsonEncode(saving.toJson()),
      createdAt: '2026-06-19T08:00:00.000Z',
      availableAt: '2026-06-19T08:00:00.000Z',
      dedupeKey: 'savings:sv1',
    );

    await processor.processQueue('user123');

    expect(fakeFirestore.syncedSavings, hasLength(1));
    expect(fakeFirestore.syncedSavings.first.id, 'sv1');

    final remaining = await syncQueueDao.loadReadyBatch();
    expect(remaining, isEmpty);
  });

  test(
    'successfully processes upsert gold saving and deletes queue row',
    () async {
      final Saving saving = Saving(
        id: 'gold1',
        assetType: 'gold',
        dateAcquired: '2026-06-19',
        amount: 12.5,
        remainingAmount: 12.5,
        unit: '24',
        description: 'Gold purchase',
        purchaseCurrency: 'USD',
        purchaseAmount: 800,
        createdAt: '2026-06-19T08:00:00.000Z',
      );

      await syncQueueDao.enqueue(
        collectionName: 'savings',
        recordId: 'gold1',
        operation: 'upsert',
        payloadJson: jsonEncode(saving.toJson()),
        createdAt: '2026-06-19T08:00:00.000Z',
        availableAt: '2026-06-19T08:00:00.000Z',
        dedupeKey: 'savings:gold1',
      );

      await processor.processQueue('user123');

      expect(fakeFirestore.syncedSavings, hasLength(1));
      expect(fakeFirestore.syncedSavings.first.assetType, 'gold');
      expect(fakeFirestore.syncedSavings.first.id, 'gold1');
      expect(await syncQueueDao.loadReadyBatch(), isEmpty);
    },
  );

  test(
    'successfully processes upsert silver saving and deletes queue row',
    () async {
      final Saving saving = Saving(
        id: 'silver1',
        assetType: 'silver',
        dateAcquired: '2026-06-19',
        amount: 50,
        remainingAmount: 50,
        unit: 'g',
        description: 'Silver purchase',
        purchaseCurrency: 'USD',
        purchaseAmount: 60,
        createdAt: '2026-06-19T08:00:00.000Z',
      );

      await syncQueueDao.enqueue(
        collectionName: 'savings',
        recordId: 'silver1',
        operation: 'upsert',
        payloadJson: jsonEncode(saving.toJson()),
        createdAt: '2026-06-19T08:00:00.000Z',
        availableAt: '2026-06-19T08:00:00.000Z',
        dedupeKey: 'savings:silver1',
      );

      await processor.processQueue('user123');

      expect(fakeFirestore.syncedSavings, hasLength(1));
      expect(fakeFirestore.syncedSavings.first.assetType, 'silver');
      expect(fakeFirestore.syncedSavings.first.id, 'silver1');
      expect(await syncQueueDao.loadReadyBatch(), isEmpty);
    },
  );

  test(
    'remainingAmount zero savings still sync for historical accuracy',
    () async {
      final Saving saving = Saving(
        id: 'zero1',
        assetType: 'gold',
        dateAcquired: '2026-06-19',
        amount: 5,
        remainingAmount: 0,
        unit: '24',
        description: 'Closed gold lot',
        purchaseCurrency: 'USD',
        purchaseAmount: 350,
        createdAt: '2026-06-19T08:00:00.000Z',
      );

      await syncQueueDao.enqueue(
        collectionName: 'savings',
        recordId: 'zero1',
        operation: 'upsert',
        payloadJson: jsonEncode(saving.toJson()),
        createdAt: '2026-06-19T08:00:00.000Z',
        availableAt: '2026-06-19T08:00:00.000Z',
        dedupeKey: 'savings:zero1',
      );

      await processor.processQueue('user123');

      expect(fakeFirestore.syncedSavings, hasLength(1));
      expect(fakeFirestore.syncedSavings.first.remainingAmount, 0);
      expect(await syncQueueDao.loadReadyBatch(), isEmpty);
    },
  );

  test('successfully processes delete saving and deletes queue row', () async {
    await syncQueueDao.enqueue(
      collectionName: 'savings',
      recordId: 'sv1',
      operation: 'delete',
      payloadJson: null,
      createdAt: '2026-06-19T08:00:00.000Z',
      availableAt: '2026-06-19T08:00:00.000Z',
      dedupeKey: 'savings:sv1',
    );

    await processor.processQueue('user123');

    expect(fakeFirestore.deletedSavingIds, contains('sv1'));
    final remaining = await syncQueueDao.loadReadyBatch();
    expect(remaining, isEmpty);
  });

  test(
    'successfully processes upsert investment and deletes queue row',
    () async {
      final InvestmentAsset investment = InvestmentAsset(
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
        installmentPlan: const <Map<String, dynamic>>[],
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
        description: 'Investment',
        noZakat: true,
        createdAt: '2026-06-19T08:00:00.000Z',
      );

      await syncQueueDao.enqueue(
        collectionName: 'investments',
        recordId: 'inv1',
        operation: 'upsert',
        payloadJson: jsonEncode(investment.toJson()),
        createdAt: '2026-06-19T08:00:00.000Z',
        availableAt: '2026-06-19T08:00:00.000Z',
        dedupeKey: 'investments:inv1',
      );

      await processor.processQueue('user123');

      expect(fakeFirestore.syncedInvestments, hasLength(1));
      expect(fakeFirestore.syncedInvestments.first.id, 'inv1');
      expect(fakeFirestore.deletedInvestmentIds, isEmpty);
      final remaining = await syncQueueDao.loadReadyBatch();
      expect(remaining, isEmpty);
    },
  );

  test(
    'successfully processes delete investment and deletes queue row',
    () async {
      await syncQueueDao.enqueue(
        collectionName: 'investments',
        recordId: 'inv1',
        operation: 'delete',
        payloadJson: null,
        createdAt: '2026-06-19T08:00:00.000Z',
        availableAt: '2026-06-19T08:00:00.000Z',
        dedupeKey: 'investments:inv1',
      );

      await processor.processQueue('user123');

      expect(fakeFirestore.deletedInvestmentIds, contains('inv1'));
      final remaining = await syncQueueDao.loadReadyBatch();
      expect(remaining, isEmpty);
    },
  );

  test(
    'successfully processes upsert financial plan and deletes queue row',
    () async {
      final FinancialPlan plan = FinancialPlan(
        id: 'plan1',
        name: 'Plan 1',
        startDate: '2026-06-01',
        projectionCurrency: 'USD',
        startingBalance: 1000,
        startingBalanceDate: '2026-06-01',
        startingBalanceMode: 'manual',
        snapshotWealthCurrency: 'USD',
        startingAssetBreakdown: const <String, double>{'cash': 1000},
        monthlyIncome: 2000,
        monthlyExpenses: 1000,
        includeInstallments: true,
        includeZakat: false,
        durationYears: 1,
        createdAt: '2026-06-19T08:00:00.000Z',
        isActive: true,
        startingAssets: 1000,
        startingLiabilities: 0,
        startingNetWorth: 1000,
        startingNisabSnapshot: 0,
        startingGoldPriceSnapshot: 0,
        startingFxSnapshot: const <String, double>{},
      );

      await syncQueueDao.enqueue(
        collectionName: 'financial_plans',
        recordId: 'plan1',
        operation: 'upsert',
        payloadJson: jsonEncode(plan.toJson()),
        createdAt: '2026-06-19T08:00:00.000Z',
        availableAt: '2026-06-19T08:00:00.000Z',
        dedupeKey: 'financial_plans:plan1',
      );

      await processor.processQueue('user123');

      expect(fakeFirestore.syncedFinancialPlans, hasLength(1));
      expect(fakeFirestore.syncedFinancialPlans.first.id, 'plan1');
      final remaining = await syncQueueDao.loadReadyBatch();
      expect(remaining, isEmpty);
    },
  );

  test(
    'successfully processes delete financial plan and deletes queue row',
    () async {
      await syncQueueDao.enqueue(
        collectionName: 'financial_plans',
        recordId: 'plan1',
        operation: 'delete',
        payloadJson: null,
        createdAt: '2026-06-19T08:00:00.000Z',
        availableAt: '2026-06-19T08:00:00.000Z',
        dedupeKey: 'financial_plans:plan1',
      );

      await processor.processQueue('user123');

      expect(fakeFirestore.deletedFinancialPlanIds, contains('plan1'));
      final remaining = await syncQueueDao.loadReadyBatch();
      expect(remaining, isEmpty);
    },
  );

  test(
    'successfully processes upsert recurring transaction and deletes queue row',
    () async {
      final RecurringTransaction recurring = RecurringTransaction(
        id: 'rt1',
        name: 'Recurring 1',
        type: 'expense',
        amount: 50,
        currency: 'USD',
        category: 'Bills',
        description: 'Monthly',
        dayOfMonth: 10,
        frequency: 'monthly',
        lastProcessed: '2026-06-01',
        enabled: true,
        skipMonth: '',
        createdAt: '2026-06-19T08:00:00.000Z',
      );

      await syncQueueDao.enqueue(
        collectionName: 'recurring_transactions',
        recordId: 'rt1',
        operation: 'upsert',
        payloadJson: jsonEncode(recurring.toJson()),
        createdAt: '2026-06-19T08:00:00.000Z',
        availableAt: '2026-06-19T08:00:00.000Z',
        dedupeKey: 'recurring_transactions:rt1',
      );

      await processor.processQueue('user123');

      expect(fakeFirestore.syncedRecurringTransactions, hasLength(1));
      expect(fakeFirestore.syncedRecurringTransactions.first.id, 'rt1');
      final remaining = await syncQueueDao.loadReadyBatch();
      expect(remaining, isEmpty);
    },
  );

  test(
    'successfully processes delete recurring transaction and deletes queue row',
    () async {
      await syncQueueDao.enqueue(
        collectionName: 'recurring_transactions',
        recordId: 'rt1',
        operation: 'delete',
        payloadJson: null,
        createdAt: '2026-06-19T08:00:00.000Z',
        availableAt: '2026-06-19T08:00:00.000Z',
        dedupeKey: 'recurring_transactions:rt1',
      );

      await processor.processQueue('user123');

      expect(fakeFirestore.deletedRecurringTransactionIds, contains('rt1'));
      final remaining = await syncQueueDao.loadReadyBatch();
      expect(remaining, isEmpty);
    },
  );

  test(
    'successfully processes upsert merchant rule and deletes queue row',
    () async {
      final MerchantRule rule = MerchantRule(
        merchantName: 'Coffee Shop',
        categoryId: 'Food',
        defaultType: 'expense',
        autoApprove: true,
        usageCount: 7,
        confidence: 0.8,
        lastUsed: '2026-06-19T08:00:00.000Z',
        source: 'custom',
        aliases: const <String>['Cafe'],
        enabled: true,
        isBuiltinOverride: false,
      );

      await syncQueueDao.enqueue(
        collectionName: 'merchant_rules',
        recordId: 'coffee shop',
        operation: 'upsert',
        payloadJson: jsonEncode(rule.toJson()),
        createdAt: '2026-06-19T08:00:00.000Z',
        availableAt: '2026-06-19T08:00:00.000Z',
        dedupeKey: 'merchant_rules:coffee shop',
      );

      await processor.processQueue('user123');

      expect(fakeFirestore.syncedMerchantRules, hasLength(1));
      expect(
        fakeFirestore.syncedMerchantRules.first.merchantName,
        'Coffee Shop',
      );
      expect(await syncQueueDao.loadReadyBatch(), isEmpty);
    },
  );

  test(
    'successfully processes delete merchant rule and deletes queue row',
    () async {
      await syncQueueDao.enqueue(
        collectionName: 'merchant_rules',
        recordId: 'coffee shop',
        operation: 'delete',
        payloadJson: null,
        createdAt: '2026-06-19T08:00:00.000Z',
        availableAt: '2026-06-19T08:00:00.000Z',
        dedupeKey: 'merchant_rules:coffee shop',
      );

      await processor.processQueue('user123');

      expect(fakeFirestore.deletedMerchantRuleIds, contains('coffee shop'));
      expect(await syncQueueDao.loadReadyBatch(), isEmpty);
    },
  );

  test(
    'successfully processes upsert merchant confirmation and deletes queue row',
    () async {
      final MerchantConfirmation item = MerchantConfirmation(
        merchantName: 'Coffee Shop',
        categoryId: 'Food',
        confirmations: 3,
        corrections: 1,
      );

      await syncQueueDao.enqueue(
        collectionName: 'merchant_confirmations',
        recordId: 'coffee shop|food',
        operation: 'upsert',
        payloadJson: jsonEncode(item.toJson()),
        createdAt: '2026-06-19T08:00:00.000Z',
        availableAt: '2026-06-19T08:00:00.000Z',
        dedupeKey: 'merchant_confirmations:coffee shop|food',
      );

      await processor.processQueue('user123');

      expect(fakeFirestore.syncedMerchantConfirmations, hasLength(1));
      expect(
        fakeFirestore.syncedMerchantConfirmations.first.merchantName,
        'Coffee Shop',
      );
      expect(await syncQueueDao.loadReadyBatch(), isEmpty);
    },
  );

  test(
    'successfully processes upsert correction feedback and deletes queue row',
    () async {
      final CorrectionFeedback item = CorrectionFeedback(
        id: 'fb1',
        fieldName: 'category',
        originalValue: 'Food',
        correctedValue: 'Bills',
        createdAt: '2026-06-19T08:00:00.000Z',
      );

      await syncQueueDao.enqueue(
        collectionName: 'correction_feedback',
        recordId: 'fb1',
        operation: 'upsert',
        payloadJson: jsonEncode(item.toJson()),
        createdAt: '2026-06-19T08:00:00.000Z',
        availableAt: '2026-06-19T08:00:00.000Z',
        dedupeKey: 'correction_feedback:fb1',
      );

      await processor.processQueue('user123');

      expect(fakeFirestore.syncedCorrectionFeedback, hasLength(1));
      expect(fakeFirestore.syncedCorrectionFeedback.first.id, 'fb1');
      expect(await syncQueueDao.loadReadyBatch(), isEmpty);
    },
  );

  test(
    'successfully processes upsert pending transaction and deletes queue row',
    () async {
      final PendingTransaction pending = PendingTransaction(
        id: 'pt1',
        source: PendingTransactionSource.manual,
        rawMessage: 'message',
        createdAt: '2026-06-19T08:00:00.000Z',
        suggestedType: 'expense',
        suggestedAmount: 10.5,
        suggestedCurrency: 'USD',
        confidence: 0.9,
        status: CaptureStatus.pendingReview,
      );

      await syncQueueDao.enqueue(
        collectionName: 'pending_transactions',
        recordId: 'pt1',
        operation: 'upsert',
        payloadJson: jsonEncode(pending.toJson()),
        createdAt: '2026-06-19T08:00:00.000Z',
        availableAt: '2026-06-19T08:00:00.000Z',
        dedupeKey: 'pending_transactions:pt1',
      );

      await processor.processQueue('user123');

      expect(fakeFirestore.syncedPendingTransactions, hasLength(1));
      expect(fakeFirestore.syncedPendingTransactions.first.id, 'pt1');
      final remaining = await syncQueueDao.loadReadyBatch();
      expect(remaining, isEmpty);
    },
  );

  test(
    'successfully processes delete pending transaction and deletes queue row',
    () async {
      await syncQueueDao.enqueue(
        collectionName: 'pending_transactions',
        recordId: 'pt1',
        operation: 'delete',
        payloadJson: null,
        createdAt: '2026-06-19T08:00:00.000Z',
        availableAt: '2026-06-19T08:00:00.000Z',
        dedupeKey: 'pending_transactions:pt1',
      );

      await processor.processQueue('user123');

      expect(fakeFirestore.deletedPendingTransactionIds, contains('pt1'));
      final remaining = await syncQueueDao.loadReadyBatch();
      expect(remaining, isEmpty);
    },
  );

  test(
    'failed push triggers exponential backoff and increments attemptCount',
    () async {
      final Transaction tx = Transaction(
        id: 'tx1',
        type: 'income',
        date: '2026-06-19',
        amount: 100.0,
        currency: 'USD',
        category: 'Salary',
        description: 'Monthly pay',
        createdAt: '2026-06-19T08:00:00.000Z',
        rolledOver: false,
      );

      await syncQueueDao.enqueue(
        collectionName: 'transactions',
        recordId: 'tx1',
        operation: 'upsert',
        payloadJson: jsonEncode(tx.toJson()),
        createdAt: '2026-06-19T08:00:00.000Z',
        availableAt: '2026-06-19T08:00:00.000Z',
        dedupeKey: 'transactions:tx1',
      );

      fakeFirestore.shouldFail = true;

      await processor.processQueue('user123');

      // Verify row was NOT deleted from sync queue
      final remaining = await (database.select(database.syncQueue)).get();
      expect(remaining, hasLength(1));

      final row = remaining.first;
      expect(row.attemptCount, 1);
      expect(row.lastError, contains('Firestore push failed'));

      // Check backoff scheduling: availableAt should be after now + 20 seconds (pow(2, 1) * 10 = 20)
      final DateTime available = DateTime.parse(row.availableAt);
      final DateTime now = DateTime.now().toUtc();
      final difference = available.difference(now).inSeconds;
      expect(difference, greaterThan(15));
      expect(difference, lessThanOrEqualTo(25));
    },
  );
}
