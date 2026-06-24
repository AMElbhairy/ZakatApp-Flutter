import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/core/i18n/app_localizations.dart';
import 'package:zakatapp_flutter/core/theme/app_theme.dart';
import 'package:zakatapp_flutter/core/utils/currency_presentation.dart';
import 'package:zakatapp_flutter/models/user_profile.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/screens/account/account_screen.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/auth_controller.dart';
import 'package:zakatapp_flutter/services/auth_service.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/market_data_api_service.dart';
import 'dart:convert';

class _FakeAuthService implements AuthService {
  static const UserProfile _defaultUser = UserProfile(
    id: 'test-user',
    email: 'test@example.com',
    displayName: 'Test User',
    provider: 'google',
    accessToken: 'token',
  );

  _FakeAuthService({this.user});

  final UserProfile? user;

  @override
  Future<bool> ensureSession() async => true;

  @override
  Future<UserProfile?> restoreSession() async => user ?? _defaultUser;

  @override
  Future<UserProfile?> signIn({
    AuthProvider provider = AuthProvider.google,
  }) async => user ?? _defaultUser;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildApp({AuthService? authService}) {
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository = AppStateRepository(
    localStorage: localStorage,
  );
  return MultiProvider(
    providers: <ChangeNotifierProvider<dynamic>>[
      ChangeNotifierProvider<AppStateController>(
        create: (_) => AppStateController(
          repository: repository,
          marketDataApiService: _FakeMarketDataApiService(),
          enableBackgroundSync: false,
          enableMarketAutoRefresh: false,
        ),
      ),
      ChangeNotifierProvider<AuthController>(
        create: (_) => AuthController(
          authService: authService ?? _FakeAuthService(),
          localStorage: localStorage,
        ),
      ),
    ],
    child: const _SettingsTestApp(),
  );
}

Widget _buildAppWithService(MarketDataApiService service) {
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository = AppStateRepository(
    localStorage: localStorage,
  );
  return MultiProvider(
    providers: <ChangeNotifierProvider<dynamic>>[
      ChangeNotifierProvider<AppStateController>(
        create: (_) => AppStateController(
          repository: repository,
          marketDataApiService: service,
          enableBackgroundSync: false,
          enableMarketAutoRefresh: false,
        ),
      ),
      ChangeNotifierProvider<AuthController>(
        create: (_) => AuthController(
          authService: _FakeAuthService(),
          localStorage: localStorage,
        ),
      ),
    ],
    child: const _SettingsTestApp(),
  );
}

class _SettingsTestApp extends StatelessWidget {
  const _SettingsTestApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: SafeArea(child: AccountScreen())),
    );
  }
}

class _FakeMarketDataApiService implements MarketDataApiService {
  @override
  Future<Map<String, double>?> fetchFxRatesToEgp() async => <String, double>{
    'USD': 50,
    'SAR': 13.3,
    'AED': 13.6,
  };

  @override
  Future<double?> fetchGold24kPerGramEgp({required double usdToEgp}) async =>
      null;

  @override
  Future<double?> fetchSilverPerGramEgp({required double usdToEgp}) async =>
      null;
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

    expect(find.byKey(const Key('settingsMainCurrencyField')), findsOneWidget);
    expect(find.byKey(const Key('settingsZakatMethodField')), findsOneWidget);
    expect(find.byKey(const Key('openCurrencyExchangeButton')), findsNothing);
    expect(find.text('Market Snapshot'), findsOneWidget);
    expect(find.text('Google Drive Backup'), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });

  testWidgets('debug developer diagnostics button is hidden by default', (
    WidgetTester tester,
  ) async {
    if (!kDebugMode) return;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('developerDiagnosticsButton')), findsNothing);
    expect(find.text('Developer Diagnostics'), findsNothing);
  });

  testWidgets('update main currency persists', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _setDropdownString(
      tester,
      fieldKey: const Key('settingsMainCurrencyField'),
      value: CurrencyPresentation.label('SAR'),
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    expect(find.text(CurrencyPresentation.label('SAR')), findsWidgets);
  });

  testWidgets('update default entry currency persists', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _setDropdownString(
      tester,
      fieldKey: const Key('settingsDefaultEntryCurrencyField'),
      value: CurrencyPresentation.label('USD'),
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    expect(find.text(CurrencyPresentation.label('USD')), findsWidgets);
  });

  testWidgets('update theme mode persists', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -1400),
    );
    await tester.pumpAndSettle();

    await _setDropdownString(
      tester,
      fieldKey: const Key('settingsThemeModeField'),
      value: 'Dark',
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('zakatAppData');
    expect(raw, isNotNull);
    final Map<String, dynamic> json = jsonDecode(raw!) as Map<String, dynamic>;
    expect(json['themeMode'], 'dark');
  });

  testWidgets('update zakat method persists', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _setDropdownString(
      tester,
      fieldKey: const Key('settingsZakatMethodField'),
      value: 'Annual',
    );

    expect(find.byKey(const Key('settingsAnnualDateSection')), findsOneWidget);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settingsAnnualDateSection')), findsOneWidget);
  });

  testWidgets('update cash nisab basis persists', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _setDropdownString(
      tester,
      fieldKey: const Key('settingsZakatNisabBasisField'),
      value: '595 g silver 999',
    );

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('zakatAppData');
    expect(raw, isNotNull);
    final Map<String, dynamic> json = jsonDecode(raw!) as Map<String, dynamic>;
    expect(json['zakatNisabBasis'], 'silver595');
  });

  testWidgets('annual date fields shown only for annual', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

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

    await _setDropdownString(
      tester,
      fieldKey: const Key('settingsMainCurrencyField'),
      value: CurrencyPresentation.label('QAR'),
    );
    await _setDropdownString(
      tester,
      fieldKey: const Key('settingsDefaultEntryCurrencyField'),
      value: CurrencyPresentation.label('AED'),
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

  testWidgets('view all market snapshot opens read only page', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('viewAllMarketSnapshotButton')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('viewAllMarketSnapshotButton')));
    await tester.pumpAndSettle();

    expect(find.text('Market Data'), findsOneWidget);
    expect(find.text('Read only'), findsOneWidget);
  });

  testWidgets('settings refresh button triggers refresh', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildAppWithService(_FakeMarketDataApiService()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('refreshMarketDataOverviewButton')),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('refreshMarketDataOverviewButton')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('refreshMarketDataOverviewButton')));
    await tester.pumpAndSettle();

    expect(find.text('Market data refreshed.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('categories section opens manager', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('settingsCategoriesTile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsCategoriesTile')));
    await tester.pumpAndSettle();
    expect(find.text('Manage categories'), findsOneWidget);
  });

  testWidgets('delete all data cancel does nothing', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      _buildApp(
        authService: _FakeAuthService(
          user: const UserProfile(
            id: 'u_1',
            email: 'user@example.com',
            displayName: 'User One',
            provider: 'google',
            photoUrl: null,
            accessToken: 'token',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('settingsSecurityTile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsSecurityTile')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('deleteAccountButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deleteAccountButton')));
    await tester.pumpAndSettle();
    if (find.text('Cancel').evaluate().isNotEmpty) {
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Google Drive Backup'), findsOneWidget);
  });

  testWidgets('backup section shows passive cloud sync status', skip: true, (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -1300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cloud Sync: Active'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
  });
}
