import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
import 'package:zakatapp_flutter/data/repositories/local_financial_operations_repository.dart';
import 'package:zakatapp_flutter/data/repositories/local_savings_repository.dart';
import 'package:zakatapp_flutter/data/repositories/local_transactions_repository.dart';
import 'package:zakatapp_flutter/models/currency_exchange_edit_request.dart';
import 'package:zakatapp_flutter/models/saving.dart' as model;
import 'package:zakatapp_flutter/models/transaction.dart' as model;
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

class _StaticGate implements UseSqliteLocalStoreProvider {
  _StaticGate(this.value);
  final bool value;
  @override
  Future<bool> prepareForRead({String? userId}) async => value;
}

class _FakeTransactionsStore implements TransactionsLocalStore {
  _FakeTransactionsStore(this.transactions);
  final List<model.Transaction> transactions;

  @override
  Future<void> deleteTransaction(
    String id, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {}
  @override
  Future<List<model.Transaction>> getActiveTransactions() async => transactions;
  @override
  Future<void> replaceAllForLocalMirror(
    Iterable<model.Transaction> transactions,
  ) async {}
  @override
  Future<void> saveTransaction(
    model.Transaction transaction, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {}

  @override
  Stream<List<model.Transaction>> watchActiveTransactions() async* {
    yield transactions;
  }
}

class _FakeSavingsStore implements SavingsLocalStore {
  _FakeSavingsStore(this.savings);
  final List<model.Saving> savings;

  @override
  Future<void> deleteSaving(
    String id, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {}
  @override
  Future<List<model.Saving>> getActiveSavings() async => savings;
  @override
  Future<void> replaceAllForLocalMirror(Iterable<model.Saving> savings) async {}
  @override
  Future<void> saveSaving(
    model.Saving saving, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {}
  @override
  Stream<List<model.Saving>> watchActiveSavings() async* {
    yield savings;
  }
}

class _FakeFinancialOps implements FinancialOperationsLocalStore {
  _FakeFinancialOps({this.result, this.error});

  final FinancialOperationResult? result;
  final Object? error;
  int updateCalls = 0;
  String? lastOldActivityId;
  CurrencyExchangeOperation? lastNewOperation;

  @override
  Future<FinancialOperationResult> deleteCurrencyExchange(String activityId) async {
    throw UnimplementedError();
  }
  @override
  Future<FinancialOperationResult> deleteMetalSale(String transactionId) async {
    throw UnimplementedError();
  }
  @override
  Future<FinancialOperationResult> deleteInternalTransfer(String activityId) async {
    throw UnimplementedError();
  }
  @override
  Future<FinancialOperationResult> recordCurrencyExchange(CurrencyExchangeOperation input) async {
    throw UnimplementedError();
  }

  @override
  Future<FinancialOperationResult> updateCurrencyExchange(
    String oldActivityId,
    CurrencyExchangeOperation newOperation,
  ) async {
    updateCalls += 1;
    lastOldActivityId = oldActivityId;
    lastNewOperation = newOperation;
    if (error != null) throw error!;
    return result!;
  }

  @override
  Future<FinancialOperationResult> recordMetalSale(MetalSaleOperation input) {
    throw UnimplementedError();
  }

  @override
  Future<FinancialOperationResult> updateMetalSale(
    String oldTransactionId,
    MetalSaleOperation newOperation,
  ) {
    throw UnimplementedError();
  }
}

Future<AppStateController> _makeController({
  required bool useSqlite,
  required FinancialOperationsLocalStore? financialOps,
}) async {
  const initialTransactions = <model.Transaction>[
    model.Transaction(
      id: "tx-old",
      type: "expense",
      date: "2026-06-19",
      amount: 10,
      currency: "USD",
      category: "Currency Exchange",
      description: "Currency exchange out",
      createdAt: "2026-06-19T08:00:00.000Z",
      rolledOver: false,
      exchangePairId: "exch_1",
    )
  ];

  const initialSavings = <model.Saving>[
    model.Saving(
      id: "sav-target",
      assetType: "cash",
      dateAcquired: "2026-06-19",
      amount: 100,
      remainingAmount: 100,
      unit: "EGP",
      description: "Savings exchange: 10 USD → 100 EGP",
      purchaseCurrency: "EGP",
      purchaseAmount: 100,
      createdAt: "2026-06-19T08:00:00.000Z",
      transferActivityId: "exch_1",
      exchangeSourceSavingId: "sav-source",
    ),
    model.Saving(
      id: "sav-source",
      assetType: "cash",
      dateAcquired: "2026-06-18",
      amount: 90,
      remainingAmount: 90,
      unit: "USD",
      description: "Source",
      purchaseCurrency: "USD",
      purchaseAmount: 100,
      createdAt: "2026-06-18T08:00:00.000Z",
    )
  ];

  SharedPreferences.setMockInitialValues(<String, Object>{
    'zakatAppData':
        '{"transactions":[{"id":"tx-old","type":"expense","date":"2026-06-19","amount":10,"currency":"USD","category":"Currency Exchange","description":"Currency exchange out","createdAt":"2026-06-19T08:00:00.000Z","rolledOver":false,"exchangePairId":"exch_1"}],"savings":[{"id":"sav-target","assetType":"cash","dateAcquired":"2026-06-19","amount":100,"remainingAmount":100,"unit":"EGP","description":"Savings exchange: 10 USD → 100 EGP","purchaseCurrency":"EGP","purchaseAmount":100,"createdAt":"2026-06-19T08:00:00.000Z","transferActivityId":"exch_1","exchangeSourceSavingId":"sav-source"},{"id":"sav-source","assetType":"cash","dateAcquired":"2026-06-18","amount":90,"remainingAmount":90,"unit":"USD","description":"Source","purchaseCurrency":"USD","purchaseAmount":100,"createdAt":"2026-06-18T08:00:00.000Z"}],"recurringTransactions":[],"investments":[],"financialPlans":[],"pendingTransactions":[],"lastRollover":"","categories":{"income":[],"expense":[]},"zakatPaidMonths":[],"processedExpenseIds":[],"mainCurrency":"USD","defaultEntryCurrency":"USD","zakatExpenseIds":{},"zakatMethod":"hawl","zakatAnnualDate":"","zakatNisabBasis":"gold85","zakatScheduleFilter":"unpaid","marketData":{},"marketHistory":[],"syncHealth":{"lastSuccessAt":"","lastFailureAt":"","lastError":"","pendingWrites":0},"lastModifiedAt":"","languagePreference":"en","themeMode":"system","biometricLockEnabled":false,"biometricHideWealthEnabled":false,"biometricExportEnabled":false,"biometricRestoreEnabled":false,"biometricAutoLockDelay":"1_minute","merchantRules":{},"merchantAliases":{},"captureAnalytics":{"parsedMessages":0,"autoApprovedMessages":0,"duplicateMessages":0,"ignoredMessages":0,"correctedMessages":0,"learnedRules":0,"autoApprovedRules":0,"capturedFromAppleShortcuts":0,"capturedFromAppleShortcutsAutoApproved":0,"capturedFromAppleShortcutsIgnored":0},"correctionFeedback":[],"merchantConfirmations":[],"smartCaptureEnabled":true,"smartCaptureAutoApproveEnabled":false}',
  });
  const localStorage = LocalStorageService();
  final repository = AppStateRepository(localStorage: localStorage);
  final controller = AppStateController(
    repository: repository,
    localTransactionsRepository: _FakeTransactionsStore(initialTransactions),
    localSavingsRepository: _FakeSavingsStore(initialSavings),
    localFinancialOperationsRepository: financialOps,
    useSqliteLocalStoreProvider: _StaticGate(useSqlite),
  );
  await controller.load();
  return controller;
}

void main() {
  test('SQLite mode update calls financial operation repo and replaces state', () async {
    final fakeOps = _FakeFinancialOps(
      result: const FinancialOperationResult(
        transactions: <model.Transaction>[
          model.Transaction(
            id: 'tx-new',
            type: 'expense',
            date: '2026-06-19',
            amount: 15,
            currency: 'USD',
            category: 'Currency Exchange',
            description: 'Currency exchange out',
            createdAt: '2026-06-19T08:00:00.000Z',
            rolledOver: false,
            exchangePairId: 'exch_new',
          ),
        ],
        savings: <model.Saving>[
          model.Saving(
            id: 'sav-new-target',
            assetType: 'cash',
            dateAcquired: '2026-06-19',
            amount: 150,
            remainingAmount: 150,
            unit: 'EGP',
            description: 'Savings exchange: 15 USD → 150 EGP',
            purchaseCurrency: 'EGP',
            purchaseAmount: 150,
            createdAt: '2026-06-19T08:00:00.000Z',
            transferActivityId: 'exch_new',
            exchangeSourceSavingId: 'sav-source',
          ),
          model.Saving(
            id: 'sav-source',
            assetType: 'cash',
            dateAcquired: '2026-06-18',
            amount: 85,
            remainingAmount: 85,
            unit: 'USD',
            description: 'Source',
            purchaseCurrency: 'USD',
            purchaseAmount: 100,
            createdAt: '2026-06-18T08:00:00.000Z',
          ),
        ],
        affectedTransactionIds: <String>['tx-old', 'tx-new'],
        affectedSavingIds: <String>['sav-target', 'sav-source', 'sav-new-target'],
      ),
    );
    final controller = await _makeController(
      useSqlite: true,
      financialOps: fakeOps,
    );

    final request = CurrencyExchangeEditRequest(
      oldActivityId: 'exch_1',
      oldTargetSavingIds: const <String>['sav-target'],
      oldSourceSavingDeductions: const <String, double>{'sav-source': 10},
      date: '2026-06-19',
      sourceCurrency: 'USD',
      targetCurrency: 'EGP',
      sourceAmount: 15,
      targetAmount: 150,
    );

    await controller.updateCurrencyExchange(request);

    expect(fakeOps.updateCalls, 1);
    expect(fakeOps.lastOldActivityId, 'exch_1');
    expect(fakeOps.lastNewOperation, isNotNull);
    expect(fakeOps.lastNewOperation!.sourceAmountText, '15.0');
    expect(fakeOps.lastNewOperation!.targetAmountText, '150.0');

    expect(controller.state.transactions.map((t) => t.id), ['tx-new']);
    expect(controller.state.savings.map((s) => s.id), ['sav-new-target', 'sav-source']);

    // JSON compatibility save still runs (collections are stripped in Phase 1 SQLite mode)
    final savedDataString = await const LocalStorageService().loadString('zakatAppData');
    expect(savedDataString, isNotNull);
    final savedData = jsonDecode(savedDataString!);
    expect(savedData['transactions'], isEmpty);
    expect(savedData['savings'], isEmpty);
  });

  test('SQLite mode operation failure leaves state unchanged', () async {
    final fakeOps = _FakeFinancialOps(error: StateError('ops failed'));
    final controller = await _makeController(
      useSqlite: true,
      financialOps: fakeOps,
    );

    final beforeTxIds = controller.state.transactions.map((t) => t.id).toList();
    final beforeSavingIds = controller.state.savings.map((s) => s.id).toList();

    final request = CurrencyExchangeEditRequest(
      oldActivityId: 'exch_1',
      oldTargetSavingIds: const <String>['sav-target'],
      oldSourceSavingDeductions: const <String, double>{'sav-source': 10},
      date: '2026-06-19',
      sourceCurrency: 'USD',
      targetCurrency: 'EGP',
      sourceAmount: 15,
      targetAmount: 150,
    );

    await controller.updateCurrencyExchange(request);

    expect(controller.state.transactions.map((t) => t.id), beforeTxIds);
    expect(controller.state.savings.map((s) => s.id), beforeSavingIds);
  });

  test('JSON mode still uses legacy update path', () async {
    final fakeOps = _FakeFinancialOps();
    final controller = await _makeController(
      useSqlite: false,
      financialOps: fakeOps,
    );

    final request = CurrencyExchangeEditRequest(
      oldActivityId: 'exch_1',
      oldTargetSavingIds: const <String>['sav-target'],
      oldSourceSavingDeductions: const <String, double>{'sav-source': 10},
      date: '2026-06-19',
      sourceCurrency: 'USD',
      targetCurrency: 'EGP',
      sourceAmount: 15,
      targetAmount: 150,
    );

    await controller.updateCurrencyExchange(request);

    expect(fakeOps.updateCalls, 0);
    // Legacy path results:
    // Old tx is deleted, old target saving is deleted, source is restored by 10 and then deducted by 15.
    // Source initial: 90 USD. After restoration: 100 USD. Deducted: 15 USD. Next remaining: 85 USD.
    final sourceSaving = controller.state.savings.firstWhere((s) => s.id == 'sav-source');
    expect(sourceSaving.remainingAmount, 85.0);
  });
}
