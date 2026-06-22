import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart'
    as db
    hide FinancialPlan, RecurringTransaction;
import 'package:zakatapp_flutter/data/local/daos/recurring_transactions_dao.dart';
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/recurring_transaction.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

class _AlwaysSqliteProvider implements UseSqliteLocalStoreProvider {
  @override
  Future<bool> prepareForRead({String? userId}) async => true;
}

RecurringTransaction _recurring(String id, {bool enabled = true}) {
  return RecurringTransaction(
    id: id,
    name: 'Recurring $id',
    type: 'expense',
    amount: 90,
    currency: 'USD',
    category: 'Bills',
    description: 'Monthly bill',
    dayOfMonth: 10,
    frequency: 'monthly',
    lastProcessed: '2026-06-01',
    enabled: enabled,
    skipMonth: '',
    createdAt: '2026-06-19T08:00:00.000Z',
  );
}

AppStateModel _stateWithRecurring(List<RecurringTransaction> items) {
  return AppStateModel.fromJson(<String, dynamic>{
    'transactions': <dynamic>[],
    'savings': <dynamic>[],
    'recurringTransactions': items
        .map((RecurringTransaction item) => item.toJson())
        .toList(),
    'investments': <dynamic>[],
    'financialPlans': <dynamic>[],
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
  late RecurringTransactionsDao dao;

  setUp(() {
    database = db.AppDatabase(executor: NativeDatabase.memory());
    dao = RecurringTransactionsDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'JSON recurring transactions migrate into SQLite and survive reload',
    () async {
      final AppStateController controller1 = await _makeController(
        database: database,
        state: _stateWithRecurring(<RecurringTransaction>[
          _recurring('json-rt'),
        ]),
      );

      expect(controller1.state.recurringTransactions, hasLength(1));
      expect(controller1.state.recurringTransactions.single.id, 'json-rt');
      expect(await dao.getActiveRecurringTransactions(), hasLength(1));

      final AppStateController controller2 = await _makeController(
        database: database,
        state: _stateWithRecurring(<RecurringTransaction>[_recurring('other')]),
      );

      expect(controller2.state.recurringTransactions, hasLength(1));
      expect(controller2.state.recurringTransactions.single.id, 'json-rt');
    },
  );

  test(
    'updating recurring transactions mirrors to SQLite and JSON compatibility',
    () async {
      final AppStateController controller = await _makeController(
        database: database,
        state: _stateWithRecurring(<RecurringTransaction>[
          _recurring('initial'),
        ]),
      );

      await controller.updateState(
        controller.state.copyWith(
          recurringTransactions: <RecurringTransaction>[_recurring('updated')],
        ),
      );

      final List<RecurringTransaction> sqliteRows = await dao
          .getActiveRecurringTransactions();
      expect(sqliteRows, hasLength(1));
      expect(sqliteRows.single.id, 'updated');

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString('zakatAppData');
      expect(raw, isNotNull);
      expect(raw!, contains('updated'));
    },
  );
}
