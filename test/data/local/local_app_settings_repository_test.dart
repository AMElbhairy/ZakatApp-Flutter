import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/daos/app_settings_dao.dart';
import 'package:zakatapp_flutter/data/repositories/local_app_settings_repository.dart';

void main() {
  late AppDatabase database;
  late LocalAppSettingsRepository repository;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    repository = LocalAppSettingsRepository(
      appSettingsDao: AppSettingsDao(database),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('imported settings can be read back as typed JSON', () async {
    await repository.importSettings(<String, dynamic>{
      'zakat_paid_months': <String>['2026-06'],
      'zakat_method': 'hawl',
    });

    expect(await repository.getJson<List<String>>('zakat_paid_months'), [
      '2026-06',
    ]);
    expect(await repository.getJson<String>('zakat_method'), 'hawl');
  });

  test('raw writes and map reads stay in sync', () async {
    await repository.setRaw('zakat_annual_date', '"09-01"');

    expect(await repository.getRaw('zakat_annual_date'), '"09-01"');
    expect(
      await repository.getAllSettings(),
      <String, dynamic>{'zakat_annual_date': '09-01'},
    );
  });
}
