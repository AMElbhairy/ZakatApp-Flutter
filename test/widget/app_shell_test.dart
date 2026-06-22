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
import 'package:zakatapp_flutter/screens/app_shell.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/auth_controller.dart';
import 'package:zakatapp_flutter/services/auth_service.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
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

void main() {
  testWidgets('app launches and shell tabs are visible', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const LocalStorageService localStorage = LocalStorageService();
    final AppStateRepository repository = AppStateRepository(
      localStorage: localStorage,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppStateController>(
            create: (_) => AppStateController(repository: repository),
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
          home: const AppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Assets'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Plans'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);

    // Dashboard placeholder title is visible by default.
    expect(find.text('Dashboard'), findsWidgets);
  });

  testWidgets('add FAB is only visible on Activity tab', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const LocalStorageService localStorage = LocalStorageService();
    final AppStateRepository repository = AppStateRepository(
      localStorage: localStorage,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppStateController>(
            create: (_) => AppStateController(repository: repository),
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
          home: const AppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('addEntryFab')), findsNothing);

    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('addEntryFab')), findsOneWidget);
  });

  testWidgets('app still starts with corrupted local state JSON', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': '{not-json',
    });
    const LocalStorageService localStorage = LocalStorageService();
    final AppStateRepository repository = AppStateRepository(
      localStorage: localStorage,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppStateController>(
            create: (_) => AppStateController(repository: repository),
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
          home: const AppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.byKey(const Key('dashboardEmptyCard')), findsOneWidget);
  });

  testWidgets('system back from a main tab returns to Dashboard', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const LocalStorageService localStorage = LocalStorageService();
    final AppStateRepository repository = AppStateRepository(
      localStorage: localStorage,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: <ChangeNotifierProvider<dynamic>>[
          ChangeNotifierProvider<AppStateController>(
            create: (_) => AppStateController(repository: repository),
          ),
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(
              authService: _FakeAuthService(),
              localStorage: localStorage,
            ),
          ),
        ],
        child: MaterialApp(
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
          home: const AppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Assets').last);
    await tester.pumpAndSettle();
    expect(find.text('TOTAL ASSETS'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboardEmptyCard')), findsOneWidget);
  });
}
