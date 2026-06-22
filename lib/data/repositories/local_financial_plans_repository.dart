import 'dart:convert';

import '../../../models/financial_plan.dart';
import '../local/daos/financial_plans_dao.dart';
import '../local/daos/sync_queue_dao.dart';

abstract class FinancialPlansLocalStore {
  Future<List<FinancialPlan>> getActiveFinancialPlans();
  Stream<List<FinancialPlan>> watchActiveFinancialPlans();
  Future<void> replaceAllForLocalMirror(Iterable<FinancialPlan> plans);
  Future<void> saveFinancialPlan(FinancialPlan plan, {String? now});
  Future<void> deleteFinancialPlan(String id, {String? now});
}

class LocalFinancialPlansRepository implements FinancialPlansLocalStore {
  LocalFinancialPlansRepository({
    required this._financialPlansDao,
    required this._syncQueueDao,
  });

  final FinancialPlansDao _financialPlansDao;
  final SyncQueueDao _syncQueueDao;

  @override
  Future<List<FinancialPlan>> getActiveFinancialPlans() {
    return _financialPlansDao.getActiveFinancialPlans();
  }

  @override
  Stream<List<FinancialPlan>> watchActiveFinancialPlans() {
    return _financialPlansDao.watchActiveFinancialPlans();
  }

  @override
  Future<void> saveFinancialPlan(FinancialPlan plan, {String? now}) {
    final String timestamp = _resolveNow(now);
    return _saveAndEnqueue(plan, timestamp);
  }

  Future<void> _saveAndEnqueue(FinancialPlan plan, String timestamp) async {
    await _financialPlansDao.upsertFinancialPlanRow(plan, updatedAt: timestamp);
    await _syncQueueDao.enqueue(
      collectionName: 'financial_plans',
      recordId: plan.id,
      operation: 'upsert',
      payloadJson: jsonEncode(plan.toJson()),
      createdAt: timestamp,
      availableAt: timestamp,
      dedupeKey: 'financial_plans:${plan.id}',
    );
  }

  @override
  Future<void> deleteFinancialPlan(String id, {String? now}) {
    final String timestamp = _resolveNow(now);
    return _deleteAndEnqueue(id, timestamp);
  }

  Future<void> _deleteAndEnqueue(String id, String timestamp) async {
    await _financialPlansDao.markFinancialPlanDeleted(id, deletedAt: timestamp);
    await _syncQueueDao.enqueue(
      collectionName: 'financial_plans',
      recordId: id,
      operation: 'delete',
      createdAt: timestamp,
      availableAt: timestamp,
      dedupeKey: 'financial_plans:$id',
    );
  }

  Future<void> importFinancialPlans(
    Iterable<FinancialPlan> plans, {
    String? updatedAt,
  }) async {
    final String timestamp = updatedAt?.trim().isNotEmpty == true
        ? updatedAt!.trim()
        : DateTime.now().toUtc().toIso8601String();
    final List<FinancialPlan> list = plans.toList(growable: false);
    if (list.isEmpty) return;
    await _financialPlansDao.upsertFinancialPlanRows(list, updatedAt: timestamp);
    for (final FinancialPlan plan in list) {
      await _syncQueueDao.enqueue(
        collectionName: 'financial_plans',
        recordId: plan.id,
        operation: 'upsert',
        payloadJson: jsonEncode(plan.toJson()),
        createdAt: timestamp,
        availableAt: timestamp,
        dedupeKey: 'financial_plans:${plan.id}',
      );
    }
  }

  Future<void> applyRemoteUpsertFinancialPlan(
    FinancialPlan plan, {
    required String updatedAt,
  }) {
    return _financialPlansDao.upsertFinancialPlanRow(
      plan,
      updatedAt: updatedAt,
    );
  }

  Future<void> applyRemoteDeleteFinancialPlan(
    String id, {
    required String deletedAt,
  }) {
    return _financialPlansDao.markFinancialPlanDeleted(
      id,
      deletedAt: deletedAt,
    );
  }

  @override
  Future<void> replaceAllForLocalMirror(Iterable<FinancialPlan> plans) {
    return _financialPlansDao.replaceAllFinancialPlansSnapshot(plans);
  }

  String _resolveNow(String? now) {
    final String trimmed = now?.trim() ?? '';
    return trimmed.isEmpty ? DateTime.now().toUtc().toIso8601String() : trimmed;
  }
}
