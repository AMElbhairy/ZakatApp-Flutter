import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_metadata_dao.dart';

void main() {
  late AppDatabase database;
  late SyncMetadataDao dao;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    dao = SyncMetadataDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('persists collection cursors and deleted cursors', () async {
    await dao.setCursor('transactions', '2026-06-19T10:00:00.000Z');
    await dao.setDeletedCursor(
      'transactions',
      '2026-06-19T11:00:00.000Z',
    );

    expect(
      await dao.getCursor('transactions'),
      '2026-06-19T10:00:00.000Z',
    );
    expect(
      await dao.getDeletedCursor('transactions'),
      '2026-06-19T11:00:00.000Z',
    );
  });

  test('persists last sync success timestamp', () async {
    await dao.setValue(lastSyncSuccessAtKey, '2026-06-19T12:00:00.000Z');

    expect(
      await dao.getValue(lastSyncSuccessAtKey),
      '2026-06-19T12:00:00.000Z',
    );
  });
}
