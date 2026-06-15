import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/main.dart';
import 'package:zakatapp_flutter/models/saving.dart';
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
  @override
  Future<bool> ensureSession() async => true;

  final UserProfile? user;
  _FakeAuthService(this.user);
  @override
  Future<UserProfile?> signIn({AuthProvider provider = AuthProvider.google}) async => user;
  @override
  Future<UserProfile?> restoreSession() async => user;
  @override
  Future<void> signOut() async {}
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

class _FakeSheets extends GoogleSheetsService {
  _FakeSheets() : super(httpClient: null);
}

void main() {
  testWidgets('dashboard wealth includes investment', (WidgetTester tester) async {
    // 1. Setup mock services and initial state
    SharedPreferences.setMockInitialValues({});
    final localStorage = LocalStorageService();
    final repository = AppStateRepository(localStorage: localStorage);
    final appStateController = AppStateController(
      repository: repository,
      marketDataApiService: _FakeMarketDataApiService(),
    );
    final authController = AuthController(
        authService: _FakeAuthService(null), localStorage: localStorage);
    final syncController = SyncController(
        appStateController: appStateController,
        authController: authController,
        googleSheetsService: _FakeSheets());

    await appStateController.load();

    // 2. Refresh market data using the fake service
    await appStateController.refreshMarketData(force: true);

    // 3. Add a gold saving to the state
    final goldSaving = Saving(
      id: 'gold-1',
      assetType: 'gold',
      dateAcquired: '2024-01-01',
      amount: 10, // 10 grams
      unit: '24', // 24K
      remainingAmount: 10,
      description: '',
      createdAt: '2024-01-01T00:00:00.000Z',
      purchaseAmount: 0,
      purchaseCurrency: 'EGP',
    );
    await appStateController.addSaving(goldSaving);

    // 4. Pump the app widget
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appStateController),
          ChangeNotifierProvider.value(value: authController),
          ChangeNotifierProvider.value(value: syncController),
        ],
        child: const ZakatApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 5. Verify that total wealth includes the value of the gold saving.
    // Gold value = 10g * 3700 EGP/g = 37000 EGP
    expect(find.text('TOTAL WEALTH'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('dashboardHeroCard')),
        matching: find.textContaining('37K'),
      ),
      findsOneWidget,
    );

    // 6. Cleanup controllers to cancel pending timers
    appStateController.dispose();
    authController.dispose();
    syncController.dispose();
  });
}
