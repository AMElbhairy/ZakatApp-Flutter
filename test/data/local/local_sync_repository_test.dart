import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_metadata_dao.dart';
import 'package:zakatapp_flutter/data/repositories/local_sync_repository.dart';

void main() {
  late AppDatabase database;
  late LocalSyncRepository repository;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    repository = LocalSyncRepository(
      syncMetadataDao: SyncMetadataDao(database),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('set and get sync cursors', () async {
    await repository.setCursor('savings', '2026-06-19T09:00:00.000Z');
    await repository.setDeletedCursor(
      'savings',
      '2026-06-19T10:00:00.000Z',
    );

    expect(await repository.getCursor('savings'), '2026-06-19T09:00:00.000Z');
    expect(
      await repository.getDeletedCursor('savings'),
      '2026-06-19T10:00:00.000Z',
    );
  });

  test('set and get last sync success', () async {
    await repository.setLastSyncSuccessAt('2026-06-19T12:00:00.000Z');

    expect(
      await repository.getLastSyncSuccessAt(),
      '2026-06-19T12:00:00.000Z',
    );
  });
}
