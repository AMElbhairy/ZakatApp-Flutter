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

Future<void> _openAddInvestment(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('addEntryFab')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('actionAddInvestment')));
  await tester.pumpAndSettle();
}

Future<void> _addInvestment(
  WidgetTester tester, {
  required String assetType,
  required String name,
  required String currentValue,
  String ownership = '100',
}) async {
  await _openAddInvestment(tester);

  await tester.tap(find.byKey(const Key('investmentTypeField')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(assetType).last);
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('investmentNameField')), name);
  await tester.enterText(
      find.byKey(const Key('investmentCurrentValueField')), currentValue);
  await tester.enterText(
      find.byKey(const Key('investmentOwnershipField')), ownership);

  await tester.ensureVisible(find.byKey(const Key('saveInvestmentButton')));
  await tester.tap(find.byKey(const Key('saveInvestmentButton')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('add property', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addInvestment(
      tester,
      assetType: 'Property',
      name: 'Cairo Apartment',
      currentValue: '1000000',
    );

    await tester.tap(find.text('Assets').first);
    await tester.pumpAndSettle();

    expect(find.text('Property'), findsOneWidget);
    expect(find.text('Cairo Apartment'), findsOneWidget);
  });

  testWidgets('add company share', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addInvestment(
      tester,
      assetType: 'Company Share',
      name: 'Listed Shares',
      currentValue: '250000',
    );

    await tester.tap(find.text('Assets').first);
    await tester.pumpAndSettle();

    expect(find.text('Company Shares'), findsOneWidget);
    expect(find.text('Listed Shares'), findsOneWidget);
  });

  testWidgets('edit investment and persistence survives reload',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addInvestment(
      tester,
      assetType: 'Property',
      name: 'Villa',
      currentValue: '900000',
    );

    await tester.tap(find.text('Assets').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Villa').first);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('investmentCurrentValueField')), '950000');
    await tester.ensureVisible(find.byKey(const Key('saveInvestmentButton')));
    await tester.tap(find.byKey(const Key('saveInvestmentButton')));
    await tester.pumpAndSettle();

    expect(find.text('950000.00'), findsWidgets);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Assets').first);
    await tester.pumpAndSettle();

    expect(find.text('950000.00'), findsWidgets);
  });

  testWidgets('delete investment', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addInvestment(
      tester,
      assetType: 'Property',
      name: 'Delete Me',
      currentValue: '120000',
    );

    await tester.tap(find.text('Assets').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Me'), findsNothing);
  });

  testWidgets('dashboard wealth includes investment',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addInvestment(
      tester,
      assetType: 'Property',
      name: 'Dashboard Asset',
      currentValue: '500000',
    );

    expect(find.text('Investment Wealth'), findsOneWidget);
    expect(find.text('Total Wealth'), findsOneWidget);
    expect(find.textContaining('E£ '), findsWidgets);
  });
}
