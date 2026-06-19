import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/main.dart';
import 'package:zakatapp_flutter/core/widgets/app_ui.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'dart:convert';
import 'package:zakatapp_flutter/models/user_profile.dart';
import 'package:zakatapp_flutter/services/auth_controller.dart';
import 'package:zakatapp_flutter/services/auth_service.dart';
import 'package:zakatapp_flutter/screens/entry/add_transaction_screen.dart';

Map<String, dynamic> _seedStateWithMarketData() {
  return <String, dynamic>{
    'transactions': <dynamic>[],
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
    'marketData': <String, dynamic>{
      'GOLD_PRICE_24K_EGP': 5000,
      'SILVER_PRICE_EGP': 60,
      'USD_TO_EGP': 50,
      'SAR_TO_EGP': 13.3,
      'RATES_TO_EGP': <String, dynamic>{'EGP': 1, 'USD': 50, 'SAR': 13.3},
      'LAST_UPDATED': '2026-05-31T10:00:00Z',
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

class _FakeAuthService implements AuthService {
  @override
  Future<bool> ensureSession() async => true;
  @override
  Future<UserProfile?> restoreSession() async => null;
  @override
  Future<UserProfile?> signIn({
    AuthProvider provider = AuthProvider.google,
  }) async => null;
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
  );
}

Future<void> _openTransactionForm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('addEntryFab')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('actionAddIncome')));
  await tester.pumpAndSettle();
}

void main() {
  test('receipt scan errors are concise and classify transient statuses', () {
    expect(isTransientReceiptScanStatus(503), isTrue);
    expect(isTransientReceiptScanStatus(429), isTrue);
    expect(isTransientReceiptScanStatus(403), isFalse);
    expect(
      receiptScanFailureMessage(503, isArabic: false),
      'Gemini is busy right now. Please try again shortly.',
    );
    expect(
      receiptScanFailureMessage(403, isArabic: false),
      'Gemini API key was rejected. Check it in Settings.',
    );
    expect(
      receiptScanFailureMessage(null, isArabic: false),
      isNot(contains('Exception')),
    );
  });

  testWidgets('top toast constrains long error messages', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: FilledButton(
              onPressed: () => showTopSnackBar(
                context,
                List<String>.filled(30, 'Long API error').join(' '),
              ),
              child: const Text('Show error'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show error'));
    await tester.pump();

    final Text toastText = tester.widget<Text>(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text && widget.data?.contains('Long API error') == true,
      ),
    );
    expect(toastText.maxLines, 3);
    expect(toastText.overflow, TextOverflow.ellipsis);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'AI confirmation shows extracted data and saves selected entries',
    (WidgetTester tester) async {
      List<Map<String, dynamic>>? saved;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: FilledButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => ScannedTransactionsConfirmationDialog(
                    transactions: <Map<String, dynamic>>[
                      <String, dynamic>{
                        'merchant': 'Market One',
                        'description': 'Groceries',
                        'date': '2026-06-06',
                        'amount': 125,
                        'currency': 'EGP',
                        'category': 'Food & Dining',
                      },
                      <String, dynamic>{
                        'merchant': 'Market Two',
                        'description': 'Drinks',
                        'date': '2026-06-06',
                        'amount': '25.50',
                        'currency': 'EGP',
                        'category': 'Food & Dining',
                      },
                    ],
                    categories: const <String>['Food & Dining'],
                    onSave: (List<Map<String, dynamic>> entries) async {
                      saved = entries;
                    },
                  ),
                ),
                child: const Text('Open confirmation'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open confirmation'));
      await tester.pumpAndSettle();

      expect(find.text('Market One'), findsOneWidget);
      expect(find.text('Market Two'), findsOneWidget);
      expect(find.byKey(const Key('scannedDate_0')), findsOneWidget);
      expect(find.byKey(const Key('scannedAmount_0')), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('saveSelectedScannedTransactions')),
      );
      await tester.pumpAndSettle();

      expect(saved, hasLength(2));
      expect(saved!.first['date'], '2026-06-06');
      expect(saved!.first['amount'], 125);
    },
  );

  testWidgets('save transaction and dashboard updates', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(_seedStateWithMarketData()),
    });

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboardEmptyCard')), findsOneWidget);

    await _openTransactionForm(tester);

    await tester.enterText(find.byKey(const Key('amountField')), '100');

    await tester.tap(find.byKey(const Key('categoryField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salary').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('saveTransactionButton')));
    await tester.pumpAndSettle();

    // Verify the hero card shows total wealth including the new transaction
    expect(find.text('TOTAL WEALTH'), findsOneWidget);
    expect(find.textContaining('100'), findsWidgets);
  });

  testWidgets('persistence survives reload', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(_seedStateWithMarketData()),
    });

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _openTransactionForm(tester);

    await tester.enterText(find.byKey(const Key('amountField')), '250');

    await tester.tap(find.byKey(const Key('categoryField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salary').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('saveTransactionButton')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Verify the hero card shows total wealth persisted across reload
    expect(find.text('TOTAL WEALTH'), findsOneWidget);
    expect(find.textContaining('250'), findsWidgets);
  });
}
