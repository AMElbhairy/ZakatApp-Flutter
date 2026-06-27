import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/daos/savings_dao.dart';
import 'package:zakatapp_flutter/data/local/mappers/savings_mapper.dart';
import 'package:zakatapp_flutter/models/saving.dart' as model;

void main() {
  late SavingsMapper mapper;
  late AppDatabase database;
  late SavingsDao dao;

  setUp(() {
    mapper = const SavingsMapper();
    database = AppDatabase(executor: NativeDatabase.memory());
    dao = SavingsDao(database, mapper: mapper);
  });

  tearDown(() async {
    await database.close();
  });

  test('mapper preserves id and converts amount to text', () {
    const saving = model.Saving(
      id: 'sv1',
      assetType: 'cash',
      dateAcquired: '2026-06-19',
      amount: 500.25,
      remainingAmount: 450,
      unit: 'USD',
      description: 'Reserve',
      purchaseCurrency: 'USD',
      purchaseAmount: 500.25,
      createdAt: '2026-06-19T12:00:00.000Z',
    );

    final companion = mapper.toCompanion(saving);

    expect(companion.id.value, 'sv1');
    expect(companion.amountText.value, '500.25');
    expect(companion.remainingAmountText.value, '450');
  });

  test('active savings query excludes deleted_at rows', () async {
    const active = model.Saving(
      id: 'active-saving',
      assetType: 'cash',
      dateAcquired: '2026-06-19',
      amount: 500,
      remainingAmount: 450,
      unit: 'USD',
      description: 'Active',
      purchaseCurrency: 'USD',
      purchaseAmount: 500,
      createdAt: '2026-06-19T12:00:00.000Z',
    );
    const deleted = model.Saving(
      id: 'deleted-saving',
      assetType: 'gold',
      dateAcquired: '2026-06-18',
      amount: 100,
      remainingAmount: 100,
      unit: 'GRAM',
      description: 'Deleted',
      purchaseCurrency: 'USD',
      purchaseAmount: 100,
      createdAt: '2026-06-18T12:00:00.000Z',
    );

    await dao.upsertSavingRow(active);
    await dao.upsertSavingRow(
      deleted,
      deletedAt: '2026-06-19T13:00:00.000Z',
      updatedAt: '2026-06-19T13:00:00.000Z',
    );

    final rows = await dao.getActiveSavings();

    expect(rows.map((model.Saving row) => row.id), <String>['active-saving']);
  });
}
