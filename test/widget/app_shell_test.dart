import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/main.dart';
import 'package:zakatapp_flutter/models/user_profile.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
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
  testWidgets('app launches and shell tabs are visible',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const LocalStorageService localStorage = LocalStorageService();
    final AppStateRepository repository =
        AppStateRepository(localStorage: localStorage);

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
        child: const ZakatApp(),
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

  testWidgets('app still starts with corrupted local state JSON',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': '{not-json',
    });
    const LocalStorageService localStorage = LocalStorageService();
    final AppStateRepository repository =
        AppStateRepository(localStorage: localStorage);

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
        child: const ZakatApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.byKey(const Key('dashboardEmptyCard')), findsOneWidget);
  });

  testWidgets('system back from a main tab returns to Dashboard',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const LocalStorageService localStorage = LocalStorageService();
    final AppStateRepository repository =
        AppStateRepository(localStorage: localStorage);

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
        child: const ZakatApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Assets').last);
    await tester.pumpAndSettle();
    expect(find.text('Total Assets'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboardEmptyCard')), findsOneWidget);
  });
}
