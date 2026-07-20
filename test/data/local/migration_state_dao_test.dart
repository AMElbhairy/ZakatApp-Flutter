import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/daos/migration_state_dao.dart';

void main() {
  late AppDatabase database;
  late MigrationStateDao dao;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    dao = MigrationStateDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('set/get/clear migration state values', () async {
    await dao.setValue(jsonToSqliteV1StartedAt, '2026-06-19T12:00:00.000Z');

    expect(
      await dao.getValue(jsonToSqliteV1StartedAt),
      '2026-06-19T12:00:00.000Z',
    );

    await dao.clearValue(jsonToSqliteV1StartedAt);

    expect(await dao.getValue(jsonToSqliteV1StartedAt), isNull);
  });

  test('completed flag depends on completed_at value', () async {
    expect(await dao.hasCompletedJsonToSqliteV1(), isFalse);

    await dao.setValue(jsonToSqliteV1CompletedAt, '2026-06-19T12:00:00.000Z');

    expect(await dao.hasCompletedJsonToSqliteV1(), isTrue);
  });
}
