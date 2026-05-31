import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/core/services/zakat_engine.dart';
import 'package:zakatapp_flutter/core/services/zakat_schedule_service.dart';

import 'test_helpers.dart';

void main() {
  final fixture = loadJsonFixture('test/fixtures/sample_app_state.json');
  final marketFixture = loadJsonFixture('test/fixtures/market_data.json');
  final marketData = MarketData.fromJson(marketFixture);
  final highIncomeTransactions = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'tx_big_income',
      'type': 'income',
      'date': '2024-01-01',
      'amount': 500000,
      'currency': 'EGP',
      'category': 'Salary',
      'description': 'Large income lot',
      'createdAt': '2024-01-01T00:00:00.000Z',
      'rolledOver': false,
    }
  ];
  final highSavings = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'sav_big_cash',
      'assetType': 'cash',
      'dateAcquired': '2024-01-01',
      'amount': 500000,
      'remainingAmount': 500000,
      'unit': 'EGP',
      'description': 'Large cash',
      'purchaseCurrency': '',
      'purchaseAmount': 0,
      'createdAt': '2024-01-01T00:00:00.000Z'
    }
  ];

  test('monthly zakat schedule', () {
    final schedule = ZakatScheduleService.calculateMonthlyZakatSchedule(
      transactions: highIncomeTransactions,
      marketData: marketData,
      now: DateTime(2026, 5, 31),
    );

    expect(schedule, isNotEmpty);
    expect(schedule.first.containsKey('monthKey'), true);
    expect(schedule.first.containsKey('paymentDate'), true);
    expect(schedule.first.containsKey('totalZakat'), true);
    expect(schedule.first.containsKey('entries'), true);

    final firstEntries = schedule.first['entries'] as List;
    expect(firstEntries.first['type'], 'income');
  });

  test('savings zakat schedule', () {
    final schedule = ZakatScheduleService.calculateSavingsZakatSchedule(
      savings: highSavings,
      marketData: marketData,
      now: DateTime(2026, 5, 31),
    );

    expect(schedule, isNotEmpty);
    final firstEntries = schedule.first['entries'] as List;
    expect(firstEntries.first['type'], 'savings');
    expect(firstEntries.first.containsKey('assetType'), true);
  });

  test('annual zakat schedule', () {
    final schedule = ZakatScheduleService.calculateAnnualZakatSchedule(
      zakatAnnualDate: fixture['zakatAnnualDate'] as String,
      transactions: highIncomeTransactions,
      savings: highSavings,
      investments: (fixture['investments'] as List).cast<Map<String, dynamic>>(),
      marketData: marketData,
      now: DateTime(2026, 5, 31),
    );

    expect(schedule, isNotEmpty);
    final first = schedule.first;
    expect(first.containsKey('hijriYear'), true);
    expect(first.containsKey('totalWealth'), true);
    expect(first.containsKey('entries'), true);

    final entries = first['entries'] as List;
    final entry = entries.first as Map<String, dynamic>;
    expect(entry['type'], 'annual');
    expect((entry['zakatAmount'] as num).toDouble(),
        closeTo((entry['totalWealth'] as num).toDouble() * 0.025, 1e-6));
  });
}
