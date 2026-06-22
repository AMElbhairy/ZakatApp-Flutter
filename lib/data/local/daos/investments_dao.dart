import 'package:drift/drift.dart';

import '../../../models/investment_asset.dart' as model;
import '../app_database.dart' as db;
import '../mappers/investments_mapper.dart';

class InvestmentsDao extends DatabaseAccessor<db.AppDatabase> {
  InvestmentsDao(super.db, {InvestmentsMapper? mapper})
    : _mapper = mapper ?? const InvestmentsMapper();

  final InvestmentsMapper _mapper;

  Stream<List<model.InvestmentAsset>> watchActiveInvestments() {
    return (select(attachedDatabase.investments)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .watch()
        .map(
          (List<db.Investment> rows) =>
              rows.map(_mapper.fromRow).toList(growable: false),
        );
  }

  Future<List<model.InvestmentAsset>> getActiveInvestments() async {
    final List<db.Investment> rows =
        await (select(attachedDatabase.investments)
              ..where((tbl) => tbl.deletedAt.isNull())
              ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
            .get();
    return rows.map(_mapper.fromRow).toList(growable: false);
  }

  Future<void> upsertInvestmentRow(
    model.InvestmentAsset row, {
    String? updatedAt,
    String? deletedAt,
  }) {
    return into(attachedDatabase.investments).insertOnConflictUpdate(
      _mapper.toCompanion(row, updatedAt: updatedAt, deletedAt: deletedAt),
    );
  }

  Future<void> upsertInvestmentRows(
    Iterable<model.InvestmentAsset> rows, {
    String? updatedAt,
  }) async {
    final List<db.InvestmentsCompanion> companions = rows
        .map(
          (model.InvestmentAsset row) =>
              _mapper.toCompanion(row, updatedAt: updatedAt),
        )
        .toList(growable: false);
    if (companions.isEmpty) return;
    await batch((Batch batch) {
      batch.insertAllOnConflictUpdate(attachedDatabase.investments, companions);
    });
  }

  Future<void> markInvestmentDeleted(String id, {required String deletedAt}) {
    return (update(
      attachedDatabase.investments,
    )..where((tbl) => tbl.id.equals(id))).write(
      db.InvestmentsCompanion(
        deletedAt: Value<String>(deletedAt),
        updatedAt: Value<String>(deletedAt),
      ),
    );
  }

  Future<List<model.InvestmentAsset>> getChangedSince(
    String updatedAtCursor,
  ) async {
    final List<db.Investment> rows =
        await (select(attachedDatabase.investments)
              ..where(
                (tbl) =>
                    tbl.deletedAt.isNull() &
                    tbl.updatedAt.isBiggerThanValue(updatedAtCursor),
              )
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.updatedAt)]))
            .get();
    return rows.map(_mapper.fromRow).toList(growable: false);
  }

  Future<List<db.Investment>> getDeletedSince(String deletedAtCursor) {
    return (select(attachedDatabase.investments)
          ..where(
            (tbl) =>
                tbl.deletedAt.isNotNull() &
                tbl.deletedAt.isBiggerThanValue(deletedAtCursor),
          )
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.deletedAt)]))
        .get();
  }

  Future<void> replaceAllInvestmentSnapshot(
    Iterable<model.InvestmentAsset> investments,
  ) async {
    await transaction(() async {
      await delete(attachedDatabase.investments).go();
      await upsertInvestmentRows(investments);
    });
  }
}
