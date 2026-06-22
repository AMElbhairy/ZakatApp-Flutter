import 'dart:convert';

import '../../models/investment_asset.dart';
import '../local/daos/investments_dao.dart';
import '../local/daos/sync_queue_dao.dart';

class LocalInvestmentsRepository {
  factory LocalInvestmentsRepository({
    required InvestmentsDao investmentsDao,
    required SyncQueueDao syncQueueDao,
  }) {
    return LocalInvestmentsRepository._(investmentsDao, syncQueueDao);
  }

  LocalInvestmentsRepository._(this._investmentsDao, this._syncQueueDao);

  final InvestmentsDao _investmentsDao;
  final SyncQueueDao _syncQueueDao;

  Stream<List<InvestmentAsset>> watchActiveInvestments() {
    return _investmentsDao.watchActiveInvestments();
  }

  Future<List<InvestmentAsset>> getActiveInvestments() {
    return _investmentsDao.getActiveInvestments();
  }

  Future<void> saveInvestment(
    InvestmentAsset investment, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {
    final String timestamp = _resolveNow(now);
    await _investmentsDao.upsertInvestmentRow(investment, updatedAt: timestamp);
    await _syncQueueDao.enqueue(
      collectionName: 'investments',
      recordId: investment.id,
      operation: 'upsert',
      payloadJson: jsonEncode(investment.toJson()),
      createdAt: timestamp,
      availableAt: timestamp,
      dedupeKey: 'investments:${investment.id}',
      priority: priority,
      deviceId: deviceId,
    );
  }

  Future<void> deleteInvestment(
    String id, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {
    final String timestamp = _resolveNow(now);
    await _investmentsDao.markInvestmentDeleted(id, deletedAt: timestamp);
    await _syncQueueDao.enqueue(
      collectionName: 'investments',
      recordId: id,
      operation: 'delete',
      createdAt: timestamp,
      availableAt: timestamp,
      dedupeKey: 'investments:$id',
      priority: priority,
      deviceId: deviceId,
    );
  }

  Future<void> importInvestment(
    InvestmentAsset investment, {
    String? updatedAt,
    String? deletedAt,
  }) {
    return _investmentsDao.upsertInvestmentRow(
      investment,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }

  Future<void> importInvestments(
    Iterable<InvestmentAsset> investments, {
    String? updatedAt,
  }) async {
    final String timestamp = updatedAt?.trim().isNotEmpty == true
        ? updatedAt!.trim()
        : DateTime.now().toUtc().toIso8601String();
    final List<InvestmentAsset> list = investments.toList(growable: false);
    if (list.isEmpty) return;
    await _investmentsDao.upsertInvestmentRows(list, updatedAt: timestamp);
    for (final InvestmentAsset investment in list) {
      await _syncQueueDao.enqueue(
        collectionName: 'investments',
        recordId: investment.id,
        operation: 'upsert',
        payloadJson: jsonEncode(investment.toJson()),
        createdAt: timestamp,
        availableAt: timestamp,
        dedupeKey: 'investments:${investment.id}',
      );
    }
  }

  Future<void> replaceAllForLocalMirror(
    Iterable<InvestmentAsset> investments,
  ) async {
    await _investmentsDao.replaceAllInvestmentSnapshot(investments);
  }

  Future<void> applyRemoteUpsertInvestment(
    InvestmentAsset investment, {
    required String updatedAt,
  }) {
    return _investmentsDao.upsertInvestmentRow(
      investment,
      updatedAt: updatedAt,
    );
  }

  Future<void> applyRemoteDeleteInvestment(
    String id, {
    required String deletedAt,
  }) {
    return _investmentsDao.markInvestmentDeleted(id, deletedAt: deletedAt);
  }

  Future<List<InvestmentAsset>> getChangedSince(String updatedAtCursor) {
    return _investmentsDao.getChangedSince(updatedAtCursor);
  }

  String _resolveNow(String? now) {
    final String trimmed = now?.trim() ?? '';
    return trimmed.isEmpty ? DateTime.now().toUtc().toIso8601String() : trimmed;
  }
}
