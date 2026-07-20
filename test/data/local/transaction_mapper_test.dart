import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/daos/transactions_dao.dart';
import 'package:zakatapp_flutter/data/local/mappers/transactions_mapper.dart';
import 'package:zakatapp_flutter/models/transaction.dart' as model;

void main() {
  late TransactionsMapper mapper;
  late AppDatabase database;
  late TransactionsDao dao;

  setUp(() {
    mapper = const TransactionsMapper();
    database = AppDatabase(executor: NativeDatabase.memory());
    dao = TransactionsDao(database, mapper: mapper);
  });

  tearDown(() async {
    await database.close();
  });

  test('mapper preserves id and converts amount to text', () {
    const transaction = model.Transaction(
      id: 'tx1',
      type: 'income',
      date: '2026-06-19',
      amount: 1234.5,
      currency: 'USD',
      category: 'Salary',
      description: 'Monthly salary',
      createdAt: '2026-06-19T12:00:00.000Z',
      rolledOver: false,
    );

    final companion = mapper.toCompanion(transaction);

    expect(companion.id.value, 'tx1');
    expect(companion.amountText.value, '1234.5');
  });

  test('active transaction query excludes deleted_at rows', () async {
    const active = model.Transaction(
      id: 'active-tx',
      type: 'income',
      date: '2026-06-19',
      amount: 50,
      currency: 'USD',
      category: 'Salary',
      description: 'Active',
      createdAt: '2026-06-19T12:00:00.000Z',
      rolledOver: false,
    );
    const deleted = model.Transaction(
      id: 'deleted-tx',
      type: 'expense',
      date: '2026-06-18',
      amount: 20,
      currency: 'USD',
      category: 'Food',
      description: 'Deleted',
      createdAt: '2026-06-18T12:00:00.000Z',
      rolledOver: false,
    );

    await dao.upsertTransactionRow(active);
    await dao.upsertTransactionRow(
      deleted,
      deletedAt: '2026-06-19T13:00:00.000Z',
      updatedAt: '2026-06-19T13:00:00.000Z',
    );

    final rows = await dao.getActiveTransactions();

    expect(rows.map((model.Transaction tx) => tx.id), <String>['active-tx']);
  });
}
