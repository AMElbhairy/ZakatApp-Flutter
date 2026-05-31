import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/models/investment_asset.dart';
import 'package:zakatapp_flutter/models/saving.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

void main() {
  late AppStateRepository repository;
  late AppStateController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const LocalStorageService localStorage = LocalStorageService();
    repository = AppStateRepository(localStorage: localStorage);
    controller = AppStateController(repository: repository);
  });

  test('loading empty state returns default AppState', () async {
    await controller.load();

    expect(controller.state.transactions, isEmpty);
    expect(controller.state.savings, isEmpty);
    expect(controller.state.mainCurrency, 'EGP');
    expect(controller.state.zakatMethod, 'hawl');
    expect(controller.state.categories.income, isNotEmpty);
  });

  test('save/load roundtrip', () async {
    await controller.load();

    final Transaction tx = Transaction(
      id: 't1',
      type: 'income',
      date: '2024-01-01',
      amount: 1000,
      currency: 'EGP',
      category: 'Salary',
      description: 'Salary',
      createdAt: '2024-01-01T00:00:00.000Z',
      rolledOver: false,
    );

    await controller.addTransaction(tx);

    final AppStateController reloaded = AppStateController(repository: repository);
    await reloaded.load();

    expect(reloaded.state.transactions.length, 1);
    expect(reloaded.state.transactions.first.id, 't1');
  });

  test('add transaction persists', () async {
    await controller.load();

    await controller.addTransaction(
      const Transaction(
        id: 'tx1',
        type: 'expense',
        date: '2024-01-02',
        amount: 120,
        currency: 'EGP',
        category: 'Food & Dining',
        description: 'Lunch',
        createdAt: '2024-01-02T12:00:00.000Z',
        rolledOver: false,
      ),
    );

    final loaded = await repository.loadAppState();
    expect(loaded.transactions.length, 1);
    expect(loaded.transactions.first.category, 'Food & Dining');
  });

  test('add saving persists', () async {
    await controller.load();

    await controller.addSaving(
      const Saving(
        id: 's1',
        assetType: 'cash',
        dateAcquired: '2024-01-03',
        amount: 500,
        remainingAmount: 500,
        unit: 'EGP',
        description: 'Reserve',
        linkedCashEntryId: null,
        purchaseCurrency: '',
        purchaseAmount: 0,
        createdAt: '2024-01-03T00:00:00.000Z',
        sourceIncomeId: null,
        exchangeSourceSavingId: null,
        exchangeSourceIncomeId: null,
        internalTransfer: null,
        internalTransferType: null,
      ),
    );

    final loaded = await repository.loadAppState();
    expect(loaded.savings.length, 1);
    expect(loaded.savings.first.assetType, 'cash');
  });

  test('add investment persists', () async {
    await controller.load();

    await controller.addInvestment(
      const InvestmentAsset(
        id: 'i1',
        investmentType: 'real_estate',
        assetSubtype: 'apartment',
        ownershipType: 'fully_owned',
        valuationMode: 'net_fair',
        currency: 'EGP',
        originalPrice: 100000,
        totalInterest: 0,
        totalPayable: 100000,
        paidAmount: 100000,
        remainingAmount: 0,
        installmentPlan: <Map<String, dynamic>>[],
        valuationDate: '2024-01-01',
        marketValue: 120000,
        marketValueDate: '2024-01-01',
        valuationSource: 'manual',
        loanBalance: 0,
        loanAsOfDate: '2024-01-01',
        paidAmountToDate: 100000,
        ownershipSharePct: 100,
        country: 'EG',
        location: 'Cairo',
        inflationRateAnnual: 10,
        estimatedCurrentValue: 120000,
        description: 'Investment',
        noZakat: true,
        createdAt: '2024-01-01T00:00:00.000Z',
      ),
    );

    final loaded = await repository.loadAppState();
    expect(loaded.investments.length, 1);
    expect(loaded.investments.first.id, 'i1');
  });

  test('clearLocalData works', () async {
    await controller.load();

    await controller.addTransaction(
      const Transaction(
        id: 'tx_to_clear',
        type: 'income',
        date: '2024-01-04',
        amount: 100,
        currency: 'EGP',
        category: 'Salary',
        description: 'Temp',
        createdAt: '2024-01-04T00:00:00.000Z',
        rolledOver: false,
      ),
    );

    await controller.clearLocalData();
    final loaded = await repository.loadAppState();

    expect(loaded.transactions, isEmpty);
    expect(loaded.mainCurrency, 'EGP');
  });
}
