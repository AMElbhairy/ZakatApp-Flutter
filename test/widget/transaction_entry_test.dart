import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/main.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'dart:convert';

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
      'RATES_TO_EGP': <String, dynamic>{'EGP': 1, 'USD': 50, 'SAR': 13.3},
      'LAST_UPDATED': '2026-05-31T10:00:00Z',
    },
    'marketHistory': <dynamic>[],
    'syncHealth': <String, dynamic>{
      'lastSuccessAt': '',
      'lastFailureAt': '',
      'lastError': '',
      'pendingWrites': 0,
    },
    'aiSettings': <String, dynamic>{'keys': <String>['', ''], 'defaultKeyIndex': 0},
    'cloudHydrated': false,
    'hasUnsyncedAuthChanges': false,
  };
}

Widget _buildApp() {
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository =
      AppStateRepository(localStorage: localStorage);
  return ChangeNotifierProvider<AppStateController>(
    create: (_) => AppStateController(repository: repository),
    child: const ZakatApp(),
  );
}

Future<void> _openTransactionForm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('addEntryFab')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('actionAddTransaction')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('save transaction and dashboard updates',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(_seedStateWithMarketData()),
    });

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboardEmptyCard')), findsOneWidget);

    await _openTransactionForm(tester);

    await tester.enterText(find.byKey(const Key('amountField')), '100');

    await tester.tap(find.byKey(const Key('categoryField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salary').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('saveTransactionButton')));
    await tester.pumpAndSettle();

    expect(find.text('Financial Summary'), findsOneWidget);
    expect(find.text('Total Income'), findsOneWidget);
    expect(find.text('E£ 100.00'), findsWidgets);
    expect(find.text('Total Expenses'), findsOneWidget);
  });

  testWidgets('persistence survives reload', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(_seedStateWithMarketData()),
    });

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _openTransactionForm(tester);

    await tester.enterText(find.byKey(const Key('amountField')), '250');

    await tester.tap(find.byKey(const Key('categoryField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salary').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('saveTransactionButton')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Total Income'), findsOneWidget);
    expect(find.text('E£ 250.00'), findsWidgets);
  });
}
