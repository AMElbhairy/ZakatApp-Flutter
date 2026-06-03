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
    },
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
      'createdAt': '2024-01-01T00:00:00.000Z',
    },
  ];
  final subNisabIncomeTransactions = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'tx_sub_nisab_income',
      'type': 'income',
      'date': '2024-01-01',
      'amount': 200000,
      'currency': 'EGP',
      'category': 'Salary',
      'description': 'Sub-nisab income lot',
      'createdAt': '2024-01-01T00:00:00.000Z',
      'rolledOver': false,
      'remainingAmount': 200000,
    },
  ];
  final subNisabCashSavings = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'sav_sub_nisab_cash',
      'assetType': 'cash',
      'dateAcquired': '2024-01-01',
      'amount': 60000,
      'remainingAmount': 60000,
      'unit': 'EGP',
      'description': 'Sub-nisab cash',
      'purchaseCurrency': '',
      'purchaseAmount': 0,
      'createdAt': '2024-01-01T00:00:00.000Z',
    },
  ];
  final screenshotTransactions = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'income_mar',
      'type': 'income',
      'date': '2025-03-01',
      'amount': 100000,
      'currency': 'EGP',
      'category': 'Salary',
      'description': 'March salary',
      'createdAt': '2025-03-01T00:00:00.000Z',
      'rolledOver': false,
    },
    <String, dynamic>{
      'id': 'expense_mar',
      'type': 'expense',
      'date': '2025-03-15',
      'amount': 50000,
      'currency': 'EGP',
      'category': 'Groceries',
      'description': 'Groceries',
      'createdAt': '2025-03-15T00:00:00.000Z',
      'rolledOver': false,
    },
    <String, dynamic>{
      'id': 'income_apr',
      'type': 'income',
      'date': '2025-04-01',
      'amount': 100000,
      'currency': 'EGP',
      'category': 'Salary',
      'description': 'April salary',
      'createdAt': '2025-04-01T00:00:00.000Z',
      'rolledOver': false,
    },
    <String, dynamic>{
      'id': 'expense_may',
      'type': 'expense',
      'date': '2025-05-15',
      'amount': 125000,
      'currency': 'EGP',
      'category': 'Internet & Phone',
      'description': 'Internet & Phone',
      'createdAt': '2025-05-15T00:00:00.000Z',
      'rolledOver': false,
    },
    <String, dynamic>{
      'id': 'income_jun',
      'type': 'income',
      'date': '2025-06-01',
      'amount': 50000,
      'currency': 'EGP',
      'category': 'Business',
      'description': 'June business',
      'createdAt': '2025-06-01T00:00:00.000Z',
      'rolledOver': false,
    },
    <String, dynamic>{
      'id': 'expense_jun',
      'type': 'expense',
      'date': '2025-06-20',
      'amount': 25000,
      'currency': 'EGP',
      'category': 'Healthcare',
      'description': 'Healthcare',
      'createdAt': '2025-06-20T00:00:00.000Z',
      'rolledOver': false,
    },
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

  test('monthly zakat uses combined savings and income nisab', () {
    final schedule = ZakatScheduleService.calculateMonthlyZakatSchedule(
      transactions: subNisabIncomeTransactions,
      savings: subNisabCashSavings,
      marketData: marketData,
      now: DateTime(2025, 1, 31),
    );

    expect(schedule, isNotEmpty);
    final entries = schedule.first['entries'] as List;
    final entry = entries.first as Map<String, dynamic>;
    expect(entry['lotAmount'], 200000);
    expect((entry['zakatAmount'] as num).toDouble(), closeTo(5000, 1e-6));
  });

  test('monthly zakat stays empty when combined portfolio is below nisab', () {
    final schedule = ZakatScheduleService.calculateMonthlyZakatSchedule(
      transactions: subNisabIncomeTransactions,
      marketData: marketData,
      now: DateTime(2025, 1, 31),
    );

    expect(schedule, isEmpty);
  });

  test('monthly zakat deducts expenses from newest income first', () {
    final schedule = ZakatScheduleService.calculateMonthlyZakatSchedule(
      transactions: screenshotTransactions,
      savings: highSavings,
      marketData: marketData,
      now: DateTime(2025, 7),
    );

    final feb2026 = schedule.firstWhere(
      (Map<String, dynamic> entry) => entry['monthKey'] == '2026-02',
    );
    final may2026 = schedule.firstWhere(
      (Map<String, dynamic> entry) => entry['monthKey'] == '2026-05',
    );

    expect((feb2026['totalZakat'] as num).toDouble(), closeTo(625, 1e-6));
    expect((may2026['totalZakat'] as num).toDouble(), closeTo(625, 1e-6));

    final febEntry =
        (feb2026['entries'] as List).single as Map<String, dynamic>;
    final mayEntry =
        (may2026['entries'] as List).single as Map<String, dynamic>;
    expect(febEntry['lotAmount'], 25000);
    expect(mayEntry['lotAmount'], 25000);
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

  test('savings zakat uses income cash in the nisab check', () {
    final schedule = ZakatScheduleService.calculateSavingsZakatSchedule(
      savings: subNisabCashSavings,
      transactions: subNisabIncomeTransactions,
      marketData: marketData,
      now: DateTime(2025, 1, 31),
    );

    expect(schedule, isNotEmpty);
    final entries = schedule.first['entries'] as List;
    final entry = entries.first as Map<String, dynamic>;
    expect(entry['amount'], 60000);
    expect((entry['zakatAmount'] as num).toDouble(), closeTo(1500, 1e-6));
  });

  test('linked gold inherits hawl dates from funding allocations', () {
    final schedule = ZakatScheduleService.calculateSavingsZakatSchedule(
      savings: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'gold_linked',
          'assetType': 'gold',
          'dateAcquired': '2025-06-01',
          'amount': 100,
          'remainingAmount': 100,
          'unit': '24',
          'description': 'Linked gold',
          'purchaseCurrency': 'EGP',
          'purchaseAmount': 800000,
          'createdAt': '2025-06-01T00:00:00.000Z',
          'fundingAllocations': <Map<String, dynamic>>[
            <String, dynamic>{
              'sourceType': 'savings',
              'sourceId': 'cash_feb',
              'sourceDate': '2025-02-01',
              'currency': 'EGP',
              'amount': 400000,
            },
            <String, dynamic>{
              'sourceType': 'income',
              'sourceId': 'income_jun',
              'sourceDate': '2025-06-01',
              'currency': 'EGP',
              'amount': 400000,
            },
          ],
        },
      ],
      marketData: marketData,
      now: DateTime(2025, 7),
    );

    final jan2026 = schedule.firstWhere(
      (Map<String, dynamic> entry) => entry['monthKey'] == '2026-01',
    );
    final may2026 = schedule.firstWhere(
      (Map<String, dynamic> entry) => entry['monthKey'] == '2026-05',
    );

    expect((jan2026['totalZakat'] as num).toDouble(), closeTo(3750, 1e-6));
    expect((may2026['totalZakat'] as num).toDouble(), closeTo(3750, 1e-6));
    expect(((jan2026['entries'] as List).single as Map)['amount'], 50);
    expect(((may2026['entries'] as List).single as Map)['amount'], 50);
  });

  test('annual zakat schedule', () {
    final schedule = ZakatScheduleService.calculateAnnualZakatSchedule(
      zakatAnnualDate: fixture['zakatAnnualDate'] as String,
      transactions: highIncomeTransactions,
      savings: highSavings,
      investments: (fixture['investments'] as List)
          .cast<Map<String, dynamic>>(),
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
    expect(
      (entry['zakatAmount'] as num).toDouble(),
      closeTo((entry['totalWealth'] as num).toDouble() * 0.025, 1e-6),
    );
  });

  test('annual zakat uses exact selected Hijri due date', () {
    const int hijriMonth = 12;
    const int hijriDay = 20;
    final DateTime now = DateTime(2026, 6, 3);
    final int hijriYear = ZakatEngineService.gregorianToHijri(now).year;
    final DateTime dueGreg = ZakatEngineService.hijriToGregorian(
      hijriYear,
      hijriMonth,
      hijriDay,
    );
    final String dueDate =
        '${dueGreg.year}-${dueGreg.month.toString().padLeft(2, '0')}-${dueGreg.day.toString().padLeft(2, '0')}';

    final schedule = ZakatScheduleService.calculateAnnualZakatSchedule(
      zakatAnnualDate: '$hijriMonth-$hijriDay',
      transactions: const <Map<String, dynamic>>[],
      savings: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'cash_on_due_date',
          'assetType': 'cash',
          'dateAcquired': dueDate,
          'amount': 300000,
          'remainingAmount': 300000,
          'unit': 'EGP',
          'description': 'Cash acquired on annual due date',
          'purchaseCurrency': '',
          'purchaseAmount': 0,
          'createdAt': '${dueDate}T00:00:00.000Z',
        },
      ],
      investments: const <Map<String, dynamic>>[],
      marketData: marketData,
      now: now,
    );

    final row = schedule.firstWhere(
      (Map<String, dynamic> entry) => entry['monthKey'] == dueDate,
    );
    final entry = (row['entries'] as List).single as Map<String, dynamic>;

    expect(row['paymentDate'], dueDate);
    expect(row['hijriMonth'], hijriMonth);
    expect(row['hijriDay'], hijriDay);
    expect(entry['dueDateRaw'], dueDate);
    expect(entry['totalWealth'], 300000);
    expect((entry['zakatAmount'] as num).toDouble(), closeTo(7500, 1e-6));
  });
}
