import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/core/services/zakat_engine.dart';
import 'package:zakatapp_flutter/services/financial_metrics_service.dart';

FinancialMetricsRecord<String> _record({
  required String id,
  required FinancialRecordType type,
  required DateTime date,
  required double amount,
  required String currency,
  required MarketData market,
  String category = 'Groceries',
  String label = 'Merchant',
  String description = '',
}) {
  return FinancialMetricsRecord<String>(
    source: id,
    type: type,
    date: date,
    createdAt: date,
    amountEgp: ZakatEngineService.convertToEgp(amount, currency, market),
    category: category,
    label: label,
    description: description,
    currencyCode: currency,
  );
}

MarketData _market() {
  return MarketData.fromJson(<String, dynamic>{
    'USD_TO_EGP': 50,
    'SAR_TO_EGP': 13.3,
    'RATES_TO_EGP': <String, dynamic>{
      'EGP': 1,
      'USD': 50,
      'SAR': 13.3,
    },
  });
}

void main() {
  test('30D filtering includes all current days and peak matches the highest daily total', () {
    final MarketData market = _market();
    final DateTime now = DateTime(2026, 7, 11);
    final List<FinancialMetricsRecord<String>> records = <FinancialMetricsRecord<String>>[
      _record(
        id: 'd1',
        type: FinancialRecordType.expense,
        date: DateTime(2026, 7, 11),
        amount: 10,
        currency: 'USD',
        market: market,
      ),
      _record(
        id: 'd2',
        type: FinancialRecordType.expense,
        date: DateTime(2026, 7, 11),
        amount: 5,
        currency: 'USD',
        market: market,
      ),
      _record(
        id: 'd3',
        type: FinancialRecordType.expense,
        date: DateTime(2026, 7, 10),
        amount: 20,
        currency: 'USD',
        market: market,
      ),
    ];

    final FinancialMetricsResult<String> metrics =
        FinancialMetricsService.calculate<String>(
          records: records,
          selectedPeriod: '30D',
          now: now,
          locale: 'en_US',
          typeFilter: FinancialRecordType.expense,
        );

    expect(metrics.granularity, 'daily');
    expect(metrics.currentRecords, hasLength(3));
    expect(metrics.chartBuckets, hasLength(31));
    expect(metrics.highestSpendingDay, DateTime(2026, 7, 10));
    expect(metrics.highestSpendingDayValue, closeTo(1000, 0.001));
    expect(metrics.dailyTotals[DateTime(2026, 7, 11)], closeTo(750, 0.001));
  });

  test('90D filtering aggregates weekly and excludes transfers from expenses', () {
    final MarketData market = _market();
    final DateTime now = DateTime(2026, 7, 11);
    final List<FinancialMetricsRecord<String>> records = <FinancialMetricsRecord<String>>[
      _record(
        id: 'expense',
        type: FinancialRecordType.expense,
        date: DateTime(2026, 7, 1),
        amount: 10,
        currency: 'USD',
        market: market,
      ),
      _record(
        id: 'transfer',
        type: FinancialRecordType.transfer,
        date: DateTime(2026, 7, 1),
        amount: 30,
        currency: 'USD',
        market: market,
        category: 'Currency Exchange',
        label: 'Transfer',
      ),
    ];

    final FinancialMetricsResult<String> metrics =
        FinancialMetricsService.calculate<String>(
          records: records,
          selectedPeriod: '90D',
          now: now,
          locale: 'en_US',
          typeFilter: FinancialRecordType.expense,
        );

    expect(metrics.granularity, 'weekly');
    expect(metrics.currentRecords, hasLength(1));
    expect(metrics.totalCurrent, closeTo(500, 0.001));
    expect(metrics.transferCurrent, 0);
  });

  test('custom ranges and empty periods return stable zeroed metrics', () {
    final MarketData market = _market();
    final DateTime now = DateTime(2026, 7, 11);
    final List<FinancialMetricsRecord<String>> records = <FinancialMetricsRecord<String>>[
      _record(
        id: 'old',
        type: FinancialRecordType.expense,
        date: DateTime(2026, 6, 1),
        amount: 10,
        currency: 'USD',
        market: market,
      ),
    ];

    final FinancialMetricsResult<String> emptyMetrics =
        FinancialMetricsService.calculate<String>(
          records: const <FinancialMetricsRecord<String>>[],
          selectedPeriod: '30D',
          now: now,
          locale: 'en_US',
          typeFilter: FinancialRecordType.expense,
        );

    expect(emptyMetrics.currentRecords, isEmpty);
    expect(emptyMetrics.totalCurrent, 0);
    expect(emptyMetrics.highestSpendingDay, isNull);
    expect(emptyMetrics.highestSpendingDayValue, 0);

    final FinancialMetricsResult<String> customMetrics =
        FinancialMetricsService.calculate<String>(
          records: records,
          selectedPeriod: 'Custom',
          customRange: DateTimeRange(
            start: DateTime(2026, 6, 1),
            end: DateTime(2026, 6, 30),
          ),
          now: now,
          locale: 'en_US',
          typeFilter: FinancialRecordType.expense,
        );

    expect(customMetrics.currentRecords, hasLength(1));
    expect(customMetrics.range.start, DateTime(2026, 6, 1));
    expect(customMetrics.range.end, DateTime(2026, 6, 30));
  });

  test('negative expenses reduce totals and same-day transactions aggregate', () {
    final MarketData market = _market();
    final DateTime now = DateTime(2026, 7, 11);
    final List<FinancialMetricsRecord<String>> records = <FinancialMetricsRecord<String>>[
      _record(
        id: 'r1',
        type: FinancialRecordType.expense,
        date: DateTime(2026, 7, 8),
        amount: 10,
        currency: 'USD',
        market: market,
      ),
      _record(
        id: 'r2',
        type: FinancialRecordType.expense,
        date: DateTime(2026, 7, 8),
        amount: -2,
        currency: 'USD',
        market: market,
        label: 'Refund',
      ),
    ];

    final FinancialMetricsResult<String> metrics =
        FinancialMetricsService.calculate<String>(
          records: records,
          selectedPeriod: '30D',
          now: now,
          locale: 'en_US',
          typeFilter: FinancialRecordType.expense,
        );

    expect(metrics.totalCurrent, closeTo(400, 0.001));
    expect(metrics.dailyTotals[DateTime(2026, 7, 8)], closeTo(400, 0.001));
    expect(metrics.highestSpendingDayValue, closeTo(400, 0.001));
  });

  test('comparison periods and multi-currency conversion stay aligned', () {
    final MarketData market = _market();
    final DateTime now = DateTime(2026, 7, 11);
    final List<FinancialMetricsRecord<String>> records = <FinancialMetricsRecord<String>>[
      _record(
        id: 'current',
        type: FinancialRecordType.expense,
        date: DateTime(2026, 7, 10),
        amount: 10,
        currency: 'USD',
        market: market,
      ),
      _record(
        id: 'previous',
        type: FinancialRecordType.expense,
        date: DateTime(2026, 6, 10),
        amount: 5,
        currency: 'SAR',
        market: market,
      ),
    ];

    final FinancialMetricsResult<String> first =
        FinancialMetricsService.calculate<String>(
          records: records,
          selectedPeriod: '30D',
          now: now,
          locale: 'en_US',
          typeFilter: FinancialRecordType.expense,
        );
    final FinancialMetricsResult<String> second =
        FinancialMetricsService.calculate<String>(
          records: records,
          selectedPeriod: '30D',
          now: now,
          locale: 'en_US',
          typeFilter: FinancialRecordType.expense,
        );

    expect(first.highestSpendingDay, second.highestSpendingDay);
    expect(first.highestSpendingDayValue, second.highestSpendingDayValue);
    final double expectedPct =
        ((first.totalCurrent - first.totalPrevious) / first.totalPrevious) *
        100;
    expect(first.changePct, closeTo(expectedPct, 0.0001));
    expect(first.totalPrevious, closeTo(66.5, 0.001));
  });
}
