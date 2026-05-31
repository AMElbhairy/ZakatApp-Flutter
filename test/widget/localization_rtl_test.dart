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

Map<String, dynamic> _arabicSeededState({bool withTransaction = false}) {
  return <String, dynamic>{
    'transactions': withTransaction
        ? <dynamic>[
            <String, dynamic>{
              'id': 'tx_1',
              'type': 'income',
              'date': '2026-06-01',
              'amount': 100,
              'currency': 'EGP',
              'category': 'Salary',
              'description': '',
              'createdAt': '2026-06-01T00:00:00Z',
              'rolledOver': false,
            }
          ]
        : <dynamic>[],
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
    final Map<String, dynamic> seeded = _arabicSeededState();
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

  testWidgets('Arabic settings screen has Arabic headers',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(_arabicSeededState()),
    });
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('الحساب').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(find.text('الحساب'), findsWidgets);
    expect(find.text('بيانات السوق'), findsOneWidget);
    expect(find.text('المظهر'), findsOneWidget);
    expect(find.text('Backup & Sync'), findsNothing);
  });

  testWidgets('Arabic action sheet labels are Arabic',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(_arabicSeededState()),
    });
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addEntryFab')));
    await tester.pumpAndSettle();

    expect(find.text('إضافة إدخال'), findsOneWidget);
    expect(find.text('إضافة دخل/مصروف'), findsOneWidget);
    expect(find.text('إضافة ادخار'), findsOneWidget);
  });

  testWidgets('Arabic validation messages are Arabic',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(_arabicSeededState()),
    });
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addEntryFab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('actionAddTransaction')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveTransactionButton')));
    await tester.pumpAndSettle();
    expect(find.text('يجب أن يكون المبلغ أكبر من 0'), findsOneWidget);

  });

  testWidgets('Arabic delete dialogs are Arabic', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(_arabicSeededState(withTransaction: true)),
    });
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('النشاط').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deleteTransaction_tx_1')));
    await tester.pumpAndSettle();
    expect(find.text('حذف المعاملة؟'), findsOneWidget);
    expect(find.text('إلغاء'), findsOneWidget);
    expect(find.text('حذف'), findsOneWidget);
  });
}
