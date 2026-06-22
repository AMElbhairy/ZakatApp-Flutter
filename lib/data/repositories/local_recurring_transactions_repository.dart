import 'dart:convert';

import '../../../models/recurring_transaction.dart';
import '../local/daos/recurring_transactions_dao.dart';
import '../local/daos/sync_queue_dao.dart';

abstract class RecurringTransactionsLocalStore {
  Future<List<RecurringTransaction>> getActiveRecurringTransactions();
  Stream<List<RecurringTransaction>> watchActiveRecurringTransactions();
  Future<void> replaceAllForLocalMirror(Iterable<RecurringTransaction> items);
  Future<void> saveRecurringTransaction(
    RecurringTransaction recurring, {
    String? now,
  });
  Future<void> deleteRecurringTransaction(String id, {String? now});
}

class LocalRecurringTransactionsRepository
    implements RecurringTransactionsLocalStore {
  LocalRecurringTransactionsRepository({
    required this._recurringTransactionsDao,
    required this._syncQueueDao,
  });

  final RecurringTransactionsDao _recurringTransactionsDao;
  final SyncQueueDao _syncQueueDao;

  @override
  Future<List<RecurringTransaction>> getActiveRecurringTransactions() {
    return _recurringTransactionsDao.getActiveRecurringTransactions();
  }

  @override
  Stream<List<RecurringTransaction>> watchActiveRecurringTransactions() {
    return _recurringTransactionsDao.watchActiveRecurringTransactions();
  }

  @override
  Future<void> saveRecurringTransaction(
    RecurringTransaction recurring, {
    String? now,
  }) {
    final String timestamp = _resolveNow(now);
    return _saveAndEnqueue(recurring, timestamp);
  }

  Future<void> _saveAndEnqueue(
    RecurringTransaction recurring,
    String timestamp,
  ) async {
    await _recurringTransactionsDao.upsertRecurringTransactionRow(
      recurring,
      updatedAt: timestamp,
    );
    await _syncQueueDao.enqueue(
      collectionName: 'recurring_transactions',
      recordId: recurring.id,
      operation: 'upsert',
      payloadJson: jsonEncode(recurring.toJson()),
      createdAt: timestamp,
      availableAt: timestamp,
      dedupeKey: 'recurring_transactions:${recurring.id}',
    );
  }

  @override
  Future<void> deleteRecurringTransaction(String id, {String? now}) {
    final String timestamp = _resolveNow(now);
    return _deleteAndEnqueue(id, timestamp);
  }

  Future<void> _deleteAndEnqueue(String id, String timestamp) async {
    await _recurringTransactionsDao.markRecurringTransactionDeleted(
      id,
      deletedAt: timestamp,
    );
    await _syncQueueDao.enqueue(
      collectionName: 'recurring_transactions',
      recordId: id,
      operation: 'delete',
      createdAt: timestamp,
      availableAt: timestamp,
      dedupeKey: 'recurring_transactions:$id',
    );
  }

  Future<void> importRecurringTransactions(
    Iterable<RecurringTransaction> recurringTransactions, {
    String? updatedAt,
  }) async {
    final String timestamp = updatedAt?.trim().isNotEmpty == true
        ? updatedAt!.trim()
        : DateTime.now().toUtc().toIso8601String();
    final List<RecurringTransaction> list =
        recurringTransactions.toList(growable: false);
    if (list.isEmpty) return;
    await _recurringTransactionsDao.upsertRecurringTransactionRows(
      list,
      updatedAt: timestamp,
    );
    for (final RecurringTransaction recurring in list) {
      await _syncQueueDao.enqueue(
        collectionName: 'recurring_transactions',
        recordId: recurring.id,
        operation: 'upsert',
        payloadJson: jsonEncode(recurring.toJson()),
        createdAt: timestamp,
        availableAt: timestamp,
        dedupeKey: 'recurring_transactions:${recurring.id}',
      );
    }
  }

  Future<void> applyRemoteUpsertRecurringTransaction(
    RecurringTransaction recurring, {
    required String updatedAt,
  }) {
    return _recurringTransactionsDao.upsertRecurringTransactionRow(
      recurring,
      updatedAt: updatedAt,
    );
  }

  Future<void> applyRemoteDeleteRecurringTransaction(
    String id, {
    required String deletedAt,
  }) {
    return _recurringTransactionsDao.markRecurringTransactionDeleted(
      id,
      deletedAt: deletedAt,
    );
  }

  @override
  Future<void> replaceAllForLocalMirror(Iterable<RecurringTransaction> items) {
    return _recurringTransactionsDao.replaceAllRecurringTransactionsSnapshot(
      items,
    );
  }

  String _resolveNow(String? now) {
    final String trimmed = now?.trim() ?? '';
    return trimmed.isEmpty ? DateTime.now().toUtc().toIso8601String() : trimmed;
  }
}
