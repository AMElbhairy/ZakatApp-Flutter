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

Widget _buildApp({Key? key}) {
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository = AppStateRepository(
    localStorage: localStorage,
  );
  return MultiProvider(
    key: key,
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

Future<void> _openAddCash(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('addEntryFab')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('actionAddIncome')));
  await tester.pumpAndSettle();
}

Future<void> _addCashSaving(WidgetTester tester, String amount) async {
  await _openAddCash(tester);
  await tester.tap(find.byKey(const Key('categoryField')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Salary').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('amountField')), amount);
  await tester.enterText(find.byKey(const Key('notesField')), 'Cash Wallet');
  await tester.tap(find.byKey(const Key('saveTransactionButton')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('add cash saving', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addCashSaving(tester, '500');

    await tester.tap(find.text('Assets').last);
    await tester.pumpAndSettle();

    // Tap on Cash category tile to go to CategoryDetailsScreen
    await tester.tap(find.text('Cash').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('500.00'), findsWidgets);
    expect(find.text('TOTAL ASSETS'), findsOneWidget);
  });

  testWidgets('cash statement lists savings, income, and expenses', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final AppStateController controller = Provider.of<AppStateController>(
      tester.element(find.byType(ZakatApp)),
      listen: false,
    );
    await controller.addSaving(
      const Saving(
        id: 'statement-saving',
        assetType: 'cash',
        dateAcquired: '2026-06-01',
        amount: 100,
        remainingAmount: 100,
        unit: 'EGP',
        description: 'Statement Saving',
        purchaseCurrency: '',
        purchaseAmount: 0,
        createdAt: '2026-06-01T00:00:00.000Z',
      ),
    );
    await controller.addTransaction(
      const Transaction(
        id: 'statement-expense',
        type: 'expense',
        date: '2026-06-02',
        amount: 20,
        currency: 'EGP',
        category: 'Food & Dining',
        description: 'Statement Expense',
        createdAt: '2026-06-02T00:00:00.000Z',
        rolledOver: false,
      ),
    );
    await controller.addTransaction(
      const Transaction(
        id: 'statement-income',
        type: 'income',
        date: '2026-06-03',
        amount: 50,
        currency: 'EGP',
        category: 'Salary',
        description: 'Statement Income',
        createdAt: '2026-06-03T00:00:00.000Z',
        rolledOver: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Assets').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash').first);
    await tester.pumpAndSettle();

    expect(find.text('Statement Saving'), findsOneWidget);
    expect(find.text('Statement Income'), findsOneWidget);
    expect(find.text('Statement Expense'), findsOneWidget);
    expect(find.textContaining('130.00'), findsWidgets);
    expect(find.textContaining('-20.00'), findsWidgets);
  });

  testWidgets('add gold and silver saving', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Navigate to Assets and open Gold category FAB to add gold
    await tester.tap(find.text('Assets').last);
    await tester.pumpAndSettle();
    final Finder goldFinder = find.text('Gold').first;
    await tester.ensureVisible(goldFinder);
    await tester.pumpAndSettle();
    await tester.tap(goldFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addAssetFab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('savingTypeField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gold').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('savingAmountField')), '20');
    await tester.enterText(
      find.byKey(const Key('savingPurchaseAmountField')),
      '200',
    );
    final Finder saveBtn = find.byKey(const Key('saveSavingButton'));
    await tester.ensureVisible(saveBtn);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();
    expect(find.textContaining('20.00'), findsWidgets);

    // Go back, open Silver category FAB to add silver
    await tester.pageBack();
    await tester.pumpAndSettle();
    final Finder silverFinder = find.text('Silver').first;
    await tester.ensureVisible(silverFinder);
    await tester.pumpAndSettle();
    await tester.tap(silverFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addAssetFab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('savingTypeField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Silver').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('savingAmountField')), '70');
    await tester.enterText(
      find.byKey(const Key('savingPurchaseAmountField')),
      '700',
    );
    final Finder saveBtn2 = find.byKey(const Key('saveSavingButton'));
    await tester.ensureVisible(saveBtn2);
    await tester.tap(saveBtn2);
    await tester.pumpAndSettle();
    expect(find.textContaining('70.00'), findsWidgets);
  });

  testWidgets('edit saving and persist after reload', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addCashSaving(tester, '400');

    await tester.tap(find.text('Assets').last);
    await tester.pumpAndSettle();

    // Tap Cash card to open its CategoryDetailsScreen
    await tester.tap(find.text('Cash').first);
    await tester.pumpAndSettle();

    // Tap the cash item in the list (now opens AddTransactionScreen in cashMode)
    await tester.tap(find.text('Cash Wallet'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('amountField')), '900');
    await tester.tap(find.byKey(const Key('saveTransactionButton')));
    await tester.pumpAndSettle();

    expect(find.textContaining('900.00'), findsWidgets);

    await tester.pumpWidget(_buildApp(key: UniqueKey()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Assets').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cash').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('900.00'), findsWidgets);
  });

  testWidgets('delete saving', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addCashSaving(tester, '220');

    await tester.tap(find.text('Assets').last);
    await tester.pumpAndSettle();

    // Tap Cash card to open its CategoryDetailsScreen
    await tester.tap(find.text('Cash').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('assetsEmptyState')), findsOneWidget);

    // Go back to main Assets screen
    await tester.pageBack();
    await tester.pumpAndSettle();
  });
}
