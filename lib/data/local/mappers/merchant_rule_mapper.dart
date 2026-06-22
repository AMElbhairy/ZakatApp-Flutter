import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../models/merchant_rule.dart';
import '../app_database.dart' as db;

class MerchantRuleMapper {
  const MerchantRuleMapper();

  db.MerchantRulesCompanion toCompanion(
    MerchantRule rule, {
    String? updatedAt,
    String? deletedAt,
  }) {
    final String resolvedUpdatedAt = _timestampOrFallback(
      updatedAt ?? rule.lastUsed,
    );
    return db.MerchantRulesCompanion(
      id: Value<String>(_ruleId(rule)),
      merchantName: Value<String>(rule.merchantName),
      categoryId: Value<String>(rule.categoryId),
      defaultType: Value<String>(rule.defaultType),
      autoApprove: Value<bool>(rule.autoApprove),
      usageCount: Value<int>(rule.usageCount),
      confidenceText: Value<String>(_decimalText(rule.confidence)),
      lastUsed: Value<String?>(rule.lastUsed),
      source: Value<String>(rule.source),
      aliasesJson: Value<String>(jsonEncode(rule.aliases)),
      enabled: Value<bool>(rule.enabled),
      isBuiltinOverride: Value<bool>(rule.isBuiltinOverride),
      builtinKey: Value<String?>(rule.builtinKey),
      updatedAt: Value<String>(resolvedUpdatedAt),
      deletedAt: Value<String?>(deletedAt),
    );
  }

  MerchantRule fromRow(db.MerchantRule row) {
    return MerchantRule(
      merchantName: row.merchantName,
      categoryId: row.categoryId,
      defaultType: row.defaultType,
      autoApprove: row.autoApprove,
      usageCount: row.usageCount,
      confidence: double.tryParse(row.confidenceText) ?? 0,
      lastUsed: row.lastUsed,
      source: row.source,
      aliases: _decodeAliases(row.aliasesJson),
      enabled: row.enabled,
      isBuiltinOverride: row.isBuiltinOverride,
      builtinKey: row.builtinKey,
    );
  }

  String _ruleId(MerchantRule rule) {
    final String normalized = rule.merchantName.toLowerCase().trim();
    if (normalized.isNotEmpty) return normalized;
    final String builtinKey = rule.builtinKey?.toLowerCase().trim() ?? '';
    return builtinKey.isNotEmpty ? builtinKey : rule.merchantName;
  }

  String _decimalText(num value) {
    if (value is int) return value.toString();
    final String raw = value.toString();
    if (!raw.contains('.') || raw.contains('e') || raw.contains('E')) {
      return raw;
    }
    return raw.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _timestampOrFallback(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    return DateTime.now().toUtc().toIso8601String();
  }

  List<String> _decodeAliases(String raw) {
    if (raw.trim().isEmpty) return const <String>[];
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((dynamic alias) => alias.toString())
            .toList(growable: false);
      }
    } catch (_) {
      return const <String>[];
    }
    return const <String>[];
  }
}
