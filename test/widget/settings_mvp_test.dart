import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/main.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/market_data_api_service.dart';
import 'dart:convert';

Widget _buildApp() {
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository =
      AppStateRepository(localStorage: localStorage);
  return ChangeNotifierProvider<AppStateController>(
    create: (_) => AppStateController(repository: repository),
    child: const ZakatApp(),
  );
}

Widget _buildAppWithService(MarketDataApiService service) {
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository =
      AppStateRepository(localStorage: localStorage);
  return ChangeNotifierProvider<AppStateController>(
    create: (_) =>
        AppStateController(repository: repository, marketDataApiService: service),
    child: const ZakatApp(),
  );
}

class _FakeMarketDataApiService implements MarketDataApiService {
  @override
  Future<Map<String, double>?> fetchFxRatesToEgp() async =>
      <String, double>{'USD': 50, 'SAR': 13.3, 'AED': 13.6};

  @override
  Future<double?> fetchGold24kPerGramEgp() async => null;

  @override
  Future<double?> fetchSilverPerGramEgp() async => null;
}

Future<void> _openSettings(WidgetTester tester) async {
  final Finder navAccount = find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text('Account'),
  );
  await tester.tap(navAccount.last);
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
    await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
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

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('zakatAppData');
    expect(raw, isNotNull);
    final Map<String, dynamic> json = jsonDecode(raw!) as Map<String, dynamic>;
    expect(json['mainCurrency'], 'QAR');
    expect(json['defaultEntryCurrency'], 'AED');
    expect(json['zakatMethod'], 'annual');
  });

  testWidgets('save/load market snapshot', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _openSettings(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('marketGoldField')), '5200');
    await tester.enterText(find.byKey(const Key('marketSilverField')), '62.5');
    await tester.enterText(find.byKey(const Key('marketUsdField')), '50');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('saveMarketDataButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveMarketDataButton')));
    await tester.pumpAndSettle();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = prefs.getString('zakatAppData')!;
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    final String lastUpdated = (json['marketData'] as Map<String, dynamic>)['LAST_UPDATED'] as String;
    expect(() => DateTime.parse(lastUpdated), returnsNormally);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await _openSettings(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await tester.pumpAndSettle();

    final TextFormField goldField =
        tester.widget<TextFormField>(find.byKey(const Key('marketGoldField')));
    final TextFormField silverField =
        tester.widget<TextFormField>(find.byKey(const Key('marketSilverField')));
    final TextFormField usdField =
        tester.widget<TextFormField>(find.byKey(const Key('marketUsdField')));

    expect(goldField.controller?.text, '5200');
    expect(silverField.controller?.text, '62.5');
    expect(usdField.controller?.text, '50');
  });

  testWidgets('old formatted lastUpdated still displays safely',
      (WidgetTester tester) async {
    final Map<String, dynamic> seededState = <String, dynamic>{
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
        'LAST_UPDATED': '2026-05-31 10:45',
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
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(seededState),
    });
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _openSettings(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(find.textContaining('Last updated:'), findsOneWidget);
  });

  testWidgets('settings refresh button triggers refresh',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildAppWithService(_FakeMarketDataApiService()));
    await tester.pumpAndSettle();

    await _openSettings(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('refreshMarketDataButton')));
    await tester.pumpAndSettle();

    expect(find.text('Market data refreshed.'), findsOneWidget);
  });
}
