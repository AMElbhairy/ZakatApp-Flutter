import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/financial_plan.dart';
import 'package:zakatapp_flutter/models/investment_asset.dart';
import 'package:zakatapp_flutter/models/market_snapshot.dart';
import 'package:zakatapp_flutter/models/recurring_transaction.dart';
import 'package:zakatapp_flutter/models/saving.dart';
import 'package:zakatapp_flutter/models/transaction.dart';

import 'test_helpers.dart';

void main() {
  test('internal asset movements classify as transfer activities', () {
    const Transaction exchange = Transaction(
      id: 'exchange',
      type: 'expense',
      date: '2026-06-11',
      amount: 100,
      currency: 'USD',
      category: 'Currency Exchange',
      description: '',
      createdAt: '2026-06-11T00:00:00.000Z',
      rolledOver: false,
      activityType: 'transfer',
    );
    const Transaction food = Transaction(
      id: 'food',
      type: 'expense',
      date: '2026-06-11',
      amount: 10,
      currency: 'USD',
      category: 'Food',
      description: '',
      createdAt: '2026-06-11T00:00:00.000Z',
      rolledOver: false,
    );

    expect(exchange.isTransferActivity, isTrue);
    expect(Transaction.fromJson(exchange.toJson()).activityType, 'transfer');
    expect(food.isTransferActivity, isFalse);
  });

  final Map<String, dynamic> fixture = loadJsonFixture(
    'test/fixtures/sample_app_state.json',
  );

  test('transaction parsing', () {
    final tx = Transaction.fromJson(
      fixture['transactions'][0] as Map<String, dynamic>,
    );
    expect(tx.id, 'tx_income_1');
    expect(tx.amount, 10000);
    expect(tx.rolledOver, false);
    expect(tx.toJson()['currency'], 'EGP');
  });

  test('financial model currencies normalize for consistent summaries', () {
    final Transaction transaction = Transaction.fromJson(<String, dynamic>{
      'type': 'EXPENSE',
      'currency': ' usd ',
    });
    final Saving saving = Saving.fromJson(<String, dynamic>{
      'assetType': 'cash',
      'unit': ' eur ',
      'purchaseCurrency': ' gbp ',
    });
    final InvestmentAsset investment = InvestmentAsset.fromJson(
      <String, dynamic>{'currency': ' sar '},
    );
    final RecurringTransaction recurring = RecurringTransaction.fromJson(
      <String, dynamic>{'currency': ' aed '},
    );
    final FinancialPlan plan = FinancialPlan.fromJson(<String, dynamic>{
      'currency': ' kwd ',
    });

    expect(transaction.type, 'expense');
    expect(transaction.currency, 'USD');
    expect(saving.unit, 'EUR');
    expect(saving.purchaseCurrency, 'GBP');
    expect(investment.currency, 'SAR');
    expect(recurring.currency, 'AED');
    expect(plan.currency, 'KWD');
  });

  test('saving parsing', () {
    final saving = Saving.fromJson(
      fixture['savings'][0] as Map<String, dynamic>,
    );
    expect(saving.assetType, 'cash');
    expect(saving.remainingAmount, 4000);
    expect(saving.toJson()['unit'], 'EGP');
  });

  test('saving funding allocations roundtrip', () {
    final saving = Saving.fromJson(<String, dynamic>{
      'id': 'gold1',
      'assetType': 'gold',
      'dateAcquired': '2025-06-01',
      'amount': 10,
      'remainingAmount': 10,
      'unit': '24',
      'description': 'Gold',
      'purchaseCurrency': 'EGP',
      'purchaseAmount': 1000,
      'createdAt': '2025-06-01T00:00:00Z',
      'fundingAllocations': <Map<String, dynamic>>[
        <String, dynamic>{
          'sourceType': 'savings',
          'sourceId': 'cash1',
          'sourceDate': '2025-02-01',
          'currency': 'EGP',
          'amount': 1000,
        },
      ],
    });

    expect(saving.fundingAllocations.single['sourceId'], 'cash1');
    expect(
      (saving.toJson()['fundingAllocations'] as List).single['sourceDate'],
      '2025-02-01',
    );
  });

  test('investment parsing', () {
    final inv = InvestmentAsset.fromJson(
      fixture['investments'][0] as Map<String, dynamic>,
    );
    expect(inv.investmentType, 'real_estate');
    expect(inv.marketValue, 1200000);
    expect(inv.toJson()['ownershipType'], 'fully_owned');
  });

  test('recurring transaction parsing', () {
    final rt = RecurringTransaction.fromJson(
      fixture['recurringTransactions'][0] as Map<String, dynamic>,
    );
    expect(rt.name, 'Rent');
    expect(rt.dayOfMonth, 5);
    expect(rt.toJson()['enabled'], true);
  });

  test('financial plan parsing', () {
    final plan = FinancialPlan.fromJson(
      fixture['financialPlans'][0] as Map<String, dynamic>,
    );
    expect(plan.name, 'Base plan');
    expect(plan.durationYears, 2);
    expect(plan.toJson()['includeZakat'], true);
  });

  test('app state parsing', () {
    final appState = AppStateModel.fromJson(fixture);
    expect(appState.transactions.length, 2);
    expect(appState.savings.length, 3);
    expect(appState.investments.length, 1);
    expect(appState.financialPlans.length, 1);
    expect(appState.categories.income, isNotEmpty);
    expect(appState.syncHealth.pendingWrites, 0);
  });

  test('model fromJson/toJson roundtrip', () {
    final appState = AppStateModel.fromJson(fixture);
    final roundtrip = AppStateModel.fromJson(appState.toJson());

    expect(roundtrip.transactions.length, appState.transactions.length);
    expect(roundtrip.savings.length, appState.savings.length);
    expect(roundtrip.mainCurrency, appState.mainCurrency);
    expect(roundtrip.zakatMethod, appState.zakatMethod);
    expect(roundtrip.zakatAnnualDate, appState.zakatAnnualDate);
    expect(roundtrip.zakatNisabBasis, appState.zakatNisabBasis);
  });

  test('market snapshot fromJson/toJson', () {
    final Map<String, dynamic> json = <String, dynamic>{
      'gold24kPricePerGramEgp': 5200,
      'silverPricePerGramEgp': 62.5,
      'usdToEgp': 50,
      'sarToEgp': 13.3,
      'aedToEgp': 13.6,
      'kwdToEgp': 162.5,
      'qarToEgp': 13.7,
      'eurToEgp': 55,
      'gbpToEgp': 64,
      'bhdToEgp': 130,
      'omrToEgp': 128,
      'jodToEgp': 70,
      'tryToEgp': 1.4,
      'myrToEgp': 11,
      'pkrToEgp': 0.18,
      'idrToEgp': 0.0031,
      'lastUpdated': '2026-05-31T09:00:00Z',
    };

    final MarketSnapshot snapshot = MarketSnapshot.fromJson(json);
    final Map<String, dynamic> out = snapshot.toJson();

    expect(out['gold24kPricePerGramEgp'], 5200);
    expect(out['silverPricePerGramEgp'], 62.5);
    expect(out['usdToEgp'], 50);
    expect(out['eurToEgp'], 55);
    expect(out['idrToEgp'], 0.0031);
    expect(out['lastUpdated'], '2026-05-31T09:00:00Z');
  });

  test('market snapshot missing fields falls back safely', () {
    final MarketSnapshot snapshot = MarketSnapshot.fromJson(<String, dynamic>{
      'gold24kPricePerGramEgp': 5100,
    });

    expect(snapshot.gold24kPricePerGramEgp, 5100);
    expect(snapshot.silverPricePerGramEgp, 0);
    expect(snapshot.usdToEgp, 0);
    expect(snapshot.lastUpdated, '');
  });

  test('old formatted lastUpdated value remains safe', () {
    final MarketSnapshot snapshot = MarketSnapshot.fromJson(<String, dynamic>{
      'lastUpdated': '2026-05-31 10:45',
    });
    expect(snapshot.lastUpdated, '2026-05-31 10:45');
  });

  test('market snapshot invalid field types do not throw', () {
    final MarketSnapshot snapshot = MarketSnapshot.fromJson(<String, dynamic>{
      'gold24kPricePerGramEgp': 'bad',
      'silverPricePerGramEgp': <String>['x'],
      'usdToEgp': null,
      'lastUpdated': 12345,
    });

    expect(snapshot.gold24kPricePerGramEgp, 0);
    expect(snapshot.silverPricePerGramEgp, 0);
    expect(snapshot.usdToEgp, 0);
    expect(snapshot.lastUpdated, '12345');
  });
}
