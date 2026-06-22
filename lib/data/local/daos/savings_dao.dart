import 'package:drift/drift.dart';

import '../../../models/saving.dart' as model;
import '../app_database.dart' as db;
import '../mappers/savings_mapper.dart';

class SavingsDao extends DatabaseAccessor<db.AppDatabase> {
  SavingsDao(
    super.db, {
    SavingsMapper? mapper,
  }) : _mapper = mapper ?? const SavingsMapper();

  final SavingsMapper _mapper;

  Stream<List<model.Saving>> watchActiveSavings() {
    return (select(attachedDatabase.savings)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.dateAcquired),
            (tbl) => OrderingTerm.desc(tbl.createdAt),
          ]))
        .watch()
        .map(
          (List<db.Saving> rows) =>
              rows.map(_mapper.fromRow).toList(growable: false),
        );
  }

  Future<List<model.Saving>> getActiveSavings() async {
    final List<db.Saving> rows =
        await (select(attachedDatabase.savings)
              ..where((tbl) => tbl.deletedAt.isNull())
              ..orderBy([
                (tbl) => OrderingTerm.desc(tbl.dateAcquired),
                (tbl) => OrderingTerm.desc(tbl.createdAt),
              ]))
            .get();
    return rows.map(_mapper.fromRow).toList(growable: false);
  }

  Future<void> upsertSavingRow(
    model.Saving saving, {
    String? updatedAt,
    String? deletedAt,
  }) {
    return into(attachedDatabase.savings).insertOnConflictUpdate(
      _mapper.toCompanion(
        saving,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      ),
    );
  }

  Future<void> upsertSavingRows(
    Iterable<model.Saving> savings, {
    String? updatedAt,
  }) async {
    final List<db.SavingsCompanion> rows = savings
        .map(
          (model.Saving saving) =>
              _mapper.toCompanion(saving, updatedAt: updatedAt),
        )
        .toList(growable: false);
    if (rows.isEmpty) return;
    await batch((Batch batch) {
      batch.insertAllOnConflictUpdate(attachedDatabase.savings, rows);
    });
  }

  Future<void> markSavingDeleted(
    String id, {
    required String deletedAt,
  }) {
    return (update(attachedDatabase.savings)..where((tbl) => tbl.id.equals(id)))
        .write(
          db.SavingsCompanion(
            deletedAt: Value<String>(deletedAt),
            updatedAt: Value<String>(deletedAt),
          ),
        );
  }

  Future<List<model.Saving>> getChangedSince(String updatedAtCursor) async {
    final List<db.Saving> rows =
        await (select(attachedDatabase.savings)
              ..where(
                (tbl) =>
                    tbl.deletedAt.isNull() &
                    tbl.updatedAt.isBiggerThanValue(updatedAtCursor),
              )
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.updatedAt)]))
            .get();
    return rows.map(_mapper.fromRow).toList(growable: false);
  }

  Future<List<db.Saving>> getDeletedSince(String deletedAtCursor) {
    return (select(attachedDatabase.savings)
          ..where(
            (tbl) =>
                tbl.deletedAt.isNotNull() &
                tbl.deletedAt.isBiggerThanValue(deletedAtCursor),
          )
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.deletedAt)]))
        .get();
  }

  Future<void> replaceAllSavingsSnapshot(Iterable<model.Saving> savings) async {
    await transaction(() async {
      await delete(attachedDatabase.savings).go();
      await upsertSavingRows(savings);
    });
  }
}
