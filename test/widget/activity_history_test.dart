import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/main.dart';
import 'package:zakatapp_flutter/models/saving.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
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

Future<void> _addTx(
  WidgetTester tester, {
  required String amount,
  required String category,
  required bool income,
  String notes = '',
}) async {
  await tester.tap(find.byKey(const Key('addEntryFab')));
  await tester.pumpAndSettle();
  if (income) {
    await tester.tap(find.byKey(const Key('actionAddIncome')));
  } else {
    await tester.tap(find.byKey(const Key('actionAddExpense')));
  }
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('amountField')), amount);
  await tester.tap(find.byKey(const Key('categoryField')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(category).last);
  await tester.pumpAndSettle();
  if (notes.isNotEmpty) {
    await tester.enterText(find.byKey(const Key('notesField')), notes);
  }
  await tester.tap(find.byKey(const Key('saveTransactionButton')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('list transactions and filter income/expense', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addTx(tester, amount: '100', category: 'Salary', income: true);
    await _addTx(
      tester,
      amount: '40',
      category: 'Food & Dining',
      income: false,
    );

    await tester.tap(find.text('Activity').first);
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNWidgets(2));

    await tester.tap(find.text('Income').first);
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.textContaining('E£ +100.00'), findsOneWidget);

    await tester.tap(find.text('Expense').first);
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.textContaining('E£ -40.00'), findsOneWidget);
  });

  testWidgets(
    'search filters transaction descriptions and combines with type',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await _addTx(
        tester,
        amount: '100',
        category: 'Salary',
        income: true,
        notes: 'June consulting payment',
      );
      await _addTx(
        tester,
        amount: '40',
        category: 'Food & Dining',
        income: false,
        notes: 'Team lunch downtown',
      );
      await _addTx(
        tester,
        amount: '25',
        category: 'Food & Dining',
        income: false,
        notes: 'Coffee beans',
      );

      await tester.tap(find.text('Activity').first);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('activitySearchField')),
        'LUNCH',
      );
      await tester.pumpAndSettle();

      expect(find.text('Team lunch downtown'), findsOneWidget);
      expect(find.text('June consulting payment'), findsNothing);
      expect(find.text('Coffee beans'), findsNothing);

      await tester.tap(find.text('Income').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('activityEmptyState')), findsOneWidget);

      await tester.tap(find.byKey(const Key('clearActivitySearch')));
      await tester.pumpAndSettle();
      expect(find.text('June consulting payment'), findsOneWidget);
    },
  );

  testWidgets('delete transaction with confirmation', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addTx(tester, amount: '100', category: 'Salary', income: true);

    await tester.tap(find.text('Activity').first);
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activityEmptyState')), findsOneWidget);
  });

  testWidgets('edit transaction and persist after reload', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addTx(tester, amount: '100', category: 'Salary', income: true);

    await tester.tap(find.text('Activity').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('amountField')), '250');
    await tester.tap(find.byKey(const Key('saveTransactionButton')));
    await tester.pumpAndSettle();

    expect(find.textContaining('E£ +250.00'), findsOneWidget);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activity').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('E£ +250.00'), findsOneWidget);
  });

  testWidgets('currency exchange appears only under Transfer', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final AppStateController controller = Provider.of<AppStateController>(
      tester.element(find.byType(ZakatApp)),
      listen: false,
    );
    await controller.addTransaction(
      const Transaction(
        id: 'income-transfer-test',
        type: 'income',
        date: '2026-06-11',
        amount: 100,
        currency: 'USD',
        category: 'Salary',
        description: 'Salary cash',
        createdAt: '2026-06-11T00:00:00.000Z',
        rolledOver: false,
      ),
    );
    await controller.executeCurrencyExchange(
      date: '2026-06-11',
      sourceCurrency: 'USD',
      targetCurrency: 'EGP',
      sourceAmount: 40,
      targetAmount: 2000,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activity').first);
    await tester.pumpAndSettle();
    expect(find.text('Currency Exchange'), findsOneWidget);

    await tester.tap(find.text('Income').first);
    await tester.pumpAndSettle();
    expect(find.text('Currency Exchange'), findsNothing);

    await tester.tap(find.text('Expense').first);
    await tester.pumpAndSettle();
    expect(find.text('Currency Exchange'), findsNothing);

    await tester.tap(find.text('Transfer').first);
    await tester.pumpAndSettle();
    expect(find.text('Currency Exchange'), findsOneWidget);
    expect(find.textContaining('40.00 USD → 2000.00 EGP'), findsOneWidget);
  });

  testWidgets('funded gold purchase appears under Transfer', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final AppStateController controller = Provider.of<AppStateController>(
      tester.element(find.byType(ZakatApp)),
      listen: false,
    );
    await controller.addTransaction(
      const Transaction(
        id: 'gold-funding-income',
        type: 'income',
        date: '2026-06-11',
        amount: 10000,
        currency: 'EGP',
        category: 'Salary',
        description: '',
        createdAt: '2026-06-11T00:00:00.000Z',
        rolledOver: false,
      ),
    );
    await controller.addSavingWithFundingAllocations(
      const Saving(
        id: 'gold-transfer',
        assetType: 'gold',
        dateAcquired: '2026-06-11',
        amount: 2,
        remainingAmount: 2,
        unit: '24',
        description: '',
        purchaseCurrency: 'EGP',
        purchaseAmount: 10000,
        createdAt: '2026-06-11T01:00:00.000Z',
        fundingAllocations: <Map<String, dynamic>>[
          <String, dynamic>{
            'sourceType': 'income',
            'sourceId': 'gold-funding-income',
            'currency': 'EGP',
            'amount': 10000,
          },
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activity').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer').first);
    await tester.pumpAndSettle();

    expect(find.text('Gold Purchase'), findsOneWidget);
    expect(
      find.textContaining('10000.00 EGP Cash → 2.00g Gold'),
      findsOneWidget,
    );
    expect(find.text('Precious Metals Purchase'), findsNothing);
  });
}
