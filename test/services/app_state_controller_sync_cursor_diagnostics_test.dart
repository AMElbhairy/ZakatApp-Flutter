import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_metadata_dao.dart';
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

class _StaticGate implements UseSqliteLocalStoreProvider {
  _StaticGate(this.value);

  final bool value;

  @override
  Future<bool> prepareForRead({String? userId}) async => value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'collectDiagnostics reads persisted pull cursors by expected key name',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final AppDatabase database = AppDatabase(
        executor: NativeDatabase.memory(),
      );
      final SyncMetadataDao metadataDao = SyncMetadataDao(database);
      final AppStateRepository repository = AppStateRepository(
        localStorage: const LocalStorageService(),
      );
      final AppStateController controller = AppStateController(
        repository: repository,
        database: database,
        ownsDatabase: false,
        useSqliteLocalStoreProvider: _StaticGate(true),
        enableBackgroundSync: false,
        enableMarketAutoRefresh: false,
      );

      try {
        await repository.saveAppState(
          AppStateDefaults.create().copyWith(userId: 'user-1'),
          userId: 'user-1',
        );
        await controller.loadAuthenticated('user-1');

        await metadataDao.setCursor('transactions', '2026-06-19T09:00:00.000Z');
        await metadataDao.setDeletedCursor(
          'transactions',
          '2026-06-19T09:05:00.000Z',
        );
        await metadataDao.setCursor(
          'pending_transactions',
          '2026-06-19T10:00:00.000Z',
        );
        await metadataDao.setDeletedCursor(
          'pending_transactions',
          '2026-06-19T10:05:00.000Z',
        );

        final diagnostics = await controller.collectDiagnostics();

        expect(
          diagnostics.syncCursors['transactions_cursor'],
          '2026-06-19T09:00:00.000Z',
        );
        expect(
          diagnostics.syncCursors['transactions_deleted_cursor'],
          '2026-06-19T09:05:00.000Z',
        );
        expect(
          diagnostics.syncCursors['pending_transactions_cursor'],
          '2026-06-19T10:00:00.000Z',
        );
        expect(
          diagnostics.syncCursors['pending_transactions_deleted_cursor'],
          '2026-06-19T10:05:00.000Z',
        );
      } finally {
        await database.close();
      }
    },
  );
}
