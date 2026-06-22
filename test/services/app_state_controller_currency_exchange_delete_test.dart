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

class _NoopTransactionsStore implements TransactionsLocalStore {
  const _NoopTransactionsStore();
  @override
  Future<void> deleteTransaction(
    String id, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {}
  @override
  Future<List<model.Transaction>> getActiveTransactions() async =>
      const <model.Transaction>[];
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
    yield const <model.Transaction>[];
  }
}

class _NoopSavingsStore implements SavingsLocalStore {
  const _NoopSavingsStore();
  @override
  Future<void> deleteSaving(
    String id, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {}
  @override
  Future<List<model.Saving>> getActiveSavings() async => const <model.Saving>[];
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
    yield const <model.Saving>[];
  }
}

class _FakeFinancialOps implements FinancialOperationsLocalStore {
  _FakeFinancialOps({this.result, this.error});

  final FinancialOperationResult? result;
  final Object? error;
  int deleteCalls = 0;
  String? lastActivityId;

  @override
  Future<FinancialOperationResult> deleteCurrencyExchange(
    String activityId,
  ) async {
    deleteCalls += 1;
    lastActivityId = activityId;
    if (error != null) throw error!;
    return result!;
  }

  @override
  Future<FinancialOperationResult> deleteInternalTransfer(String activityId) {
    throw UnimplementedError();
  }

  @override
  Future<FinancialOperationResult> deleteMetalSale(String transactionId) {
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
  SharedPreferences.setMockInitialValues(<String, Object>{
    'zakatAppData':
        '{"transactions":[{"id":"tx-old","type":"expense","date":"2026-06-19","amount":10,"currency":"USD","category":"Currency Exchange","description":"Currency exchange out","createdAt":"2026-06-19T08:00:00.000Z","rolledOver":false,"exchangePairId":"exch_1"}],"savings":[{"id":"sav-target","assetType":"cash","dateAcquired":"2026-06-19","amount":100,"remainingAmount":100,"unit":"EGP","description":"Savings exchange: 10 USD → 100 EGP","purchaseCurrency":"EGP","purchaseAmount":100,"createdAt":"2026-06-19T08:00:00.000Z","transferActivityId":"exch_1","exchangeSourceSavingId":"sav-source"},{"id":"sav-source","assetType":"cash","dateAcquired":"2026-06-18","amount":90,"remainingAmount":90,"unit":"USD","description":"Source","purchaseCurrency":"USD","purchaseAmount":100,"createdAt":"2026-06-18T08:00:00.000Z"}],"recurringTransactions":[],"investments":[],"financialPlans":[],"pendingTransactions":[],"lastRollover":"","categories":{"income":[],"expense":[]},"zakatPaidMonths":[],"processedExpenseIds":[],"mainCurrency":"USD","defaultEntryCurrency":"USD","zakatExpenseIds":{},"zakatMethod":"hawl","zakatAnnualDate":"","zakatNisabBasis":"gold85","zakatScheduleFilter":"unpaid","marketData":{},"marketHistory":[],"syncHealth":{"lastSuccessAt":"","lastFailureAt":"","lastError":"","pendingWrites":0},"lastModifiedAt":"","languagePreference":"en","themeMode":"system","biometricLockEnabled":false,"biometricHideWealthEnabled":false,"biometricExportEnabled":false,"biometricRestoreEnabled":false,"biometricAutoLockDelay":"1_minute","merchantRules":{},"merchantAliases":{},"captureAnalytics":{"parsedMessages":0,"autoApprovedMessages":0,"duplicateMessages":0,"ignoredMessages":0,"correctedMessages":0,"learnedRules":0,"autoApprovedRules":0,"capturedFromAppleShortcuts":0,"capturedFromAppleShortcutsAutoApproved":0,"capturedFromAppleShortcutsIgnored":0},"correctionFeedback":[],"merchantConfirmations":[],"smartCaptureEnabled":true,"smartCaptureAutoApproveEnabled":false}',
  });
  const localStorage = LocalStorageService();
  final repository = AppStateRepository(localStorage: localStorage);
  final controller = AppStateController(
    repository: repository,
    localTransactionsRepository: const _NoopTransactionsStore(),
    localSavingsRepository: const _NoopSavingsStore(),
    localFinancialOperationsRepository: financialOps,
    useSqliteLocalStoreProvider: _StaticGate(useSqlite),
  );
  await controller.load();
  return controller;
}

void main() {
  test(
    'SQLite mode currency exchange delete calls operation repo and replaces state',
    () async {
      final fakeOps = _FakeFinancialOps(
        result: const FinancialOperationResult(
          transactions: <model.Transaction>[],
          savings: <model.Saving>[
            model.Saving(
              id: 'sav-source',
              assetType: 'cash',
              dateAcquired: '2026-06-18',
              amount: 100,
              remainingAmount: 100,
              unit: 'USD',
              description: 'Source',
              purchaseCurrency: 'USD',
              purchaseAmount: 100,
              createdAt: '2026-06-18T08:00:00.000Z',
            ),
          ],
          affectedTransactionIds: <String>['tx-old'],
          affectedSavingIds: <String>['sav-target', 'sav-source'],
        ),
      );
      final controller = await _makeController(
        useSqlite: true,
        financialOps: fakeOps,
      );

      await controller.deleteCurrencyExchangeActivity('exch_1');

      expect(fakeOps.deleteCalls, 1);
      expect(fakeOps.lastActivityId, 'exch_1');
      expect(controller.state.transactions, isEmpty);
      expect(controller.state.savings.map((model.Saving s) => s.id), [
        'sav-source',
      ]);
      expect(
        controller.state.savings
            .singleWhere((model.Saving s) => s.id == 'sav-source')
            .remainingAmount,
        100,
      );
      expect(
        jsonDecode(
          (await const LocalStorageService().loadString('zakatAppData'))!,
        )['savings'][0]['id'],
        'sav-source',
      );
    },
  );

  test('SQLite mode operation failure leaves state unchanged', () async {
    final fakeOps = _FakeFinancialOps(error: StateError('ops failed'));
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

    await controller.deleteCurrencyExchangeActivity('exch_1');

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
      result: const FinancialOperationResult(
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

    await controller.deleteCurrencyExchangeActivity('exch_1');

    expect(fakeOps.deleteCalls, 0);
    expect(controller.state.transactions, isEmpty);
    expect(controller.state.savings.map((model.Saving s) => s.id), [
      'sav-source',
    ]);
  });
}
