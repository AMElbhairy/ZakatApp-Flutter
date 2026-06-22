import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/main.dart';
import 'package:zakatapp_flutter/models/investment_asset.dart';
import 'package:zakatapp_flutter/models/user_profile.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/auth_controller.dart';
import 'package:zakatapp_flutter/services/auth_service.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/screens/entry/add_investment_screen.dart';

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

void main() {
  testWidgets('AddInvestmentScreen respects initialAssetType and calculates growth rate', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final localStorage = LocalStorageService();
    final repository = AppStateRepository(localStorage: localStorage);
    final appStateController = AppStateController(
      repository: repository,
      enableBackgroundSync: false,
      enableMarketAutoRefresh: false,
    );
    final authController = AuthController(
      authService: _FakeAuthService(),
      localStorage: localStorage,
    );

    await appStateController.load();

    // Verify FAB Company Share Navigation Pre-selection
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appStateController),
          ChangeNotifierProvider.value(value: authController),
        ],
        child: const MaterialApp(
          home: AddInvestmentScreen(
            initialAssetType: 'company_share',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify that the dropdown selection is company_share
    final DropdownButtonFormField<String> typeField = tester.widget(
      find.byKey(const Key('investmentTypeField')),
    );
    expect(typeField.initialValue, 'company_share');

    // Test Growth Rate Calculations
    final purchasePriceFinder = find.byKey(const Key('investmentPurchasePriceField'));
    final growthRateFinder = find.byKey(const Key('investmentGrowthRateField'));
    final currentValueFinder = find.byKey(const Key('investmentCurrentValueField'));

    expect(purchasePriceFinder, findsOneWidget);
    expect(growthRateFinder, findsOneWidget);

    await tester.enterText(purchasePriceFinder, '100000');
    await tester.enterText(growthRateFinder, '10'); // 10% growth rate
    await tester.pump();

    // By default, if valuationDate is today, valuationDate.difference(today) is 0 days, so currentValue = purchasePrice = 100000
    final TextFormField currentValueWidget = tester.widget(currentValueFinder);
    expect(currentValueWidget.controller?.text, '100000');

    // Clean up
    appStateController.dispose();
    authController.dispose();
  });

  testWidgets('AddInvestmentScreen calculates compound interest over 1 year gap', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final localStorage = LocalStorageService();
    final repository = AppStateRepository(localStorage: localStorage);
    final appStateController = AppStateController(
      repository: repository,
      enableBackgroundSync: false,
      enableMarketAutoRefresh: false,
    );
    final authController = AuthController(
      authService: _FakeAuthService(),
      localStorage: localStorage,
    );

    await appStateController.load();

    // Start date is exactly 365 days before today
    final String valuationDateStr = DateTime.now().subtract(const Duration(days: 365)).toIso8601String().split('T').first;

    final initialInvestment = InvestmentAsset(
      id: 'i-test',
      investmentType: 'real_estate',
      assetSubtype: 'property',
      ownershipType: 'fully_owned',
      valuationMode: 'net_fair',
      currency: 'USD',
      originalPrice: 100000,
      totalInterest: 0,
      totalPayable: 100000,
      paidAmount: 100000,
      remainingAmount: 0,
      installmentPlan: const [],
      valuationDate: valuationDateStr,
      marketValue: 100000,
      marketValueDate: valuationDateStr,
      valuationSource: 'manual',
      loanBalance: 0,
      loanAsOfDate: valuationDateStr,
      paidAmountToDate: 100000,
      ownershipSharePct: 100,
      country: 'US',
      location: 'NY',
      inflationRateAnnual: 0,
      estimatedCurrentValue: 100000,
      description: 'Compound test',
      noZakat: false,
      createdAt: '2025-06-22T08:00:00.000Z',
      yearlyGrowthRate: 10.0,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appStateController),
          ChangeNotifierProvider.value(value: authController),
        ],
        child: MaterialApp(
          home: AddInvestmentScreen(
            initialInvestment: initialInvestment,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final currentValueFinder = find.byKey(const Key('investmentCurrentValueField'));
    final TextFormField currentValueWidget = tester.widget(currentValueFinder);
    
    // Elapsed time is approx 1 year, so calculated current value should be close to 110000 (100k * (1.10)^1)
    final double val = double.tryParse(currentValueWidget.controller?.text ?? '') ?? 0;
    expect(val, closeTo(110000, 500)); 

    // Clean up
    appStateController.dispose();
    authController.dispose();
  });

  testWidgets('AddInvestmentScreen calculates remaining liability as sum of unpaid installments and validates fields', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final localStorage = LocalStorageService();
    final repository = AppStateRepository(localStorage: localStorage);
    final appStateController = AppStateController(
      repository: repository,
      enableBackgroundSync: false,
      enableMarketAutoRefresh: false,
    );
    final authController = AuthController(
      authService: _FakeAuthService(),
      localStorage: localStorage,
    );

    await appStateController.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appStateController),
          ChangeNotifierProvider.value(value: authController),
        ],
        child: const MaterialApp(
          home: AddInvestmentScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Fill in Name
    await tester.enterText(find.byKey(const Key('investmentNameField')), 'Test Property');

    // Toggle the include installments switch to show configuration
    final switchFinder = find.byKey(const Key('includeInstallmentsSwitch'));
    expect(switchFinder, findsOneWidget);
    await tester.ensureVisible(switchFinder);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    // Verify installment_schedule section is visible
    expect(find.text('Total Liability:'), findsOneWidget);

    // Enter Number of Installments = 3
    final numInstFinder = find.widgetWithText(TextFormField, 'Number of Installments');
    expect(numInstFinder, findsOneWidget);
    await tester.ensureVisible(numInstFinder);
    await tester.enterText(numInstFinder, '3');
    await tester.pumpAndSettle();

    // Enter Total Installments Amount = 1200
    final totalAmountFinder = find.byKey(const Key('investmentTotalInstallmentsAmountField'));
    expect(totalAmountFinder, findsOneWidget);
    await tester.ensureVisible(totalAmountFinder);
    await tester.enterText(totalAmountFinder, '1200');
    await tester.pumpAndSettle();

    // Tap "Generate Installments"
    final genBtnFinder = find.text('Generate Installments');
    expect(genBtnFinder, findsOneWidget);
    await tester.ensureVisible(genBtnFinder);
    await tester.tap(genBtnFinder);
    await tester.pumpAndSettle();

    // Verify 3 installments are added
    expect(find.textContaining('Installment #1'), findsOneWidget);
    expect(find.textContaining('Installment #2'), findsOneWidget);
    expect(find.textContaining('Installment #3'), findsOneWidget);

    // Toggle the first installment as paid
    final checkboxFinder = find.byType(Checkbox);
    expect(checkboxFinder, findsNWidgets(3));
    await tester.ensureVisible(checkboxFinder.first);
    await tester.tap(checkboxFinder.first);
    await tester.pumpAndSettle();

    // Fill purchase price
    final purchasePriceFieldFinder = find.byKey(const Key('investmentPurchasePriceField'));
    await tester.ensureVisible(purchasePriceFieldFinder);
    await tester.enterText(purchasePriceFieldFinder, '10000');
    await tester.pumpAndSettle();

    // Current value is left empty (optional).

    // Tap save
    final saveBtnFinder = find.byKey(const Key('saveInvestmentButton'));
    await tester.ensureVisible(saveBtnFinder);
    await tester.tap(saveBtnFinder);
    await tester.pumpAndSettle();

    // Verify investment is saved
    expect(appStateController.state.investments, hasLength(1));
    final savedAsset = appStateController.state.investments.first;
    
    // Remaining liability (loanBalance) should be the sum of unpaid installments (1200 / 3 * 2 = 800)
    expect(savedAsset.loanBalance, 800.0);
    expect(savedAsset.remainingAmount, 800.0);
    // Current value should default to purchase price = 10000
    expect(savedAsset.marketValue, 10000.0);
    // Paid amount should be purchase price - liability = 10000 - 800 = 9200
    expect(savedAsset.paidAmount, 9200.0);

    // Clean up
    appStateController.dispose();
    authController.dispose();
  });
}
