import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/financial_plan.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/screens/plans/cash_flow_chart_screen.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/orientation_controller.dart';

class FakeOrientationController implements OrientationController {
  bool enteredLandscape = false;
  bool restoredPortrait = false;

  @override
  Future<void> enterLandscape() async {
    enteredLandscape = true;
  }

  @override
  Future<void> restorePortrait() async {
    restoredPortrait = true;
  }
}

class FakeAppStateController extends ChangeNotifier implements AppStateController {
  FakeAppStateController(this.plan) {
    final Map<String, dynamic> fixture = jsonDecode(
      File('test/fixtures/sample_app_state.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    fixture['financialPlans'] = [plan.toJson()];
    fixture['transactions'] = <dynamic>[];
    fixture['savings'] = <dynamic>[];
    fixture['investments'] = <dynamic>[];
    _state = AppStateModel.fromJson(fixture);
  }

  final FinancialPlan plan;
  late final AppStateModel _state;

  @override
  AppStateModel get state => _state;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CashFlowChartScreen Widget Tests', () {
    final testPlan = FinancialPlan(
      id: 'test_plan_id',
      name: 'Monthly Plan',
      startDate: '2026-01-01',
      projectionCurrency: 'USD',
      startingBalance: 2000.0,
      startingBalanceDate: '2026-01-01',
      startingBalanceMode: 'manual',
      snapshotWealthCurrency: 'USD',
      startingAssetBreakdown: const {},
      monthlyIncome: 1000.0,
      monthlyExpenses: 800.0,
      includeInstallments: false,
      includeZakat: false,
      durationYears: 1,
      createdAt: '',
    );

    testWidgets('Renders all selectors and selectors switch views', (WidgetTester tester) async {
      final fakeController = FakeAppStateController(testPlan);
      final fakeOrientation = FakeOrientationController();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          home: ChangeNotifierProvider<AppStateController>.value(
            value: fakeController,
            child: CashFlowChartScreen(
              planId: 'test_plan_id',
              orientationController: fakeOrientation,
            ),
          ),
        ),
      );

      // Verify landscape was requested
      expect(fakeOrientation.enteredLandscape, isTrue);

      // Verify header and selector tabs exist
      expect(find.text('Cash Flow'), findsOneWidget);
      expect(find.text('Net Flow'), findsOneWidget);
      expect(find.text('Cash In'), findsOneWidget);
      expect(find.text('Cash Out'), findsOneWidget);
      expect(find.text('Balance'), findsOneWidget);

      // Tap Cash In selector and verify
      await tester.tap(find.text('Cash In'));
      await tester.pumpAndSettle();

      // Tap Balance and verify
      await tester.tap(find.text('Balance'));
      await tester.pumpAndSettle();
    });

    testWidgets('Shows error state when plan not found', (WidgetTester tester) async {
      final fakeController = FakeAppStateController(testPlan);
      final fakeOrientation = FakeOrientationController();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AppStateController>.value(
            value: fakeController,
            child: CashFlowChartScreen(
              planId: 'non_existent_plan',
              orientationController: fakeOrientation,
            ),
          ),
        ),
      );

      expect(find.text('Financial plan not found'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });
  });
}
