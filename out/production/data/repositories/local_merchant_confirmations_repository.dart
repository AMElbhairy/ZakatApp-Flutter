import 'dart:convert';

import '../../models/merchant_confirmation.dart';
import '../local/daos/merchant_confirmations_dao.dart';
import '../local/daos/sync_queue_dao.dart';

abstract class MerchantConfirmationsLocalStore {
  Future<List<MerchantConfirmation>> getActiveMerchantConfirmations();
  Stream<List<MerchantConfirmation>> watchActiveMerchantConfirmations();
  Future<void> replaceAllForLocalMirror(Iterable<MerchantConfirmation> items);
  Future<void> saveMerchantConfirmation(
    MerchantConfirmation item, {
    String? now,
  });
  Future<void> deleteMerchantConfirmation(String id, {String? now});
}

class LocalMerchantConfirmationsRepository
    implements MerchantConfirmationsLocalStore {
  factory LocalMerchantConfirmationsRepository({
    required MerchantConfirmationsDao merchantConfirmationsDao,
    required SyncQueueDao syncQueueDao,
  }) {
    return LocalMerchantConfirmationsRepository._(
      merchantConfirmationsDao,
      syncQueueDao,
    );
  }

  LocalMerchantConfirmationsRepository._(
    this._merchantConfirmationsDao,
    this._syncQueueDao,
  );

  final MerchantConfirmationsDao _merchantConfirmationsDao;
  final SyncQueueDao _syncQueueDao;

  @override
  Future<List<MerchantConfirmation>> getActiveMerchantConfirmations() {
    return _merchantConfirmationsDao.getActiveMerchantConfirmations();
  }

  @override
  Stream<List<MerchantConfirmation>> watchActiveMerchantConfirmations() {
    return _merchantConfirmationsDao.watchActiveMerchantConfirmations();
  }

  @override
  Future<void> saveMerchantConfirmation(
    MerchantConfirmation item, {
    String? now,
  }) async {
    final String timestamp = _resolveNow(now);
    await _merchantConfirmationsDao.upsertMerchantConfirmationRow(
      item,
      updatedAt: timestamp,
    );
    await _syncQueueDao.enqueue(
      collectionName: 'merchant_confirmations',
      recordId: _recordId(item),
      operation: 'upsert',
      payloadJson: jsonEncode(item.toJson()),
      createdAt: timestamp,
      availableAt: timestamp,
      dedupeKey: 'merchant_confirmations:${_recordId(item)}',
    );
  }

  @override
  Future<void> deleteMerchantConfirmation(String id, {String? now}) async {
    final String timestamp = _resolveNow(now);
    await _merchantConfirmationsDao.markMerchantConfirmationDeleted(
      id,
      deletedAt: timestamp,
    );
    await _syncQueueDao.enqueue(
      collectionName: 'merchant_confirmations',
      recordId: id,
      operation: 'delete',
      createdAt: timestamp,
      availableAt: timestamp,
      dedupeKey: 'merchant_confirmations:$id',
    );
  }

  Future<void> importMerchantConfirmations(
    Iterable<MerchantConfirmation> items, {
    String? updatedAt,
  }) async {
    final String timestamp = updatedAt?.trim().isNotEmpty == true
        ? updatedAt!.trim()
        : DateTime.now().toUtc().toIso8601String();
    final List<MerchantConfirmation> list = items.toList(growable: false);
    if (list.isEmpty) return;
    await _merchantConfirmationsDao.upsertMerchantConfirmationRows(
      list,
      updatedAt: timestamp,
    );
    for (final MerchantConfirmation item in list) {
      final String recordId = _recordId(item);
      await _syncQueueDao.enqueue(
        collectionName: 'merchant_confirmations',
        recordId: recordId,
        operation: 'upsert',
        payloadJson: jsonEncode(item.toJson()),
        createdAt: timestamp,
        availableAt: timestamp,
        dedupeKey: 'merchant_confirmations:$recordId',
      );
    }
  }

  Future<void> applyRemoteUpsertMerchantConfirmation(
    MerchantConfirmation item, {
    required String updatedAt,
  }) {
    return _merchantConfirmationsDao.upsertMerchantConfirmationRow(
      item,
      updatedAt: updatedAt,
    );
  }

  Future<void> applyRemoteDeleteMerchantConfirmation(
    String id, {
    required String deletedAt,
  }) {
    return _merchantConfirmationsDao.markMerchantConfirmationDeleted(
      id,
      deletedAt: deletedAt,
    );
  }

  @override
  Future<void> replaceAllForLocalMirror(Iterable<MerchantConfirmation> items) {
    return _merchantConfirmationsDao.replaceAllMerchantConfirmationsSnapshot(
      items,
    );
  }

  String _resolveNow(String? now) {
    final String trimmed = now?.trim() ?? '';
    return trimmed.isEmpty ? DateTime.now().toUtc().toIso8601String() : trimmed;
  }

  String _recordId(MerchantConfirmation item) {
    return '${item.merchantName.toLowerCase().trim()}|${item.categoryId.toLowerCase().trim()}';
  }
}
