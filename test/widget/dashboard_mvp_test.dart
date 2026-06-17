import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/main.dart';
import 'package:zakatapp_flutter/models/user_profile.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/auth_controller.dart';
import 'package:zakatapp_flutter/services/auth_service.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/market_data_api_service.dart';

class _NoopMarketDataApiService implements MarketDataApiService {
  @override
  Future<Map<String, double>?> fetchFxRatesToEgp() async => null;

  @override
  Future<double?> fetchGold24kPerGramEgp({required double usdToEgp}) async =>
      null;

  @override
  Future<double?> fetchSilverPerGramEgp({required double usdToEgp}) async =>
      null;
}

class _FakeAuthService implements AuthService {
  @override
  Future<bool> ensureSession() async => true;

  @override
  Future<UserProfile?> restoreSession() async => null;

  @override
  Future<UserProfile?> signIn({AuthProvider provider = AuthProvider.google}) async => null;

  @override
  Future<void> signOut() async {}
}

Map<String, dynamic> _seedStateWithMarketData() {
  return <String, dynamic>{
    'transactions': <dynamic>[],
    'savings': <dynamic>[],
    'recurringTransactions': <dynamic>[],
    'investments': <dynamic>[],
    'financialPlans': <dynamic>[],
    'lastRollover': '',
    'categories': <String, dynamic>{
      'income': <String>['Salary'],
      'expense': <String>['Food & Dining'],
    },
    'zakatPaidMonths': <dynamic>[],
    'processedExpenseIds': <dynamic>[],
    'mainCurrency': 'EGP',
    'defaultEntryCurrency': 'EGP',
    'zakatExpenseIds': <String, dynamic>{},
    'zakatMethod': 'hawl',
    'zakatAnnualDate': '',
    'zakatScheduleFilter': 'unpaid',
    'marketData': <String, dynamic>{
      'GOLD_PRICE_24K_EGP': 5000,
      'SILVER_PRICE_EGP': 60,
      'USD_TO_EGP': 50,
      'SAR_TO_EGP': 13.3,
      'RATES_TO_EGP': <String, dynamic>{
        'EGP': 1,
        'USD': 50,
        'SAR': 13.3,
        'EUR': 54,
        'GBP': 63,
        'AED': 13.6,
        'KWD': 162,
        'QAR': 13.7,
        'BHD': 132,
        'OMR': 130,
        'JOD': 70,
        'TRY': 1.55,
        'MYR': 10.6,
        'PKR': 0.18,
        'IDR': 0.0031,
      },
      'LAST_UPDATED': '2026-05-31T10:00:00Z',
    },
    'marketHistory': <dynamic>[],
    'syncHealth': <String, dynamic>{
      'lastSuccessAt': '',
      'lastFailureAt': '',
      'lastError': '',
      'pendingWrites': 0,
    },
    'aiSettings': <String, dynamic>{
      'keys': <String>['', ''],
      'defaultKeyIndex': 0,
    },
    'cloudHydrated': false,
    'hasUnsyncedAuthChanges': false,
  };
}

Map<String, dynamic> _seedStateWithGrowth({
  required double startingWealth,
  double incomeAfterStart = 0,
  double expenseAfterStart = 0,
  bool privacyMode = false,
  List<Map<String, dynamic>> marketHistory = const <Map<String, dynamic>>[],
}) {
  final int year = DateTime.now().year;
  final Map<String, dynamic> seeded = _seedStateWithMarketData();
  final List<Map<String, dynamic>> transactions = <Map<String, dynamic>>[
    _transactionJson(
      id: 'starting-income',
      type: 'income',
      date: '${year - 1}-12-01',
      amount: startingWealth,
    ),
  ];

  if (incomeAfterStart > 0) {
    transactions.add(
      _transactionJson(
        id: 'year-income',
        type: 'income',
        date: '$year-02-01',
        amount: incomeAfterStart,
      ),
    );
  }

  if (expenseAfterStart > 0) {
    transactions.add(
      _transactionJson(
        id: 'year-expense',
        type: 'expense',
        date: '$year-02-01',
        amount: expenseAfterStart,
      ),
    );
  }

  seeded['transactions'] = transactions;
  seeded['marketHistory'] = marketHistory;
  seeded['aiSettings'] = <String, dynamic>{
    'keys': <String>['', ''],
    'defaultKeyIndex': 0,
    if (privacyMode) 'privacyMode': true,
  };
  return seeded;
}

