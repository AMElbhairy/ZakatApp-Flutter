import 'package:drift/drift.dart';

import '../../../models/recurring_transaction.dart';
import '../app_database.dart' as db;
import '../mappers/recurring_transaction_mapper.dart';

class RecurringTransactionsDao extends DatabaseAccessor<db.AppDatabase> {
  RecurringTransactionsDao(
    super.db, {
    RecurringTransactionMapper? mapper,
  }) : _mapper = mapper ?? const RecurringTransactionMapper();

  final RecurringTransactionMapper _mapper;

  Stream<List<RecurringTransaction>> watchActiveRecurringTransactions() {
    return (select(attachedDatabase.recurringTransactions)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.dayOfMonth),
            (tbl) => OrderingTerm.desc(tbl.createdAt),
          ]))
        .watch()
        .map(
          (List<db.RecurringTransaction> rows) =>
              rows.map(_mapper.fromRow).toList(growable: false),
        );
  }

  Future<List<RecurringTransaction>> getActiveRecurringTransactions() async {
    final List<db.RecurringTransaction> rows =
        await (select(attachedDatabase.recurringTransactions)
              ..where((tbl) => tbl.deletedAt.isNull())
              ..orderBy([
                (tbl) => OrderingTerm.asc(tbl.dayOfMonth),
                (tbl) => OrderingTerm.desc(tbl.createdAt),
              ]))
            .get();
    return rows.map(_mapper.fromRow).toList(growable: false);
  }

  Future<void> upsertRecurringTransactionRow(
    RecurringTransaction recurring, {
    String? updatedAt,
    String? deletedAt,
  }) {
    return into(attachedDatabase.recurringTransactions).insertOnConflictUpdate(
      _mapper.toCompanion(
        recurring,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      ),
    );
  }

  Future<void> upsertRecurringTransactionRows(
    Iterable<RecurringTransaction> recurringTransactions, {
    String? updatedAt,
  }) async {
    final List<db.RecurringTransactionsCompanion> rows = recurringTransactions
        .map(
          (RecurringTransaction recurring) =>
              _mapper.toCompanion(recurring, updatedAt: updatedAt),
        )
        .toList(growable: false);
    if (rows.isEmpty) return;
    await batch((Batch batch) {
      batch.insertAllOnConflictUpdate(
        attachedDatabase.recurringTransactions,
        rows,
      );
    });
  }

  Future<void> markRecurringTransactionDeleted(
    String id, {
    required String deletedAt,
  }) {
    return (update(attachedDatabase.recurringTransactions)
          ..where((tbl) => tbl.id.equals(id)))
        .write(
          db.RecurringTransactionsCompanion(
            deletedAt: Value<String>(deletedAt),
            updatedAt: Value<String>(deletedAt),
          ),
        );
  }

  Future<void> replaceAllRecurringTransactionsSnapshot(
    Iterable<RecurringTransaction> recurringTransactions,
  ) async {
    await transaction(() async {
      await delete(attachedDatabase.recurringTransactions).go();
      await upsertRecurringTransactionRows(recurringTransactions);
    });
  }
}
