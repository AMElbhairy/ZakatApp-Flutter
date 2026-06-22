import 'dart:async';
import 'package:drift/native.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/market_snapshot.dart';
import 'package:zakatapp_flutter/models/merchant_rule.dart';
import 'package:zakatapp_flutter/models/pending_transaction.dart';
import 'package:zakatapp_flutter/models/saving.dart' as model_saving;
import 'package:zakatapp_flutter/data/local/app_database.dart'
    hide FinancialPlan,
         RecurringTransaction,
         MerchantRule,
         MerchantConfirmation,
         CorrectionFeedback,
         PendingTransaction;
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/backup_restore_service.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import '../support/recording_firestore_sync_manager.dart';

class _AllowSqliteProvider implements UseSqliteLocalStoreProvider {
  @override
  Future<bool> prepareForRead({String? userId}) async => true;
}

class _BlockingRecordingFirestoreSyncManager
    extends RecordingFirestoreSyncManager {
  _BlockingRecordingFirestoreSyncManager({
    required this.gate,
    super.uid,
  });

  final Future<void> gate;

  @override
  Future<void> syncSavings({
    required String uid,
    required Iterable<model_saving.Saving> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    savingsSyncCalls += 1;
    await gate;
  }
}

void main() {
  late AppStateController controller;
  late BackupRestoreService service;
  late AppStateRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const LocalStorageService storage = LocalStorageService();
    repository = AppStateRepository(localStorage: storage);
    controller = AppStateController(repository: repository);
    await controller.load();
    service = BackupRestoreService(controller: controller);
  });

  test('replace restore persists state', () async {
    final String raw = jsonEncode(<String, dynamic>{
      'appName': 'ZakatApp',
      'schemaVersion': 1,
      'exportedAt': '2026-01-01T00:00:00Z',
      'counts': <String, dynamic>{},
      'appState': <String, dynamic>{
        'transactions': <dynamic>[
          <String, dynamic>{'id': 'tx1', 'date': '2026-01-01'},
        ],
        'savings': <dynamic>[],
        'investments': <dynamic>[],
        'recurringTransactions': <dynamic>[],
        'financialPlans': <dynamic>[],
      },
    });

    await service.restoreReplace(raw, allowWhenLocalDataExists: true);
    expect(controller.state.transactions.length, 1);
    expect(controller.state.transactions.first.id, 'tx1');
  });

  test('merge restore upserts by id', () async {
    await service.restoreReplace(
      jsonEncode(<String, dynamic>{
        'appName': 'ZakatApp',
        'appState': <String, dynamic>{
          'transactions': <dynamic>[
            <String, dynamic>{'id': 'tx1', 'description': 'old'},
          ],
          'savings': <dynamic>[],
          'investments': <dynamic>[],
          'recurringTransactions': <dynamic>[],
          'financialPlans': <dynamic>[],
        },
      }),
      allowWhenLocalDataExists: true,
    );

    await service.restoreMerge(
      jsonEncode(<String, dynamic>{
        'appName': 'ZakatApp',
        'appState': <String, dynamic>{
          'transactions': <dynamic>[
            <String, dynamic>{'id': 'tx1', 'description': 'new'},
            <String, dynamic>{'id': 'tx2', 'description': 'second'},
          ],
          'savings': <dynamic>[],
          'investments': <dynamic>[],
          'recurringTransactions': <dynamic>[],
          'financialPlans': <dynamic>[],
        },
      }),
      allowWhenLocalDataExists: true,
    );

    expect(controller.state.transactions.length, 2);
    expect(
      controller.state.transactions
          .firstWhere((e) => e.id == 'tx1')
          .description,
      'new',
    );
  });

  test('local conflict requires explicit action', () async {
    await service.restoreReplace(
      jsonEncode(<String, dynamic>{
        'appName': 'ZakatApp',
        'appState': <String, dynamic>{
          'transactions': <dynamic>[
            <String, dynamic>{'id': 'tx1'},
          ],
          'savings': <dynamic>[],
          'investments': <dynamic>[],
          'recurringTransactions': <dynamic>[],
          'financialPlans': <dynamic>[],
        },
      }),
      allowWhenLocalDataExists: true,
    );

    expect(
      () => service.restoreMerge(
        jsonEncode(<String, dynamic>{
          'appName': 'ZakatApp',
          'appState': <String, dynamic>{
            'transactions': <dynamic>[
              <String, dynamic>{'id': 'tx2'},
            ],
            'savings': <dynamic>[],
            'investments': <dynamic>[],
            'recurringTransactions': <dynamic>[],
            'financialPlans': <dynamic>[],
          },
        }),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'merge restore keeps existing market data when incoming market data is empty',
    () async {
      await controller.updateMarketSnapshot(
        const MarketSnapshot(
          gold24kPricePerGramEgp: 5400,
          silverPricePerGramEgp: 64,
          usdToEgp: 50,
          sarToEgp: 13.3,
          aedToEgp: 13.6,
          kwdToEgp: 160,
          qarToEgp: 13.7,
          eurToEgp: 54,
          gbpToEgp: 63,
          bhdToEgp: 133,
          omrToEgp: 130,
          jodToEgp: 71,
          tryToEgp: 1.5,
          myrToEgp: 10.8,
          pkrToEgp: 0.18,
          idrToEgp: 0.0031,
          lastUpdated: '2026-01-01T00:00:00Z',
        ),
      );

      await service.restoreMerge(
        jsonEncode(<String, dynamic>{
          'appName': 'ZakatApp',
          'appState': <String, dynamic>{
            'transactions': <dynamic>[],
            'savings': <dynamic>[],
            'investments': <dynamic>[],
            'recurringTransactions': <dynamic>[],
            'financialPlans': <dynamic>[],
            'marketData': <String, dynamic>{},
          },
        }),
        allowWhenLocalDataExists: true,
      );

      expect(controller.currentMarketSnapshot.usdToEgp, 50);
      expect(
        controller.currentMarketSnapshot.lastUpdated,
        '2026-01-01T00:00:00Z',
      );
    },
  );

  test('merge restore keeps zakat paid state across reloads', () async {
    final AppStateModel initialState = AppStateDefaults.create().copyWith(
      userId: 'user-1',
      zakatPaidMonths: <String>['2026-06'],
      processedExpenseIds: <String>['tx-paid'],
      zakatExpenseIds: <String, dynamic>{'2026-06': 'tx-paid'},
    );
    await repository.saveAppState(initialState, userId: 'user-1');
    controller = AppStateController(repository: repository);
    await controller.loadAuthenticated('user-1');
    service = BackupRestoreService(controller: controller);

    await service.restoreMerge(
      jsonEncode(<String, dynamic>{
        'appName': 'ZakatApp',
        'appState': <String, dynamic>{
          'transactions': <dynamic>[
            <String, dynamic>{
              'id': 'tx-incoming',
              'type': 'income',
              'date': '2026-06-20',
              'amount': 100,
              'currency': 'USD',
              'category': 'Salary',
              'description': 'incoming',
              'createdAt': '2026-06-20T08:00:00.000Z',
              'rolledOver': false,
            },
          ],
          'savings': <dynamic>[],
          'investments': <dynamic>[],
          'recurringTransactions': <dynamic>[],
          'financialPlans': <dynamic>[],
          'zakatPaidMonths': <dynamic>[],
          'processedExpenseIds': <dynamic>[],
          'zakatExpenseIds': <String, dynamic>{},
        },
      }),
      allowWhenLocalDataExists: true,
    );

    expect(controller.state.zakatPaidMonths, <String>['2026-06']);
    expect(controller.state.processedExpenseIds, <String>['tx-paid']);
    expect(controller.state.zakatExpenseIds, <String, dynamic>{
      '2026-06': 'tx-paid',
    });

    final AppStateController reloaded = AppStateController(
      repository: AppStateRepository(localStorage: const LocalStorageService()),
    );
    await reloaded.loadAuthenticated('user-1');

    expect(reloaded.state.zakatPaidMonths, <String>['2026-06']);
    expect(reloaded.state.processedExpenseIds, <String>['tx-paid']);
    expect(reloaded.state.zakatExpenseIds, <String, dynamic>{
      '2026-06': 'tx-paid',
    });
  });

  test(
    'merge restore keeps merchant rules and capture inbox and syncs them once',
    () async {
      final RecordingFirestoreSyncManager firestore =
          RecordingFirestoreSyncManager(uid: 'user-1');
      final AppStateModel initialState = AppStateDefaults.create().copyWith(
        userId: 'user-1',
        merchantRules: <String, MerchantRule>{
          'coffee shop': const MerchantRule(
            merchantName: 'Coffee Shop',
            categoryId: 'food',
            defaultType: 'expense',
            autoApprove: false,
            usageCount: 1,
            confidence: 1,
            source: 'custom',
            aliases: <String>['coffee shop'],
          ),
        },
        pendingTransactions: const <PendingTransaction>[],
      );
      await repository.saveAppState(initialState, userId: 'user-1');
      controller = AppStateController(
        repository: repository,
        firestoreSyncManager: firestore,
      );
      await controller.loadAuthenticated('user-1');
      service = BackupRestoreService(controller: controller);

      await service.restoreMerge(
        jsonEncode(<String, dynamic>{
          'appName': 'ZakatApp',
          'appState': <String, dynamic>{
            'transactions': <dynamic>[],
            'savings': <dynamic>[],
            'investments': <dynamic>[],
            'recurringTransactions': <dynamic>[],
            'financialPlans': <dynamic>[],
            'pendingTransactions': <dynamic>[
              <String, dynamic>{
                'id': 'capture-1',
                'merchant': 'Coffee Shop',
                'description': 'Card capture',
                'amount': 10,
                'currency': 'USD',
                'createdAt': '2026-06-20T08:00:00.000Z',
              },
            ],
            'merchantRules': <String, dynamic>{
              'coffee shop': <String, dynamic>{
                'merchantName': 'Coffee Shop',
                'aliases': <String>['coffee shop', 'coffee'],
                'categoryId': 'food',
                'categoryName': 'Food',
              },
            },
            'merchantAliases': <String, dynamic>{'coffee': 'Coffee Shop'},
          },
        }),
        allowWhenLocalDataExists: true,
      );

      expect(controller.state.pendingTransactions, hasLength(1));
      expect(controller.state.pendingTransactions.single.id, 'capture-1');
      expect(controller.state.merchantRules, contains('coffee shop'));
      expect(controller.state.merchantAliases['coffee'], 'Coffee Shop');
      expect(firestore.captureInboxSyncCalls, 0);
      expect(firestore.merchantRulesSyncCalls, 0);
    },
  );

  test('restore stamps active user id when backup omits user id', () async {
    final RecordingFirestoreSyncManager firestore =
        RecordingFirestoreSyncManager(uid: 'user-1');
    controller = AppStateController(
      repository: repository,
      firestoreSyncManager: firestore,
    );
    await controller.loadAuthenticated('user-1');
    service = BackupRestoreService(controller: controller);

    await service.restoreReplace(
      jsonEncode(<String, dynamic>{
        'appName': 'ZakatApp',
        'appState': <String, dynamic>{
          'transactions': <dynamic>[],
          'savings': <dynamic>[],
          'investments': <dynamic>[],
          'recurringTransactions': <dynamic>[],
          'financialPlans': <dynamic>[],
          'pendingTransactions': <dynamic>[
            <String, dynamic>{
              'id': 'capture-1',
              'source': PendingTransactionSource.manual,
              'rawMessage': 'Card capture',
              'createdAt': '2026-06-20T08:00:00.000Z',
              'suggestedType': 'expense',
              'confidence': 1,
              'status': 'pendingReview',
            },
          ],
        },
      }),
      allowWhenLocalDataExists: true,
    );

    expect(controller.state.userId, 'user-1');
    expect(firestore.captureInboxSyncCalls, 0);
  });

  test(
    'restore auto-triggers sync after enqueueing imported records',
    () async {
      final AppDatabase database = AppDatabase(executor: NativeDatabase.memory());
      final RecordingFirestoreSyncManager firestore =
          RecordingFirestoreSyncManager(uid: 'user-1');
      final AppStateController sqliteController = AppStateController(
        repository: AppStateRepository(
          localStorage: const LocalStorageService(),
        ),
        firestoreSyncManager: firestore,
        database: database,
        useSqliteLocalStoreProvider: _AllowSqliteProvider(),
      );
      await sqliteController.loadAuthenticated('user-1');
      final BackupRestoreService sqliteService = BackupRestoreService(
        controller: sqliteController,
      );

      final String raw = jsonEncode(<String, dynamic>{
        'appName': 'ZakatApp',
        'appState': <String, dynamic>{
          'transactions': <dynamic>[],
          'savings': <dynamic>[
            <String, dynamic>{
              'id': 'sv-1',
              'assetType': 'gold',
              'dateAcquired': '2026-06-20',
              'amount': 10,
              'remainingAmount': 10,
              'unit': 'g',
              'description': 'Imported gold',
              'purchaseCurrency': 'USD',
              'purchaseAmount': 1000,
              'createdAt': '2026-06-20T00:00:00Z',
            },
          ],
          'investments': <dynamic>[],
          'recurringTransactions': <dynamic>[],
          'financialPlans': <dynamic>[],
        },
      });

      final int beforeCalls = firestore.savingsSyncCalls;
      await sqliteService.restoreReplace(raw, allowWhenLocalDataExists: true);

      final int queueCount = await (database.select(database.syncQueue)).get()
          .then((rows) => rows.length);

      expect(firestore.savingsSyncCalls, greaterThan(beforeCalls));
      expect(queueCount, 0);

      await database.close();
    },
  );

  test('triggerSyncPipeline skips duplicate sync when already in progress', () async {
    final AppDatabase database = AppDatabase(executor: NativeDatabase.memory());
    final Completer<void> gate = Completer<void>();
    final _BlockingRecordingFirestoreSyncManager firestore =
        _BlockingRecordingFirestoreSyncManager(
          gate: gate.future,
          uid: 'user-1',
        );
    final AppStateController sqliteController = AppStateController(
      repository: AppStateRepository(localStorage: const LocalStorageService()),
      firestoreSyncManager: firestore,
      database: database,
      useSqliteLocalStoreProvider: _AllowSqliteProvider(),
    );
    await sqliteController.loadAuthenticated('user-1');
    await sqliteController.updateState(
      AppStateDefaults.create().copyWith(
        userId: 'user-1',
        savings: <model_saving.Saving>[
          const model_saving.Saving(
            id: 'sv-1',
            assetType: 'silver',
            dateAcquired: '2026-06-20',
            amount: 10,
            remainingAmount: 10,
            unit: 'g',
            description: 'Imported silver',
            purchaseCurrency: 'USD',
            purchaseAmount: 1000,
            createdAt: '2026-06-20T00:00:00Z',
          ),
        ],
      ),
    );
    await sqliteController.enqueueAllLocalDataForCloudSync();

    final Future<void> first = sqliteController.triggerSyncPipeline(
      reason: 'import_restore',
    );
    for (int i = 0; i < 20 && firestore.savingsSyncCalls == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(firestore.savingsSyncCalls, 1);
    final Future<void> second = sqliteController.triggerSyncPipeline(
      reason: 'import_restore',
    );
    gate.complete();
    await Future.wait(<Future<void>>[first, second]);

    expect(firestore.savingsSyncCalls, 1);
    await database.close();
  });
}
