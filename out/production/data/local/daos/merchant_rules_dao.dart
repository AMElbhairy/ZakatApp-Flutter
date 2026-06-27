import 'package:drift/drift.dart';

import '../../../models/merchant_rule.dart';
import '../app_database.dart' as db;
import '../mappers/merchant_rule_mapper.dart';

class MerchantRulesDao extends DatabaseAccessor<db.AppDatabase> {
  MerchantRulesDao(
    super.db, {
    MerchantRuleMapper? mapper,
  }) : _mapper = mapper ?? const MerchantRuleMapper();

  final MerchantRuleMapper _mapper;

  Stream<List<MerchantRule>> watchActiveMerchantRules() {
    return (select(attachedDatabase.merchantRules)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.usageCount),
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
            (tbl) => OrderingTerm.asc(tbl.id),
          ]))
        .watch()
        .map(
          (List<db.MerchantRule> rows) =>
              rows.map(_mapper.fromRow).toList(growable: false),
        );
  }

  Future<List<MerchantRule>> getActiveMerchantRules() async {
    final List<db.MerchantRule> rows =
        await (select(attachedDatabase.merchantRules)
              ..where((tbl) => tbl.deletedAt.isNull())
              ..orderBy([
                (tbl) => OrderingTerm.desc(tbl.usageCount),
                (tbl) => OrderingTerm.desc(tbl.updatedAt),
                (tbl) => OrderingTerm.asc(tbl.id),
              ]))
            .get();
    return rows.map(_mapper.fromRow).toList(growable: false);
  }

  Future<void> upsertMerchantRuleRow(
    MerchantRule rule, {
    String? updatedAt,
    String? deletedAt,
  }) {
    return into(attachedDatabase.merchantRules).insertOnConflictUpdate(
      _mapper.toCompanion(rule, updatedAt: updatedAt, deletedAt: deletedAt),
    );
  }

  Future<void> upsertMerchantRuleRows(
    Iterable<MerchantRule> rules, {
    String? updatedAt,
  }) async {
    final List<db.MerchantRulesCompanion> rows = rules
        .map(
          (MerchantRule rule) =>
              _mapper.toCompanion(rule, updatedAt: updatedAt),
        )
        .toList(growable: false);
    if (rows.isEmpty) return;
    await batch((Batch batch) {
      batch.insertAllOnConflictUpdate(attachedDatabase.merchantRules, rows);
    });
  }

  Future<void> markMerchantRuleDeleted(
    String id, {
    required String deletedAt,
  }) {
    return (update(attachedDatabase.merchantRules)
          ..where((tbl) => tbl.id.equals(id)))
        .write(
          db.MerchantRulesCompanion(
            deletedAt: Value<String>(deletedAt),
            updatedAt: Value<String>(deletedAt),
          ),
        );
  }

  Future<void> replaceAllMerchantRulesSnapshot(
    Iterable<MerchantRule> rules,
  ) async {
    await transaction(() async {
      await delete(attachedDatabase.merchantRules).go();
      await upsertMerchantRuleRows(rules);
    });
  }
}
