import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/main.dart';
import 'package:zakatapp_flutter/core/theme/app_icons.dart';
import 'package:zakatapp_flutter/core/services/zakat_engine.dart';
import 'package:zakatapp_flutter/models/investment_asset.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/models/saving.dart';
import 'package:zakatapp_flutter/models/user_profile.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/auth_controller.dart';
import 'package:zakatapp_flutter/services/auth_service.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/plan_wealth_service.dart';
import 'package:zakatapp_flutter/services/plan_health_service.dart';
import 'package:zakatapp_flutter/services/projection_service.dart';

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

Future<void> _openPlans(WidgetTester tester) async {
  await tester.tap(find.byIcon(AppIcons.plans).first);
  await tester.pumpAndSettle();
}

Future<void> _addPlan(
  WidgetTester tester, {
  required String name,
  required String monthlySaving,
  String mode = 'snapshot',
  String balance = '0',
  Map<String, String> manualBreakdown = const <String, String>{},
}) async {
  await _openPlans(tester);

  await tester.enterText(find.byKey(const Key('planNameField')), name);

  if (mode == 'manual') {
    // Select manual mode radio
    await tester.tap(find.text('Enter Manually'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('planStartingBalanceField')),
      balance,
    );
    if (manualBreakdown.isNotEmpty) {
      await tester.tap(find.byKey(const Key('planManualBreakdownToggle')));
      await tester.pumpAndSettle();
      for (final MapEntry<String, String> entry in manualBreakdown.entries) {
        final Finder field = find.byKey(
          Key('planManualBreakdown_${entry.key}'),
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
    }
  }

  await tester.enterText(
    find.byKey(const Key('planMonthlySavingField')),
    monthlySaving,
  );
  await tester.enterText(find.byKey(const Key('planDurationYearsField')), '2');

  await tester.drag(
    find.byType(SingleChildScrollView).last,
    const Offset(0, -500),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('savePlanButton')));
  await tester.pumpAndSettle();
}

void main() {
  group('Unit Tests: Services', () {
    final MarketData marketData = MarketData.fromJson(const <String, dynamic>{
      'GOLD_PRICE_24K_EGP': 3200.0,
      'SILVER_PRICE_EGP': 40.0,
      'USD_TO_EGP': 48.0,
      'SAR_TO_EGP': 12.8,
    });

    test('Plan wealth and remaining installment liability calculation', () {
      final List<Transaction> transactions = <Transaction>[];
      final List<Saving> savings = <Saving>[
        Saving(
          id: 's1',
          assetType: 'cash',
          dateAcquired: '2026-06-12',
          amount: 5000.0,
          remainingAmount: 5000.0,
          unit: 'USD',
          purchaseCurrency: 'USD',
          purchaseAmount: 5000.0,
          description: '',
          createdAt: '2026-06-12',
        ),
      ];

      final List<InvestmentAsset> investments = <InvestmentAsset>[
        InvestmentAsset(
          id: 'i1',
          investmentType: 'real_estate',
          assetSubtype: 'apartment',
          ownershipType: 'fully_owned',
          valuationMode: 'manual',
          currency: 'USD',
          originalPrice: 100000.0,
          totalInterest: 0,
          totalPayable: 100000.0,
          paidAmount: 40000.0, // Remaining liability = 60000 USD
          remainingAmount: 60000.0,
          installmentPlan: const <Map<String, dynamic>>[],
          valuationDate: '2026-06-12',
          marketValue: 120000.0,
          marketValueDate: '2026-06-12',
          valuationSource: 'manual',
          loanBalance: 0,
          loanAsOfDate: '',
          paidAmountToDate: 40000.0,
          ownershipSharePct: 100.0,
          country: '',
          location: '',
          inflationRateAnnual: 0,
          estimatedCurrentValue: 120000.0,
          description: '',
          noZakat: false,
          createdAt: '',
        ),
      ];

      // Cash: 5000 USD = 240,000 EGP
      // Real estate estimated value: 120,000 USD = 5,760,000 EGP
      // Total assets in USD = 5000 + 120000 = 125,000 USD
      // Remaining Installment Liability = 60,000 USD
      // Net Plan Wealth = 125,000 - 60,000 = 65,000 USD

      final double actualWealthUSD =
          PlanWealthService.calculateActualPlanWealth(
            transactions: transactions,
            savings: savings,
            investments: investments,
            marketData: marketData,
            projectionCurrency: 'USD',
          );

      expect(actualWealthUSD, 65000.0);
    });

    test('Variance & Health status thresholds', () {
      // expected = 10000, actual = 10600 (ahead by 6%, which is > 5%)
      expect(
        PlanHealthService.getHealthStatus(actual: 10600, expected: 10000),
        'ahead',
      );

      // expected = 10000, actual = 9400 (behind by 6%, which is < -5%)
      expect(
        PlanHealthService.getHealthStatus(actual: 9400, expected: 10000),
        'behind',
      );

      // expected = 10000, actual = 10100 (on track)
      expect(
        PlanHealthService.getHealthStatus(actual: 10100, expected: 10000),
        'on_track',
      );
    });

    test('Asset drift calculations', () {
      final List<Transaction> transactions = <Transaction>[];
      final List<Saving> savings = <Saving>[
        Saving(
          id: 's1',
          assetType: 'cash',
          dateAcquired: '2026-06-12',
          amount: 1000.0,
          remainingAmount: 1000.0,
          unit: 'USD',
          purchaseCurrency: 'USD',
          purchaseAmount: 1000.0,
          description: '',
          createdAt: '2026-06-12',
        ),
      ];

      final Map<String, double> startBreakdown = <String, double>{
        'cash': 800.0,
      };

      final drift = PlanWealthService.calculateAssetDrift(
        startingAssetBreakdown: startBreakdown,
        transactions: transactions,
        savings: savings,
        investments: const <InvestmentAsset>[],
        marketData: marketData,
        projectionCurrency: 'USD',
      );

      expect(drift['cash']?['started'], 800.0);
      expect(drift['cash']?['current'], 1000.0);
      expect(drift['cash']?['variance'], 200.0);
    });

    test(
      'Actual average surplus uses net worth growth over elapsed months',
      () {
        final double surplus = PlanWealthService.calculateActualAverageSurplus(
          currentNetWorth: 1600000,
          startingNetWorth: 1000000,
          startDate: DateTime(2026, 3, 14),
          asOf: DateTime(2026, 6, 12, 23, 59),
        );

        expect(surplus, closeTo(200000, 1e-6));
      },
    );

    test('Actual average surplus requires at least 30 elapsed days', () {
      final double surplus = PlanWealthService.calculateActualAverageSurplus(
        currentNetWorth: 1200000,
        startingNetWorth: 1000000,
        startDate: DateTime(2026, 6, 1),
        asOf: DateTime(2026, 6, 12, 23, 59),
      );

      expect(surplus, 0);
    });

    test('Actual plan wealth preserves negative net worth', () {
      const List<Transaction> transactions = <Transaction>[
        Transaction(
          id: 'overdraft',
          type: 'expense',
          date: '2026-06-12',
          amount: 500,
          currency: 'EGP',
          category: 'Living',
          description: '',
          createdAt: '',
          rolledOver: false,
        ),
      ];

      final double wealth = PlanWealthService.calculateActualPlanWealth(
        transactions: transactions,
        savings: const <Saving>[],
        investments: const <InvestmentAsset>[],
        marketData: marketData,
        projectionCurrency: 'EGP',
      );

      expect(wealth, -500);
    });

    test('Expected wealth at month zero equals starting net worth', () {
      const double startingNetWorth = 2716643.85;
      final List<ProjectionPoint> projection = <ProjectionPoint>[
        ProjectionPoint(
          monthNumber: 1,
          date: DateTime(2026, 7, 12),
          balance: 3016643.85,
          income: 1000000,
          expenses: 700000,
          installmentsOutflow: 0,
          zakatOutflow: 0,
        ),
      ];

      expect(
        PlanWealthService.calculateExpectedPlanWealth(
          projection: projection,
          currentMonthIndex: 0,
          startingBalance: startingNetWorth,
        ),
        startingNetWorth,
      );
    });

    test('Forecast applies pace gap and current financial variance', () {
      final double forecast = PlanWealthService.calculateForecastEndBalance(
        planEndGoal: 38000000,
        currentFinancialVariance: 2200000,
        averageMonthlySurplus: 260000,
        requiredMonthlySurplus: 300000,
        remainingMonths: 115,
      );

      expect(forecast, 35600000);
    });
  });

  group('Widget Tests: Plans Integration Flow', () {
    testWidgets('add manual plan and verify snapshot to manual override', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await _addPlan(
        tester,
        name: 'Manual Plan',
        monthlySaving: '1500',
        mode: 'manual',
        balance: '250000',
        manualBreakdown: const <String, String>{
          'cash': '300000',
          'gold': '50000',
          'liability': '100000',
        },
      );

      expect(find.textContaining('Manual Plan'), findsWidgets);
      expect(find.textContaining('250,000'), findsWidgets);
      expect(find.textContaining('100,000'), findsWidgets);
    });

    testWidgets(
      'edit plan snapshot refresh toggle behavior and locking rules',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues(<String, Object>{});
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // Creates a snapshot plan (default)
        await _addPlan(
          tester,
          name: 'Locking Test Plan',
          monthlySaving: '1000',
        );

        // Click Edit
        await tester.ensureVisible(find.byKey(const Key('editPlanButton')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('editPlanButton')));
        await tester.pumpAndSettle();

        // Name field should be 'Locking Test Plan'
        await tester.enterText(
          find.byKey(const Key('planNameField')),
          'Locking Test Plan Edited',
        );

        // Scroll and save WITHOUT checking "Refresh Starting Balance Snapshot"
        await tester.drag(
          find.byType(SingleChildScrollView).last,
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('savePlanButton')));
        await tester.pumpAndSettle();

        // Name should be updated
        expect(find.textContaining('Locking Test Plan Edited'), findsWidgets);
      },
    );
  });
}
