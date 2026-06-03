import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
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

class _FakeAuthService implements AuthService {
  @override
  Future<bool> ensureSession() async => true;

  @override
  Future<UserProfile?> restoreSession() async => null;

  @override
  Future<UserProfile?> signIn() async => null;

  @override
  Future<void> signOut() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App shell renders locked navigation', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    const LocalStorageService localStorage = LocalStorageService();
    final AppStateController appStateController = AppStateController(
      repository: AppStateRepository(localStorage: localStorage),
    );
    final AuthController authController = AuthController(
      authService: _FakeAuthService(),
      localStorage: localStorage,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppStateController>.value(value: appStateController),
          ChangeNotifierProvider<AuthController>.value(value: authController),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
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

    await tester.pump();

    expect(find.byKey(const Key('premiumBottomNav')), findsOneWidget);
    expect(find.byKey(const Key('addEntryFab')), findsOneWidget);
    expect(find.text('Assets'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Plans'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });
}