Map<String, dynamic> _transactionJson({
  required String id,
  required String type,
  required String date,
  required double amount,
}) {
  return <String, dynamic>{
    'id': id,
    'type': type,
    'date': date,
    'amount': amount,
    'currency': 'EGP',
    'category': type == 'income' ? 'Salary' : 'Food & Dining',
    'description': '',
    'createdAt': '${date}T00:00:00Z',
    'rolledOver': false,
  };
}

Widget _buildApp() {
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository = AppStateRepository(
    localStorage: localStorage,
  );
  return MultiProvider(
    providers: <ChangeNotifierProvider<dynamic>>[
      ChangeNotifierProvider<AppStateController>(
        create: (_) => AppStateController(
          repository: repository,
          marketDataApiService: _NoopMarketDataApiService(),
        ),
      ),
      ChangeNotifierProvider<AuthController>(
        create: (_) => AuthController(
          authService: _FakeAuthService(),
          localStorage: localStorage,
        ),
      ),
    ],
    child: const ZakatApp(),
  );
}

Future<void> _openAction(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(const Key('addEntryFab')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> _addIncome(WidgetTester tester, String amount) async {
  await _openAction(tester, const Key('actionAddIncome'));
  await tester.enterText(find.byKey(const Key('amountField')), amount);
  await tester.tap(find.byKey(const Key('categoryField')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Salary').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('saveTransactionButton')));
  await tester.pumpAndSettle();
}

Future<void> _addSaving(WidgetTester tester, String amount) async {
  await _openAction(tester, const Key('actionAddIncome'));
  await tester.tap(find.byKey(const Key('categoryField')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Salary').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('amountField')), amount);
  await tester.tap(find.byKey(const Key('saveTransactionButton')));
  await tester.pumpAndSettle();
}

Future<void> _addInvestment(WidgetTester tester, String value) async {
  await _openAction(tester, const Key('actionAddInvestment'));
  await tester.enterText(
    find.byKey(const Key('investmentNameField')),
    'Dashboard Property',
  );
  await tester.enterText(
    find.byKey(const Key('investmentCurrentValueField')),
    value,
  );
  await tester.ensureVisible(find.byKey(const Key('saveInvestmentButton')));
  await tester.tap(find.byKey(const Key('saveInvestmentButton')));
  await tester.pumpAndSettle();
}

Future<void> _scrollToText(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    320,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 12,
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollToKey(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    320,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 12,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty dashboard renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboardEmptyCard')), findsOneWidget);
    expect(find.text('Add First Entry'), findsOneWidget);
  });

  testWidgets('adding transaction updates total wealth', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(_seedStateWithMarketData()),
    });
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addIncome(tester, '1200');

    // Verify the hero card shows total wealth including the new income
    expect(find.text('TOTAL WEALTH'), findsOneWidget);
    expect(find.textContaining('1,200'), findsWidgets);
  });

  testWidgets(
    'foreign currency expense updates dashboard and assets summaries',
    (WidgetTester tester) async {
      final Map<String, dynamic> seeded = _seedStateWithMarketData();
      seeded['transactions'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'egp-income',
          'type': 'income',
          'date': '2026-06-01',
          'amount': 100,
          'currency': 'egp',
          'category': 'Salary',
          'description': '',
          'createdAt': '2026-06-01T00:00:00.000Z',
          'rolledOver': false,
        },
        <String, dynamic>{
          'id': 'usd-expense',
          'type': 'expense',
          'date': '2026-06-02',
          'amount': 10,
          'currency': 'usd',
          'category': 'Food & Dining',
          'description': 'AI or normal expense',
          'createdAt': '2026-06-02T00:00:00.000Z',
          'rolledOver': false,
        },
      ];
      SharedPreferences.setMockInitialValues(<String, Object>{
        'zakatAppData': jsonEncode(seeded),
      });

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('NET POSITION'), findsOneWidget);
      expect(find.textContaining('-400.00'), findsWidgets);

      await tester.tap(find.text('Assets').last);
      await tester.pumpAndSettle();

      expect(find.text('LIABILITIES'), findsOneWidget);
      expect(find.textContaining('500.00'), findsWidgets);
    },
  );

  testWidgets('adding saving updates total wealth', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(_seedStateWithMarketData()),
    });
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addSaving(tester, '700');

    // Verify the hero card shows total wealth including the new saving
    expect(find.text('TOTAL WEALTH'), findsOneWidget);
    expect(find.textContaining('700'), findsWidgets);
  });

  testWidgets('adding investment updates total wealth', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(_seedStateWithMarketData()),
    });
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addInvestment(tester, '500000');

    // Verify the hero card shows total wealth including the investment
    expect(find.text('TOTAL WEALTH'), findsOneWidget);
    expect(find.textContaining('500,000'), findsWidgets);
  });

  testWidgets('nisab status appears', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addIncome(tester, '100');

    await _scrollToText(tester, 'CURRENT NISAB THRESHOLD');
    expect(find.text('CURRENT NISAB THRESHOLD'), findsOneWidget);
    expect(find.textContaining('NISAB'), findsWidgets);

    await _scrollToText(tester, 'Upcoming Obligations');
    expect(find.text('Upcoming Obligations'), findsOneWidget);
  });

  testWidgets('recent activity limited to 4', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addIncome(tester, '100');
    await _addIncome(tester, '200');
    await _addIncome(tester, '300');
    await _addIncome(tester, '400');
    await _addIncome(tester, '500');

    await _scrollToText(tester, 'Recent Activity');

    expect(find.text('Recent Activity'), findsOneWidget);

    final Finder rows = find.byWidgetPredicate(
      (Widget w) =>
          w.key != null && w.key.toString().contains('dashboardRecent_'),
    );
    expect(rows, findsNWidgets(4));
  });

  testWidgets('recent activity includes income, expense, and cash savings', (
    WidgetTester tester,
  ) async {
    final Map<String, dynamic> seeded = _seedStateWithMarketData();
    seeded['transactions'] = <Map<String, dynamic>>[
      _transactionJson(
        id: 'recent-income',
        type: 'income',
        date: '2026-06-01',
        amount: 100,
      ),
      _transactionJson(
        id: 'recent-expense',
        type: 'expense',
        date: '2026-06-02',
        amount: 20,
      ),
    ];
    seeded['savings'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'recent-saving',
        'assetType': 'cash',
        'dateAcquired': '2026-06-03',
        'amount': 40,
        'remainingAmount': 40,
        'unit': 'EGP',
        'description': 'Emergency fund',
        'purchaseCurrency': '',
        'purchaseAmount': 0,
        'createdAt': '2026-06-03T00:00:00.000Z',
      },
    ];
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(seeded),
    });

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await _scrollToText(tester, 'Recent Activity');

    expect(
      find.byKey(const Key('dashboardRecent_tx_recent-income')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('dashboardRecent_tx_recent-expense')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('dashboardRecent_saving_recent-saving')),
      findsOneWidget,
    );
  });

  testWidgets('recent currency exchange uses gold transfer icon', (
    WidgetTester tester,
  ) async {
    final Map<String, dynamic> seeded = _seedStateWithMarketData();
    seeded['transactions'] = <Map<String, dynamic>>[
      <String, dynamic>{
        ..._transactionJson(
          id: 'recent-exchange',
          type: 'expense',
          date: '2026-06-11',
          amount: 20,
        ),
        'category': 'Currency Exchange',
        'activityType': 'transfer',
      },
    ];
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(seeded),
    });

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await _scrollToText(tester, 'Recent Activity');

    final Icon icon = tester.widget<Icon>(
      find.byKey(const Key('dashboardRecentTransferIcon')),
    );
    expect(icon.icon, Icons.swap_horiz_rounded);
    expect(icon.color, const Color(0xFFD4AF37));
  });

  testWidgets('View All goes to Activity tab', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addIncome(tester, '111');

    await _scrollToKey(tester, const Key('dashboardViewAllActivityButton'));

    await tester.tap(find.byKey(const Key('dashboardViewAllActivityButton')));
    await tester.pumpAndSettle();

    expect(find.text('Activity'), findsWidgets);
    expect(find.text('All'), findsWidgets);
  });

  testWidgets('dashboard shows Market data required when missing', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addIncome(tester, '350');

    expect(find.text('Market data required'), findsWidgets);
  });

  testWidgets('dashboard shows Market data required when FX rate is missing', (
    WidgetTester tester,
  ) async {
    final Map<String, dynamic> seeded = _seedStateWithMarketData();
    seeded['marketData'] = <String, dynamic>{
      'GOLD_PRICE_24K_EGP': 5000,
      'SILVER_PRICE_EGP': 60,
      'USD_TO_EGP': 0,
      'SAR_TO_EGP': 13.3,
      'RATES_TO_EGP': <String, dynamic>{'EGP': 1, 'SAR': 13.3},
      'LAST_UPDATED': '2026-05-31T10:00:00Z',
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(seeded),
    });
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _openAction(tester, const Key('actionAddIncome'));
    await tester.enterText(find.byKey(const Key('amountField')), '100');
    await tester.tap(find.byKey(const Key('currencyField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('\$').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('categoryField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salary').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveTransactionButton')));
    await tester.pumpAndSettle();

    expect(find.text('Market data required'), findsWidgets);
  });

  testWidgets('dashboard shows nisab threshold when market data exists', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(_seedStateWithMarketData()),
    });
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addIncome(tester, '100');

    await _scrollToText(tester, 'CURRENT NISAB THRESHOLD');
    expect(find.text('CURRENT NISAB THRESHOLD'), findsOneWidget);
    expect(find.textContaining('E£ 425,000.00'), findsWidgets);
  });

  testWidgets('dashboard remains safe when metals missing', (
    WidgetTester tester,
  ) async {
    final Map<String, dynamic> seeded = _seedStateWithMarketData();
    seeded['marketData'] = <String, dynamic>{
      'GOLD_PRICE_24K_EGP': 0,
      'SILVER_PRICE_EGP': 0,
      'USD_TO_EGP': 50,
      'SAR_TO_EGP': 13.3,
      'RATES_TO_EGP': <String, dynamic>{'EGP': 1, 'USD': 50, 'SAR': 13.3},
      'LAST_UPDATED': '2026-05-31T10:00:00Z',
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(seeded),
    });
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addIncome(tester, '1200');
    await _scrollToText(tester, 'CURRENT NISAB THRESHOLD');
    expect(find.text('CURRENT NISAB THRESHOLD'), findsOneWidget);
    expect(find.text('Gold/Silver prices required'), findsWidgets);
  });

  testWidgets('hero shows positive real yearly growth', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(
        _seedStateWithGrowth(startingWealth: 1000, incomeAfterStart: 500),
      ),
    });
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.text('50.0% this year'), findsOneWidget);
  });

  testWidgets('hero shows negative real yearly growth', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(
        _seedStateWithGrowth(startingWealth: 1000, expenseAfterStart: 250),
      ),
    });
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.text('25.0% this year'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
  });

  testWidgets('hero hides growth when start-of-year wealth is invalid', (
    WidgetTester tester,
  ) async {
    final int year = DateTime.now().year;
    final Map<String, dynamic> seeded = _seedStateWithMarketData();
    seeded['transactions'] = <Map<String, dynamic>>[
      _transactionJson(
        id: 'new-income',
        type: 'income',
        date: '$year-02-01',
        amount: 500,
      ),
    ];
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(seeded),
    });
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('this year'), findsNothing);
  });

  testWidgets('hero hides growth when balances are hidden', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(
        _seedStateWithGrowth(
          startingWealth: 1000,
          incomeAfterStart: 500,
          privacyMode: true,
        ),
      ),
    });
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('this year'), findsNothing);
    expect(find.text('••••••'), findsWidgets);
  });

  testWidgets('hero sparkline renders from real dated wealth points', (
    WidgetTester tester,
  ) async {
    final int year = DateTime.now().year;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(
        _seedStateWithGrowth(
          startingWealth: 1000,
          incomeAfterStart: 500,
          marketHistory: <Map<String, dynamic>>[
            <String, dynamic>{
              'recordedAt': '$year-01-31T00:00:00Z',
              'totalWealthEgp': 1000,
            },
            <String, dynamic>{
              'recordedAt': '$year-02-28T00:00:00Z',
              'totalWealthEgp': 1500,
            },
          ],
        ),
      ),
    });
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget.runtimeType.toString() == '_HeroSparkline',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Top Expense Categories widget displays empty state when no expenses', (WidgetTester tester) async {
    final Map<String, dynamic> seeded = _seedStateWithMarketData();
    // Seed one income transaction to make hasAnyData = true so the dashboard loads instead of the empty card
    seeded['transactions'] = <Map<String, dynamic>>[
      _transactionJson(
        id: 'income1',
        type: 'income',
        date: '2026-06-01',
        amount: 10000,
      ),
    ];
    
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(seeded),
    });
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    
    await _scrollToText(tester, 'Top Expense Categories');
    expect(find.text('Top Expense Categories'), findsOneWidget);
    expect(find.text('Add expenses to see spending insights.'), findsOneWidget);
  });

  testWidgets('Top Expense Categories widget displays categories, percentages, amounts, and progress bars correctly', (WidgetTester tester) async {
    final Map<String, dynamic> seeded = _seedStateWithMarketData();
    final int year = DateTime.now().year;
    final int month = DateTime.now().month;
    final String currentMonthStr = month < 10 ? '0$month' : '$month';
    final String prevMonthStr = month == 1 ? '12' : (month - 1 < 10 ? '0${month - 1}' : '${month - 1}');
    final int prevYear = month == 1 ? year - 1 : year;
    
    seeded['transactions'] = <Map<String, dynamic>>[
      <String, dynamic>{
        ..._transactionJson(id: 'rent', type: 'expense', date: '$year-$currentMonthStr-05', amount: 4000),
        'category': 'Rent',
      },
      <String, dynamic>{
        ..._transactionJson(id: 'food', type: 'expense', date: '$year-$currentMonthStr-06', amount: 3000),
        'category': 'Food',
      },
      <String, dynamic>{
        ..._transactionJson(id: 'shopping', type: 'expense', date: '$year-$currentMonthStr-07', amount: 2000),
        'category': 'Shopping',
      },
      <String, dynamic>{
        ..._transactionJson(id: 'transport', type: 'expense', date: '$year-$currentMonthStr-08', amount: 1000),
        'category': 'Transport',
      },
      <String, dynamic>{
        ..._transactionJson(id: 'other', type: 'expense', date: '$year-$currentMonthStr-09', amount: 500),
        'category': 'Other',
      },
      <String, dynamic>{
        ..._transactionJson(id: 'prev_month', type: 'expense', date: '$prevYear-$prevMonthStr-15', amount: 5000),
        'category': 'Rent',
      },
    ];

    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(seeded),
    });
    
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await _scrollToText(tester, 'Top Expense Categories');

    // Verify header title and subtitle
    expect(find.text('Top Expense Categories'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_TopExpenseCategoriesCard'),
        matching: find.text('This Month'),
      ),
      findsOneWidget,
    );

    final Finder cardFinder = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_TopExpenseCategoriesCard');

    // Verify top 4 categories are displayed
    expect(find.descendant(of: cardFinder, matching: find.text('Rent')), findsOneWidget);
    expect(find.descendant(of: cardFinder, matching: find.text('Food')), findsOneWidget);
    expect(find.descendant(of: cardFinder, matching: find.text('Shopping')), findsOneWidget);
    expect(find.descendant(of: cardFinder, matching: find.text('Transport')), findsOneWidget);
    
    // Verify 5th category (Other) is NOT displayed
    expect(find.descendant(of: cardFinder, matching: find.text('Other')), findsNothing);

    // Verify percentages
    // Rent: 4000 / 10500 = 38%
    // Food: 3000 / 10500 = 29%
    // Shopping: 2000 / 10500 = 19%
    // Transport: 1000 / 10500 = 10%
    expect(find.descendant(of: cardFinder, matching: find.text('38%')), findsOneWidget);
    expect(find.descendant(of: cardFinder, matching: find.text('29%')), findsOneWidget);
    expect(find.descendant(of: cardFinder, matching: find.text('19%')), findsOneWidget);
    expect(find.descendant(of: cardFinder, matching: find.text('10%')), findsOneWidget);

    // Verify amounts formatted without decimals
    expect(find.descendant(of: cardFinder, matching: find.textContaining('4,000')), findsOneWidget);
    expect(find.descendant(of: cardFinder, matching: find.textContaining('3,000')), findsOneWidget);
    expect(find.descendant(of: cardFinder, matching: find.textContaining('2,000')), findsOneWidget);
    expect(find.descendant(of: cardFinder, matching: find.textContaining('1,000')), findsOneWidget);

    // Click on the widget and verify snackbar
    await tester.tap(find.text('Top Expense Categories'));
    await tester.pump();
    
    expect(find.text('Expense Analysis screen coming soon'), findsOneWidget);
    
    // Allow the toast dismissal timer to complete and fade out by advancing the clock
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Top Expense Categories excludes transfers and Recent Activity displays transfers in gold styling', (WidgetTester tester) async {
    final Map<String, dynamic> seeded = _seedStateWithMarketData();
    final int year = DateTime.now().year;
    final int month = DateTime.now().month;
    final String currentMonthStr = month < 10 ? '0$month' : '$month';
    
    seeded['transactions'] = <Map<String, dynamic>>[
      // Expense that should show in Top Expense Categories
      <String, dynamic>{
        ..._transactionJson(id: 'food', type: 'expense', date: '$year-$currentMonthStr-06', amount: 3000),
        'category': 'Food',
      },
      // Currency Exchange Transfer that should NOT show in Top Expense Categories but SHOULD show in Recent Activity
      <String, dynamic>{
        ..._transactionJson(id: 'ex_out', type: 'expense', date: '$year-$currentMonthStr-07', amount: 5000),
        'category': 'Currency Exchange',
        'exchangePairId': 'ex_pair_1',
        'currency': 'SAR',
      },
      <String, dynamic>{
        ..._transactionJson(id: 'ex_in', type: 'income', date: '$year-$currentMonthStr-07', amount: 1333),
        'category': 'Currency Exchange',
        'exchangePairId': 'ex_pair_1',
        'currency': 'USD',
      },
      // Gold Purchase Transfer that should NOT show in Top Expense Categories
      <String, dynamic>{
        ..._transactionJson(id: 'gold_out', type: 'expense', date: '$year-$currentMonthStr-08', amount: 2000),
        'category': 'Gold Purchase',
        'exchangePairId': 'gold_saving_1',
        'currency': 'SAR',
      },
    ];

    // Seed one gold purchase in savings to form the gold transfer description
    seeded['savings'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'gold_saving_1',
        'assetType': 'gold',
        'dateAcquired': '$year-$currentMonthStr-08',
        'amount': 3.2,
        'remainingAmount': 3.2,
        'unit': 'g',
        'description': 'Gold acquired',
        'purchaseCurrency': 'SAR',
        'purchaseAmount': 2000.0,
        'fundingAllocations': <Map<String, dynamic>>[
          <String, dynamic>{
            'sourceSavingId': 'some_source_id',
            'amount': 2000.0,
          }
        ],
        'createdAt': '$year-$currentMonthStr-08T00:00:00.000Z',
      }
    ];

    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(seeded),
    });
    
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    
    // 1. Verify Top Expense Categories excludes transfers
    await _scrollToText(tester, 'Top Expense Categories');
    final Finder cardFinder = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_TopExpenseCategoriesCard');
    
    // Food category should be displayed (100% of total expenses, since transfers are excluded)
    expect(find.descendant(of: cardFinder, matching: find.text('Food')), findsOneWidget);
    expect(find.descendant(of: cardFinder, matching: find.text('100%')), findsOneWidget);
    
    // Transfers must NOT be listed in Top Expense Categories
    expect(find.descendant(of: cardFinder, matching: find.text('Currency Exchange')), findsNothing);
    expect(find.descendant(of: cardFinder, matching: find.text('Gold Purchase')), findsNothing);

    // 2. Verify Recent Activity displays the grouped transfers
    await _scrollToText(tester, 'Recent Activity');
    
    // Currency Exchange grouped row is present
    expect(find.text('Currency Exchange'), findsOneWidget);
    expect(find.text('SAR 5,000 → USD 1,333'), findsOneWidget);
    expect(find.byKey(const Key('dashboardRecentTransferIcon')), findsWidgets);
    
    // Gold Purchase grouped row is present
    expect(find.text('Gold Purchase'), findsOneWidget);
    expect(find.text('3.2g Gold • SAR 2,000'), findsOneWidget);
  });
}
