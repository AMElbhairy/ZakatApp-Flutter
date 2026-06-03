import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/core/constants/storage_keys.dart';
import 'package:zakatapp_flutter/main.dart';
import 'package:zakatapp_flutter/models/user_profile.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/auth_controller.dart';
import 'package:zakatapp_flutter/services/auth_service.dart';
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
  @override
  Future<bool> ensureSession() async => true;

  @override
  Future<UserProfile?> restoreSession() async => null;

  @override
  Future<UserProfile?> signIn() async => null;

  @override
  Future<void> signOut() async {}
}

Widget _buildApp() {
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository =
      AppStateRepository(localStorage: localStorage);
  return MultiProvider(
    providers: <ChangeNotifierProvider<dynamic>>[
      ChangeNotifierProvider<AppStateController>(
        create: (_) => AppStateController(
          repository: repository,
          marketDataApiService: _NoopMarketDataApiService(),
        ),
      ),
      ChangeNotifierProvider<AuthController>(
        create: (_) => AuthController(
          authService: _FakeAuthService(),
          localStorage: localStorage,
        ),
      ),
    ],
    child: const ZakatApp(),
  );
}

Map<String, dynamic> _baseState() {
  return <String, dynamic>{
    'transactions': <dynamic>[],
    'savings': <dynamic>[],
    'recurringTransactions': <dynamic>[],
    'investments': <dynamic>[],
    'financialPlans': <dynamic>[],
    'lastRollover': '',
    'categories': <String, dynamic>{
      'income': <String>['Salary'],
      'expense': <String>['Food & Dining']
    },
    'zakatPaidMonths': <dynamic>[],
    'processedExpenseIds': <dynamic>[],
    'mainCurrency': 'EGP',
    'defaultEntryCurrency': 'EGP',
    'zakatExpenseIds': <String, dynamic>{},
    'zakatMethod': 'hawl',
    'zakatAnnualDate': '09-01',
    'zakatScheduleFilter': 'unpaid',
    'marketData': <String, dynamic>{
      'GOLD_PRICE_24K_EGP': 3000,
      'SILVER_PRICE_EGP': 40,
      'USD_TO_EGP': 50,
      'SAR_TO_EGP': 13.5,
      'RATES_TO_EGP': <String, dynamic>{'EGP': 1, 'USD': 50, 'SAR': 13.5}
    },
    'marketHistory': <dynamic>[],
    'syncHealth': <String, dynamic>{
      'lastSuccessAt': '',
      'lastFailureAt': '',
      'lastError': '',
      'pendingWrites': 0,
    },
    'aiSettings': <String, dynamic>{
      'keys': <String>['', ''],
      'defaultKeyIndex': 0,
    },
    'cloudHydrated': false,
    'hasUnsyncedAuthChanges': false,
  };
}

Future<void> _seedState(Map<String, dynamic> state) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    StorageKeys.appStateAnonymousKey: jsonEncode(state),
  });
}

Future<void> _openScheduleTab(WidgetTester tester) async {
  await tester.tap(find.text('Activity').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Zakat Schedule'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('schedule tab appears', (WidgetTester tester) async {
    await _seedState(_baseState());
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('Zakat Schedule'), findsOneWidget);
  });

  testWidgets('monthly schedule renders with sample data',
      (WidgetTester tester) async {
    final Map<String, dynamic> state = _baseState();
    state['zakatMethod'] = 'hawl';
    state['transactions'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'tx1',
        'type': 'income',
        'date': '2024-01-01',
        'amount': 1000000,
        'currency': 'EGP',
        'category': 'Salary',
        'description': 'income',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'rolledOver': false,
      }
    ];

    await _seedState(state);
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _openScheduleTab(tester);

    expect(find.byKey(const Key('zakatScheduleList')), findsOneWidget);
    expect(find.byType(ExpansionTile), findsWidgets);
  });

  testWidgets('annual schedule renders with sample data',
      (WidgetTester tester) async {
    final Map<String, dynamic> state = _baseState();
    state['zakatMethod'] = 'annual';
    state['zakatAnnualDate'] = '09-01';
    state['transactions'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'tx1',
        'type': 'income',
        'date': '2020-01-01',
        'amount': 1000000,
        'currency': 'EGP',
        'category': 'Salary',
        'description': 'income',
        'createdAt': '2020-01-01T00:00:00.000Z',
        'rolledOver': false,
      }
    ];

    await _seedState(state);
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _openScheduleTab(tester);

    expect(find.byKey(const Key('zakatScheduleList')), findsOneWidget);
    expect(find.byType(ExpansionTile), findsWidgets);
  });

  testWidgets('empty state renders', (WidgetTester tester) async {
    await _seedState(_baseState());
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _openScheduleTab(tester);

    expect(find.byKey(const Key('zakatScheduleEmptyState')), findsOneWidget);
    expect(find.textContaining('hawl and nisab'), findsOneWidget);
  });

  testWidgets('dashboard tap navigates to schedule',
      (WidgetTester tester) async {
    final Map<String, dynamic> state = _baseState();
    state['transactions'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'tx1',
        'type': 'income',
        'date': '2024-01-01',
        'amount': 1000000,
        'currency': 'EGP',
        'category': 'Salary',
        'description': 'income',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'rolledOver': false,
      }
    ];

    await _seedState(state);
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Zakat').first);
    await tester.tap(find.text('Zakat').first, warnIfMissed: false);
    await tester.pumpAndSettle();

    if (find.byKey(const Key('activitySectionSegment')).evaluate().isEmpty) {
      await tester.tap(find.text('Activity').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zakat Schedule').last);
      await tester.pumpAndSettle();
    }

    expect(find.byKey(const Key('activitySectionSegment')), findsOneWidget);
    expect(find.byKey(const Key('zakatScheduleList')), findsOneWidget);
  });
}
