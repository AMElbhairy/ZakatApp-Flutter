import 'dart:convert';

import '../../models/transaction.dart';
import '../local/daos/sync_queue_dao.dart';
import '../local/daos/transactions_dao.dart';

abstract class TransactionsLocalStore {
  Future<List<Transaction>> getActiveTransactions();
  Stream<List<Transaction>> watchActiveTransactions();
  Future<void> replaceAllForLocalMirror(Iterable<Transaction> transactions);
  Future<void> saveTransaction(
    Transaction transaction, {
    String? now,
    int priority,
    String? deviceId,
  });
  Future<void> deleteTransaction(
    String id, {
    String? now,
    int priority,
    String? deviceId,
  });
}

class LocalTransactionsRepository implements TransactionsLocalStore {
  factory LocalTransactionsRepository({
    required TransactionsDao transactionsDao,
    required SyncQueueDao syncQueueDao,
  }) {
    return LocalTransactionsRepository._(transactionsDao, syncQueueDao);
  }

  LocalTransactionsRepository._(this._transactionsDao, this._syncQueueDao);

  final TransactionsDao _transactionsDao;
  final SyncQueueDao _syncQueueDao;

  @override
  Stream<List<Transaction>> watchActiveTransactions() {
    return _transactionsDao.watchActiveTransactions();
  }

  @override
  Future<List<Transaction>> getActiveTransactions() {
    return _transactionsDao.getActiveTransactions();
  }

  @override
  Future<void> saveTransaction(
    Transaction transaction, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {
    final String timestamp = _resolveNow(now);
    await _transactionsDao.upsertTransactionRow(
      transaction,
      updatedAt: timestamp,
    );
    await _syncQueueDao.enqueue(
      collectionName: 'transactions',
      recordId: transaction.id,
      operation: 'upsert',
      payloadJson: jsonEncode(transaction.toJson()),
      createdAt: timestamp,
      availableAt: timestamp,
      dedupeKey: 'transactions:${transaction.id}',
      priority: priority,
      deviceId: deviceId,
    );
  }

  Future<void> importTransaction(
    Transaction transaction, {
    String? updatedAt,
    String? deletedAt,
  }) {
    return _transactionsDao.upsertTransactionRow(
      transaction,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }

  Future<void> importTransactions(
    Iterable<Transaction> transactions, {
    String? updatedAt,
  }) async {
    final String timestamp = updatedAt?.trim().isNotEmpty == true
        ? updatedAt!.trim()
        : DateTime.now().toUtc().toIso8601String();
    final List<Transaction> list = transactions.toList(growable: false);
    if (list.isEmpty) return;
    await _transactionsDao.upsertTransactionRows(list, updatedAt: timestamp);
    for (final Transaction transaction in list) {
      await _syncQueueDao.enqueue(
        collectionName: 'transactions',
        recordId: transaction.id,
        operation: 'upsert',
        payloadJson: jsonEncode(transaction.toJson()),
        createdAt: timestamp,
        availableAt: timestamp,
        dedupeKey: 'transactions:${transaction.id}',
      );
    }
  }

  Future<void> applyRemoteUpsertTransaction(
    Transaction transaction, {
    required String updatedAt,
  }) {
    return _transactionsDao.upsertTransactionRow(
      transaction,
      updatedAt: updatedAt,
    );
  }

  Future<void> applyRemoteDeleteTransaction(
    String id, {
    required String deletedAt,
  }) {
    return _transactionsDao.markTransactionDeleted(id, deletedAt: deletedAt);
  }

  @override
  Future<void> deleteTransaction(
    String id, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {
    final String timestamp = _resolveNow(now);
    await _transactionsDao.markTransactionDeleted(id, deletedAt: timestamp);
    await _syncQueueDao.enqueue(
      collectionName: 'transactions',
      recordId: id,
      operation: 'delete',
      createdAt: timestamp,
      availableAt: timestamp,
      dedupeKey: 'transactions:$id',
      priority: priority,
      deviceId: deviceId,
    );
  }

  Future<List<Transaction>> getChangedSince(String updatedAtCursor) {
    return _transactionsDao.getChangedSince(updatedAtCursor);
  }

  @override
  Future<void> replaceAllForLocalMirror(Iterable<Transaction> transactions) {
    return _transactionsDao.replaceAllTransactionsSnapshot(transactions);
  }

  String _resolveNow(String? now) {
    final String trimmed = now?.trim() ?? '';
    return trimmed.isEmpty ? DateTime.now().toUtc().toIso8601String() : trimmed;
  }
}
