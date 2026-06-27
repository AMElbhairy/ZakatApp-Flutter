import 'package:drift/drift.dart';

import '../../../models/financial_plan.dart';
import '../app_database.dart' as db;
import '../mappers/financial_plan_mapper.dart';

class FinancialPlansDao extends DatabaseAccessor<db.AppDatabase> {
  FinancialPlansDao(
    super.db, {
    FinancialPlanMapper? mapper,
  }) : _mapper = mapper ?? const FinancialPlanMapper();

  final FinancialPlanMapper _mapper;

  Stream<List<FinancialPlan>> watchActiveFinancialPlans() {
    return (select(attachedDatabase.financialPlans)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.createdAt),
            (tbl) => OrderingTerm.desc(tbl.startDate),
          ]))
        .watch()
        .map(
          (List<db.FinancialPlan> rows) =>
              rows.map(_mapper.fromRow).toList(growable: false),
        );
  }

  Future<List<FinancialPlan>> getActiveFinancialPlans() async {
    final List<db.FinancialPlan> rows =
        await (select(attachedDatabase.financialPlans)
              ..where((tbl) => tbl.deletedAt.isNull())
              ..orderBy([
                (tbl) => OrderingTerm.desc(tbl.createdAt),
                (tbl) => OrderingTerm.desc(tbl.startDate),
              ]))
            .get();
    return rows.map(_mapper.fromRow).toList(growable: false);
  }

  Future<void> upsertFinancialPlanRow(
    FinancialPlan plan, {
    String? updatedAt,
    String? deletedAt,
  }) {
    return into(attachedDatabase.financialPlans).insertOnConflictUpdate(
      _mapper.toCompanion(plan, updatedAt: updatedAt, deletedAt: deletedAt),
    );
  }

  Future<void> upsertFinancialPlanRows(
    Iterable<FinancialPlan> plans, {
    String? updatedAt,
  }) async {
    final List<db.FinancialPlansCompanion> rows = plans
        .map(
          (FinancialPlan plan) =>
              _mapper.toCompanion(plan, updatedAt: updatedAt),
        )
        .toList(growable: false);
    if (rows.isEmpty) return;
    await batch((Batch batch) {
      batch.insertAllOnConflictUpdate(attachedDatabase.financialPlans, rows);
    });
  }

  Future<void> markFinancialPlanDeleted(
    String id, {
    required String deletedAt,
  }) {
    return (update(attachedDatabase.financialPlans)
          ..where((tbl) => tbl.id.equals(id)))
        .write(
          db.FinancialPlansCompanion(
            deletedAt: Value<String>(deletedAt),
            updatedAt: Value<String>(deletedAt),
          ),
        );
  }

  Future<void> replaceAllFinancialPlansSnapshot(
    Iterable<FinancialPlan> plans,
  ) async {
    await transaction(() async {
      await delete(attachedDatabase.financialPlans).go();
      await upsertFinancialPlanRows(plans);
    });
  }
}
