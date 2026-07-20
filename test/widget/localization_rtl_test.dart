import 'dart:convert';

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
import 'package:zakatapp_flutter/services/bootstrap_coordinator.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/market_data_api_service.dart';

class _NoopMarketDataApiService implements MarketDataApiService {
  @override
  Future<Map<String, double>?> fetchFxRatesToEgp() async => null;

  @override
  Future<double?> fetchGold24kPerGramEgp({required double usdToEgp}) async =>
      null;

  @override
  Future<double?> fetchSilverPerGramEgp({required double usdToEgp}) async =>
      null;
}

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

Widget _buildApp() {
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository = AppStateRepository(
    localStorage: localStorage,
  );
  return MultiProvider(
    providers: <ChangeNotifierProvider<dynamic>>[
      ChangeNotifierProvider<AppStateController>(
        create: (_) => AppStateController(
          repository: repository,
          marketDataApiService: _NoopMarketDataApiService(),
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
      ChangeNotifierProvider<BootstrapCoordinator>(
        create: (BuildContext ctx) => BootstrapCoordinator(
          dependencies: BootstrapDependencies(
            authController: ctx.read<AuthController>(),
            appStateController: ctx.read<AppStateController>(),
          ),
        ),
      ),
    ],
    child: ZakatApp(preferences: _sharedPrefs),
  );
}

late SharedPreferences _sharedPrefs;

Map<String, dynamic> _seededState({bool withTransaction = false}) {
  return <String, dynamic>{
    'transactions': withTransaction
        ? <dynamic>[
            <String, dynamic>{
              'id': 'tx_1',
              'type': 'income',
              'date': '2026-06-01',
              'amount': 100,
              'currency': 'EGP',
              'category': 'Salary',
              'description': '',
              'createdAt': '2026-06-01T00:00:00Z',
              'rolledOver': false,
            },
          ]
        : <dynamic>[],
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
    'marketData': <String, dynamic>{},
    'marketHistory': <dynamic>[],
    'syncHealth': <String, dynamic>{
      'lastSuccessAt': '',
      'lastFailureAt': '',
      'lastError': '',
      'pendingWrites': 0,
    },
    'languagePreference': 'en',
  };
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _sharedPrefs = await SharedPreferences.getInstance();
    await _sharedPrefs.clear();
  });
  Future<void> openAccountTab(WidgetTester tester) async {
    final Finder navBar = find.byKey(const Key('premiumBottomNav'));
    expect(navBar, findsOneWidget);
    await tester.tap(find.byKey(const Key('bottomNavTab_4')));
    await tester.pumpAndSettle();
  }

  testWidgets('English default renders', (WidgetTester tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboardEmptyCard')), findsOneWidget);
  });

  testWidgets('Seeded Arabic state renders RTL', (WidgetTester tester) async {
    final Map<String, dynamic> seeded = _seededState();
    seeded['languagePreference'] = 'ar';
    await _sharedPrefs.setString('zakatAppData', jsonEncode(seeded));
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboardEmptyCard')), findsOneWidget);
    final Directionality dir = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(dir.textDirection, TextDirection.rtl);
    expect(find.text('الرئيسية'), findsWidgets);
  });

  testWidgets('language persists after reload', (WidgetTester tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final AppStateController controller = Provider.of<AppStateController>(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    await tester.runAsync(() async {
      await controller.load();
    });
    await tester.pumpAndSettle();

    final MaterialApp before = tester.widget<MaterialApp>(find.byType(MaterialApp));
    await controller.updateLanguagePreference('ar');
    await tester.pumpAndSettle();

    final MaterialApp after = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(before.key, isNot(equals(after.key)));
    expect(
      Provider.of<AppStateController>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      ).state.languagePreference,
      'ar',
    );
  });

  testWidgets('Arabic cold launch restarts to English immediately', (
    WidgetTester tester,
  ) async {
    final Map<String, dynamic> seeded = _seededState();
    seeded['languagePreference'] = 'ar';
    await _sharedPrefs.setString('zakatAppData', jsonEncode(seeded));
    await _sharedPrefs.setString('language_preference', 'ar');

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final MaterialApp before = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(before.locale, const Locale('ar'));

    final AppStateController controller = Provider.of<AppStateController>(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    await tester.runAsync(() async {
      await controller.load();
    });
    await tester.pumpAndSettle();

    await controller.updateLanguagePreference('en');
    await tester.pumpAndSettle();

    final MaterialApp after = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(after.locale, const Locale('en'));
    expect(before.key, isNot(equals(after.key)));
    expect(
      Provider.of<AppStateController>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      ).state.languagePreference,
      'en',
    );
  });

  testWidgets(
    'Arabic cold launch queues English restart until hydration is ready',
    (WidgetTester tester) async {
      final Map<String, dynamic> seeded = _seededState();
      seeded['languagePreference'] = 'ar';
      await _sharedPrefs.setString('zakatAppData', jsonEncode(seeded));
      await _sharedPrefs.setString('language_preference', 'ar');

      await tester.pumpWidget(_buildApp());
      await tester.pump();

      final MaterialApp before = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(before.locale, const Locale('ar'));

      final AppStateController controller = Provider.of<AppStateController>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );
      await controller.updateLanguagePreference('en');
      await tester.pump();

      await tester.runAsync(() async {
        await controller.load();
      });
      await tester.pumpAndSettle();

      final MaterialApp after = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(after.locale, const Locale('en'));
      expect(before.key, isNot(equals(after.key)));
      expect(
        Provider.of<AppStateController>(
          tester.element(find.byType(MaterialApp)),
          listen: false,
        ).state.languagePreference,
        'en',
      );
    },
  );

  testWidgets('Arabic settings screen has Arabic headers', (
    WidgetTester tester,
  ) async {
    final Map<String, dynamic> seeded = _seededState();
    seeded['languagePreference'] = 'ar';
    await _sharedPrefs.setString('zakatAppData', jsonEncode(seeded));
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await openAccountTab(tester);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(find.text('التفضيلات'), findsOneWidget);
    expect(find.text('المظهر'), findsOneWidget);
    expect(find.text('اللغة'), findsWidgets);
  });

  testWidgets('English actions stay accessible', (WidgetTester tester) async {
    await _sharedPrefs.setString('zakatAppData', jsonEncode(_seededState()));
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bottomNavTab_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addEntryFab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('actionAddIncome')), findsOneWidget);
    expect(find.byKey(const Key('actionAddExpense')), findsOneWidget);
    expect(find.byKey(const Key('actionAddSaving')), findsOneWidget);
  });
}
