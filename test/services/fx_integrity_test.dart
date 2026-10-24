import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/core/services/zakat_engine.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/services/projection_service.dart';

MarketData market(Map<String, double> rates) => MarketData(
  goldPrice24kEgp: 5000, silverPriceEgp: 60,
  usdToEgp: 0, sarToEgp: 0, ratesToEgp: rates,
);

void main() {
  double convert(String from, String to, MarketData data) =>
    ProjectionService.convertToCurrency(amount: 100, from: from, to: to, marketData: data);

  test('missing source FX is unavailable', () {
    expect(convert('EUR', 'EGP', market({})).isNaN, isTrue);
  });
  test('missing target FX must not relabel EGP as target currency', () {
    expect(convert('EGP', 'EUR', market({})).isNaN, isTrue);
  });
  for (final rate in [0.0, -1.0, double.nan, double.infinity, double.negativeInfinity]) {
    test('invalid FX $rate is unavailable in both directions', () {
      final data = market({'EUR': rate});
      expect(ZakatEngineService.isCurrencyConversionAvailable('EUR', data), isFalse);
      expect(ZakatEngineService.tryConvertToEgp(100, 'EUR', data), isNull);
      expect(convert('EUR', 'EGP', data).isNaN, isTrue);
      expect(convert('EGP', 'EUR', data).isNaN, isTrue);
    });
  }
  test('same currency needs no FX, including normalized currency codes', () {
    expect(convert(' eur ', 'EUR', market({})), 100);
  });
  test('valid cross currency uses source and target rates', () {
    expect(convert('USD', 'EUR', market({'USD': 50, 'EUR': 100})), 50);
  });
  test('legitimate zero remains zero without FX', () {
    expect(ProjectionService.convertToCurrency(amount: 0, from: 'EGP', to: 'EUR', marketData: market({})), 0);
  });
  const expense = Transaction(id: 'overdraft', type: 'expense', date: '2026-01-01',
    amount: 10, currency: 'EUR', category: 'Food', description: '',
    createdAt: '2026-01-01T00:00:00Z', rolledOver: false);
  test('missing current overdraft FX makes liabilities and net worth unavailable', () {
    expect(ZakatEngineService.calculateTotalLiabilitiesEgp(transactions: [expense], savings: [], investments: [], marketData: market({})).isNaN, isTrue);
    expect(ZakatEngineService.calculateNetWorthEgp(transactions: [expense], savings: [], investments: [], marketData: market({})).isNaN, isTrue);
  });
  test('missing historical overdraft FX makes liabilities unavailable', () {
    expect(ZakatEngineService.calculateTotalLiabilitiesEgpAt(asOf: DateTime(2026, 1, 2), transactions: [expense], savings: [], investments: [], marketData: market({})).isNaN, isTrue);
  });
}
