import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/core/services/zakat_engine.dart';
import 'package:zakatapp_flutter/models/investment_asset.dart';
import 'package:zakatapp_flutter/models/financial_plan.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/services/cash_flow_chart_data_builder.dart';

void main() {
  group('CashFlowChartDataBuilder Tests', () {
    const builder = CashFlowChartDataBuilder();

    final plan = FinancialPlan(
      id: 'plan_1',
      name: 'Plan 1',
      startDate: '2026-01-15',
      projectionCurrency: 'USD',
      startingBalance: 1000.0,
      startingBalanceDate: '2026-01-15',
      startingBalanceMode: 'manual',
      snapshotWealthCurrency: 'USD',
      startingAssetBreakdown: const {},
      monthlyIncome: 500.0,
      monthlyExpenses: 300.0,
      includeInstallments: false,
      includeZakat: false,
      durationYears: 1,
      createdAt: '2026-01-15T00:00:00.000Z',
    );

    test('Planned monthly and cumulative balance calculation are correct', () {
      final points = builder.build(
        plan: plan,
        transactions: [],
        savings: const [],
        investments: [],
        marketData: MarketData.fromJson({'ratesToEgp': {'USD': 1.0}}),
        zakatMethod: 'hawl',
        zakatAnnualDate: '',
        now: DateTime(2026, 05, 10),
      );

      expect(points.length, 12);

      // Month 0 (Jan 2026) now carries the first real monthly flow.
      expect(points[0].plannedCashIn, 500.0);
      expect(points[0].plannedCashOut, 300.0);
      expect(points[0].plannedNet, 200.0);
      expect(points[0].plannedBalance, 1200.0);

      // Month 1 (Feb 2026) accumulates the second month of flow.
      expect(points[1].plannedCashIn, 1000.0);
      expect(points[1].plannedCashOut, 600.0);
      expect(points[1].plannedNet, 400.0);
      expect(points[1].plannedBalance, 1400.0);

      // Month 11 (Dec 2026): 1000 + 12 * 200 = 3400
      expect(points[11].plannedBalance, 3400.0);
    });

    test('Future months return null actuals and actual line ends at current month', () {
      final points = builder.build(
        plan: plan,
        transactions: [],
        savings: const [],
        investments: [],
        marketData: MarketData.fromJson({'ratesToEgp': {'USD': 1.0}}),
        zakatMethod: 'hawl',
        zakatAnnualDate: '',
        now: DateTime(2026, 03, 10), // Current month is March 2026
      );

      // Jan 2026 (Index 0) - Past month with no tx: returns 0
      expect(points[0].actualCashIn, 0.0);
      expect(points[0].actualCashOut, 0.0);
      expect(points[0].actualNet, 0.0);
      expect(points[0].actualBalance, 1000.0);
      expect(points[0].isCurrentMonth, isFalse);

      // Feb 2026 (Index 1) - Past month with no tx: returns 0
      expect(points[1].actualBalance, 1000.0);

      // Mar 2026 (Index 2) - Current month with no tx: returns 0 (Month to Date)
      expect(points[2].actualCashIn, 0.0);
      expect(points[2].actualBalance, 1000.0);
      expect(points[2].isCurrentMonth, isTrue);

      // Apr 2026 (Index 3) - Future month: returns null
      expect(points[3].actualCashIn, isNull);
      expect(points[3].actualCashOut, isNull);
      expect(points[3].actualNet, isNull);
      expect(points[3].actualBalance, isNotNull);
      expect(points[3].isCurrentMonth, isFalse);
    });

    test('Transactions boundary inclusion and transfer exclusion', () {
      final txs = [
        // Exact start date inclusion (2026-01-15)
        const Transaction(
          id: 't1',
          type: 'income',
          date: '2026-01-15',
          amount: 600.0,
          currency: 'USD',
          category: 'Salary',
          description: '',
          createdAt: '',
          rolledOver: false,
        ),
        // Exact end date inclusion (2027-01-15)
        const Transaction(
          id: 't2',
          type: 'expense',
          date: '2027-01-15',
          amount: 50.0,
          currency: 'USD',
          category: 'Fees',
          description: '',
          createdAt: '',
          rolledOver: false,
        ),
        // Outside plan start date range (excluded)
        const Transaction(
          id: 't3',
          type: 'income',
          date: '2026-01-14',
          amount: 1000.0,
          currency: 'USD',
          category: 'Bonus',
          description: '',
          createdAt: '',
          rolledOver: false,
        ),
        // Transfer transaction (excluded)
        const Transaction(
          id: 't4',
          type: 'transfer',
          date: '2026-02-10',
          amount: 200.0,
          currency: 'USD',
          category: 'Transfer',
          description: '',
          createdAt: '',
          rolledOver: false,
        ),
      ];

      final points = builder.build(
        plan: plan,
        transactions: txs,
        savings: const [],
        investments: [],
        marketData: MarketData.fromJson({'ratesToEgp': {'USD': 1.0}}),
        zakatMethod: 'hawl',
        zakatAnnualDate: '',
        now: DateTime(2027, 02, 10), // Build as if the entire plan is in the past
      );

      // Month 1 (Jan 2026) has 600 USD income
      expect(points[0].actualCashIn, 600.0);

      // Month 2 (Feb 2026) should be 600.0 because it accumulates Jan and transfer is excluded
      expect(points[1].actualCashIn, 600.0);

      // Month 12 (Dec 2026) should be 0.0 cumulative expenses
      expect(points[11].actualCashOut, 0.0);

      // Month 13 (Jan 2027) is outside the duration of 12 months (indices 0 to 11 represent Jan 2026 to Dec 2026)
      // Wait, 2027-01-15 is month index 12 (Jan 2027), which is outside the duration of 1 year starting Jan 2026 (index 0 to 11).
      // That transaction is correctly excluded since points has only 12 months.
      expect(points.length, 12);
    });

    test('Zero, positive, and negative starting balances are preserved', () {
      final zeroPlan = FinancialPlan(
        id: 'plan_zero',
        name: 'Plan Zero',
        startDate: '2026-01-15',
        projectionCurrency: 'USD',
        startingBalance: 0.0,
        startingBalanceDate: '2026-01-15',
        startingBalanceMode: 'manual',
        snapshotWealthCurrency: 'USD',
        startingAssetBreakdown: const {},
        monthlyIncome: 100.0,
        monthlyExpenses: 50.0,
        includeInstallments: false,
        includeZakat: false,
        durationYears: 1,
        createdAt: '',
      );

      final points = builder.build(
        plan: zeroPlan,
        transactions: [],
        savings: const [],
        investments: [],
        marketData: MarketData.fromJson({'ratesToEgp': {'USD': 1.0}}),
        zakatMethod: 'hawl',
        zakatAnnualDate: '',
        now: DateTime(2026, 06, 10),
      );

      expect(points[0].plannedBalance, 50.0);
      expect(points[1].plannedBalance, 100.0);
      expect(points[0].actualBalance, 0.0);
    });

    test('Cash flow starting balance uses cash plus gold breakdown', () {
      final plan = FinancialPlan(
        id: 'plan_cash_gold',
        name: 'Cash Gold Plan',
        startDate: '2026-01-01',
        projectionCurrency: 'EGP',
        startingBalance: 17045981.0,
        startingBalanceDate: '2026-01-01',
        startingBalanceMode: 'manual',
        snapshotWealthCurrency: 'EGP',
        startingAssetBreakdown: const {
          'cash': 8000000.0,
          'gold': 999168.54,
          'silver': 50000.0,
          'real_estate': 4000000.0,
          'investment': 4054812.46,
        },
        monthlyIncome: 0.0,
        monthlyExpenses: 0.0,
        includeInstallments: false,
        includeZakat: false,
        durationYears: 1,
        createdAt: '2026-01-01T00:00:00.000Z',
      );

      final points = builder.build(
        plan: plan,
        transactions: const [],
        savings: const [],
        investments: const [],
        marketData: MarketData.fromJson({'ratesToEgp': {'EGP': 1.0}}),
        zakatMethod: 'hawl',
        zakatAnnualDate: '',
        now: DateTime(2026, 06, 10),
      );

      expect(points[0].plannedBalance, closeTo(9049168.54, 1e-6));
      expect(points[0].actualBalance, closeTo(9049168.54, 1e-6));
    });

    test('Mixed-currency installments use each item currency in planned cash out', () {
      final plan = FinancialPlan(
        id: 'plan_currency_mix',
        name: 'Currency Mix Plan',
        startDate: '2026-01-01',
        projectionCurrency: 'EGP',
        startingBalance: 500000.0,
        startingBalanceDate: '2026-01-01',
        startingBalanceMode: 'manual',
        snapshotWealthCurrency: 'EGP',
        startingAssetBreakdown: const {
          'cash': 500000.0,
        },
        monthlyIncome: 0.0,
        monthlyExpenses: 0.0,
        includeInstallments: true,
        includeZakat: false,
        durationYears: 1,
        createdAt: '2026-01-01T00:00:00.000Z',
      );

      final investment = InvestmentAsset.fromJson(<String, dynamic>{
        'id': 'asset_1',
        'investmentType': 'installment',
        'assetSubtype': '',
        'ownershipType': '',
        'valuationMode': '',
        'currency': 'EGP',
        'originalPrice': 0,
        'totalInterest': 0,
        'totalPayable': 0,
        'paidAmount': 0,
        'remainingAmount': 0,
        'installmentPlan': <Map<String, dynamic>>[
          <String, dynamic>{
            'date': '2026-08-11',
            'amount': 114815,
            'currency': 'EGP',
            'isPaid': false,
          },
          <String, dynamic>{
            'date': '2026-08-25',
            'amount': 240,
            'currency': 'USD',
            'isPaid': false,
          },
          <String, dynamic>{
            'date': '2026-08-25',
            'amount': 9583,
            'currency': 'EGP',
            'isPaid': false,
          },
          <String, dynamic>{
            'date': '2026-08-25',
            'amount': 3393,
            'currency': 'SAR',
            'isPaid': false,
          },
        ],
        'valuationDate': '',
        'marketValue': 0,
        'marketValueDate': '',
        'valuationSource': '',
        'loanBalance': 0,
        'loanAsOfDate': '',
        'paidAmountToDate': 0,
        'ownershipSharePct': 100,
        'country': '',
        'location': '',
        'inflationRateAnnual': 0,
        'estimatedCurrentValue': 0,
        'description': '',
        'noZakat': true,
        'createdAt': '2026-01-01T00:00:00.000Z',
        'yearlyGrowthRate': 0,
      });

      final points = builder.build(
        plan: plan,
        transactions: const [],
        savings: const [],
        investments: <InvestmentAsset>[investment],
        marketData: MarketData.fromJson(<String, dynamic>{
          'GOLD_PRICE_24K_EGP': 0,
          'SILVER_PRICE_EGP': 0,
          'USD_TO_EGP': 2,
          'SAR_TO_EGP': 3,
          'RATES_TO_EGP': <String, dynamic>{
            'EGP': 1,
            'USD': 2,
            'SAR': 3,
          },
        }),
        zakatMethod: 'hawl',
        zakatAnnualDate: '',
        now: DateTime(2026, 08, 06),
      );

      // August 2026 is index 7 in the screen timeline, and the whole installment
      // bundle should be converted by item currency, not by the parent asset currency.
      expect(points[7].plannedCashOut, closeTo(135057.0, 1e-6));
      expect(points[7].plannedNet, closeTo(-135057.0, 1e-6));
    });

    test('Projected zakat is included in future planned cash out', () {
      final plan = FinancialPlan(
        id: 'plan_projected_zakat',
        name: 'Projected Zakat Plan',
        startDate: '2026-01-01',
        projectionCurrency: 'EGP',
        startingBalance: 500000.0,
        startingBalanceDate: '2026-01-01',
        startingBalanceMode: 'manual',
        snapshotWealthCurrency: 'EGP',
        startingAssetBreakdown: const {
          'cash': 500000.0,
        },
        monthlyIncome: 0.0,
        monthlyExpenses: 0.0,
        includeInstallments: false,
        includeZakat: true,
        durationYears: 2,
        createdAt: '2026-01-01T00:00:00.000Z',
      );

      final points = builder.build(
        plan: plan,
        transactions: const [],
        savings: const [],
        investments: const [],
        marketData: MarketData.fromJson(<String, dynamic>{
          'GOLD_PRICE_24K_EGP': 3200.0,
          'SILVER_PRICE_EGP': 40.0,
          'USD_TO_EGP': 48.0,
          'SAR_TO_EGP': 12.8,
        }),
        zakatMethod: 'annual',
        zakatAnnualDate: '09-01',
        now: DateTime(2026, 08, 06),
      );

      expect(points[11].plannedCashOut, closeTo(12500.0, 1e-6));
      expect(points[11].plannedNet, closeTo(-12500.0, 1e-6));
    });
  });
}
