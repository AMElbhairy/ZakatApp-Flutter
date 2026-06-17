import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/core/services/zakat_engine.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/saving.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/services/legacy_backup_migration_service.dart';

import 'test_helpers.dart';

void main() {
  final fixture = loadJsonFixture('test/fixtures/sample_app_state.json');
  final marketFixture = loadJsonFixture('test/fixtures/market_data.json');

  final appState = AppStateModel.fromJson(fixture);
  final marketData = MarketData.fromJson(marketFixture);

  test('currency conversion', () {
    expect(ZakatEngineService.convertToEgp(100, 'EGP', marketData), 100);
    expect(ZakatEngineService.convertToEgp(2, 'USD', marketData), 100);
    expect(
      ZakatEngineService.convertToEgp(10, 'SAR', marketData),
      closeTo(135, 1e-9),
    );
    expect(ZakatEngineService.convertToEgp(1, 'EUR', marketData), 55);
    expect(
      ZakatEngineService.convertFromEgp(100, 'USD', marketData),
      closeTo(2, 1e-9),
    );
  });

  test('EGP conversion works without FX', () {
    final MarketData emptyMarket = MarketData.fromJson(
      const <String, dynamic>{},
    );
    expect(ZakatEngineService.convertToEgp(42, 'EGP', emptyMarket), 42);
  });

  test('non-EGP missing rate does not silently equal amount', () {
    final MarketData emptyMarket = MarketData.fromJson(
      const <String, dynamic>{},
    );
    final double converted = ZakatEngineService.convertToEgp(
      10,
      'USD',
      emptyMarket,
    );
    expect(converted.isNaN, isTrue);
    expect(ZakatEngineService.tryConvertToEgp(10, 'USD', emptyMarket), isNull);
  });

  test('missing USD/SAR/AED/KWD/QAR rates are unavailable', () {
    final MarketData emptyMarket = MarketData.fromJson(
      const <String, dynamic>{},
    );
    for (final String c in <String>['USD', 'SAR', 'AED', 'KWD', 'QAR']) {
      expect(
        ZakatEngineService.isCurrencyConversionAvailable(c, emptyMarket),
        isFalse,
      );
      expect(ZakatEngineService.tryConvertToEgp(10, c, emptyMarket), isNull);
      expect(ZakatEngineService.convertToEgp(10, c, emptyMarket).isNaN, isTrue);
    }
  });

  test('nisab calculation', () {
    final totals = ZakatEngineService.computeNisabTotals(
      savings: appState.savings,
      marketData: marketData,
    );

    expect(totals.totalCashEgp, 4000);
    expect(totals.totalGold24k, 10);
    expect(totals.totalGoldEgp, 30000);
    expect(totals.totalSilverGrams, 200);
    expect(totals.totalSilverEgp, 8000);
    expect(totals.totalSavingsWealthEgp, 42000);
  });

  test('cash nisab basis can use gold or silver threshold', () {
    final double goldThreshold = ZakatEngineService.cashNisabThresholdEgp(
      marketData,
      zakatNisabBasis: ZakatEngineService.nisabBasisGold85,
    );
    final double silverThreshold = ZakatEngineService.cashNisabThresholdEgp(
      marketData,
      zakatNisabBasis: ZakatEngineService.nisabBasisSilver595,
    );

    expect(goldThreshold, 85 * marketData.goldPrice24kEgp);
    expect(silverThreshold, 595 * marketData.silverPriceEgp);

    final double amountBetweenThresholds =
        (goldThreshold + silverThreshold) / 2;
    expect(
      ZakatEngineService.checkCashNisab(
        amountBetweenThresholds,
        marketData,
        zakatNisabBasis: ZakatEngineService.nisabBasisGold85,
      ),
      isFalse,
    );
    expect(
      ZakatEngineService.checkCashNisab(
        amountBetweenThresholds,
        marketData,
        zakatNisabBasis: ZakatEngineService.nisabBasisSilver595,
      ),
      isTrue,
    );
  });

  test('cash zakat calculation', () {
    expect(ZakatEngineService.calculateCashZakat(1000), 25);
  });

  test('gold/silver zakat calculation', () {
    expect(ZakatEngineService.calculateGoldZakat(100), 2.5);

    final silverSaving = appState.savings.firstWhere(
      (s) => s.assetType == 'silver',
    );
    final status = ZakatEngineService.evaluateSavingStatus(
      saving: silverSaving,
      savings: appState.savings,
      marketData: marketData,
    );
    expect(status.zakatDue, greaterThanOrEqualTo(0));
  });

  test('investment type normalization matches old app semantics', () {
    expect(
      ZakatEngineService.normaliseInvestmentType('real_estate'),
      'real_estate',
    );
    expect(
      ZakatEngineService.normaliseInvestmentType('property'),
      'real_estate',
    );
    expect(
      ZakatEngineService.normaliseInvestmentType('company_investment'),
      'company_investment',
    );
    expect(
      ZakatEngineService.normaliseInvestmentType('company_share'),
      'company_investment',
    );

    expect(ZakatEngineService.isCompanyInvestmentType('company_share'), isTrue);
    expect(
      ZakatEngineService.isCompanyInvestmentType('company_investment'),
      isTrue,
    );
    expect(ZakatEngineService.isCompanyInvestmentType('real_estate'), isFalse);
  });

  test('total wealth calculation', () {
    final wealth = ZakatEngineService.calculateTotalWealthEgp(
      transactions: appState.transactions,
      savings: appState.savings,
      investments: appState.investments,
      marketData: marketData,
    );

    expect(wealth, closeTo(1251500, 1e-6));
  });

  test(
    'cash summaries include every rate-backed currency and normalize codes',
    () {
      final MarketData market = MarketData.fromJson(<String, dynamic>{
        'RATES_TO_EGP': <String, dynamic>{'EGP': 1, 'EUR': 55, 'CHF': 60},
      });
      final List<Transaction> transactions = <Transaction>[
        const Transaction(
          id: 'eur-income',
          type: 'income',
          date: '2026-06-01',
          amount: 10,
          currency: 'eur',
          category: 'Salary',
          description: '',
          createdAt: '2026-06-01T00:00:00.000Z',
          rolledOver: false,
        ),
        const Transaction(
          id: 'eur-expense',
          type: 'expense',
          date: '2026-06-02',
          amount: 2,
          currency: 'EUR',
          category: 'Food',
          description: '',
          createdAt: '2026-06-02T00:00:00.000Z',
          rolledOver: false,
        ),
        const Transaction(
          id: 'chf-income',
          type: 'income',
          date: '2026-06-01',
          amount: 3,
          currency: 'chf',
          category: 'Salary',
          description: '',
          createdAt: '2026-06-01T00:00:01.000Z',
          rolledOver: false,
        ),
      ];

      final Map<String, double> cash =
          ZakatEngineService.calculateCashByCurrency(
            transactions: transactions,
            savings: const [],
            marketData: market,
          );

      expect(cash['EUR'], 8);
      expect(cash['CHF'], 3);
      expect(
        ZakatEngineService.calculateTotalCashWealthEgp(
          transactions: transactions,
          savings: const [],
          marketData: market,
        ),
        620,
      );
    },
  );

  test('foreign currency overdrafts update liabilities and net worth', () {
    final List<Transaction> transactions = <Transaction>[
      const Transaction(
        id: 'egp-income',
        type: 'income',
        date: '2026-06-01',
        amount: 100,
        currency: 'EGP',
        category: 'Salary',
        description: '',
        createdAt: '2026-06-01T00:00:00.000Z',
        rolledOver: false,
      ),
      const Transaction(
        id: 'usd-expense',
        type: 'expense',
        date: '2026-06-02',
        amount: 10,
        currency: 'USD',
        category: 'Food',
        description: 'AI or normal expense',
        createdAt: '2026-06-02T00:00:00.000Z',
        rolledOver: false,
      ),
    ];

    final double assets = ZakatEngineService.calculateTotalAssetsEgp(
      transactions: transactions,
      savings: const [],
      investments: const [],
      marketData: marketData,
    );
    final double liabilities = ZakatEngineService.calculateTotalLiabilitiesEgp(
      transactions: transactions,
      savings: const [],
      investments: const [],
      marketData: marketData,
    );
    final double netWorth = ZakatEngineService.calculateNetWorthEgp(
      transactions: transactions,
      savings: const [],
      investments: const [],
      marketData: marketData,
    );

    expect(assets, 100);
    expect(liabilities, 500);
    expect(netWorth, -400);
  });

  test('expenses reduce reconciled cash savings in every currency', () {
    const List<Transaction> transactions = <Transaction>[
      Transaction(
        id: 'egp-expense',
        type: 'expense',
        date: '2026-06-02',
        amount: 20,
        currency: 'EGP',
        category: 'Food',
        description: '',
        createdAt: '2026-06-02T00:00:00.000Z',
        rolledOver: false,
      ),
      Transaction(
        id: 'usd-expense',
        type: 'expense',
        date: '2026-06-02',
        amount: 2,
        currency: 'USD',
        category: 'Food',
        description: '',
        createdAt: '2026-06-02T00:00:01.000Z',
        rolledOver: false,
      ),
      Transaction(
        id: 'sar-expense',
        type: 'expense',
        date: '2026-06-02',
        amount: 3,
        currency: 'SAR',
        category: 'Food',
        description: '',
        createdAt: '2026-06-02T00:00:02.000Z',
        rolledOver: false,
      ),
    ];
    const List<Saving> savings = <Saving>[
      Saving(
        id: 'egp-cash',
        assetType: 'cash',
        dateAcquired: '2026-06-01',
        amount: 100,
        remainingAmount: 80,
        unit: 'EGP',
        description: '',
        purchaseCurrency: '',
        purchaseAmount: 0,
        createdAt: '2026-06-01T00:00:00.000Z',
      ),
      Saving(
        id: 'usd-cash',
        assetType: 'cash',
        dateAcquired: '2026-06-01',
        amount: 10,
        remainingAmount: 8,
        unit: 'USD',
        description: '',
        purchaseCurrency: '',
        purchaseAmount: 0,
        createdAt: '2026-06-01T00:00:01.000Z',
      ),
      Saving(
        id: 'sar-cash',
        assetType: 'cash',
        dateAcquired: '2026-06-01',
        amount: 20,
        remainingAmount: 17,
        unit: 'SAR',
        description: '',
        purchaseCurrency: '',
        purchaseAmount: 0,
        createdAt: '2026-06-01T00:00:02.000Z',
      ),
    ];

    final Map<String, double> cash = ZakatEngineService.calculateCashByCurrency(
      transactions: transactions,
      savings: savings,
      marketData: marketData,
    );

    expect(cash['EGP'], 80);
    expect(cash['USD'], 8);
    expect(cash['SAR'], 17);
    expect(
      ZakatEngineService.calculateTotalLiabilitiesEgp(
        transactions: transactions,
        savings: savings,
        investments: const [],
        marketData: marketData,
      ),
      0,
    );
  });

  test(
    'cash statement reflects savings, income, and expenses exactly once',
    () {
      const List<Transaction> transactions = <Transaction>[
        Transaction(
          id: 'expense',
          type: 'expense',
          date: '2026-06-01',
          amount: 20,
          currency: 'EGP',
          category: 'Food',
          description: '',
          createdAt: '2026-06-01T00:00:00.000Z',
          rolledOver: false,
        ),
        Transaction(
          id: 'income',
          type: 'income',
          date: '2026-06-02',
          amount: 50,
          currency: 'EGP',
          category: 'Salary',
          description: '',
          createdAt: '2026-06-02T00:00:00.000Z',
          rolledOver: false,
        ),
      ];
      const List<Saving> savings = <Saving>[
        Saving(
          id: 'cash-saving',
          assetType: 'cash',
          dateAcquired: '2026-05-31',
          amount: 100,
          remainingAmount: 80,
          unit: 'EGP',
          description: '',
          purchaseCurrency: '',
          purchaseAmount: 0,
          createdAt: '2026-05-31T00:00:00.000Z',
        ),
      ];

      final Map<String, double> cash =
          ZakatEngineService.calculateCashByCurrency(
            transactions: transactions,
            savings: savings,
            marketData: marketData,
          );

      expect(cash['EGP'], 130);
    },
  );

  test('legacy backup cash by currency does not double count derived cash', () {
    final File backup = File(
      '/Users/ahmedelbhairy/Downloads/zakatapp-backup-2026-06-04.json',
    );
    if (!backup.existsSync()) {
      markTestSkipped('Attached legacy backup is not available locally.');
      return;
    }

    final Map<String, dynamic> migrated = LegacyBackupMigrationService()
        .parseAndMigrate(backup.readAsStringSync());
    final AppStateModel legacyState = AppStateModel.fromJson(migrated);
    final MarketData legacyMarket = MarketData.fromJson(legacyState.marketData);

    final Map<String, double> cashByCurrency =
        ZakatEngineService.calculateCashByCurrency(
          transactions: legacyState.transactions,
          savings: legacyState.savings,
          marketData: legacyMarket,
          lastRollover: legacyState.lastRollover,
        );

    expect(cashByCurrency['EGP'], closeTo(5131.33, 0.01));
    expect(cashByCurrency['USD'], closeTo(11500.00, 0.01));
    expect(cashByCurrency['SAR'], closeTo(59318.05, 0.01));
    expect(cashByCurrency['SAR'], isNot(closeTo(80629.84, 0.01)));
  });

  test('Hijri date conversion examples', () {
    final h = ZakatEngineService.gregorianToHijri(DateTime(2026, 5, 31));
    expect(h.month, inInclusiveRange(1, 12));
    expect(h.day, inInclusiveRange(1, 30));

    final g = ZakatEngineService.hijriToGregorian(h.year, h.month, h.day);
    expect(g.year, greaterThan(1900));
    expect(g.month, inInclusiveRange(1, 12));
    expect(g.day, inInclusiveRange(1, 31));

    expect(ZakatEngineService.hijriMonthLength(1), 30);
    expect(ZakatEngineService.hijriMonthLength(2), 29);
  });
}
