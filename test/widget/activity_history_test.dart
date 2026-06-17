import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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
  Future<UserProfile?> signIn({AuthProvider provider = AuthProvider.google}) async => null;
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

    for (final String label in <String>['Income', 'Expense', 'Transfer']) {
      final Text text = tester.widget<Text>(find.text(label).first);
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
    }
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

      expect(find.textContaining('Team lunch downtown'), findsOneWidget);
      expect(find.textContaining('June consulting payment'), findsNothing);
      expect(find.textContaining('Coffee beans'), findsNothing);

      await tester.tap(find.text('Income').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('activityEmptyState')), findsOneWidget);

      await tester.tap(find.byKey(const Key('clearActivitySearch')));
      await tester.pumpAndSettle();
      expect(find.textContaining('June consulting payment'), findsOneWidget);
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

    await tester.drag(find.byType(Slidable).first, const Offset(-500.0, 0.0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
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
    expect(find.textContaining('\u200E\$ 40.00 → \u200EE£ 2,000.00'), findsOneWidget);
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
    expect(find.textContaining('2g Gold • \u200EE£ 10,000.00'), findsOneWidget);
    expect(find.text('Precious Metals Purchase'), findsNothing);
  });

  testWidgets(
    'gold sale appears once under Transfer and hides internal cash proceeds',
    (WidgetTester tester) async {
      final Map<String, dynamic> seeded = <String, dynamic>{
        ...AppStateDefaults.create().toJson(),
        'transactions': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'gold-sale-1',
            'type': 'transfer',
            'date': '2026-06-11',
            'amount': 40000,
            'currency': 'EGP',
            'category': 'Gold Sale',
            'description': '5.00g Gold -> EGP 40000.00',
            'createdAt': '2026-06-11T00:00:00.000Z',
            'rolledOver': false,
            'activityType': 'transfer',
            'exchangePairId': 'gold-holding-1',
          },
        ],
        'savings': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'gold-holding-1',
            'assetType': 'gold',
            'dateAcquired': '2026-01-01',
            'amount': 10,
            'remainingAmount': 5,
            'unit': '24',
            'description': 'Gold bar',
            'purchaseCurrency': 'EGP',
            'purchaseAmount': 80000,
            'createdAt': '2026-01-01T00:00:00.000Z',
          },
          <String, dynamic>{
            'id': 'gold-sale-cash-1',
            'assetType': 'cash',
            'dateAcquired': '2026-06-11',
            'amount': 40000,
            'remainingAmount': 40000,
            'unit': 'EGP',
            'description': 'Gold Sale proceeds',
            'purchaseCurrency': 'EGP',
            'purchaseAmount': 40000,
            'createdAt': '2026-06-11T00:00:00.000Z',
            'internalTransfer': true,
            'internalTransferType': 'precious_metals_sale',
            'transferActivityId': 'gold-sale-1',
          },
        ],
      };
      SharedPreferences.setMockInitialValues(<String, Object>{
        'zakatAppData': jsonEncode(seeded),
      });

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Activity').first);
      await tester.pumpAndSettle();

      expect(find.text('Gold Sale'), findsOneWidget);
      expect(find.text('Currency Exchange'), findsNothing);
      expect(find.text('Gold Sale proceeds'), findsNothing);

      await tester.tap(find.text('Income').first);
      await tester.pumpAndSettle();
      expect(find.text('Gold Sale'), findsNothing);

      await tester.tap(find.text('Expense').first);
      await tester.pumpAndSettle();
      expect(find.text('Gold Sale'), findsNothing);

      await tester.tap(find.text('Transfer').first);
      await tester.pumpAndSettle();
      expect(find.text('Gold Sale'), findsOneWidget);
      expect(find.textContaining('5g Gold • \u200EE£ 40,000.00'), findsOneWidget);
    },
  );
}
