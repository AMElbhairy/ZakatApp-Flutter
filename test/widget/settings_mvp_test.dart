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

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.text('Account').first);
  await tester.pumpAndSettle();
}

Future<void> _setDropdownString(
  WidgetTester tester, {
  required Key fieldKey,
  required String value,
}) async {
  await tester.ensureVisible(find.byKey(fieldKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(fieldKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('settings screen renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _openSettings(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Currency'), findsOneWidget);
    expect(find.text('Zakat Calculation'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Backup & Sync'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });

  testWidgets('update main currency persists', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _openSettings(tester);
    await _setDropdownString(
      tester,
      fieldKey: const Key('settingsMainCurrencyField'),
      value: 'SAR',
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await _openSettings(tester);

    expect(find.text('SAR'), findsWidgets);
  });

  testWidgets('update default entry currency persists',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _openSettings(tester);
    await _setDropdownString(
      tester,
      fieldKey: const Key('settingsDefaultEntryCurrencyField'),
      value: 'USD',
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await _openSettings(tester);

    expect(find.text('USD'), findsWidgets);
  });

  testWidgets('update zakat method persists', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _openSettings(tester);
    await _setDropdownString(
      tester,
      fieldKey: const Key('settingsZakatMethodField'),
      value: 'Annual',
    );

    expect(find.byKey(const Key('settingsAnnualDateSection')), findsOneWidget);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await _openSettings(tester);

    expect(find.byKey(const Key('settingsAnnualDateSection')), findsOneWidget);
  });

  testWidgets('annual date fields shown only for annual',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _openSettings(tester);

    expect(find.byKey(const Key('settingsAnnualDateSection')), findsNothing);

    await _setDropdownString(
      tester,
      fieldKey: const Key('settingsZakatMethodField'),
      value: 'Annual',
    );

    expect(find.byKey(const Key('settingsAnnualDateSection')), findsOneWidget);
  });

  testWidgets('values survive reload', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _openSettings(tester);
    await _setDropdownString(
      tester,
      fieldKey: const Key('settingsMainCurrencyField'),
      value: 'QAR',
    );
    await _setDropdownString(
      tester,
      fieldKey: const Key('settingsDefaultEntryCurrencyField'),
      value: 'AED',
    );
    await _setDropdownString(
      tester,
      fieldKey: const Key('settingsZakatMethodField'),
      value: 'Annual',
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await _openSettings(tester);

    expect(find.text('QAR'), findsWidgets);
    expect(find.text('AED'), findsWidgets);
    expect(find.byKey(const Key('settingsAnnualDateSection')), findsOneWidget);
  });
}
