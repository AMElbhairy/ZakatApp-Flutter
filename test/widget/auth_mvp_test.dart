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
import 'package:zakatapp_flutter/services/market_data_api_service.dart';

class _FakeAuthService implements AuthService {
  UserProfile? _user;

  @override
  Future<UserProfile?> signIn() async {
    _user = const UserProfile(
      id: 'u_1',
      email: 'user@example.com',
      name: 'User One',
      photoUrl: null,
      accessToken: 'token',
    );
    return _user;
  }

  @override
  Future<void> signOut() async {
    _user = null;
  }

  @override
  Future<UserProfile?> restoreSession() async => _user;
}

class _FakeMarketDataApiService implements MarketDataApiService {
  @override
  Future<Map<String, double>?> fetchFxRatesToEgp() async {
    return <String, double>{'USD': 50.0, 'SAR': 13.0, 'EGP': 1.0};
  }
  @override
  Future<double?> fetchGold24kPerGramEgp({required double usdToEgp}) async {
    return 3700.0;
  }
  @override
  Future<double?> fetchSilverPerGramEgp({required double usdToEgp}) async {
    return 40.0;
  }
}

Widget _buildApp({AuthService? authService}) {
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository =
      AppStateRepository(localStorage: localStorage);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppStateController>(
        create: (_) => AppStateController(
          repository: repository,
          marketDataApiService: _FakeMarketDataApiService(),
        ),
      ),
      ChangeNotifierProvider<AuthController>(
        create: (_) => AuthController(
          authService: authService ?? _FakeAuthService(),
          localStorage: localStorage,
        ),
      ),
    ],
    child: const ZakatApp(),
  );
}

Future<void> _openAccount(WidgetTester tester) async {
  await tester.tap(find.text('Account').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signed-out state renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _openAccount(tester);

    expect(find.byKey(const Key('googleSignInButton')), findsOneWidget);
    expect(find.byKey(const Key('googleSignOutButton')), findsNothing);
  });

  testWidgets('fake sign-in updates UI', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp(authService: _FakeAuthService()));
    await tester.pumpAndSettle();

    await _openAccount(tester);
    await tester.tap(find.byKey(const Key('googleSignInButton')));
    await tester.pumpAndSettle();

    expect(find.text('user@example.com'), findsOneWidget);
    expect(find.byKey(const Key('googleSignOutButton')), findsOneWidget);
  });

  testWidgets('fake sign-out clears UI', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp(authService: _FakeAuthService()));
    await tester.pumpAndSettle();

    await _openAccount(tester);
    await tester.tap(find.byKey(const Key('googleSignInButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('googleSignOutButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('googleSignInButton')), findsOneWidget);
    expect(find.text('user@example.com'), findsNothing);
  });

  testWidgets('startup works without auth', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp(authService: _FakeAuthService()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('premiumBottomNav')), findsOneWidget);
  });
}
