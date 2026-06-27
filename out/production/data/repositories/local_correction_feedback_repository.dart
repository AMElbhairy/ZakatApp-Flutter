import 'dart:convert';

import '../../models/correction_feedback.dart';
import '../local/daos/correction_feedback_dao.dart';
import '../local/daos/sync_queue_dao.dart';

abstract class CorrectionFeedbackLocalStore {
  Future<List<CorrectionFeedback>> getActiveCorrectionFeedback();
  Stream<List<CorrectionFeedback>> watchActiveCorrectionFeedback();
  Future<void> replaceAllForLocalMirror(Iterable<CorrectionFeedback> items);
  Future<void> saveCorrectionFeedback(CorrectionFeedback item, {String? now});
  Future<void> deleteCorrectionFeedback(String id, {String? now});
}

class LocalCorrectionFeedbackRepository
    implements CorrectionFeedbackLocalStore {
  factory LocalCorrectionFeedbackRepository({
    required CorrectionFeedbackDao correctionFeedbackDao,
    required SyncQueueDao syncQueueDao,
  }) {
    return LocalCorrectionFeedbackRepository._(
      correctionFeedbackDao,
      syncQueueDao,
    );
  }

  LocalCorrectionFeedbackRepository._(
    this._correctionFeedbackDao,
    this._syncQueueDao,
  );

  final CorrectionFeedbackDao _correctionFeedbackDao;
  final SyncQueueDao _syncQueueDao;

  @override
  Future<List<CorrectionFeedback>> getActiveCorrectionFeedback() {
    return _correctionFeedbackDao.getActiveCorrectionFeedback();
  }

  @override
  Stream<List<CorrectionFeedback>> watchActiveCorrectionFeedback() {
    return _correctionFeedbackDao.watchActiveCorrectionFeedback();
  }

  @override
  Future<void> saveCorrectionFeedback(
    CorrectionFeedback item, {
    String? now,
  }) async {
    final String timestamp = _resolveNow(now);
    await _correctionFeedbackDao.upsertCorrectionFeedbackRow(
      item,
      updatedAt: timestamp,
    );
    await _syncQueueDao.enqueue(
      collectionName: 'correction_feedback',
      recordId: item.id,
      operation: 'upsert',
      payloadJson: jsonEncode(item.toJson()),
      createdAt: timestamp,
      availableAt: timestamp,
      dedupeKey: 'correction_feedback:${item.id}',
    );
  }

  @override
  Future<void> deleteCorrectionFeedback(String id, {String? now}) async {
    final String timestamp = _resolveNow(now);
    await _correctionFeedbackDao.markCorrectionFeedbackDeleted(
      id,
      deletedAt: timestamp,
    );
    await _syncQueueDao.enqueue(
      collectionName: 'correction_feedback',
      recordId: id,
      operation: 'delete',
      createdAt: timestamp,
      availableAt: timestamp,
      dedupeKey: 'correction_feedback:$id',
    );
  }

  Future<void> importCorrectionFeedback(
    Iterable<CorrectionFeedback> items, {
    String? updatedAt,
  }) async {
    final String timestamp = updatedAt?.trim().isNotEmpty == true
        ? updatedAt!.trim()
        : DateTime.now().toUtc().toIso8601String();
    final List<CorrectionFeedback> list = items.toList(growable: false);
    if (list.isEmpty) return;
    await _correctionFeedbackDao.upsertCorrectionFeedbackRows(
      list,
      updatedAt: timestamp,
    );
    for (final CorrectionFeedback item in list) {
      await _syncQueueDao.enqueue(
        collectionName: 'correction_feedback',
        recordId: item.id,
        operation: 'upsert',
        payloadJson: jsonEncode(item.toJson()),
        createdAt: timestamp,
        availableAt: timestamp,
        dedupeKey: 'correction_feedback:${item.id}',
      );
    }
  }

  Future<void> applyRemoteUpsertCorrectionFeedback(
    CorrectionFeedback item, {
    required String updatedAt,
  }) {
    return _correctionFeedbackDao.upsertCorrectionFeedbackRow(
      item,
      updatedAt: updatedAt,
    );
  }

  Future<void> applyRemoteDeleteCorrectionFeedback(
    String id, {
    required String deletedAt,
  }) {
    return _correctionFeedbackDao.markCorrectionFeedbackDeleted(
      id,
      deletedAt: deletedAt,
    );
  }

  @override
  Future<void> replaceAllForLocalMirror(Iterable<CorrectionFeedback> items) {
    return _correctionFeedbackDao.replaceAllCorrectionFeedbackSnapshot(items);
  }

  String _resolveNow(String? now) {
    final String trimmed = now?.trim() ?? '';
    return trimmed.isEmpty ? DateTime.now().toUtc().toIso8601String() : trimmed;
  }
}
