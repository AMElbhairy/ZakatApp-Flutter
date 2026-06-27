import 'package:drift/drift.dart';

import '../../../models/pending_transaction.dart' as model;
import '../app_database.dart' as db;

class PendingTransactionsMapper {
  const PendingTransactionsMapper();

  db.PendingTransactionsCompanion toCompanion(
    model.PendingTransaction pending, {
    String? updatedAt,
    String? deletedAt,
  }) {
    return db.PendingTransactionsCompanion(
      id: Value<String>(pending.id),
      source: Value<String>(pending.source),
      sourceIdentifier: Value<String?>(pending.sourceIdentifier),
      rawMessage: Value<String>(pending.rawMessage),
      createdAt: Value<String>(_timestampOrFallback(pending.createdAt)),
      reviewedAt: Value<String?>(pending.reviewedAt),
      suggestedType: Value<String>(pending.suggestedType),
      suggestedAmountText: Value<String?>(
        pending.suggestedAmount == null ? null : _decimalText(pending.suggestedAmount!),
      ),
      suggestedCurrency: Value<String?>(pending.suggestedCurrency),
      suggestedDescription: Value<String?>(pending.suggestedDescription),
      merchantName: Value<String?>(pending.merchantName),
      suggestedCategory: Value<String?>(pending.suggestedCategory),
      confidenceText: Value<String>(_decimalText(pending.confidence)),
      status: Value<String>(pending.status.name),
      approvalSource: Value<String?>(pending.approvalSource?.name),
      merchantRuleUsed: Value<String?>(pending.merchantRuleUsed),
      merchantRuleSource: Value<String?>(pending.merchantRuleSource),
      ignoreReason: Value<String?>(pending.ignoreReason),
      parserVersion: Value<String?>(pending.parserVersion),
      detectedBank: Value<String?>(pending.detectedBank),
      requiresReview: Value<bool>(pending.requiresReview),
      isRead: Value<bool>(pending.isRead),
      linkedTransactionId: Value<String?>(pending.linkedTransactionId),
      updatedAt: Value<String>(_timestampOrFallback(updatedAt ?? pending.createdAt)),
      deletedAt: Value<String?>(deletedAt),
    );
  }

  model.PendingTransaction fromRow(db.PendingTransaction row) {
    return model.PendingTransaction(
      id: row.id,
      source: row.source,
      sourceIdentifier: row.sourceIdentifier,
      rawMessage: row.rawMessage,
      createdAt: row.createdAt,
      reviewedAt: row.reviewedAt,
      suggestedType: row.suggestedType,
      suggestedAmount: _nullableDouble(row.suggestedAmountText),
      suggestedCurrency: row.suggestedCurrency,
      suggestedDescription: row.suggestedDescription,
      merchantName: row.merchantName,
      suggestedCategory: row.suggestedCategory,
      confidence: _nullableDouble(row.confidenceText) ?? 0,
      status: _parseStatus(row.status),
      approvalSource: _parseApprovalSource(row.approvalSource),
      merchantRuleUsed: row.merchantRuleUsed,
      merchantRuleSource: row.merchantRuleSource,
      ignoreReason: row.ignoreReason,
      parserVersion: row.parserVersion,
      detectedBank: row.detectedBank,
      requiresReview: row.requiresReview,
      isRead: row.isRead,
      linkedTransactionId: row.linkedTransactionId,
    );
  }

  double? _nullableDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    return double.tryParse(value);
  }

  model.CaptureStatus _parseStatus(String value) {
    switch (value) {
      case 'autoApproved':
        return model.CaptureStatus.autoApproved;
      case 'manuallyApproved':
        return model.CaptureStatus.manuallyApproved;
      case 'ignored':
        return model.CaptureStatus.ignored;
      case 'pending':
      case 'pendingReview':
      default:
        return model.CaptureStatus.pendingReview;
    }
  }

  model.ApprovalSource? _parseApprovalSource(String? value) {
    switch (value) {
      case 'auto':
        return model.ApprovalSource.auto;
      case 'manual':
        return model.ApprovalSource.manual;
      default:
        return null;
    }
  }

  String _decimalText(num value) {
    if (value is int) return value.toString();
    final String raw = value.toString();
    if (!raw.contains('.') || raw.contains('e') || raw.contains('E')) return raw;
    return raw.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _timestampOrFallback(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    return DateTime.now().toUtc().toIso8601String();
  }
}
