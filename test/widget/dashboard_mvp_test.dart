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

Future<void> _openAction(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(const Key('addEntryFab')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> _addIncome(WidgetTester tester, String amount) async {
  await _openAction(tester, const Key('actionAddTransaction'));
  await tester.enterText(find.byKey(const Key('amountField')), amount);
  await tester.tap(find.byKey(const Key('categoryField')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Salary').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('saveTransactionButton')));
  await tester.pumpAndSettle();
}

Future<void> _addSaving(WidgetTester tester, String amount) async {
  await _openAction(tester, const Key('actionAddSaving'));
  await tester.enterText(find.byKey(const Key('savingAmountField')), amount);
  await tester.tap(find.byKey(const Key('saveSavingButton')));
  await tester.pumpAndSettle();
}

Future<void> _addInvestment(WidgetTester tester, String value) async {
  await _openAction(tester, const Key('actionAddInvestment'));
  await tester.enterText(
      find.byKey(const Key('investmentNameField')), 'Dashboard Property');
  await tester.enterText(
      find.byKey(const Key('investmentCurrentValueField')), value);
  await tester.ensureVisible(find.byKey(const Key('saveInvestmentButton')));
  await tester.tap(find.byKey(const Key('saveInvestmentButton')));
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

  testWidgets('adding transaction updates income/expense',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addIncome(tester, '1200');

    expect(find.text('Total Income'), findsOneWidget);
    expect(find.textContaining('E£ 1,200.00'), findsWidgets);
    expect(find.text('Total Expenses'), findsOneWidget);
  });

  testWidgets('adding saving updates savings wealth',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addSaving(tester, '700');

    expect(find.text('Total Savings Wealth'), findsOneWidget);
    expect(find.textContaining('E£ 700.00'), findsWidgets);
  });

  testWidgets('adding investment updates investment wealth',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addInvestment(tester, '500000');

    expect(find.text('Investment Wealth'), findsOneWidget);
    expect(find.textContaining('E£ 500,000.00'), findsWidgets);
  });

  testWidgets('nisab status appears', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addIncome(tester, '100');

    expect(find.text('Zakat Summary'), findsOneWidget);
    expect(find.text('Nisab Status'), findsOneWidget);
    expect(find.text('Current Nisab Threshold'), findsOneWidget);
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

    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.text('Recent Activity'), findsOneWidget);

    final Finder tiles = find.byWidgetPredicate(
      (Widget w) =>
          w is ListTile &&
          w.key != null &&
          w.key.toString().contains('dashboardRecentTx_'),
    );
    expect(tiles, findsNWidgets(4));
  });

  testWidgets('View All goes to Activity tab', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addIncome(tester, '111');

    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dashboardViewAllActivityButton')));
    await tester.pumpAndSettle();

    expect(find.text('Activity'), findsWidgets);
    expect(find.text('All'), findsWidgets);
  });
}
