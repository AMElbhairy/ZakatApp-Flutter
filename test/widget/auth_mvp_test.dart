import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/main.dart';
import 'package:zakatapp_flutter/models/user_profile.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/auth_controller.dart';
import 'package:zakatapp_flutter/services/auth_service.dart';
import 'package:zakatapp_flutter/services/cloud_backup_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/market_data_api_service.dart';

class _FakeAuthService implements AuthService, AuthGateStateSource {
  final StreamController<AuthGateState> _authStateController =
      StreamController<AuthGateState>.broadcast();

  @override
  Future<bool> ensureSession() async => true;

  UserProfile? _user;

  @override
  Stream<AuthGateState> get authGateStateChanges => _authStateController.stream;

  @override
  Future<UserProfile?> signIn({
    AuthProvider provider = AuthProvider.google,
  }) async {
    _user = const UserProfile(
      id: 'u_1',
      email: 'user@example.com',
      displayName: 'User One',
      provider: 'google',
      photoUrl: null,
      accessToken: 'token',
    );
    _authStateController.add(
      AuthGateState(status: AuthGateStatus.signedIn, user: _user),
    );
    return _user;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _authStateController.add(
      const AuthGateState(status: AuthGateStatus.signedOut),
    );
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

class _DelayedMarketDataApiService implements MarketDataApiService {
  final Completer<void> _fxGate = Completer<void>();

  void releaseFx() {
    if (!_fxGate.isCompleted) {
      _fxGate.complete();
    }
  }

  @override
  Future<Map<String, double>?> fetchFxRatesToEgp() async {
    await _fxGate.future;
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

class _TestAppStateController extends AppStateController {
  _TestAppStateController({
    required super.repository,
    required super.marketDataApiService,
  });

  @override
  Future<void> startMarketAutoRefresh({bool refreshImmediately = true}) async {
    if (refreshImmediately) {
      await refreshMarketData(force: true);
    }
  }
}

Widget _buildApp({
  AuthService? authService,
  MarketDataApiService? marketDataApiService,
}) {
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository = AppStateRepository(
    localStorage: localStorage,
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppPrivacyOverlayController>(
        create: (_) => AppPrivacyOverlayController(),
      ),
      ChangeNotifierProvider<AppStateController>(
        create: (_) => _TestAppStateController(
          repository: repository,
          marketDataApiService:
              marketDataApiService ?? _FakeMarketDataApiService(),
        ),
      ),
      ChangeNotifierProvider<AuthController>(
        create: (_) => AuthController(
          authService: authService ?? _FakeAuthService(),
          localStorage: localStorage,
        ),
      ),
      ChangeNotifierProvider<CloudBackupController>(
        create: (BuildContext ctx) => CloudBackupController(
          appStateController: ctx.read<AppStateController>(),
          authController: ctx.read<AuthController>(),
        ),
      ),
    ],
    child: const ZakatApp(),
  );
}

void main() {
  testWidgets('signed-out state renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('googleSignInButton')), findsOneWidget);
    expect(find.byKey(const Key('appleSignInButton')), findsNothing);
    expect(find.byKey(const Key('premiumBottomNav')), findsNothing);
  });

  testWidgets('fake sign-in updates UI', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp(authService: _FakeAuthService()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('googleSignInButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('premiumBottomNav')), findsOneWidget);
  });

  testWidgets('fake sign-out clears UI', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp(authService: _FakeAuthService()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('googleSignInButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Account').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('googleSignOutButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('googleSignInButton')), findsOneWidget);
    expect(find.byKey(const Key('premiumBottomNav')), findsNothing);
  });

  testWidgets('sign in waits for market refresh before showing dashboard', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final _DelayedMarketDataApiService marketService =
        _DelayedMarketDataApiService();

    await tester.pumpWidget(
      _buildApp(
        authService: _FakeAuthService(),
        marketDataApiService: marketService,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('googleSignInButton')));
    await tester.pump();

    expect(find.byKey(const Key('loadingMarketDataStep')), findsOneWidget);
    expect(find.byKey(const Key('premiumBottomNav')), findsNothing);

    marketService.releaseFx();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('premiumBottomNav')), findsOneWidget);
  });

  testWidgets('startup works without auth', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp(authService: _FakeAuthService()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('googleSignInButton')), findsOneWidget);
  });
}
