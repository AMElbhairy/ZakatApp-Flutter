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

Future<void> _openAddSaving(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('addEntryFab')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('actionAddSaving')));
  await tester.pumpAndSettle();
}

Future<void> _addCashSaving(WidgetTester tester, String amount) async {
  await _openAddSaving(tester);
  await tester.enterText(find.byKey(const Key('savingAmountField')), amount);
  await tester.enterText(find.byKey(const Key('savingNotesField')), 'Cash Wallet');
  await tester.tap(find.byKey(const Key('saveSavingButton')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('add cash saving', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addCashSaving(tester, '500');

    await tester.tap(find.text('Assets').last);
    await tester.pumpAndSettle();

    expect(find.text('500.00'), findsWidgets);
    expect(find.text('Total Cash'), findsOneWidget);
  });

  testWidgets('add gold and silver saving', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _openAddSaving(tester);
    await tester.tap(find.byKey(const Key('savingTypeField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gold').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('savingAmountField')), '20');
    await tester.tap(find.byKey(const Key('saveSavingButton')));
    await tester.pumpAndSettle();

    await _openAddSaving(tester);
    await tester.tap(find.byKey(const Key('savingTypeField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Silver').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('savingAmountField')), '70');
    await tester.tap(find.byKey(const Key('saveSavingButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Assets').last);
    await tester.pumpAndSettle();

    expect(find.text('Total Gold (g)'), findsOneWidget);
    expect(find.text('Total Silver (g)'), findsOneWidget);
    expect(find.text('20.00'), findsWidgets);
    expect(find.text('70.00'), findsWidgets);
  });

  testWidgets('edit saving and persist after reload', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addCashSaving(tester, '400');

    await tester.tap(find.text('Assets').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('savingAmountField')), '900');
    await tester.tap(find.byKey(const Key('saveSavingButton')));
    await tester.pumpAndSettle();

    expect(find.text('900.00'), findsWidgets);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Assets').last);
    await tester.pumpAndSettle();

    expect(find.text('900.00'), findsWidgets);
  });

  testWidgets('delete saving', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addCashSaving(tester, '220');

    await tester.tap(find.text('Assets').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('assetsEmptyState')), findsOneWidget);
  });
}
