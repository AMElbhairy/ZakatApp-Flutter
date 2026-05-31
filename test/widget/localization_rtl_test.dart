import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/main.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

Widget _buildApp() {
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository =
      AppStateRepository(localStorage: localStorage);
  return ChangeNotifierProvider<AppStateController>(
    create: (_) => AppStateController(repository: repository),
    child: const ZakatApp(),
  );
}

void main() {
  testWidgets('English default renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
  });

  testWidgets('Arabic mode renders Arabic labels and RTL',
      (WidgetTester tester) async {
    final Map<String, dynamic> seeded = <String, dynamic>{
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
      'marketData': <String, dynamic>{},
      'marketHistory': <dynamic>[],
      'syncHealth': <String, dynamic>{
        'lastSuccessAt': '',
        'lastFailureAt': '',
        'lastError': '',
        'pendingWrites': 0,
      },
      'languagePreference': 'ar',
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(seeded),
    });
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.text('لوحة التحكم'), findsWidgets);
    final Directionality dir =
        tester.widget<Directionality>(find.byType(Directionality).first);
    expect(dir.textDirection, TextDirection.rtl);
  });

  testWidgets('language persists after reload', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final BuildContext ctx = tester.element(find.byType(MaterialApp));
    await Provider.of<AppStateController>(ctx, listen: false)
        .updateLanguagePreference('ar');
    await tester.pumpAndSettle();

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.text('لوحة التحكم'), findsWidgets);
  });
}
