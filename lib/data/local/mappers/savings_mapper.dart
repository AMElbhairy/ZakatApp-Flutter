import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../models/saving.dart' as model;
import '../app_database.dart' as db;

class SavingsMapper {
  const SavingsMapper();

  db.SavingsCompanion toCompanion(
    model.Saving saving, {
    String? updatedAt,
    String? deletedAt,
  }) {
    final String resolvedUpdatedAt = _timestampOrFallback(
      updatedAt ?? saving.createdAt,
    );
    return db.SavingsCompanion(
      id: Value<String>(saving.id),
      assetType: Value<String>(saving.assetType),
      dateAcquired: Value<String>(saving.dateAcquired),
      amountText: Value<String>(_decimalText(saving.amount)),
      remainingAmountText: Value<String>(_decimalText(saving.remainingAmount)),
      unit: Value<String>(saving.unit),
      description: Value<String>(saving.description),
      linkedCashEntryId: Value<String?>(saving.linkedCashEntryId),
      purchaseCurrency: Value<String>(saving.purchaseCurrency),
      purchaseAmountText: Value<String>(_decimalText(saving.purchaseAmount)),
      createdAt: Value<String>(_timestampOrFallback(saving.createdAt)),
      sourceIncomeId: Value<String?>(saving.sourceIncomeId),
      exchangeSourceSavingId: Value<String?>(saving.exchangeSourceSavingId),
      exchangeSourceIncomeId: Value<String?>(saving.exchangeSourceIncomeId),
      internalTransfer: Value<bool?>(saving.internalTransfer),
      internalTransferType: Value<String?>(saving.internalTransferType),
      fundingAllocationsJson: Value<String>(
        jsonEncode(saving.fundingAllocations),
      ),
      transferActivityId: Value<String?>(saving.transferActivityId),
      updatedAt: Value<String>(resolvedUpdatedAt),
      deletedAt: Value<String?>(deletedAt),
    );
  }

  model.Saving fromRow(db.Saving row) {
    return model.Saving(
      id: row.id,
      assetType: row.assetType,
      dateAcquired: row.dateAcquired,
      amount: _toDouble(row.amountText),
      remainingAmount: _toDouble(row.remainingAmountText),
      unit: row.unit,
      description: row.description,
      linkedCashEntryId: row.linkedCashEntryId,
      purchaseCurrency: row.purchaseCurrency,
      purchaseAmount: _toDouble(row.purchaseAmountText),
      createdAt: row.createdAt,
      sourceIncomeId: row.sourceIncomeId,
      exchangeSourceSavingId: row.exchangeSourceSavingId,
      exchangeSourceIncomeId: row.exchangeSourceIncomeId,
      internalTransfer: row.internalTransfer,
      internalTransferType: row.internalTransferType,
      fundingAllocations: _decodeFundingAllocations(row.fundingAllocationsJson),
      transferActivityId: row.transferActivityId,
    );
  }

  List<Map<String, dynamic>> _decodeFundingAllocations(String raw) {
    if (raw.trim().isEmpty) return const <Map<String, dynamic>>[];
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! List) return const <Map<String, dynamic>>[];
    return decoded
        .whereType<Map>()
        .map((Map<dynamic, dynamic> item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
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

  String _timestampOrFallback(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    return DateTime.now().toUtc().toIso8601String();
  }
}
