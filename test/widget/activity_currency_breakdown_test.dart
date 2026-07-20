import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/core/constants/storage_keys.dart';
import 'package:zakatapp_flutter/main.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/models/user_profile.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/auth_controller.dart';
import 'package:zakatapp_flutter/services/auth_service.dart';
import 'package:zakatapp_flutter/services/google_sheets_service.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/market_data_api_service.dart';
import 'package:zakatapp_flutter/services/sync_controller.dart';

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
  Future<Map<String, double>?> fetchFxRatesToEgp() async {
    return <String, double>{
      'USD': 50.0,
      'SAR': 13.333333,
      'AED': 13.6,
      'EUR': 54.0,
      'GBP': 63.0,
      'EGP': 1.0,
    };
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

class _FakeSheets extends GoogleSheetsService {
  _FakeSheets() : super(httpClient: null);
}

Future<MultiProvider> _buildApp() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.setBool(StorageKeys.onboardingCompletedKey, true);

  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository = AppStateRepository(
    localStorage: localStorage,
  );
  final AppStateController appStateController = AppStateController(
    repository: repository,
    marketDataApiService: _FakeMarketDataApiService(),
    enableBackgroundSync: false,
    enableMarketAutoRefresh: false,
  );
  final AuthController authController = AuthController(
    authService: _FakeAuthService(),
    localStorage: localStorage,
  );
  final SyncController syncController = SyncController(
    appStateController: appStateController,
    authController: authController,
    googleSheetsService: _FakeSheets(),
  );

  await appStateController.load();
  await appStateController.refreshMarketData(force: true);

  final List<Transaction> transactions = <Transaction>[
    Transaction(
      id: 'inc-egp',
      type: 'income',
      date: '2026-07-01',
      amount: 2450800.25,
      currency: 'EGP',
      category: 'Salary',
      description: 'Egypt income',
      createdAt: '2026-07-01T08:00:00.000Z',
      rolledOver: false,
    ),
    Transaction(
      id: 'inc-usd',
      type: 'income',
      date: '2026-07-01',
      amount: 18240.50,
      currency: 'USD',
      category: 'Salary',
      description: 'US income',
      createdAt: '2026-07-01T09:00:00.000Z',
      rolledOver: false,
    ),
    Transaction(
      id: 'inc-sar',
      type: 'income',
      date: '2026-07-01',
      amount: 1052.45,
      currency: 'SAR',
      category: 'Salary',
      description: 'Saudi income',
      createdAt: '2026-07-01T10:00:00.000Z',
      rolledOver: false,
    ),
    Transaction(
      id: 'inc-aed',
      type: 'income',
      date: '2026-07-01',
      amount: 350.0,
      currency: 'AED',
      category: 'Salary',
      description: 'UAE income',
      createdAt: '2026-07-01T11:00:00.000Z',
      rolledOver: false,
    ),
    Transaction(
      id: 'inc-eur',
      type: 'income',
      date: '2026-07-01',
      amount: 250.0,
      currency: 'EUR',
      category: 'Salary',
      description: 'Euro income',
      createdAt: '2026-07-01T12:00:00.000Z',
      rolledOver: false,
    ),
    Transaction(
      id: 'inc-gbp',
      type: 'income',
      date: '2026-07-01',
      amount: 100.0,
      currency: 'GBP',
      category: 'Salary',
      description: 'UK income',
      createdAt: '2026-07-01T13:00:00.000Z',
      rolledOver: false,
    ),
  ];

  await appStateController.addTransactions(transactions);

  return MultiProvider(
    providers: <ChangeNotifierProvider<dynamic>>[
      ChangeNotifierProvider<AppStateController>.value(
        value: appStateController,
      ),
      ChangeNotifierProvider<AuthController>.value(value: authController),
      ChangeNotifierProvider<SyncController>.value(value: syncController),
    ],
    child: ZakatApp(preferences: preferences),
  );
}

void main() {
  testWidgets('income summary shows and hides currency breakdown overlay', (
    WidgetTester tester,
  ) async {
    final MultiProvider app = await _buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activity').first);
    await tester.pumpAndSettle();

    final Finder incomeCell = find
        .descendant(
          of: find.byKey(const Key('activitySummaryCard')),
          matching: find.text('Income'),
        )
        .first;
    final Offset beforePosition = tester.getTopLeft(incomeCell);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(incomeCell),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 120));

    expect(
      find.byKey(const Key('activityCurrencyBreakdownOverlay')),
      findsOneWidget,
    );
    expect(find.text('Income by currency'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('activityCurrencyBreakdownBubble')),
        matching: find.text('USD'),
      ),
      findsOneWidget,
    );

    final Offset duringPosition = tester.getTopLeft(incomeCell);
    expect((duringPosition - beforePosition).distance, lessThan(0.5));

    await gesture.up();
    await tester.pump();

    expect(
      find.byKey(const Key('activityCurrencyBreakdownOverlay')),
      findsNothing,
    );
    expect(
      (tester.getTopLeft(incomeCell) - beforePosition).distance,
      lessThan(0.5),
    );
  });
}
