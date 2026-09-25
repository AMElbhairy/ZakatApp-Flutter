import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/core/services/zakat_engine.dart';
import 'package:zakatapp_flutter/models/credit_card.dart';
import 'package:zakatapp_flutter/models/saving.dart';
import 'package:zakatapp_flutter/screens/dashboard/dashboard_screen.dart';

void main() {
  group('Net Worth number formatting unit tests', () {
    test('Compact notation removes unnecessary trailing zeros', () {
      // 21.40M -> 21.4M
      expect(ZakatEngineService.formatCompactNumber(21400000), '21.4M');
      // 21.00M -> 21M
      expect(ZakatEngineService.formatCompactNumber(21000000), '21M');
      // 21.45M -> 21.45M
      expect(ZakatEngineService.formatCompactNumber(21449381.72), '21.45M');
    });

    test('Full currency values remove .00 and preserve meaningful fractional currency values', () {
      // 850,000 -> E£ 850,000 (.00 removed)
      expect(
        ZakatEngineService.formatCurrency(850000, 'EGP', trimZeroCents: true),
        '\u200EE£ 850,000',
      );
      // 1,000,000 -> E£ 1,000,000 (.00 removed)
      expect(
        ZakatEngineService.formatCurrency(1000000, 'EGP', trimZeroCents: true),
        '\u200EE£ 1,000,000',
      );
      // 2,049,918.90 -> E£ 2,049,918.90 (preserves .90)
      expect(
        ZakatEngineService.formatCurrency(2049918.90, 'EGP', trimZeroCents: true),
        '\u200EE£ 2,049,918.90',
      );
      // 21,449,381.72 -> E£ 21,449,381.72 (preserves .72)
      expect(
        ZakatEngineService.formatCurrency(21449381.72, 'EGP', trimZeroCents: true),
        '\u200EE£ 21,449,381.72',
      );
    });

    test('Required minimum test values - full & compact outputs', () {
      final Map<double, ({String full, String compact})> cases = {
        999999.99: (
          full: '\u200EE£ 999,999.99',
          compact: '\u200EE£ 1M',
        ),
        1000000.0: (
          full: '\u200EE£ 1,000,000',
          compact: '\u200EE£ 1M',
        ),
        2049918.90: (
          full: '\u200EE£ 2,049,918.90',
          compact: '\u200EE£ 2.05M',
        ),
        21449381.72: (
          full: '\u200EE£ 21,449,381.72',
          compact: '\u200EE£ 21.45M',
        ),
        99999999.99: (
          full: '\u200EE£ 99,999,999.99',
          compact: '\u200EE£ 100M',
        ),
        100000000.0: (
          full: '\u200EE£ 100,000,000',
          compact: '\u200EE£ 100M',
        ),
        999999999.99: (
          full: '\u200EE£ 999,999,999.99',
          compact: '\u200EE£ 1B',
        ),
        1000000000.0: (
          full: '\u200EE£ 1,000,000,000',
          compact: '\u200EE£ 1B',
        ),
        12345678901.23: (
          full: '\u200EE£ 12,345,678,901.23',
          compact: '\u200EE£ 12.35B',
        ),
      };

      cases.forEach((val, expected) {
        final fullResult = ZakatEngineService.formatCurrency(
          val,
          'EGP',
          trimZeroCents: true,
        );
        expect(
          fullResult,
          expected.full,
          reason: 'Full currency failure for $val',
        );

        final compactResult = ZakatEngineService.formatCurrency(
          val,
          'EGP',
          compact: true,
          maxFractionDigits: 2,
        );
        expect(
          compactResult,
          expected.compact,
          reason: 'Compact currency failure for $val',
        );
      });
    });

    test('Fallback formatting examples from requirements', () {
      // 123.46M
      expect(
        ZakatEngineService.formatCurrency(123456789.0, 'EGP', compact: true),
        '\u200EE£ 123.46M',
      );
      // 1.23B
      expect(
        ZakatEngineService.formatCurrency(1234567890.0, 'EGP', compact: true),
        '\u200EE£ 1.23B',
      );
      // 12.35B
      expect(
        ZakatEngineService.formatCurrency(12345678901.23, 'EGP', compact: true),
        '\u200EE£ 12.35B',
      );
      // 1.24T
      expect(
        ZakatEngineService.formatCurrency(1236000000000.0, 'EGP', compact: true),
        '\u200EE£ 1.24T',
      );
    });

    testWidgets('Dashboard Hero adaptive display selects full when comfortable and compact when needed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              const style = TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              );

              // 1. Wide space (e.g. tablet width 400pt): full amounts should always display
              final wideFull21M = DashboardScreenTestExport.formatHeroNetWorthDisplay(
                context,
                21449381.72,
                'EGP',
                availableWidth: 400,
                style: style,
              );
              expect(wideFull21M, '\u200EE£ 21,449,381.72');

              final wideFull12B = DashboardScreenTestExport.formatHeroNetWorthDisplay(
                context,
                12345678901.23,
                'EGP',
                availableWidth: 600,
                style: style,
              );
              expect(wideFull12B, '\u200EE£ 12,345,678,901.23');

              // 2. Narrow space (e.g. 150pt):
              // 850,000 fits comfortably
              final narrow850k = DashboardScreenTestExport.formatHeroNetWorthDisplay(
                context,
                850000,
                'EGP',
                availableWidth: 350,
                style: style,
              );
              expect(narrow850k, '\u200EE£ 850,000');

              // Large billion amount falls back to compact with 2 decimals
              final compact12B = DashboardScreenTestExport.formatHeroNetWorthDisplay(
                context,
                12345678901.23,
                'EGP',
                availableWidth: 230,
                style: style,
              );
              expect(compact12B, '\u200EE£ 12.35B');

              // In very tight space, gracefully falls back to 1 decimal place
              final tight12B = DashboardScreenTestExport.formatHeroNetWorthDisplay(
                context,
                12345678901.23,
                'EGP',
                availableWidth: 150,
                style: style,
              );
              expect(tight12B, '\u200EE£ 12.3B');

              return const SizedBox();
            },
          ),
        ),
      );
    });

    test('Net Worth calculation parity: Dashboard hero and Widget service share exact formulas', () {
      final Map<String, dynamic> sampleMarketData = {
        'GOLD_PRICE_24K_EGP': 4800.0,
        'SILVER_PRICE_EGP': 55.0,
        'USD_TO_EGP': 49.5,
        'SAR_TO_EGP': 13.2,
        'RATES_TO_EGP': {
          'USD': 49.5,
          'SAR': 13.2,
          'EUR': 53.8,
        },
      };

      final MarketData market = MarketData.fromJson(sampleMarketData);

      final double totalWealthEgp = 25000000.0;
      final double totalLiabilitiesEgp = 3550618.28;
      final double netPositionEgp = totalWealthEgp - totalLiabilitiesEgp;

      // Dashboard hero conversion:
      final double dashboardDisplayValue = ZakatEngineService.convertFromEgp(
        netPositionEgp,
        'EGP',
        market,
      );

      // Widget service calculation:
      final double widgetNetWorthMain = ZakatEngineService.convertFromEgp(
        netPositionEgp,
        'EGP',
        market,
      );

      expect(widgetNetWorthMain, dashboardDisplayValue);

      // Formatting parity:
      final String dashboardCompact = ZakatEngineService.formatCurrency(
        dashboardDisplayValue,
        'EGP',
        compact: true,
        maxFractionDigits: 2,
      );
      final String widgetCompact = ZakatEngineService.formatCurrency(
        widgetNetWorthMain,
        'EGP',
        compact: true,
        maxFractionDigits: 2,
      );

      expect(dashboardCompact, widgetCompact);
      expect(dashboardCompact, '\u200EE£ 21.45M');
    });

    test('Parity between Assets Tab liabilities and Dashboard Net Worth with credit cards', () {
      final Map<String, dynamic> sampleMarketData = {
        'GOLD_PRICE_24K_EGP': 3000.0,
        'SILVER_PRICE_EGP': 55.0,
        'USD_TO_EGP': 50.0,
        'SAR_TO_EGP': 13.0,
        'RATES_TO_EGP': {
          'USD': 50.0,
          'SAR': 13.0,
        },
      };
      final MarketData market = MarketData.fromJson(sampleMarketData);

      const List<CreditCard> cards = <CreditCard>[
        CreditCard(
          id: 'card-1',
          bankName: 'CIB',
          cardNickname: 'Cashback',
          network: CreditCardNetwork.visa,
          last4Digits: '1111',
          creditLimit: 50000,
          currency: 'EGP',
          openingBalance: 25000,
        ),
        CreditCard(
          id: 'card-2',
          bankName: 'HSBC',
          cardNickname: 'Premier',
          network: CreditCardNetwork.mastercard,
          last4Digits: '2222',
          creditLimit: 2000,
          currency: 'USD',
          openingBalance: 500, // 500 * 50 = 25,000 EGP
        ),
      ];

      const List<Saving> cashSavings = <Saving>[
        Saving(
          id: 'cash-1',
          assetType: 'cash',
          amount: 500000.0,
          remainingAmount: 500000.0,
          unit: 'EGP',
          description: 'Cash Holding',
          purchaseCurrency: 'EGP',
          purchaseAmount: 500000.0,
          dateAcquired: '2026-01-01',
          createdAt: '2026-01-01',
        ),
      ];

      // Assets tab calculation
      final double assetsTabWealthEgp = ZakatEngineService.calculateTotalWealthEgp(
        transactions: const [],
        savings: cashSavings,
        investments: const [],
        marketData: market,
      );
      final double assetsTabLiabilitiesEgp =
          ZakatEngineService.calculateTotalLiabilitiesEgp(
            transactions: const [],
            savings: cashSavings,
            investments: const [],
            marketData: market,
            creditCards: cards,
          );
      // 25,000 + 25,000 = 50,000
      expect(assetsTabLiabilitiesEgp, 50000.0);

      final double assetsTabNetWorthEgp =
          assetsTabWealthEgp - assetsTabLiabilitiesEgp;

      // Dashboard calculation
      final double dashboardNetPositionEgp =
          assetsTabWealthEgp -
          ZakatEngineService.calculateTotalLiabilitiesEgp(
            transactions: const [],
            savings: cashSavings,
            investments: const [],
            marketData: market,
            creditCards: cards,
          );

      // Core engine calculation
      final double engineNetWorthEgp = ZakatEngineService.calculateNetWorthEgp(
        transactions: const [],
        savings: cashSavings,
        investments: const [],
        marketData: market,
        creditCards: cards,
      );

      // Verify exact parity
      expect(assetsTabWealthEgp, 500000.0);
      expect(assetsTabNetWorthEgp, 450000.0);
      expect(dashboardNetPositionEgp, 450000.0);
      expect(engineNetWorthEgp, 450000.0);
      expect(assetsTabNetWorthEgp, dashboardNetPositionEgp);
      expect(engineNetWorthEgp, dashboardNetPositionEgp);
    });
  });
}
