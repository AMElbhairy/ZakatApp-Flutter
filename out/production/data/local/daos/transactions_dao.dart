import 'package:drift/drift.dart';

import '../../../models/transaction.dart' as model;
import '../app_database.dart' as db;
import '../mappers/transactions_mapper.dart';

class TransactionsDao extends DatabaseAccessor<db.AppDatabase> {
  TransactionsDao(
    super.db, {
    TransactionsMapper? mapper,
  }) : _mapper = mapper ?? const TransactionsMapper();

  final TransactionsMapper _mapper;

  Stream<List<model.Transaction>> watchActiveTransactions() {
    return (select(attachedDatabase.transactions)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.date),
            (tbl) => OrderingTerm.desc(tbl.createdAt),
          ]))
        .watch()
        .map(
          (List<db.Transaction> rows) =>
              rows.map(_mapper.fromRow).toList(growable: false),
        );
  }

  Future<List<model.Transaction>> getActiveTransactions() async {
    final List<db.Transaction> rows =
        await (select(attachedDatabase.transactions)
              ..where((tbl) => tbl.deletedAt.isNull())
              ..orderBy([
                (tbl) => OrderingTerm.desc(tbl.date),
                (tbl) => OrderingTerm.desc(tbl.createdAt),
              ]))
            .get();
    return rows.map(_mapper.fromRow).toList(growable: false);
  }

  Future<void> upsertTransactionRow(
    model.Transaction transaction, {
    String? updatedAt,
    String? deletedAt,
  }) {
    return into(attachedDatabase.transactions).insertOnConflictUpdate(
      _mapper.toCompanion(
        transaction,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      ),
    );
  }

  Future<void> upsertTransactionRows(
    Iterable<model.Transaction> transactions, {
    String? updatedAt,
  }) async {
    final List<db.TransactionsCompanion> rows = transactions
        .map(
          (model.Transaction transaction) =>
              _mapper.toCompanion(transaction, updatedAt: updatedAt),
        )
        .toList(growable: false);
    if (rows.isEmpty) return;
    await batch((Batch batch) {
      batch.insertAllOnConflictUpdate(attachedDatabase.transactions, rows);
    });
  }

  Future<void> markTransactionDeleted(
    String id, {
    required String deletedAt,
  }) {
    return (update(attachedDatabase.transactions)
          ..where((tbl) => tbl.id.equals(id)))
        .write(
          db.TransactionsCompanion(
            deletedAt: Value<String>(deletedAt),
            updatedAt: Value<String>(deletedAt),
          ),
        );
  }

  Future<List<model.Transaction>> getChangedSince(String updatedAtCursor) async {
    final List<db.Transaction> rows =
        await (select(attachedDatabase.transactions)
              ..where(
                (tbl) =>
                    tbl.deletedAt.isNull() &
                    tbl.updatedAt.isBiggerThanValue(updatedAtCursor),
              )
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.updatedAt)]))
            .get();
    return rows.map(_mapper.fromRow).toList(growable: false);
  }

  Future<List<db.Transaction>> getDeletedSince(String deletedAtCursor) {
    return (select(attachedDatabase.transactions)
          ..where(
            (tbl) =>
                tbl.deletedAt.isNotNull() &
                tbl.deletedAt.isBiggerThanValue(deletedAtCursor),
          )
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.deletedAt)]))
        .get();
  }

  Future<void> replaceAllTransactionsSnapshot(
    Iterable<model.Transaction> transactions,
  ) async {
    await transaction(() async {
      await delete(attachedDatabase.transactions).go();
      await upsertTransactionRows(transactions);
    });
  }
}
