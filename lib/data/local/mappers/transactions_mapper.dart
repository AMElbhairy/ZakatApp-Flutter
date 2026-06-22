import 'package:drift/drift.dart';

import '../../../models/transaction.dart' as model;
import '../app_database.dart' as db;

class TransactionsMapper {
  const TransactionsMapper();

  db.TransactionsCompanion toCompanion(
    model.Transaction transaction, {
    String? updatedAt,
    String? deletedAt,
  }) {
    final String resolvedUpdatedAt = _timestampOrFallback(
      updatedAt ?? transaction.createdAt,
    );
    return db.TransactionsCompanion(
      id: Value<String>(transaction.id),
      type: Value<String>(transaction.type),
      date: Value<String>(transaction.date),
      amountText: Value<String>(_decimalText(transaction.amount)),
      currency: Value<String>(transaction.currency),
      category: Value<String>(transaction.category),
      description: Value<String>(transaction.description),
      createdAt: Value<String>(_timestampOrFallback(transaction.createdAt)),
      rolledOver: Value<bool>(transaction.rolledOver),
      rolledAmountText: Value<String?>(
        transaction.rolledAmount == null
            ? null
            : _decimalText(transaction.rolledAmount!),
      ),
      sourceIncomeId: Value<String?>(transaction.sourceIncomeId),
      exchangePairId: Value<String?>(transaction.exchangePairId),
      exchangeSourceIncomeId: Value<String?>(transaction.exchangeSourceIncomeId),
      remainingAmountText: Value<String?>(
        transaction.remainingAmount == null
            ? null
            : _decimalText(transaction.remainingAmount!),
      ),
      activityType: Value<String?>(transaction.activityType),
      costBasisText: Value<String?>(
        transaction.costBasis == null ? null : _decimalText(transaction.costBasis!),
      ),
      saleValueText: Value<String?>(
        transaction.saleValue == null ? null : _decimalText(transaction.saleValue!),
      ),
      realizedGainText: Value<String?>(
        transaction.realizedGain == null
            ? null
            : _decimalText(transaction.realizedGain!),
      ),
      realizedGainLossCurrency: Value<String?>(
        transaction.realizedGainLossCurrency,
      ),
      metalQuantityText: Value<String?>(
        transaction.metalQuantity == null
            ? null
            : _decimalText(transaction.metalQuantity!),
      ),
      updatedAt: Value<String>(resolvedUpdatedAt),
      deletedAt: Value<String?>(deletedAt),
    );
  }

  model.Transaction fromRow(db.Transaction row) {
    return model.Transaction(
      id: row.id,
      type: row.type,
      date: row.date,
      amount: _toDouble(row.amountText),
      currency: row.currency,
      category: row.category,
      description: row.description,
      createdAt: row.createdAt,
      rolledOver: row.rolledOver,
      rolledAmount: _nullableDouble(row.rolledAmountText),
      sourceIncomeId: row.sourceIncomeId,
      exchangePairId: row.exchangePairId,
      exchangeSourceIncomeId: row.exchangeSourceIncomeId,
      remainingAmount: _nullableDouble(row.remainingAmountText),
      activityType: row.activityType,
      costBasis: _nullableDouble(row.costBasisText),
      saleValue: _nullableDouble(row.saleValueText),
      realizedGain: _nullableDouble(row.realizedGainText),
      realizedGainLossCurrency: row.realizedGainLossCurrency,
      metalQuantity: _nullableDouble(row.metalQuantityText),
    );
  }

  String decimalTextFromAny(dynamic value, {String fallback = '0'}) {
    if (value == null) return fallback;
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? fallback : trimmed;
    }
    if (value is num) return _decimalText(value);
    final String raw = value.toString().trim();
    return raw.isEmpty ? fallback : raw;
  }

  String timestampFromAny(dynamic value, {String? fallback}) {
    return _timestampOrFallback(value?.toString(), fallback: fallback);
  }

  String _decimalText(num value) {
    if (value is int) return value.toString();
    final String raw = value.toString();
    if (!raw.contains('.') || raw.contains('e') || raw.contains('E')) {
      return raw;
    }
    return raw.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  double _toDouble(String value) => double.tryParse(value) ?? 0;

  double? _nullableDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    return double.tryParse(value);
  }

  String _timestampOrFallback(String? value, {String? fallback}) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    final String fallbackValue = fallback?.trim() ?? '';
    if (fallbackValue.isNotEmpty) return fallbackValue;
    return DateTime.now().toUtc().toIso8601String();
  }
}
