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

Future<void> _addTx(
  WidgetTester tester, {
  required String amount,
  required String category,
  required bool income,
}) async {
  await tester.tap(find.byKey(const Key('addEntryFab')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('actionAddTransaction')));
  await tester.pumpAndSettle();

  if (!income) {
    await tester.tap(find.text('Expense'));
    await tester.pumpAndSettle();
  }

  await tester.enterText(find.byKey(const Key('amountField')), amount);
  await tester.tap(find.byKey(const Key('categoryField')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(category).last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('saveTransactionButton')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('list transactions and filter income/expense',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addTx(tester, amount: '100', category: 'Salary', income: true);
    await _addTx(
      tester,
      amount: '40',
      category: 'Food & Dining',
      income: false,
    );

    await tester.tap(find.text('Activity').first);
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNWidgets(2));

    await tester.tap(find.text('Income').first);
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.textContaining('+100.00 EGP'), findsOneWidget);

    await tester.tap(find.text('Expense').first);
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.textContaining('-40.00 EGP'), findsOneWidget);
  });

  testWidgets('delete transaction with confirmation',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addTx(tester, amount: '100', category: 'Salary', income: true);

    await tester.tap(find.text('Activity').first);
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activityEmptyState')), findsOneWidget);
  });

  testWidgets('edit transaction and persist after reload',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addTx(tester, amount: '100', category: 'Salary', income: true);

    await tester.tap(find.text('Activity').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('amountField')), '250');
    await tester.tap(find.byKey(const Key('saveTransactionButton')));
    await tester.pumpAndSettle();

    expect(find.textContaining('+250.00 EGP'), findsOneWidget);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activity').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('+250.00 EGP'), findsOneWidget);
  });
}
