import 'dart:convert';

import '../../models/merchant_rule.dart';
import '../local/daos/merchant_rules_dao.dart';
import '../local/daos/sync_queue_dao.dart';

abstract class MerchantRulesLocalStore {
  Future<Map<String, MerchantRule>> getActiveMerchantRules();
  Stream<Map<String, MerchantRule>> watchActiveMerchantRules();
  Future<void> replaceAllForLocalMirror(Iterable<MerchantRule> rules);
  Future<void> saveMerchantRule(MerchantRule rule, {String? now});
  Future<void> deleteMerchantRule(String id, {String? now});
}

class LocalMerchantRulesRepository implements MerchantRulesLocalStore {
  factory LocalMerchantRulesRepository({
    required MerchantRulesDao merchantRulesDao,
    required SyncQueueDao syncQueueDao,
  }) {
    return LocalMerchantRulesRepository._(merchantRulesDao, syncQueueDao);
  }

  LocalMerchantRulesRepository._(this._merchantRulesDao, this._syncQueueDao);

  final MerchantRulesDao _merchantRulesDao;
  final SyncQueueDao _syncQueueDao;

  @override
  Future<Map<String, MerchantRule>> getActiveMerchantRules() async {
    final List<MerchantRule> rules = await _merchantRulesDao
        .getActiveMerchantRules();
    return <String, MerchantRule>{
      for (final MerchantRule rule in rules)
        rule.merchantName.toLowerCase().trim(): rule,
    };
  }

  @override
  Stream<Map<String, MerchantRule>> watchActiveMerchantRules() {
    return _merchantRulesDao.watchActiveMerchantRules().map(
      (List<MerchantRule> rules) => <String, MerchantRule>{
        for (final MerchantRule rule in rules)
          rule.merchantName.toLowerCase().trim(): rule,
      },
    );
  }

  @override
  Future<void> saveMerchantRule(MerchantRule rule, {String? now}) async {
    final String timestamp = _resolveNow(now);
    await _merchantRulesDao.upsertMerchantRuleRow(rule, updatedAt: timestamp);
    await _syncQueueDao.enqueue(
      collectionName: 'merchant_rules',
      recordId: _ruleId(rule),
      operation: 'upsert',
      payloadJson: jsonEncode(rule.toJson()),
      createdAt: timestamp,
      availableAt: timestamp,
      dedupeKey: 'merchant_rules:${_ruleId(rule)}',
    );
  }

  @override
  Future<void> deleteMerchantRule(String id, {String? now}) async {
    final String timestamp = _resolveNow(now);
    await _merchantRulesDao.markMerchantRuleDeleted(id, deletedAt: timestamp);
    await _syncQueueDao.enqueue(
      collectionName: 'merchant_rules',
      recordId: id,
      operation: 'delete',
      createdAt: timestamp,
      availableAt: timestamp,
      dedupeKey: 'merchant_rules:$id',
    );
  }

  Future<void> importMerchantRules(
    Iterable<MerchantRule> rules, {
    String? updatedAt,
  }) async {
    final String timestamp = updatedAt?.trim().isNotEmpty == true
        ? updatedAt!.trim()
        : DateTime.now().toUtc().toIso8601String();
    final List<MerchantRule> list = rules.toList(growable: false);
    if (list.isEmpty) return;
    await _merchantRulesDao.upsertMerchantRuleRows(list, updatedAt: timestamp);
    for (final MerchantRule rule in list) {
      final String recordId = _ruleId(rule);
      await _syncQueueDao.enqueue(
        collectionName: 'merchant_rules',
        recordId: recordId,
        operation: 'upsert',
        payloadJson: jsonEncode(rule.toJson()),
        createdAt: timestamp,
        availableAt: timestamp,
        dedupeKey: 'merchant_rules:$recordId',
      );
    }
  }

  Future<void> applyRemoteUpsertMerchantRule(
    MerchantRule rule, {
    required String updatedAt,
  }) {
    return _merchantRulesDao.upsertMerchantRuleRow(rule, updatedAt: updatedAt);
  }

  Future<void> applyRemoteDeleteMerchantRule(
    String id, {
    required String deletedAt,
  }) {
    return _merchantRulesDao.markMerchantRuleDeleted(id, deletedAt: deletedAt);
  }

  @override
  Future<void> replaceAllForLocalMirror(Iterable<MerchantRule> rules) {
    return _merchantRulesDao.replaceAllMerchantRulesSnapshot(rules);
  }

  String _resolveNow(String? now) {
    final String trimmed = now?.trim() ?? '';
    return trimmed.isEmpty ? DateTime.now().toUtc().toIso8601String() : trimmed;
  }

  String _ruleId(MerchantRule rule) {
    final String normalized = rule.merchantName.toLowerCase().trim();
    if (normalized.isNotEmpty) return normalized;
    final String builtinKey = rule.builtinKey?.toLowerCase().trim() ?? '';
    return builtinKey.isNotEmpty ? builtinKey : rule.merchantName;
  }
}
