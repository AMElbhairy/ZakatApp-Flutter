import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
import 'package:zakatapp_flutter/data/repositories/local_financial_operations_repository.dart';
import 'package:zakatapp_flutter/data/repositories/local_savings_repository.dart';
import 'package:zakatapp_flutter/data/repositories/local_transactions_repository.dart';
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

class _SeededTransactionsStore implements TransactionsLocalStore {
  _SeededTransactionsStore(this._transactions);

  final List<model.Transaction> _transactions;

  @override
  Future<void> deleteTransaction(
    String id, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {
    _transactions.removeWhere((model.Transaction tx) => tx.id == id);
  }
  @override
  Future<List<model.Transaction>> getActiveTransactions() async =>
      List<model.Transaction>.from(_transactions);
  @override
  Future<void> replaceAllForLocalMirror(
    Iterable<model.Transaction> transactions,
  ) async {
    _transactions
      ..clear()
      ..addAll(transactions);
  }
  @override
  Future<void> saveTransaction(
    model.Transaction transaction, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {
    _transactions.removeWhere((model.Transaction tx) => tx.id == transaction.id);
    _transactions.add(transaction);
  }
  @override
  Stream<List<model.Transaction>> watchActiveTransactions() async* {
    yield List<model.Transaction>.from(_transactions);
  }
}

class _SeededSavingsStore implements SavingsLocalStore {
  _SeededSavingsStore(this._savings);

  final List<model.Saving> _savings;

  @override
  Future<void> deleteSaving(
    String id, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {
    _savings.removeWhere((model.Saving saving) => saving.id == id);
  }
  @override
  Future<List<model.Saving>> getActiveSavings() async =>
      List<model.Saving>.from(_savings);
  @override
  Future<void> replaceAllForLocalMirror(Iterable<model.Saving> savings) async {
    _savings
      ..clear()
      ..addAll(savings);
  }
  @override
  Future<void> saveSaving(
    model.Saving saving, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {
    _savings.removeWhere((model.Saving entry) => entry.id == saving.id);
    _savings.add(saving);
  }
  @override
  Stream<List<model.Saving>> watchActiveSavings() async* {
    yield List<model.Saving>.from(_savings);
  }
}

class _FakeFinancialOps implements FinancialOperationsLocalStore {
  _FakeFinancialOps({this.metalResult, this.metalError});

  final FinancialOperationResult? metalResult;
  final Object? metalError;
  int deleteMetalSaleCalls = 0;
  int deleteCurrencyExchangeCalls = 0;
  String? lastTransactionId;

  @override
  Future<FinancialOperationResult> deleteCurrencyExchange(
    String activityId,
  ) async {
    deleteCurrencyExchangeCalls += 1;
    throw UnimplementedError();
  }

  @override
  Future<FinancialOperationResult> deleteMetalSale(String transactionId) async {
    deleteMetalSaleCalls += 1;
    lastTransactionId = transactionId;
    if (metalError != null) throw metalError!;
    return metalResult!;
  }

  @override
  Future<FinancialOperationResult> deleteInternalTransfer(String activityId) {
    throw UnimplementedError();
  }

  @override
  Future<FinancialOperationResult> recordCurrencyExchange(CurrencyExchangeOperation input) {
    throw UnimplementedError();
  }

  @override
  Future<FinancialOperationResult> updateCurrencyExchange(
    String oldActivityId,
    CurrencyExchangeOperation newOperation,
  ) {
    throw UnimplementedError();
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
  final List<model.Transaction> seededTransactions = <model.Transaction>[
    const model.Transaction(
      id: 'gold-sale-tx',
      type: 'transfer',
      date: '2026-06-19',
      amount: 250,
      currency: 'USD',
      category: 'Gold Sale',
      description: '2.50g Gold -> USD 250.00',
      createdAt: '2026-06-19T08:00:00.000Z',
      rolledOver: false,
      activityType: 'transfer',
      exchangePairId: 'gold-saving',
      costBasis: 180,
      saleValue: 250,
      realizedGain: 70,
      realizedGainLossCurrency: 'USD',
    ),
    const model.Transaction(
      id: 'regular-tx',
      type: 'expense',
      date: '2026-06-19',
      amount: 10,
      currency: 'USD',
      category: 'Food',
      description: 'Lunch',
      createdAt: '2026-06-19T09:00:00.000Z',
      rolledOver: false,
    ),
  ];
  final List<model.Saving> seededSavings = <model.Saving>[
    const model.Saving(
      id: 'gold-saving',
      assetType: 'gold',
      dateAcquired: '2026-06-10',
      amount: 100,
      remainingAmount: 97.5,
      unit: 'g',
      description: 'Gold holding',
      purchaseCurrency: 'USD',
      purchaseAmount: 7000,
      createdAt: '2026-06-10T08:00:00.000Z',
    ),
    const model.Saving(
      id: 'cash-proceeds',
      assetType: 'cash',
      dateAcquired: '2026-06-19',
      amount: 250,
      remainingAmount: 250,
      unit: 'USD',
      description: 'Gold Sale proceeds',
      purchaseCurrency: 'USD',
      purchaseAmount: 250,
      createdAt: '2026-06-19T08:00:00.000Z',
      internalTransfer: true,
      internalTransferType: 'precious_metals_sale',
      transferActivityId: 'gold-sale-tx',
    ),
  ];
  SharedPreferences.setMockInitialValues(<String, Object>{
    'zakatAppData':
        '{"transactions":[{"id":"gold-sale-tx","type":"transfer","date":"2026-06-19","amount":250,"currency":"USD","category":"Gold Sale","description":"2.50g Gold -> USD 250.00","createdAt":"2026-06-19T08:00:00.000Z","rolledOver":false,"activityType":"transfer","exchangePairId":"gold-saving","costBasis":180,"saleValue":250,"realizedGain":70,"realizedGainLossCurrency":"USD"},{"id":"regular-tx","type":"expense","date":"2026-06-19","amount":10,"currency":"USD","category":"Food","description":"Lunch","createdAt":"2026-06-19T09:00:00.000Z","rolledOver":false}],"savings":[{"id":"gold-saving","assetType":"gold","dateAcquired":"2026-06-10","amount":100,"remainingAmount":97.5,"unit":"g","description":"Gold holding","purchaseCurrency":"USD","purchaseAmount":7000,"createdAt":"2026-06-10T08:00:00.000Z"},{"id":"cash-proceeds","assetType":"cash","dateAcquired":"2026-06-19","amount":250,"remainingAmount":250,"unit":"USD","description":"Gold Sale proceeds","purchaseCurrency":"USD","purchaseAmount":250,"createdAt":"2026-06-19T08:00:00.000Z","internalTransfer":true,"internalTransferType":"precious_metals_sale","transferActivityId":"gold-sale-tx"}],"recurringTransactions":[],"investments":[],"financialPlans":[],"pendingTransactions":[],"lastRollover":"","categories":{"income":[],"expense":[]},"zakatPaidMonths":[],"processedExpenseIds":[],"mainCurrency":"USD","defaultEntryCurrency":"USD","zakatExpenseIds":{},"zakatMethod":"hawl","zakatAnnualDate":"","zakatNisabBasis":"gold85","zakatScheduleFilter":"unpaid","marketData":{},"marketHistory":[],"syncHealth":{"lastSuccessAt":"","lastFailureAt":"","lastError":"","pendingWrites":0},"lastModifiedAt":"","languagePreference":"en","themeMode":"system","biometricLockEnabled":false,"biometricHideWealthEnabled":false,"biometricExportEnabled":false,"biometricRestoreEnabled":false,"biometricAutoLockDelay":"1_minute","merchantRules":{},"merchantAliases":{},"captureAnalytics":{"parsedMessages":0,"autoApprovedMessages":0,"duplicateMessages":0,"ignoredMessages":0,"correctedMessages":0,"learnedRules":0,"autoApprovedRules":0,"capturedFromAppleShortcuts":0,"capturedFromAppleShortcutsAutoApproved":0,"capturedFromAppleShortcutsIgnored":0},"correctionFeedback":[],"merchantConfirmations":[],"smartCaptureEnabled":true,"smartCaptureAutoApproveEnabled":false}',
  });
  const localStorage = LocalStorageService();
  final repository = AppStateRepository(localStorage: localStorage);
  final controller = AppStateController(
    repository: repository,
    localTransactionsRepository: _SeededTransactionsStore(seededTransactions),
    localSavingsRepository: _SeededSavingsStore(seededSavings),
    localFinancialOperationsRepository: financialOps,
    useSqliteLocalStoreProvider: _StaticGate(useSqlite),
  );
  await controller.load();
  return controller;
}

void main() {
  test('SQLite mode gold sale delete calls operation repo and replaces state', () async {
    final fakeOps = _FakeFinancialOps(
      metalResult: const FinancialOperationResult(
        transactions: <model.Transaction>[
          model.Transaction(
            id: 'regular-tx',
            type: 'expense',
            date: '2026-06-19',
            amount: 10,
            currency: 'USD',
            category: 'Food',
            description: 'Lunch',
            createdAt: '2026-06-19T09:00:00.000Z',
            rolledOver: false,
          ),
        ],
        savings: <model.Saving>[
          model.Saving(
            id: 'gold-saving',
            assetType: 'gold',
            dateAcquired: '2026-06-10',
            amount: 100,
            remainingAmount: 100,
            unit: 'g',
            description: 'Gold holding',
            purchaseCurrency: 'USD',
            purchaseAmount: 7000,
            createdAt: '2026-06-10T08:00:00.000Z',
          ),
        ],
        affectedTransactionIds: <String>['gold-sale-tx'],
        affectedSavingIds: <String>['gold-saving', 'cash-proceeds'],
      ),
    );
    final controller = await _makeController(
      useSqlite: true,
      financialOps: fakeOps,
    );

    await controller.deleteTransaction('gold-sale-tx');

    expect(fakeOps.deleteMetalSaleCalls, 1);
    expect(fakeOps.lastTransactionId, 'gold-sale-tx');
    expect(
      controller.state.transactions.map((model.Transaction t) => t.id),
      <String>['regular-tx'],
    );
    expect(
      controller.state.savings.map((model.Saving s) => s.id),
      <String>['gold-saving'],
    );
    final persisted = jsonDecode(
      (await const LocalStorageService().loadString('zakatAppData'))!,
    ) as Map<String, dynamic>;
    expect((persisted['transactions'] as List<dynamic>), isEmpty);
    expect((persisted['savings'] as List<dynamic>), isEmpty);
  });

  test('SQLite mode operation failure leaves state unchanged', () async {
    final fakeOps = _FakeFinancialOps(metalError: StateError('ops failed'));
    final controller = await _makeController(
      useSqlite: true,
      financialOps: fakeOps,
    );
    final beforeTxIds = controller.state.transactions
        .map((model.Transaction t) => t.id)
        .toList(growable: false);
    final beforeSavingIds = controller.state.savings
        .map((model.Saving s) => s.id)
        .toList(growable: false);

    await controller.deleteTransaction('gold-sale-tx');

    expect(
      controller.state.transactions.map((model.Transaction t) => t.id),
      beforeTxIds,
    );
    expect(
      controller.state.savings.map((model.Saving s) => s.id),
      beforeSavingIds,
    );
  });

  test('JSON mode still uses legacy path', () async {
    final fakeOps = _FakeFinancialOps(
      metalResult: const FinancialOperationResult(
        transactions: <model.Transaction>[],
        savings: <model.Saving>[],
        affectedTransactionIds: <String>[],
        affectedSavingIds: <String>[],
      ),
    );
    final controller = await _makeController(
      useSqlite: false,
      financialOps: fakeOps,
    );

    await controller.deleteTransaction('gold-sale-tx');

    expect(fakeOps.deleteMetalSaleCalls, 0);
    expect(
      controller.state.transactions.map((model.Transaction t) => t.id),
      <String>['regular-tx'],
    );
    expect(controller.state.savings, hasLength(1));
    expect(controller.state.savings.first.id, 'gold-saving');
    expect(controller.state.savings.first.remainingAmount, 100);
  });

  test('non-metal transaction delete is unaffected', () async {
    final fakeOps = _FakeFinancialOps(
      metalResult: const FinancialOperationResult(
        transactions: <model.Transaction>[],
        savings: <model.Saving>[],
        affectedTransactionIds: <String>[],
        affectedSavingIds: <String>[],
      ),
    );
    final controller = await _makeController(
      useSqlite: true,
      financialOps: fakeOps,
    );

    await controller.deleteTransaction('regular-tx');

    expect(fakeOps.deleteMetalSaleCalls, 0);
    expect(
      controller.state.transactions.map((model.Transaction t) => t.id),
      <String>['gold-sale-tx'],
    );
    expect(controller.state.savings.map((model.Saving s) => s.id), <String>[
      'gold-saving',
      'cash-proceeds',
    ]);
  });
}
