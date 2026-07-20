import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/core/i18n/app_localizations.dart';
import 'package:zakatapp_flutter/core/theme/app_theme.dart';
import 'package:zakatapp_flutter/models/user_profile.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/screens/account/account_screen.dart';
import 'package:zakatapp_flutter/screens/app_shell.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/auth_controller.dart';
import 'package:zakatapp_flutter/services/auth_service.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/market_data_api_service.dart';
import 'package:zakatapp_flutter/services/smart_capture_alert_service.dart';

class _FakeAuthService implements AuthService {
  static const UserProfile _defaultUser = UserProfile(
    id: 'test-user',
    email: 'test@example.com',
    displayName: 'Test User',
    provider: 'google',
    accessToken: 'token',
  );

  @override
  Future<bool> ensureSession() async => true;

  @override
  Future<UserProfile?> restoreSession() async => _defaultUser;

  @override
  Future<UserProfile?> signIn({
    AuthProvider provider = AuthProvider.google,
  }) async => _defaultUser;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

Widget _buildAccountApp({
  required Locale locale,
  required ThemeMode themeMode,
}) {
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository = AppStateRepository(
    localStorage: localStorage,
  );

  return MultiProvider(
    providers: <SingleChildWidget>[
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
          authService: _FakeAuthService(),
          localStorage: localStorage,
        ),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: SafeArea(child: AccountScreen())),
    ),
  );
}

Widget _buildShellApp({required Locale locale, required ThemeMode themeMode}) {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository = AppStateRepository(
    localStorage: localStorage,
  );

  return MultiProvider(
    providers: <SingleChildWidget>[
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
          authService: _FakeAuthService(),
          localStorage: localStorage,
        ),
      ),
      Provider<SmartCaptureAlertService>.value(
        value: const NoopSmartCaptureAlertService(),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AppShell(),
    ),
  );
}

Future<void> _pumpAtWidth(
  WidgetTester tester, {
  required double width,
  required Widget child,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 1600);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(child);
  await tester.pumpAndSettle();
}

Future<void> _expectNoOverflow(
  WidgetTester tester, {
  required Widget Function({
    required Locale locale,
    required ThemeMode themeMode,
  })
  builder,
  required List<double> widths,
  required List<Locale> locales,
  required List<ThemeMode> themeModes,
}) async {
  for (final ThemeMode themeMode in themeModes) {
    for (final Locale locale in locales) {
      for (final double width in widths) {
        await _pumpAtWidth(
          tester,
          width: width,
          child: builder(locale: locale, themeMode: themeMode),
        );
        expect(
          tester.takeException(),
          isNull,
          reason:
              'Unexpected Flutter exception at width=$width locale=${locale.languageCode} themeMode=$themeMode',
        );
      }
    }
  }
}

void main() {
  testWidgets('account screen stays within bounds on narrow widths', (
    WidgetTester tester,
  ) async {
    await _expectNoOverflow(
      tester,
      builder: _buildAccountApp,
      widths: const <double>[360, 375, 390, 430],
      locales: const <Locale>[Locale('en')],
      themeModes: const <ThemeMode>[ThemeMode.light, ThemeMode.dark],
    );
  });

  testWidgets('shell assets tab stays within bounds on narrow widths', (
    WidgetTester tester,
  ) async {
    await _expectNoOverflow(
      tester,
      builder: _buildShellApp,
      widths: const <double>[360, 375, 390, 430],
      locales: const <Locale>[Locale('en')],
      themeModes: const <ThemeMode>[ThemeMode.light, ThemeMode.dark],
    );
  });
}
