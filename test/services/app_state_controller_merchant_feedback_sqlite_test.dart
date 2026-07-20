import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart' as db
    hide CorrectionFeedback, FinancialPlan, MerchantConfirmation, MerchantRule, RecurringTransaction;
import 'package:zakatapp_flutter/data/local/daos/correction_feedback_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/merchant_confirmations_dao.dart';
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/correction_feedback.dart' as model_fb;
import 'package:zakatapp_flutter/models/merchant_confirmation.dart' as model_conf;
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

class _AlwaysSqliteProvider implements UseSqliteLocalStoreProvider {
  @override
  Future<bool> prepareForRead({String? userId}) async => true;
}

AppStateModel _state({
  required List<model_conf.MerchantConfirmation> confirmations,
  required List<model_fb.CorrectionFeedback> feedback,
}) {
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
      'coffee shop': <String, dynamic>{
        'merchantName': 'Coffee Shop',
        'categoryId': 'Food',
        'defaultType': 'expense',
        'autoApprove': true,
        'usageCount': 1,
        'confidence': 0.8,
        'source': 'custom',
        'aliases': <String>['Cafe'],
        'enabled': true,
        'isBuiltinOverride': false,
      },
    },
    'merchantAliases': <String, dynamic>{'cafe': 'Coffee Shop'},
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
    'correctionFeedback': feedback.map((model_fb.CorrectionFeedback item) => item.toJson()).toList(),
    'merchantConfirmations': confirmations.map((model_conf.MerchantConfirmation item) => item.toJson()).toList(),
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
  late MerchantConfirmationsDao confirmationsDao;
  late CorrectionFeedbackDao feedbackDao;

  setUp(() {
    database = db.AppDatabase(executor: NativeDatabase.memory());
    confirmationsDao = MerchantConfirmationsDao(database);
    feedbackDao = CorrectionFeedbackDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('JSON confirmation and feedback lists migrate into SQLite and survive reload', () async {
    final AppStateController controller1 = await _makeController(
      database: database,
      state: _state(
        confirmations: <model_conf.MerchantConfirmation>[
          const model_conf.MerchantConfirmation(
            merchantName: 'Coffee Shop',
            categoryId: 'Food',
            confirmations: 3,
            corrections: 1,
          ),
        ],
        feedback: <model_fb.CorrectionFeedback>[
          const model_fb.CorrectionFeedback(
            id: 'fb-1',
            fieldName: 'category',
            originalValue: 'Food',
            correctedValue: 'Bills',
            createdAt: '2026-06-19T08:00:00.000Z',
          ),
        ],
      ),
    );

    expect(controller1.state.merchantConfirmations, hasLength(1));
    expect(controller1.state.correctionFeedback, hasLength(1));
    expect(await confirmationsDao.getActiveMerchantConfirmations(), hasLength(1));
    expect(await feedbackDao.getActiveCorrectionFeedback(), hasLength(1));

    final AppStateController controller2 = await _makeController(
      database: database,
      state: _state(confirmations: <model_conf.MerchantConfirmation>[], feedback: <model_fb.CorrectionFeedback>[]),
    );

    expect(controller2.state.merchantConfirmations, hasLength(1));
    expect(controller2.state.correctionFeedback, hasLength(1));
  });

  test('updating confirmation and feedback lists mirrors to SQLite and JSON compatibility', () async {
    final AppStateController controller = await _makeController(
      database: database,
      state: _state(confirmations: <model_conf.MerchantConfirmation>[], feedback: <model_fb.CorrectionFeedback>[]),
    );

    await controller.updateState(
      controller.state.copyWith(
        merchantConfirmations: <model_conf.MerchantConfirmation>[
          const model_conf.MerchantConfirmation(
            merchantName: 'Updated Shop',
            categoryId: 'Bills',
            confirmations: 4,
            corrections: 0,
          ),
        ],
        correctionFeedback: <model_fb.CorrectionFeedback>[
          const model_fb.CorrectionFeedback(
            id: 'fb-updated',
            fieldName: 'merchant',
            originalValue: 'Old',
            correctedValue: 'Updated',
            createdAt: '2026-06-19T08:00:00.000Z',
          ),
        ],
      ),
    );

    expect(await confirmationsDao.getActiveMerchantConfirmations(), hasLength(1));
    expect(await feedbackDao.getActiveCorrectionFeedback(), hasLength(1));

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('zakatAppData');
    expect(raw, isNotNull);
    expect(raw!, contains('"merchantConfirmations":[]'));
    expect(raw, contains('"correctionFeedback":[]'));
  });
}
