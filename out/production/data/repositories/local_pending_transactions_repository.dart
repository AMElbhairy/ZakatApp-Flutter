import 'dart:convert';

import '../../models/pending_transaction.dart';
import '../local/daos/pending_transactions_dao.dart';
import '../local/daos/sync_queue_dao.dart';

class LocalPendingTransactionsRepository {
  factory LocalPendingTransactionsRepository({
    required PendingTransactionsDao pendingTransactionsDao,
    required SyncQueueDao syncQueueDao,
  }) {
    return LocalPendingTransactionsRepository._(
      pendingTransactionsDao,
      syncQueueDao,
    );
  }

  LocalPendingTransactionsRepository._(
    this._pendingTransactionsDao,
    this._syncQueueDao,
  );

  final PendingTransactionsDao _pendingTransactionsDao;
  final SyncQueueDao _syncQueueDao;

  Stream<List<PendingTransaction>> watchActivePendingTransactions() {
    return _pendingTransactionsDao.watchActivePendingTransactions();
  }

  Future<List<PendingTransaction>> getActivePendingTransactions() {
    return _pendingTransactionsDao.getActivePendingTransactions();
  }

  Future<void> savePendingTransaction(
    PendingTransaction pending, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {
    final String timestamp = _resolveNow(now);
    await _pendingTransactionsDao.upsertPendingTransactionRow(
      pending,
      updatedAt: timestamp,
    );
    await _syncQueueDao.enqueue(
      collectionName: 'pending_transactions',
      recordId: pending.id,
      operation: 'upsert',
      payloadJson: jsonEncode(pending.toJson()),
      createdAt: timestamp,
      availableAt: timestamp,
      dedupeKey: 'pending_transactions:${pending.id}',
      priority: priority,
      deviceId: deviceId,
    );
  }

  Future<void> deletePendingTransaction(
    String id, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {
    final String timestamp = _resolveNow(now);
    await _pendingTransactionsDao.markPendingTransactionDeleted(
      id,
      deletedAt: timestamp,
    );
    await _syncQueueDao.enqueue(
      collectionName: 'pending_transactions',
      recordId: id,
      operation: 'delete',
      createdAt: timestamp,
      availableAt: timestamp,
      dedupeKey: 'pending_transactions:$id',
      priority: priority,
      deviceId: deviceId,
    );
  }

  Future<void> importPendingTransaction(
    PendingTransaction pending, {
    String? updatedAt,
    String? deletedAt,
  }) {
    return _pendingTransactionsDao.upsertPendingTransactionRow(
      pending,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }

  Future<void> importPendingTransactions(
    Iterable<PendingTransaction> pendingTransactions, {
    String? updatedAt,
  }) async {
    final String timestamp = updatedAt?.trim().isNotEmpty == true
        ? updatedAt!.trim()
        : DateTime.now().toUtc().toIso8601String();
    final List<PendingTransaction> list = pendingTransactions.toList(
      growable: false,
    );
    if (list.isEmpty) return;
    await _pendingTransactionsDao.upsertPendingTransactionRows(
      list,
      updatedAt: timestamp,
    );
    for (final PendingTransaction pending in list) {
      await _syncQueueDao.enqueue(
        collectionName: 'pending_transactions',
        recordId: pending.id,
        operation: 'upsert',
        payloadJson: jsonEncode(pending.toJson()),
        createdAt: timestamp,
        availableAt: timestamp,
        dedupeKey: 'pending_transactions:${pending.id}',
      );
    }
  }

  Future<void> applyRemoteUpsertPendingTransaction(
    PendingTransaction pending, {
    required String updatedAt,
  }) {
    return _pendingTransactionsDao.upsertPendingTransactionRow(
      pending,
      updatedAt: updatedAt,
    );
  }

  Future<void> applyRemoteDeletePendingTransaction(
    String id, {
    required String deletedAt,
  }) {
    return _pendingTransactionsDao.markPendingTransactionDeleted(
      id,
      deletedAt: deletedAt,
    );
  }

  Future<List<PendingTransaction>> getChangedSince(String updatedAtCursor) {
    return _pendingTransactionsDao.getChangedSince(updatedAtCursor);
  }

  Future<void> replaceAllForLocalMirror(
    Iterable<PendingTransaction> pendingTransactions,
  ) {
    return _pendingTransactionsDao.replaceAllPendingTransactionSnapshot(
      pendingTransactions,
    );
  }

  String _resolveNow(String? now) {
    final String trimmed = now?.trim() ?? '';
    return trimmed.isEmpty ? DateTime.now().toUtc().toIso8601String() : trimmed;
  }
}
