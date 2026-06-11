import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/core/services/zakat_engine.dart';
import 'package:zakatapp_flutter/models/saving.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/reconciliation_service.dart';

void main() {
  Future<AppStateController> makeController() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const localStorage = LocalStorageService();
    final repository = AppStateRepository(localStorage: localStorage);
    final controller = AppStateController(repository: repository);
    await controller.load();
    return controller;
  }

  test('controller toggleZakatPaid persists expense transaction', () async {
    final controller = await makeController();
    await controller.toggleZakatPaid(
      monthKey: '2026-06',
      zakatAmountMainCurrency: 123,
      paymentDate: '2026-06-01',
    );
    expect(controller.state.zakatPaidMonths, contains('2026-06'));
    expect(
      controller.state.transactions.any((t) => t.category == 'Zakat'),
      isTrue,
    );
  });

  test('controller executeCurrencyExchange creates linked records', () async {
    final controller = await makeController();
    await controller.addTransaction(
      const Transaction(
        id: 'income-1',
        type: 'income',
        date: '2026-06-01',
        amount: 100,
        currency: 'USD',
        category: 'Salary',
        description: '',
        createdAt: '2026-06-01T00:00:00.000Z',
        rolledOver: false,
      ),
    );
    await controller.executeCurrencyExchange(
      date: '2026-06-01',
      sourceCurrency: 'USD',
      targetCurrency: 'EGP',
      sourceAmount: 50,
      targetAmount: 2500,
    );
    final exchanged = controller.state.transactions
        .where((t) => t.exchangePairId != null)
        .toList();
    expect(exchanged.length, 2);
  });

  test('controller adds scanned transactions in one persisted batch', () async {
    final controller = await makeController();
    await controller.addTransactions(<Transaction>[
      const Transaction(
        id: 'scan-1',
        type: 'expense',
        date: '2026-06-01',
        amount: 10,
        currency: 'EGP',
        category: 'Food & Dining',
        description: 'First scanned item',
        createdAt: '2026-06-01T00:00:00.000Z',
        rolledOver: false,
      ),
      const Transaction(
        id: 'scan-2',
        type: 'expense',
        date: '2026-06-01',
        amount: 20,
        currency: 'EGP',
        category: 'Food & Dining',
        description: 'Second scanned item',
        createdAt: '2026-06-01T00:00:01.000Z',
        rolledOver: false,
      ),
    ]);

    expect(
      controller.state.transactions.map((Transaction tx) => tx.id),
      containsAll(<String>['scan-1', 'scan-2']),
    );
  });

  test('controller expense deducts post-rollover cash saving', () async {
    final controller = await makeController();
    await controller.updateState(
      controller.state.copyWith(lastRollover: '2026-05-31'),
    );
    await controller.addSaving(
      const Saving(
        id: 'saving-1',
        assetType: 'cash',
        dateAcquired: '2026-05-01',
        amount: 100,
        remainingAmount: 100,
        unit: 'EGP',
        description: '',
        purchaseCurrency: '',
        purchaseAmount: 0,
        createdAt: '2026-05-01T00:00:00.000Z',
      ),
    );
    await controller.addTransaction(
      const Transaction(
        id: 'expense-1',
        type: 'expense',
        date: '2026-06-02',
        amount: 20,
        currency: 'EGP',
        category: 'Food & Dining',
        description: '',
        createdAt: '2026-06-02T00:00:00.000Z',
        rolledOver: false,
      ),
    );

    expect(controller.state.savings.single.remainingAmount, 80);
    expect(
      ZakatEngineService.calculateCashByCurrency(
        transactions: controller.state.transactions,
        savings: controller.state.savings,
        marketData: MarketData.fromJson(controller.state.marketData),
        lastRollover: controller.state.lastRollover,
      )['EGP'],
      80,
    );
  });

  test(
    'exchange, assets, and cash details use the same cash balance',
    () async {
      final controller = await makeController();
      await controller.addSaving(
        const Saving(
          id: 'legacy-cash',
          assetType: 'cash',
          dateAcquired: '2025-01-01',
          amount: 75,
          remainingAmount: 75,
          unit: 'USD',
          description: 'Legacy cash',
          purchaseCurrency: '',
          purchaseAmount: 0,
          createdAt: '2025-01-01T00:00:00.000Z',
          sourceIncomeId: 'legacy-income',
        ),
      );
      await controller.addTransaction(
        const Transaction(
          id: 'income-1',
          type: 'income',
          date: '2026-01-01',
          amount: 100,
          currency: 'USD',
          category: 'Salary',
          description: '',
          createdAt: '2026-01-01T00:00:00.000Z',
          rolledOver: false,
        ),
      );

      final double exchangeBalance = controller.getAvailableBalance(
        currency: 'USD',
      );
      final double assetsBalance = controller.cashByCurrency['USD'] ?? 0;
      final double cashDetailsBalance =
          ZakatEngineService.calculateCashByCurrency(
            transactions: controller.state.transactions,
            savings: controller.state.savings,
            marketData: MarketData.fromJson(controller.state.marketData),
            lastRollover: controller.state.lastRollover,
          )['USD'] ??
          0;

      expect(exchangeBalance, assetsBalance);
      expect(exchangeBalance, cashDetailsBalance);
      expect(exchangeBalance, 175);
      expect(
        controller
            .getAvailableCashSources(currency: 'USD')
            .map((CashSource source) => source.id),
        containsAll(<String>['legacy-cash', 'income-1']),
      );
    },
  );
}
