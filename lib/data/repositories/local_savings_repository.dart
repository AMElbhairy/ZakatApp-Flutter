import 'dart:convert';

import '../../models/saving.dart';
import '../local/daos/savings_dao.dart';
import '../local/daos/sync_queue_dao.dart';
import '../../services/sync_diagnostics_service.dart';
import 'package:flutter/foundation.dart';

abstract class SavingsLocalStore {
  Future<List<Saving>> getActiveSavings();
  Stream<List<Saving>> watchActiveSavings();
  Future<void> replaceAllForLocalMirror(Iterable<Saving> savings);
  Future<void> saveSaving(
    Saving saving, {
    String? now,
    int priority,
    String? deviceId,
  });
  Future<void> deleteSaving(
    String id, {
    String? now,
    int priority,
    String? deviceId,
  });
}

class LocalSavingsRepository implements SavingsLocalStore {
  factory LocalSavingsRepository({
    required SavingsDao savingsDao,
    required SyncQueueDao syncQueueDao,
  }) {
    return LocalSavingsRepository._(savingsDao, syncQueueDao);
  }

  LocalSavingsRepository._(this._savingsDao, this._syncQueueDao);

  final SavingsDao _savingsDao;
  final SyncQueueDao _syncQueueDao;

  @override
  Stream<List<Saving>> watchActiveSavings() {
    return _savingsDao.watchActiveSavings();
  }

  @override
  Future<List<Saving>> getActiveSavings() {
    return _savingsDao.getActiveSavings();
  }

  @override
  Future<void> saveSaving(
    Saving saving, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {
    final String timestamp = _resolveNow(now);
    final String payloadJson = jsonEncode(saving.toFirestoreJson());
    await _savingsDao.upsertSavingRow(saving, updatedAt: timestamp);
    final int queueId = await _syncQueueDao.enqueue(
      collectionName: 'savings',
      recordId: saving.id,
      operation: 'upsert',
      payloadJson: payloadJson,
      createdAt: timestamp,
      availableAt: timestamp,
      dedupeKey: 'savings:${saving.id}',
      priority: priority,
      deviceId: deviceId,
    );
    _logQueueInsert(
      entityType: 'savings',
      entityId: saving.id,
      assetType: saving.assetType,
      queueId: queueId,
      payloadJson: payloadJson,
    );
    await SyncDiagnosticsService.recordSavingsQueueInsert(
      entityId: saving.id,
      assetType: saving.assetType,
      queueId: queueId,
      payloadJson: payloadJson,
    );
  }

  Future<void> importSaving(
    Saving saving, {
    String? updatedAt,
    String? deletedAt,
  }) {
    return _savingsDao.upsertSavingRow(
      saving,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }

  Future<void> importSavings(Iterable<Saving> savings, {String? updatedAt}) {
    return _importAndEnqueue(savings, updatedAt: updatedAt);
  }

  Future<void> _importAndEnqueue(
    Iterable<Saving> savings, {
    String? updatedAt,
  }) async {
    final String timestamp = updatedAt?.trim().isNotEmpty == true
        ? updatedAt!.trim()
        : DateTime.now().toUtc().toIso8601String();
    final List<Saving> list = savings.toList(growable: false);
    if (list.isEmpty) return;
    await _savingsDao.upsertSavingRows(list, updatedAt: timestamp);
    for (final Saving saving in list) {
      await _syncQueueDao.enqueue(
        collectionName: 'savings',
        recordId: saving.id,
        operation: 'upsert',
        payloadJson: jsonEncode(saving.toFirestoreJson()),
        createdAt: timestamp,
        availableAt: timestamp,
        dedupeKey: 'savings:${saving.id}',
      );
    }
  }

  Future<void> applyRemoteUpsertSaving(
    Saving saving, {
    required String updatedAt,
  }) {
    return _savingsDao.upsertSavingRow(saving, updatedAt: updatedAt);
  }

  Future<void> applyRemoteDeleteSaving(String id, {required String deletedAt}) {
    return _savingsDao.markSavingDeleted(id, deletedAt: deletedAt);
  }

  @override
  Future<void> deleteSaving(
    String id, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {
    final String timestamp = _resolveNow(now);
    await _savingsDao.markSavingDeleted(id, deletedAt: timestamp);
    final int queueId = await _syncQueueDao.enqueue(
      collectionName: 'savings',
      recordId: id,
      operation: 'delete',
      createdAt: timestamp,
      availableAt: timestamp,
      dedupeKey: 'savings:$id',
      priority: priority,
      deviceId: deviceId,
    );
    _logQueueInsert(
      entityType: 'savings',
      entityId: id,
      assetType: null,
      queueId: queueId,
      payloadJson: null,
    );
    await SyncDiagnosticsService.record(
      level: 'info',
      subsystem: 'queue',
      message: 'Savings queue insert',
      metadata: <String, dynamic>{
        'entityType': 'savings',
        'entityId': id,
        'assetType': 'delete',
        'queueId': queueId,
        'payload': null,
        'operation': 'delete',
      },
    );
  }

  Future<List<Saving>> getChangedSince(String updatedAtCursor) {
    return _savingsDao.getChangedSince(updatedAtCursor);
  }

  @override
  Future<void> replaceAllForLocalMirror(Iterable<Saving> savings) {
    return _savingsDao.replaceAllSavingsSnapshot(savings);
  }

  Future<void> enqueueSavingsForResync(Iterable<Saving> savings) async {
    await _importAndEnqueue(savings);
  }

  String _resolveNow(String? now) {
    final String trimmed = now?.trim() ?? '';
    return trimmed.isEmpty ? DateTime.now().toUtc().toIso8601String() : trimmed;
  }

  void _logQueueInsert({
    required String entityType,
    required String entityId,
    required String? assetType,
    required int queueId,
    required String? payloadJson,
  }) {
    if (!kDebugMode) return;
    // Queue insert logging is debug-only and intentionally includes the full
    // serialized payload so payload drift can be inspected from logs.
    // ignore: avoid_print
    print(
      '[SYNC_QUEUE] entityType=$entityType entityId=$entityId assetType=${assetType ?? ''} queueId=$queueId payload=${payloadJson ?? 'null'}',
    );
  }
}
