import 'package:drift/drift.dart';

import '../../../models/merchant_confirmation.dart';
import '../app_database.dart' as db;
import '../mappers/merchant_confirmation_mapper.dart';

class MerchantConfirmationsDao extends DatabaseAccessor<db.AppDatabase> {
  MerchantConfirmationsDao(
    super.db, {
    MerchantConfirmationMapper? mapper,
  }) : _mapper = mapper ?? const MerchantConfirmationMapper();

  final MerchantConfirmationMapper _mapper;

  Stream<List<MerchantConfirmation>> watchActiveMerchantConfirmations() {
    return (select(attachedDatabase.merchantConfirmations)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.confirmations),
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
            (tbl) => OrderingTerm.asc(tbl.id),
          ]))
        .watch()
        .map(
          (List<db.MerchantConfirmation> rows) =>
              rows.map(_mapper.fromRow).toList(growable: false),
        );
  }

  Future<List<MerchantConfirmation>> getActiveMerchantConfirmations() async {
    final List<db.MerchantConfirmation> rows =
        await (select(attachedDatabase.merchantConfirmations)
              ..where((tbl) => tbl.deletedAt.isNull())
              ..orderBy([
                (tbl) => OrderingTerm.desc(tbl.confirmations),
                (tbl) => OrderingTerm.desc(tbl.updatedAt),
                (tbl) => OrderingTerm.asc(tbl.id),
              ]))
            .get();
    return rows.map(_mapper.fromRow).toList(growable: false);
  }

  Future<void> upsertMerchantConfirmationRow(
    MerchantConfirmation item, {
    String? updatedAt,
    String? deletedAt,
  }) {
    return into(attachedDatabase.merchantConfirmations).insertOnConflictUpdate(
      _mapper.toCompanion(item, updatedAt: updatedAt, deletedAt: deletedAt),
    );
  }

  Future<void> upsertMerchantConfirmationRows(
    Iterable<MerchantConfirmation> items, {
    String? updatedAt,
  }) async {
    final List<db.MerchantConfirmationsCompanion> rows = items
        .map(
          (MerchantConfirmation item) =>
              _mapper.toCompanion(item, updatedAt: updatedAt),
        )
        .toList(growable: false);
    if (rows.isEmpty) return;
    await batch((Batch batch) {
      batch.insertAllOnConflictUpdate(
        attachedDatabase.merchantConfirmations,
        rows,
      );
    });
  }

  Future<void> markMerchantConfirmationDeleted(
    String id, {
    required String deletedAt,
  }) {
    return (update(attachedDatabase.merchantConfirmations)
          ..where((tbl) => tbl.id.equals(id)))
        .write(
          db.MerchantConfirmationsCompanion(
            deletedAt: Value<String>(deletedAt),
            updatedAt: Value<String>(deletedAt),
          ),
        );
  }

  Future<void> replaceAllMerchantConfirmationsSnapshot(
    Iterable<MerchantConfirmation> items,
  ) async {
    await transaction(() async {
      await delete(attachedDatabase.merchantConfirmations).go();
      await upsertMerchantConfirmationRows(items);
    });
  }
}
