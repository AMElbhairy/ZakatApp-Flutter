import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_queue_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/transactions_dao.dart';
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
import 'package:zakatapp_flutter/data/repositories/local_transactions_repository.dart';
import 'package:zakatapp_flutter/models/transaction.dart' as model;
import 'package:zakatapp_flutter/models/saving.dart' as model_saving;
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/firestore_sync_manager.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/data/sync/sync_reports.dart';

class _AlwaysFalseGate implements UseSqliteLocalStoreProvider {
  @override
  Future<bool> prepareForRead({String? userId}) async => false;
}

class _ManualSyncFirestoreSyncManager extends FirestoreSyncManager {
  _ManualSyncFirestoreSyncManager({
    required this.validationResult,
    this.throwOnSyncTransactions = false,
    this.throwOnLoadSavings = false,
  }) : super(
         firestore: FakeFirebaseFirestore(),
         auth: MockFirebaseAuth(
           signedIn: validationResult.isSignedIn,
           mockUser: validationResult.currentUid == null
               ? null
               : MockUser(uid: validationResult.currentUid!),
         ),
       );

  final FirestoreAuthValidationResult validationResult;
  final bool throwOnSyncTransactions;
  final bool throwOnLoadSavings;

  int transactionSyncCalls = 0;

  @override
  Future<FirestoreAuthValidationResult> validateSession({
    required String expectedUid,
  }) async {
    return validationResult;
  }

