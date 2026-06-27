import 'package:drift/drift.dart';

import '../../../models/pending_transaction.dart' as model;
import '../app_database.dart' as db;
import '../mappers/pending_transactions_mapper.dart';

class PendingTransactionsDao extends DatabaseAccessor<db.AppDatabase> {
  PendingTransactionsDao(super.db, {PendingTransactionsMapper? mapper})
    : _mapper = mapper ?? const PendingTransactionsMapper();

  final PendingTransactionsMapper _mapper;

  Stream<List<model.PendingTransaction>> watchActivePendingTransactions() {
    return (select(attachedDatabase.pendingTransactions)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .watch()
        .map(
          (List<db.PendingTransaction> rows) =>
              rows.map(_mapper.fromRow).toList(growable: false),
        );
  }

  Future<List<model.PendingTransaction>> getActivePendingTransactions() async {
    final List<db.PendingTransaction> rows =
        await (select(attachedDatabase.pendingTransactions)
              ..where((tbl) => tbl.deletedAt.isNull())
              ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
            .get();
    return rows.map(_mapper.fromRow).toList(growable: false);
  }

  Future<void> upsertPendingTransactionRow(
    model.PendingTransaction row, {
    String? updatedAt,
    String? deletedAt,
  }) {
    return into(attachedDatabase.pendingTransactions).insertOnConflictUpdate(
      _mapper.toCompanion(row, updatedAt: updatedAt, deletedAt: deletedAt),
    );
  }

  Future<void> upsertPendingTransactionRows(
    Iterable<model.PendingTransaction> rows, {
    String? updatedAt,
  }) async {
    final List<db.PendingTransactionsCompanion> companions = rows
        .map(
          (model.PendingTransaction row) =>
              _mapper.toCompanion(row, updatedAt: updatedAt),
        )
        .toList(growable: false);
    if (companions.isEmpty) return;
    await batch((Batch batch) {
      batch.insertAllOnConflictUpdate(
        attachedDatabase.pendingTransactions,
        companions,
      );
    });
  }

  Future<void> markPendingTransactionDeleted(
    String id, {
    required String deletedAt,
  }) {
    return (update(
      attachedDatabase.pendingTransactions,
    )..where((tbl) => tbl.id.equals(id))).write(
      db.PendingTransactionsCompanion(
        deletedAt: Value<String>(deletedAt),
        updatedAt: Value<String>(deletedAt),
      ),
    );
  }

  Future<List<model.PendingTransaction>> getChangedSince(
    String updatedAtCursor,
  ) async {
    final List<db.PendingTransaction> rows =
        await (select(attachedDatabase.pendingTransactions)
              ..where(
                (tbl) =>
                    tbl.deletedAt.isNull() &
                    tbl.updatedAt.isBiggerThanValue(updatedAtCursor),
              )
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.updatedAt)]))
            .get();
    return rows.map(_mapper.fromRow).toList(growable: false);
  }

  Future<List<db.PendingTransaction>> getDeletedSince(String deletedAtCursor) {
    return (select(attachedDatabase.pendingTransactions)
          ..where(
            (tbl) =>
                tbl.deletedAt.isNotNull() &
                tbl.deletedAt.isBiggerThanValue(deletedAtCursor),
          )
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.deletedAt)]))
        .get();
  }

  Future<void> replaceAllPendingTransactionSnapshot(
    Iterable<model.PendingTransaction> rows,
  ) async {
    await transaction(() async {
      await delete(attachedDatabase.pendingTransactions).go();
      await upsertPendingTransactionRows(rows);
    });
  }
}
