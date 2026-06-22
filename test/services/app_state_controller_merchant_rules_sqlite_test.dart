import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart' as db
    hide FinancialPlan, MerchantRule, RecurringTransaction;
import 'package:zakatapp_flutter/data/local/daos/merchant_rules_dao.dart';
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/merchant_rule.dart' as model;
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

class _AlwaysSqliteProvider implements UseSqliteLocalStoreProvider {
  @override
  Future<bool> prepareForRead({String? userId}) async => true;
}

model.MerchantRule _rule(String merchantName, {List<String>? aliases}) {
  return model.MerchantRule(
    merchantName: merchantName,
    categoryId: 'Food',
    defaultType: 'expense',
    autoApprove: true,
    usageCount: 3,
    confidence: 0.81,
    lastUsed: '2026-06-19T08:00:00.000Z',
    source: 'custom',
    aliases: aliases ?? const <String>['Cafe'],
    enabled: true,
    isBuiltinOverride: false,
  );
}

AppStateModel _stateWithRules(List<model.MerchantRule> rules) {
  return AppStateModel.fromJson(<String, dynamic>{
    'transactions': <dynamic>[],
    'savings': <dynamic>[],
    'recurringTransactions': <dynamic>[],
    'investments': <dynamic>[],
    'financialPlans': <dynamic>[],
    'pendingTransactions': <dynamic>[],
    'lastRollover': '',
    'categories': <String, dynamic>{'income': <dynamic>[], 'expense': <dynamic>[]},
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
    'merchantRules': <String, dynamic>{
      for (final model.MerchantRule rule in rules)
        rule.merchantName.toLowerCase().trim(): rule.toJson(),
    },
    'merchantAliases': <String, dynamic>{
      for (final model.MerchantRule rule in rules)
        for (final String alias in rule.aliases)
          alias.toLowerCase().trim(): rule.merchantName,
    },
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
  required db.AppDatabase database,
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
  late db.AppDatabase database;
  late MerchantRulesDao dao;

  setUp(() {
    database = db.AppDatabase(executor: NativeDatabase.memory());
    dao = MerchantRulesDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('JSON merchant rules migrate into SQLite and survive reload', () async {
    final AppStateController controller1 = await _makeController(
      database: database,
      state: _stateWithRules(<model.MerchantRule>[_rule('Coffee Shop')]),
    );

    expect(controller1.state.merchantRules, hasLength(1));
    expect(
      controller1.state.merchantRules.values.single.merchantName,
      'Coffee Shop',
    );
    expect(
      controller1.state.merchantAliases,
      containsPair('cafe', 'Coffee Shop'),
    );
    expect(await dao.getActiveMerchantRules(), hasLength(1));

    final AppStateController controller2 = await _makeController(
      database: database,
      state: _stateWithRules(<model.MerchantRule>[_rule('Different Shop')]),
    );

    expect(controller2.state.merchantRules, hasLength(1));
    expect(
      controller2.state.merchantRules.values.single.merchantName,
      'Coffee Shop',
    );
  });

  test('updating merchant rules mirrors to SQLite and JSON compatibility', () async {
    final AppStateController controller = await _makeController(
      database: database,
      state: _stateWithRules(<model.MerchantRule>[_rule('Initial Shop')]),
    );

    final model.MerchantRule updated = _rule(
      'Updated Shop',
      aliases: <String>['Updated Cafe'],
    );
    await controller.updateState(
      controller.state.copyWith(
        merchantRules: <String, model.MerchantRule>{
          'updated shop': updated,
        },
        merchantAliases: <String, String>{'updated cafe': 'Updated Shop'},
      ),
    );

    final List<model.MerchantRule> sqliteRules =
        await dao.getActiveMerchantRules();
    expect(sqliteRules, hasLength(1));
    expect(sqliteRules.single.merchantName, 'Updated Shop');

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('zakatAppData');
    expect(raw, isNotNull);
    expect(raw!, contains('Updated Shop'));
  });
}
