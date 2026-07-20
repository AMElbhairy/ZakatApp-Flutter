import 'package:flutter_test/flutter_test.dart';

import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/collection_hydration_evidence.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

class _RecordingAppStateRepository extends AppStateRepository {
  _RecordingAppStateRepository({required super.localStorage});

  int saveCalls = 0;

  @override
  Future<AppStateModel> loadAppState({String? userId}) async {
    return AppStateDefaults.create();
  }

  @override
  Future<void> saveAppState(AppStateModel state, {String? userId}) async {
    saveCalls += 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('authoritative writes are blocked before hydration is ready', () async {
    final _RecordingAppStateRepository repository = _RecordingAppStateRepository(
      localStorage: const LocalStorageService(),
    );
    final AppStateController controller = AppStateController(
      repository: repository,
      enableBackgroundSync: false,
      enableMarketAutoRefresh: false,
    );

    expect(controller.hydrationPhase, AppHydrationPhase.notStarted);

    await controller.save();
    expect(repository.saveCalls, 0);

    await controller.updateState(
      AppStateDefaults.create().copyWith(mainCurrency: 'USD'),
    );
    expect(repository.saveCalls, 0);
    expect(controller.hydrationPhase, AppHydrationPhase.notStarted);
  });
}
