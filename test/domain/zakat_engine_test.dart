import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/core/services/zakat_engine.dart';
import 'package:zakatapp_flutter/models/app_state.dart';

import 'test_helpers.dart';

void main() {
  final fixture = loadJsonFixture('test/fixtures/sample_app_state.json');
  final marketFixture = loadJsonFixture('test/fixtures/market_data.json');

  final appState = AppStateModel.fromJson(fixture);
  final marketData = MarketData.fromJson(marketFixture);

  test('currency conversion', () {
    expect(ZakatEngineService.convertToEgp(100, 'EGP', marketData), 100);
    expect(ZakatEngineService.convertToEgp(2, 'USD', marketData), 100);
    expect(ZakatEngineService.convertToEgp(10, 'SAR', marketData), closeTo(135, 1e-9));
    expect(ZakatEngineService.convertToEgp(1, 'EUR', marketData), 55);
    expect(ZakatEngineService.convertFromEgp(100, 'USD', marketData), closeTo(2, 1e-9));
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

  test('cash zakat calculation', () {
    expect(ZakatEngineService.calculateCashZakat(1000), 25);
  });

  test('gold/silver zakat calculation', () {
    expect(ZakatEngineService.calculateGoldZakat(100), 2.5);

    final silverSaving = appState.savings.firstWhere((s) => s.assetType == 'silver');
    final status = ZakatEngineService.evaluateSavingStatus(
      saving: silverSaving,
      savings: appState.savings,
      marketData: marketData,
    );
    expect(status.zakatDue, greaterThanOrEqualTo(0));
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
