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
    _transactions.removeWhere(
      (model.Transaction tx) => tx.id == transaction.id,
    );
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
  _FakeFinancialOps({this.internalTransferResult, this.internalTransferError});

  final FinancialOperationResult? internalTransferResult;
  final Object? internalTransferError;
  int deleteInternalTransferCalls = 0;
  int deleteCurrencyExchangeCalls = 0;
  int deleteMetalSaleCalls = 0;
  String? lastActivityId;

  @override
  Future<FinancialOperationResult> deleteCurrencyExchange(
    String activityId,
  ) async {
    deleteCurrencyExchangeCalls += 1;
    throw UnimplementedError();
  }

  @override
  Future<FinancialOperationResult> deleteInternalTransfer(
    String activityId,
  ) async {
    deleteInternalTransferCalls += 1;
    lastActivityId = activityId;
    if (internalTransferError != null) throw internalTransferError!;
    return internalTransferResult!;
  }

  @override
  Future<FinancialOperationResult> deleteMetalSale(String transactionId) async {
    deleteMetalSaleCalls += 1;
    throw UnimplementedError();
  }

  @override
  Future<FinancialOperationResult> recordCurrencyExchange(
    CurrencyExchangeOperation input,
  ) {
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
      id: 'transfer_1',
      type: 'transfer',
      date: '2026-06-19',
      amount: 20,
      currency: 'USD',
      category: 'Cash Transfer',
      description: 'Internal transfer to wallet',
      createdAt: '2026-06-19T08:00:00.000Z',
      rolledOver: false,
      activityType: 'transfer',
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
      id: 'cash-source',
      assetType: 'cash',
      dateAcquired: '2026-06-10',
      amount: 80,
      remainingAmount: 80,
      unit: 'USD',
      description: 'Wallet cash',
      purchaseCurrency: 'USD',
      purchaseAmount: 100,
      createdAt: '2026-06-10T08:00:00.000Z',
    ),
    const model.Saving(
      id: 'target-transfer',
      assetType: 'cash',
      dateAcquired: '2026-06-19',
      amount: 20,
      remainingAmount: 20,
      unit: 'USD',
      description: 'Internal transfer target',
      linkedCashEntryId: 'cash-source',
      purchaseCurrency: 'USD',
      purchaseAmount: 20,
      createdAt: '2026-06-19T08:00:00.000Z',
      internalTransfer: true,
      internalTransferType: 'cash_wallet_transfer',
      transferActivityId: 'transfer_1',
    ),
    const model.Saving(
      id: 'exchange-transfer',
      assetType: 'cash',
      dateAcquired: '2026-06-19',
      amount: 30,
      remainingAmount: 30,
      unit: 'EUR',
      description: 'Savings exchange: 10 USD -> 30 EUR',
      purchaseCurrency: 'EUR',
      purchaseAmount: 30,
      createdAt: '2026-06-19T10:00:00.000Z',
      internalTransfer: true,
      internalTransferType: 'savings_currency_exchange',
      transferActivityId: 'exch_1',
      exchangeSourceSavingId: 'cash-source',
    ),
  ];

  SharedPreferences.setMockInitialValues(<String, Object>{
    'zakatAppData':
        '{"transactions":[{"id":"transfer_1","type":"transfer","date":"2026-06-19","amount":20,"currency":"USD","category":"Cash Transfer","description":"Internal transfer to wallet","createdAt":"2026-06-19T08:00:00.000Z","rolledOver":false,"activityType":"transfer"},{"id":"regular-tx","type":"expense","date":"2026-06-19","amount":10,"currency":"USD","category":"Food","description":"Lunch","createdAt":"2026-06-19T09:00:00.000Z","rolledOver":false}],"savings":[{"id":"cash-source","assetType":"cash","dateAcquired":"2026-06-10","amount":80,"remainingAmount":80,"unit":"USD","description":"Wallet cash","purchaseCurrency":"USD","purchaseAmount":100,"createdAt":"2026-06-10T08:00:00.000Z"},{"id":"target-transfer","assetType":"cash","dateAcquired":"2026-06-19","amount":20,"remainingAmount":20,"unit":"USD","description":"Internal transfer target","linkedCashEntryId":"cash-source","purchaseCurrency":"USD","purchaseAmount":20,"createdAt":"2026-06-19T08:00:00.000Z","internalTransfer":true,"internalTransferType":"cash_wallet_transfer","transferActivityId":"transfer_1"},{"id":"exchange-transfer","assetType":"cash","dateAcquired":"2026-06-19","amount":30,"remainingAmount":30,"unit":"EUR","description":"Savings exchange: 10 USD -> 30 EUR","purchaseCurrency":"EUR","purchaseAmount":30,"createdAt":"2026-06-19T10:00:00.000Z","internalTransfer":true,"internalTransferType":"savings_currency_exchange","transferActivityId":"exch_1","exchangeSourceSavingId":"cash-source"}],"recurringTransactions":[],"investments":[],"financialPlans":[],"pendingTransactions":[],"lastRollover":"","categories":{"income":[],"expense":[]},"zakatPaidMonths":[],"processedExpenseIds":[],"mainCurrency":"USD","defaultEntryCurrency":"USD","zakatExpenseIds":{},"zakatMethod":"hawl","zakatAnnualDate":"","zakatNisabBasis":"gold85","zakatScheduleFilter":"unpaid","marketData":{},"marketHistory":[],"syncHealth":{"lastSuccessAt":"","lastFailureAt":"","lastError":"","pendingWrites":0},"lastModifiedAt":"","languagePreference":"en","themeMode":"system","biometricLockEnabled":false,"biometricHideWealthEnabled":false,"biometricExportEnabled":false,"biometricRestoreEnabled":false,"biometricAutoLockDelay":"1_minute","merchantRules":{},"merchantAliases":{},"captureAnalytics":{"parsedMessages":0,"autoApprovedMessages":0,"duplicateMessages":0,"ignoredMessages":0,"correctedMessages":0,"learnedRules":0,"autoApprovedRules":0,"capturedFromAppleShortcuts":0,"capturedFromAppleShortcutsAutoApproved":0,"capturedFromAppleShortcutsIgnored":0},"correctionFeedback":[],"merchantConfirmations":[],"smartCaptureEnabled":true,"smartCaptureAutoApproveEnabled":false}',
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
  test(
    'SQLite mode internal transfer delete calls operation repo and replaces state',
    () async {
      final fakeOps = _FakeFinancialOps(
        internalTransferResult: const FinancialOperationResult(
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
              id: 'cash-source',
              assetType: 'cash',
              dateAcquired: '2026-06-10',
              amount: 100,
              remainingAmount: 100,
              unit: 'USD',
              description: 'Wallet cash',
              purchaseCurrency: 'USD',
              purchaseAmount: 100,
              createdAt: '2026-06-10T08:00:00.000Z',
            ),
            model.Saving(
              id: 'exchange-transfer',
              assetType: 'cash',
              dateAcquired: '2026-06-19',
              amount: 30,
              remainingAmount: 30,
              unit: 'EUR',
              description: 'Savings exchange: 10 USD -> 30 EUR',
              purchaseCurrency: 'EUR',
              purchaseAmount: 30,
              createdAt: '2026-06-19T10:00:00.000Z',
              internalTransfer: true,
              internalTransferType: 'savings_currency_exchange',
              transferActivityId: 'exch_1',
              exchangeSourceSavingId: 'cash-source',
            ),
          ],
          affectedTransactionIds: <String>['transfer_1'],
          affectedSavingIds: <String>['cash-source', 'target-transfer'],
        ),
      );
      final controller = await _makeController(
        useSqlite: true,
        financialOps: fakeOps,
      );

      await controller.deleteSaving('target-transfer');

      expect(fakeOps.deleteInternalTransferCalls, 1);
      expect(fakeOps.lastActivityId, 'transfer_1');
      expect(
        controller.state.transactions.map((model.Transaction t) => t.id),
        <String>['regular-tx'],
      );
      expect(controller.state.savings.map((model.Saving s) => s.id), <String>[
        'cash-source',
        'exchange-transfer',
      ]);
      expect(
        controller.state.savings
            .firstWhere((model.Saving s) => s.id == 'cash-source')
            .remainingAmount,
        100,
      );
      expect(
        controller.state.savings
            .firstWhere((model.Saving s) => s.id == 'exchange-transfer')
            .remainingAmount,
        30,
      );
      final persisted =
          jsonDecode(
                (await const LocalStorageService().loadString('zakatAppData'))!,
              )
              as Map<String, dynamic>;
      expect((persisted['transactions'] as List<dynamic>).length, 1);
      expect((persisted['savings'] as List<dynamic>).length, 2);
    },
  );

  test(
    'SQLite mode internal transfer operation failure leaves state unchanged',
    () async {
      final fakeOps = _FakeFinancialOps(
        internalTransferError: StateError('ops failed'),
      );
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

      await controller.deleteSaving('target-transfer');

      expect(
        controller.state.transactions.map((model.Transaction t) => t.id),
        beforeTxIds,
      );
      expect(
        controller.state.savings.map((model.Saving s) => s.id),
        beforeSavingIds,
      );
    },
  );

  test(
    'currency exchange saving delete is still unaffected by internal transfer repo',
    () async {
      final fakeOps = _FakeFinancialOps(
        internalTransferResult: const FinancialOperationResult(
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

      await controller.deleteSaving('exchange-transfer');

      expect(fakeOps.deleteInternalTransferCalls, 0);
    },
  );
}
