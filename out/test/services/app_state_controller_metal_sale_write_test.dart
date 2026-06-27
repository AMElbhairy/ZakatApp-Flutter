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
  int recordCalls = 0;
  int updateCalls = 0;
  MetalSaleOperation? lastRecordOperation;
  String? lastOldTransactionId;
  MetalSaleOperation? lastUpdateOperation;

  @override
  Future<FinancialOperationResult> deleteCurrencyExchange(
    String activityId,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<FinancialOperationResult> deleteMetalSale(String transactionId) async {
    throw UnimplementedError();
  }

  @override
  Future<FinancialOperationResult> deleteInternalTransfer(
    String activityId,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<FinancialOperationResult> recordCurrencyExchange(
    CurrencyExchangeOperation input,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<FinancialOperationResult> updateCurrencyExchange(
    String oldActivityId,
    CurrencyExchangeOperation newOperation,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<FinancialOperationResult> recordMetalSale(
    MetalSaleOperation input,
  ) async {
    recordCalls += 1;
    lastRecordOperation = input;
    if (error != null) throw error!;
    return result!;
  }

  @override
  Future<FinancialOperationResult> updateMetalSale(
    String oldTransactionId,
    MetalSaleOperation newOperation,
  ) async {
    updateCalls += 1;
    lastOldTransactionId = oldTransactionId;
    lastUpdateOperation = newOperation;
    if (error != null) throw error!;
    return result!;
  }
}

Future<AppStateController> _makeController({
  required bool useSqlite,
  required FinancialOperationsLocalStore? financialOps,
}) async {
  const initialTransactions = <model.Transaction>[
    model.Transaction(
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
    ),
  ];

  const initialSavings = <model.Saving>[
    model.Saving(
      id: "gold-saving",
      assetType: "gold",
      dateAcquired: "2026-06-10",
      amount: 100,
      remainingAmount: 97.5,
      unit: "g",
      description: "Gold holding",
      purchaseCurrency: "USD",
      purchaseAmount: 7000,
      createdAt: "2026-06-10T08:00:00.000Z",
    ),
    model.Saving(
      id: "cash-proceeds",
      assetType: "cash",
      dateAcquired: "2026-06-19",
      amount: 250,
      remainingAmount: 250,
      unit: "USD",
      description: "Gold Sale proceeds",
      purchaseCurrency: "USD",
      purchaseAmount: 250,
      createdAt: "2026-06-19T08:00:00.000Z",
      internalTransfer: true,
      internalTransferType: "precious_metals_sale",
      transferActivityId: "gold-sale-tx",
    ),
  ];

  SharedPreferences.setMockInitialValues(<String, Object>{
    'zakatAppData':
        '{"transactions":[{"id":"gold-sale-tx","type":"transfer","date":"2026-06-19","amount":250,"currency":"USD","category":"Gold Sale","description":"2.50g Gold -> USD 250.00","createdAt":"2026-06-19T08:00:00.000Z","rolledOver":false,"activityType":"transfer","exchangePairId":"gold-saving"}],"savings":[{"id":"gold-saving","assetType":"gold","dateAcquired":"2026-06-10","amount":100,"remainingAmount":97.5,"unit":"g","description":"Gold holding","purchaseCurrency":"USD","purchaseAmount":7000,"createdAt":"2026-06-10T08:00:00.000Z"},{"id":"cash-proceeds","assetType":"cash","dateAcquired":"2026-06-19","amount":250,"remainingAmount":250,"unit":"USD","description":"Gold Sale proceeds","purchaseCurrency":"USD","purchaseAmount":250,"createdAt":"2026-06-19T08:00:00.000Z","internalTransfer":true,"internalTransferType":"precious_metals_sale","transferActivityId":"gold-sale-tx"}],"recurringTransactions":[],"investments":[],"financialPlans":[],"pendingTransactions":[],"lastRollover":"","categories":{"income":[],"expense":[]},"zakatPaidMonths":[],"processedExpenseIds":[],"mainCurrency":"USD","defaultEntryCurrency":"USD","zakatExpenseIds":{},"zakatMethod":"hawl","zakatAnnualDate":"","zakatNisabBasis":"gold85","zakatScheduleFilter":"unpaid","marketData":{},"marketHistory":[],"syncHealth":{"lastSuccessAt":"","lastFailureAt":"","lastError":"","pendingWrites":0},"lastModifiedAt":"","languagePreference":"en","themeMode":"system","biometricLockEnabled":false,"biometricHideWealthEnabled":false,"biometricExportEnabled":false,"biometricRestoreEnabled":false,"biometricAutoLockDelay":"1_minute","merchantRules":{},"merchantAliases":{},"captureAnalytics":{"parsedMessages":0,"autoApprovedMessages":0,"duplicateMessages":0,"ignoredMessages":0,"correctedMessages":0,"learnedRules":0,"autoApprovedRules":0,"capturedFromAppleShortcuts":0,"capturedFromAppleShortcutsAutoApproved":0,"capturedFromAppleShortcutsIgnored":0},"correctionFeedback":[],"merchantConfirmations":[],"smartCaptureEnabled":true,"smartCaptureAutoApproveEnabled":false}',
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
  test(
    'SQLite mode executeMetalSale calls recordMetalSale and replaces state',
    () async {
      final fakeOps = _FakeFinancialOps(
        result: const FinancialOperationResult(
          transactions: <model.Transaction>[
            model.Transaction(
              id: 'gold-sale-tx-2',
              type: 'transfer',
              date: '2026-06-19',
              amount: 500,
              currency: 'USD',
              category: 'Gold Sale',
              description: '5.00g Gold -> USD 500.00',
              createdAt: '2026-06-19T08:00:00.000Z',
              rolledOver: false,
              activityType: 'transfer',
              exchangePairId: 'gold-saving',
            ),
          ],
          savings: <model.Saving>[
            model.Saving(
              id: 'gold-saving',
              assetType: 'gold',
              dateAcquired: '2026-06-10',
              amount: 100,
              remainingAmount: 92.5,
              unit: 'g',
              description: 'Gold holding',
              purchaseCurrency: 'USD',
              purchaseAmount: 7000,
              createdAt: '2026-06-10T08:00:00.000Z',
            ),
            model.Saving(
              id: 'cash-proceeds-2',
              assetType: 'cash',
              dateAcquired: '2026-06-19',
              amount: 500,
              remainingAmount: 500,
              unit: 'USD',
              description: 'Gold Sale proceeds',
              purchaseCurrency: 'USD',
              purchaseAmount: 500,
              createdAt: '2026-06-19T08:00:00.000Z',
              internalTransfer: true,
              internalTransferType: 'precious_metals_sale',
              transferActivityId: 'gold-sale-tx-2',
            ),
          ],
          affectedTransactionIds: <String>['gold-sale-tx-2'],
          affectedSavingIds: <String>['gold-saving', 'cash-proceeds-2'],
        ),
      );
      final controller = await _makeController(
        useSqlite: true,
        financialOps: fakeOps,
      );

      final transaction = const model.Transaction(
        id: 'gold-sale-tx-2',
        type: 'transfer',
        date: '2026-06-19',
        amount: 500,
        currency: 'USD',
        category: 'Gold Sale',
        description: '5.00g Gold -> USD 500.00',
        createdAt: '2026-06-19T08:00:00.000Z',
        rolledOver: false,
        activityType: 'transfer',
        exchangePairId: 'gold-saving',
      );

      final cashSaving = const model.Saving(
        id: 'cash-proceeds-2',
        assetType: 'cash',
        dateAcquired: '2026-06-19',
        amount: 500,
        remainingAmount: 500,
        unit: 'USD',
        description: 'Gold Sale proceeds',
        purchaseCurrency: 'USD',
        purchaseAmount: 500,
        createdAt: '2026-06-19T08:00:00.000Z',
        internalTransfer: true,
        internalTransferType: 'precious_metals_sale',
        transferActivityId: 'gold-sale-tx-2',
      );

      await controller.executeMetalSale(
        transaction: transaction,
        generatedTargetSaving: cashSaving,
      );

      expect(fakeOps.recordCalls, 1);
      expect(fakeOps.lastRecordOperation!.transactionRow.id, 'gold-sale-tx-2');
      expect(
        fakeOps.lastRecordOperation!.generatedTargetSavingRow!.id,
        'cash-proceeds-2',
      );

      expect(controller.state.transactions.map((t) => t.id), [
        'gold-sale-tx-2',
      ]);
      expect(
        controller.state.savings.map((s) => s.id),
        containsAll(['gold-saving', 'cash-proceeds-2']),
      );
      expect(
        controller.state.savings
            .firstWhere((s) => s.id == 'gold-saving')
            .remainingAmount,
        92.5,
      );
      expect(
        controller.state.savings
            .firstWhere((s) => s.id == 'cash-proceeds-2')
            .remainingAmount,
        500,
      );
    },
  );

  test(
    'SQLite mode updateMetalSale calls repository updateMetalSale and replaces state',
    () async {
      final fakeOps = _FakeFinancialOps(
        result: const FinancialOperationResult(
          transactions: <model.Transaction>[
            model.Transaction(
              id: 'gold-sale-tx-updated',
              type: 'transfer',
              date: '2026-06-19',
              amount: 500,
              currency: 'USD',
              category: 'Gold Sale',
              description: '5.00g Gold -> USD 500.00',
              createdAt: '2026-06-19T08:00:00.000Z',
              rolledOver: false,
              activityType: 'transfer',
              exchangePairId: 'gold-saving',
            ),
          ],
          savings: <model.Saving>[
            model.Saving(
              id: 'gold-saving',
              assetType: 'gold',
              dateAcquired: '2026-06-10',
              amount: 100,
              remainingAmount: 95.0,
              unit: 'g',
              description: 'Gold holding',
              purchaseCurrency: 'USD',
              purchaseAmount: 7000,
              createdAt: '2026-06-10T08:00:00.000Z',
            ),
            model.Saving(
              id: 'cash-proceeds-updated',
              assetType: 'cash',
              dateAcquired: '2026-06-19',
              amount: 500,
              remainingAmount: 500,
              unit: 'USD',
              description: 'Gold Sale proceeds',
              purchaseCurrency: 'USD',
              purchaseAmount: 500,
              createdAt: '2026-06-19T08:00:00.000Z',
              internalTransfer: true,
              internalTransferType: 'precious_metals_sale',
              transferActivityId: 'gold-sale-tx-updated',
            ),
          ],
          affectedTransactionIds: <String>[
            'gold-sale-tx',
            'gold-sale-tx-updated',
          ],
          affectedSavingIds: <String>[
            'gold-saving',
            'cash-proceeds',
            'cash-proceeds-updated',
          ],
        ),
      );
      final controller = await _makeController(
        useSqlite: true,
        financialOps: fakeOps,
      );

      final transaction = const model.Transaction(
        id: 'gold-sale-tx-updated',
        type: 'transfer',
        date: '2026-06-19',
        amount: 500,
        currency: 'USD',
        category: 'Gold Sale',
        description: '5.00g Gold -> USD 500.00',
        createdAt: '2026-06-19T08:00:00.000Z',
        rolledOver: false,
        activityType: 'transfer',
        exchangePairId: 'gold-saving',
      );

      final cashSaving = const model.Saving(
        id: 'cash-proceeds-updated',
        assetType: 'cash',
        dateAcquired: '2026-06-19',
        amount: 500,
        remainingAmount: 500,
        unit: 'USD',
        description: 'Gold Sale proceeds',
        purchaseCurrency: 'USD',
        purchaseAmount: 500,
        createdAt: '2026-06-19T08:00:00.000Z',
        internalTransfer: true,
        internalTransferType: 'precious_metals_sale',
        transferActivityId: 'gold-sale-tx-updated',
      );

      await controller.updateMetalSale(
        oldTransactionId: 'gold-sale-tx',
        transaction: transaction,
        generatedTargetSaving: cashSaving,
      );

      expect(fakeOps.updateCalls, 1);
      expect(fakeOps.lastOldTransactionId, 'gold-sale-tx');
      expect(
        fakeOps.lastUpdateOperation!.transactionRow.id,
        'gold-sale-tx-updated',
      );

      expect(controller.state.transactions.map((t) => t.id), [
        'gold-sale-tx-updated',
      ]);
      expect(
        controller.state.savings.map((s) => s.id),
        containsAll(['gold-saving', 'cash-proceeds-updated']),
      );
      expect(
        controller.state.savings
            .firstWhere((s) => s.id == 'gold-saving')
            .remainingAmount,
        95.0,
      );
      expect(
        controller.state.savings
            .firstWhere((s) => s.id == 'cash-proceeds-updated')
            .remainingAmount,
        500,
      );
    },
  );

  test('SQLite mode failure leaves state unchanged', () async {
    final fakeOps = _FakeFinancialOps(error: StateError('failed'));
    final controller = await _makeController(
      useSqlite: true,
      financialOps: fakeOps,
    );

    final transaction = const model.Transaction(
      id: 'gold-sale-tx-updated',
      type: 'transfer',
      date: '2026-06-19',
      amount: 500,
      currency: 'USD',
      category: 'Gold Sale',
      description: '5.00g Gold -> USD 500.00',
      createdAt: '2026-06-19T08:00:00.000Z',
      rolledOver: false,
      activityType: 'transfer',
      exchangePairId: 'gold-saving',
    );

    await controller.executeMetalSale(transaction: transaction);

    expect(controller.state.transactions.map((t) => t.id), ['gold-sale-tx']);
  });
}
