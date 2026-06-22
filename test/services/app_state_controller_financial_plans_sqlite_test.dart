import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart'
    hide FinancialPlan;
import 'package:zakatapp_flutter/data/local/daos/financial_plans_dao.dart';
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/financial_plan.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

class _AlwaysSqliteProvider implements UseSqliteLocalStoreProvider {
  @override
  Future<bool> prepareForRead({String? userId}) async => true;
}

FinancialPlan _plan(
  String id, {
  String createdAt = '2026-06-19T08:00:00.000Z',
}) {
  return FinancialPlan(
    id: id,
    name: 'Plan $id',
    startDate: '2026-06-01',
    projectionCurrency: 'USD',
    startingBalance: 1000,
    startingBalanceDate: '2026-06-01',
    startingBalanceMode: 'manual',
    snapshotWealthCurrency: 'USD',
    startingAssetBreakdown: <String, double>{'cash': 1000},
    monthlyIncome: 2500,
    monthlyExpenses: 1500,
    includeInstallments: true,
    includeZakat: true,
    durationYears: 1,
    createdAt: createdAt,
    isActive: true,
    startingAssets: 1000,
    startingLiabilities: 0,
    startingNetWorth: 1000,
    startingNisabSnapshot: 0,
    startingGoldPriceSnapshot: 0,
    startingFxSnapshot: <String, double>{},
  );
}

AppStateModel _stateWithPlans(List<FinancialPlan> plans) {
  return AppStateModel.fromJson(<String, dynamic>{
    'transactions': <dynamic>[],
    'savings': <dynamic>[],
    'recurringTransactions': <dynamic>[],
    'investments': <dynamic>[],
    'financialPlans': plans.map((FinancialPlan plan) => plan.toJson()).toList(),
    'pendingTransactions': <dynamic>[],
    'lastRollover': '',
    'categories': <String, dynamic>{
      'income': <dynamic>[],
      'expense': <dynamic>[],
    },
    'zakatPaidMonths': <String>[],
    'processedExpenseIds': <String>[],
    'mainCurrency': 'USD',
    'defaultEntryCurrency': 'USD',
    'zakatExpenseIds': <String, dynamic>{},
    'zakatMethod': 'hawl',
    'zakatAnnualDate': '',
    'zakatNisabBasis': 'gold85',
    'zakatScheduleFilter': 'unpaid',
    'marketData': <String, dynamic>{},
    'marketHistory': <dynamic>[],
    'syncHealth': <String, dynamic>{
      'lastSuccessAt': '',
      'lastFailureAt': '',
      'lastError': '',
      'pendingWrites': 0,
    },
    'lastModifiedAt': '',
    'languagePreference': 'en',
    'themeMode': 'system',
    'biometricLockEnabled': false,
    'biometricHideWealthEnabled': false,
    'biometricExportEnabled': false,
    'biometricRestoreEnabled': false,
    'biometricAutoLockDelay': '1_minute',
    'merchantRules': <String, dynamic>{},
    'merchantAliases': <String, dynamic>{},
    'captureAnalytics': <String, dynamic>{
      'parsedMessages': 0,
      'autoApprovedMessages': 0,
      'duplicateMessages': 0,
      'ignoredMessages': 0,
      'correctedMessages': 0,
      'learnedRules': 0,
      'autoApprovedRules': 0,
      'capturedFromAppleShortcuts': 0,
      'capturedFromAppleShortcutsAutoApproved': 0,
      'capturedFromAppleShortcutsIgnored': 0,
    },
    'correctionFeedback': <dynamic>[],
    'merchantConfirmations': <dynamic>[],
    'smartCaptureEnabled': true,
    'smartCaptureAutoApproveEnabled': false,
  });
}

Future<AppStateController> _makeController({
  required AppDatabase database,
  required AppStateModel state,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'zakatAppData': jsonEncode(state.toJson()),
  });
  final controller = AppStateController(
    repository: AppStateRepository(localStorage: const LocalStorageService()),
    database: database,
    useSqliteLocalStoreProvider: _AlwaysSqliteProvider(),
  );
  await controller.load();
  return controller;
}

void main() {
  late AppDatabase database;
  late FinancialPlansDao financialPlansDao;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    financialPlansDao = FinancialPlansDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('JSON plans migrate into SQLite and survive reload', () async {
    final AppStateController controller1 = await _makeController(
      database: database,
      state: _stateWithPlans(<FinancialPlan>[_plan('json-plan')]),
    );

    expect(controller1.state.financialPlans, hasLength(1));
    expect(controller1.state.financialPlans.single.id, 'json-plan');
    expect(await financialPlansDao.getActiveFinancialPlans(), hasLength(1));

    final AppStateController controller2 = await _makeController(
      database: database,
      state: _stateWithPlans(<FinancialPlan>[_plan('different-plan')]),
    );

    expect(controller2.state.financialPlans, hasLength(1));
    expect(controller2.state.financialPlans.single.id, 'json-plan');
  });

  test('updating plans mirrors to SQLite and JSON compatibility', () async {
    final AppStateController controller = await _makeController(
      database: database,
      state: _stateWithPlans(<FinancialPlan>[_plan('initial-plan')]),
    );

    await controller.updateState(
      controller.state.copyWith(
        financialPlans: <FinancialPlan>[_plan('updated-plan')],
      ),
    );

    final List<FinancialPlan> sqlitePlans = await financialPlansDao
        .getActiveFinancialPlans();
    expect(sqlitePlans, hasLength(1));
    expect(sqlitePlans.single.id, 'updated-plan');

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('zakatAppData');
    expect(raw, isNotNull);
    expect(raw!, contains('updated-plan'));
  });
}
