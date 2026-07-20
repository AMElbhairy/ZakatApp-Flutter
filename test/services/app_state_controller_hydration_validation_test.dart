import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/transaction.dart' as model;
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/collection_hydration_evidence.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

class _StubRepository extends AppStateRepository {
  _StubRepository({
    required super.localStorage,
    required this.result,
  });

  final AppStateLoadResult result;

  @override
  Future<AppStateLoadResult> loadAppStateResult({String? userId}) async {
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('missing persisted state can still reach ready as legitimate empty', () async {
    final AppStateController controller = AppStateController(
      repository: _StubRepository(
        localStorage: const LocalStorageService(),
        result: AppStateLoadResult(
          state: AppStateDefaults.create(),
          source: AppStateLoadSource.missing,
          rawStatePresent: false,
        ),
      ),
    );

    await controller.load();

    expect(controller.isHydrationReady, isTrue);
    expect(controller.hydrationPhase, AppHydrationPhase.ready);
    expect(
      controller.collectionHydrationEvidence['app_settings']?.status,
      CollectionLoadStatus.missingForNewProfile,
    );
  });

  test('parsed app-state fallback is rejected before ready', () async {
    final AppStateController controller = AppStateController(
      repository: _StubRepository(
        localStorage: const LocalStorageService(),
        result: AppStateLoadResult(
          state: AppStateDefaults.create(),
          source: AppStateLoadSource.parseFailed,
          rawStatePresent: true,
          failureCode: 'parse_failed',
        ),
      ),
    );

    await controller.load();

    expect(controller.isHydrationReady, isFalse);
    expect(controller.hasHydrationFailure, isTrue);
    expect(controller.hydrationPhase, AppHydrationPhase.failed);
    expect(
      controller.collectionHydrationEvidence['app_settings']?.status,
      CollectionLoadStatus.fallbackDefault,
    );

    await controller.addTransaction(
      const model.Transaction(
        id: 'blocked-tx',
        type: 'income',
        date: '2026-07-02',
        amount: 1,
        currency: 'USD',
        category: 'Salary',
        description: '',
        createdAt: '2026-07-02T00:00:00.000Z',
        rolledOver: false,
      ),
    );
    expect(controller.state.transactions, isEmpty);
  });

  test('loaded app-state data remains ready without SQLite repositories', () async {
    final AppStateModel seeded = AppStateDefaults.create().copyWith(
      transactions: <model.Transaction>[
        const model.Transaction(
          id: 'tx-1',
          type: 'income',
          date: '2026-07-01',
          amount: 100,
          currency: 'USD',
          category: 'Salary',
          description: '',
          createdAt: '2026-07-01T00:00:00.000Z',
          rolledOver: false,
        ),
      ],
    );
    final AppStateController controller = AppStateController(
      repository: _StubRepository(
        localStorage: const LocalStorageService(),
        result: AppStateLoadResult(
          state: seeded,
          source: AppStateLoadSource.loaded,
          rawStatePresent: true,
        ),
      ),
    );

    await controller.load();

    expect(controller.isHydrationReady, isTrue);
    expect(controller.hydrationPhase, AppHydrationPhase.ready);
    expect(
      controller.collectionHydrationEvidence['transactions']?.status,
      CollectionLoadStatus.loadedAuthoritative,
    );
    expect(controller.state.transactions, hasLength(1));
  });
}
