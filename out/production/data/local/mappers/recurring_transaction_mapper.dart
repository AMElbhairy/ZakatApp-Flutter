import 'package:drift/drift.dart';

import '../../../models/recurring_transaction.dart';
import '../app_database.dart' as db;

class RecurringTransactionMapper {
  const RecurringTransactionMapper();

  db.RecurringTransactionsCompanion toCompanion(
    RecurringTransaction recurring, {
    String? updatedAt,
    String? deletedAt,
  }) {
    final String resolvedUpdatedAt = _timestampOrFallback(
      updatedAt ?? recurring.createdAt,
    );
    return db.RecurringTransactionsCompanion(
      id: Value<String>(recurring.id),
      name: Value<String>(recurring.name),
      type: Value<String>(recurring.type),
      amountText: Value<String>(_decimalText(recurring.amount)),
      currency: Value<String>(recurring.currency),
      category: Value<String>(recurring.category),
      description: Value<String>(recurring.description),
      dayOfMonth: Value<int>(recurring.dayOfMonth),
      frequency: Value<String>(recurring.frequency),
      lastProcessed: Value<String?>(recurring.lastProcessed),
      enabled: Value<bool>(recurring.enabled),
      skipMonth: Value<String>(recurring.skipMonth),
      createdAt: Value<String>(_timestampOrFallback(recurring.createdAt)),
      updatedAt: Value<String>(resolvedUpdatedAt),
      deletedAt: Value<String?>(deletedAt),
    );
  }

  RecurringTransaction fromRow(db.RecurringTransaction row) {
    return RecurringTransaction(
      id: row.id,
      name: row.name,
      type: row.type,
      amount: _toDouble(row.amountText),
      currency: row.currency,
      category: row.category,
      description: row.description,
      dayOfMonth: row.dayOfMonth,
      frequency: row.frequency,
      lastProcessed: row.lastProcessed,
      enabled: row.enabled,
      skipMonth: row.skipMonth,
      createdAt: row.createdAt,
    );
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

  double _toDouble(String value) => double.tryParse(value) ?? 0;
}
