import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/daos/app_settings_dao.dart';

void main() {
  late AppDatabase database;
  late AppSettingsDao dao;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    dao = AppSettingsDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('setRaw and getRaw round trip values', () async {
    await dao.setRaw('zakat_method', '"hawl"');

    expect(await dao.getRaw('zakat_method'), '"hawl"');
    expect(await dao.getJson<String>('zakat_method'), 'hawl');
  });

  test('setJson, getAllSettings and importSettings preserve JSON values', () async {
    await dao.setJson('zakat_paid_months', <String>['2026-06']);
    await dao.importSettings(<String, dynamic>{
      'zakat_expense_ids': <String, dynamic>{'2026-06': 'tx-1'},
      'processed_expense_ids': <String>['tx-1'],
    });

    final Map<String, dynamic> allSettings = await dao.getAllSettings();

    expect(allSettings['zakat_paid_months'], <dynamic>['2026-06']);
    expect(
      allSettings['zakat_expense_ids'],
      <String, dynamic>{'2026-06': 'tx-1'},
    );
    expect(allSettings['processed_expense_ids'], <dynamic>['tx-1']);
  });
}