  @override
  Future<void> syncTransactions({
    required String uid,
    required Iterable<model.Transaction> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    transactionSyncCalls += 1;
    if (throwOnSyncTransactions) {
      throw FirebaseException(
        plugin: 'test',
        code: 'permission-denied',
        message: 'denied',
      );
    }
    return super.syncTransactions(
      uid: uid,
      items: items,
      deletedIds: deletedIds,
    );
  }

  @override
  Future<FirestoreCollectionDelta<model_saving.Saving>> loadSavingsSince({
    required String uid,
    required String sinceCursor,
  }) async {
    if (throwOnLoadSavings) {
      throw FirebaseException(
        plugin: 'test',
        code: 'unavailable',
        message: 'pull failed',
      );
    }
    return super.loadSavingsSince(uid: uid, sinceCursor: sinceCursor);
  }
}

Future<
  ({
    AppStateController controller,
    AppDatabase database,
    LocalTransactionsRepository transactionsRepository,
    _ManualSyncFirestoreSyncManager firestore,
  })
>
_makeController({
  required FirestoreAuthValidationResult validationResult,
  bool throwOnSyncTransactions = false,
  bool throwOnLoadSavings = false,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  const LocalStorageService localStorage = LocalStorageService();
  final AppDatabase database = AppDatabase(executor: NativeDatabase.memory());
  final LocalTransactionsRepository transactionsRepository =
      LocalTransactionsRepository(
        transactionsDao: TransactionsDao(database),
        syncQueueDao: SyncQueueDao(database),
      );
  final _ManualSyncFirestoreSyncManager firestore =
      _ManualSyncFirestoreSyncManager(
        validationResult: validationResult,
        throwOnSyncTransactions: throwOnSyncTransactions,
        throwOnLoadSavings: throwOnLoadSavings,
      );
  final AppStateController controller = AppStateController(
    repository: AppStateRepository(localStorage: localStorage),
    firestoreSyncManager: firestore,
    database: database,
    useSqliteLocalStoreProvider: _AlwaysFalseGate(),
  );
  return (
    controller: controller,
    database: database,
    transactionsRepository: transactionsRepository,
    firestore: firestore,
  );
}

Future<void> _seedTransactionQueue(
  LocalTransactionsRepository repository,
) async {
  await repository.importTransactions(const <model.Transaction>[
    model.Transaction(
      id: 'tx-1',
      type: 'income',
      date: '2026-06-20',
      amount: 100,
      currency: 'USD',
      category: 'Salary',
      description: 'seed',
      createdAt: '2026-06-20T00:00:00Z',
      rolledOver: false,
    ),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('manual sync with no Firebase user reports not signed in', () async {
    final controllers = await _makeController(
      validationResult: const FirestoreAuthValidationResult(
        expectedUid: 'user-a',
        currentUid: null,
        isSignedIn: false,
        isUidMatch: false,
        tokenRefreshed: false,
        isValid: false,
        errorCode: 'not-signed-in',
        errorMessage: 'Not signed in.',
      ),
    );
    await controllers.controller.loadAuthenticated('user-a');

    final ManualSyncResult result = await controllers.controller
        .runManualSync();

    expect(result.success, isFalse);
    expect(result.message, 'Not signed in.');
    expect(result.pushAttempted, isFalse);
    expect(result.pullAttempted, isFalse);
  });

  test('manual sync detects mismatched Firebase uid', () async {
    final controllers = await _makeController(
      validationResult: const FirestoreAuthValidationResult(
        expectedUid: 'user-a',
        currentUid: 'user-b',
        isSignedIn: true,
        isUidMatch: false,
        tokenRefreshed: false,
        isValid: false,
        errorCode: 'user-mismatch',
        errorMessage:
            'FirebaseAuth uid user-b does not match expected uid user-a.',
      ),
    );
    await controllers.controller.loadAuthenticated('user-a');

    final ManualSyncResult result = await controllers.controller
        .runManualSync();

    expect(result.success, isFalse);
    expect(result.reason, 'user-mismatch');
    expect(result.pullAttempted, isFalse);
  });

  test(
    'manual sync pushes queued rows and clears the queue on success',
    () async {
      final controllers = await _makeController(
        validationResult: const FirestoreAuthValidationResult(
          expectedUid: 'user-a',
          currentUid: 'user-a',
          isSignedIn: true,
          isUidMatch: true,
          tokenRefreshed: true,
          isValid: true,
        ),
      );
      await controllers.controller.loadAuthenticated('user-a');
      await _seedTransactionQueue(controllers.transactionsRepository);

      final ManualSyncResult result = await controllers.controller
          .runManualSync();

      expect(result.success, isTrue);
    expect(result.pushAttempted, isTrue);
    expect(result.rowsPushed, 1);
    expect(result.rowsFailed, 0);
    expect(result.pullAttempted, isTrue);
    expect(result.pullDocsApplied, 1);
    expect(result.alreadySynced, isFalse);
      expect(
        await controllers.database.select(controllers.database.syncQueue).get(),
        isEmpty,
      );
    },
  );

  test(
    'manual sync reports push failure and leaves queue rows in place',
    () async {
      final controllers = await _makeController(
        validationResult: const FirestoreAuthValidationResult(
          expectedUid: 'user-a',
          currentUid: 'user-a',
          isSignedIn: true,
          isUidMatch: true,
          tokenRefreshed: true,
          isValid: true,
        ),
        throwOnSyncTransactions: true,
      );
      await controllers.controller.loadAuthenticated('user-a');
      await _seedTransactionQueue(controllers.transactionsRepository);

      final ManualSyncResult result = await controllers.controller
          .runManualSync();

      expect(result.success, isFalse);
      expect(result.rowsFailed, 1);
      expect(
        await controllers.database.select(controllers.database.syncQueue).get(),
        hasLength(1),
      );
    },
  );

  test('manual sync reports pull failure without advancing cursors', () async {
    final controllers = await _makeController(
      validationResult: const FirestoreAuthValidationResult(
        expectedUid: 'user-a',
        currentUid: 'user-a',
        isSignedIn: true,
        isUidMatch: true,
        tokenRefreshed: true,
        isValid: true,
      ),
      throwOnLoadSavings: true,
    );
    await controllers.controller.loadAuthenticated('user-a');
    await _seedTransactionQueue(controllers.transactionsRepository);

    final ManualSyncResult result = await controllers.controller
        .runManualSync();

    expect(result.success, isFalse);
    expect(result.pullAttempted, isTrue);
    expect(result.cursorUpdates, 0);
    expect(
      await controllers.controller.localSyncPipeline!.lastPullSuccessAt(),
      isNull,
    );
  });

  test(
    'manual sync with no queue and no remote changes reports already synced',
    () async {
      final controllers = await _makeController(
        validationResult: const FirestoreAuthValidationResult(
          expectedUid: 'user-a',
          currentUid: 'user-a',
          isSignedIn: true,
          isUidMatch: true,
          tokenRefreshed: true,
          isValid: true,
        ),
      );
      await controllers.controller.loadAuthenticated('user-a');

      final ManualSyncResult result = await controllers.controller
          .runManualSync();

      expect(result.success, isTrue);
      expect(result.alreadySynced, isTrue);
      expect(result.message, 'Already synced');
      expect(result.pushAttempted, isFalse);
      expect(result.pullAttempted, isTrue);
    },
  );
}
