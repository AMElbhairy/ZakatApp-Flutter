import 'package:drift/drift.dart';

import '../../../models/correction_feedback.dart';
import '../app_database.dart' as db;
import '../mappers/correction_feedback_mapper.dart';

class CorrectionFeedbackDao extends DatabaseAccessor<db.AppDatabase> {
  CorrectionFeedbackDao(
    super.db, {
    CorrectionFeedbackMapper? mapper,
  }) : _mapper = mapper ?? const CorrectionFeedbackMapper();

  final CorrectionFeedbackMapper _mapper;

  Stream<List<CorrectionFeedback>> watchActiveCorrectionFeedback() {
    return (select(attachedDatabase.correctionFeedbacks)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.createdAt),
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
            (tbl) => OrderingTerm.asc(tbl.id),
          ]))
        .watch()
        .map(
          (List<db.CorrectionFeedback> rows) =>
              rows.map(_mapper.fromRow).toList(growable: false),
        );
  }

  Future<List<CorrectionFeedback>> getActiveCorrectionFeedback() async {
    final List<db.CorrectionFeedback> rows =
        await (select(attachedDatabase.correctionFeedbacks)
              ..where((tbl) => tbl.deletedAt.isNull())
              ..orderBy([
                (tbl) => OrderingTerm.desc(tbl.createdAt),
                (tbl) => OrderingTerm.desc(tbl.updatedAt),
                (tbl) => OrderingTerm.asc(tbl.id),
              ]))
            .get();
    return rows.map(_mapper.fromRow).toList(growable: false);
  }

  Future<void> upsertCorrectionFeedbackRow(
    CorrectionFeedback item, {
    String? updatedAt,
    String? deletedAt,
  }) {
    return into(attachedDatabase.correctionFeedbacks).insertOnConflictUpdate(
      _mapper.toCompanion(item, updatedAt: updatedAt, deletedAt: deletedAt),
    );
  }

  Future<void> upsertCorrectionFeedbackRows(
    Iterable<CorrectionFeedback> items, {
    String? updatedAt,
  }) async {
    final List<db.CorrectionFeedbacksCompanion> rows = items
        .map(
          (CorrectionFeedback item) =>
              _mapper.toCompanion(item, updatedAt: updatedAt),
        )
        .toList(growable: false);
    if (rows.isEmpty) return;
    await batch((Batch batch) {
      batch.insertAllOnConflictUpdate(attachedDatabase.correctionFeedbacks, rows);
    });
  }

  Future<void> markCorrectionFeedbackDeleted(
    String id, {
    required String deletedAt,
  }) {
    return (update(attachedDatabase.correctionFeedbacks)
          ..where((tbl) => tbl.id.equals(id)))
        .write(
          db.CorrectionFeedbacksCompanion(
            deletedAt: Value<String>(deletedAt),
            updatedAt: Value<String>(deletedAt),
          ),
        );
  }

  Future<void> replaceAllCorrectionFeedbackSnapshot(
    Iterable<CorrectionFeedback> items,
  ) async {
    await transaction(() async {
      await delete(attachedDatabase.correctionFeedbacks).go();
      await upsertCorrectionFeedbackRows(items);
    });
  }
}
