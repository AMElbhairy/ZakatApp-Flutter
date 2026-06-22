import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../models/investment_asset.dart' as model;
import '../app_database.dart' as db;

class InvestmentsMapper {
  const InvestmentsMapper();

  db.InvestmentsCompanion toCompanion(
    model.InvestmentAsset asset, {
    String? updatedAt,
    String? deletedAt,
  }) {
    return db.InvestmentsCompanion(
      id: Value<String>(asset.id),
      investmentType: Value<String>(asset.investmentType),
      assetSubtype: Value<String>(asset.assetSubtype),
      ownershipType: Value<String>(asset.ownershipType),
      valuationMode: Value<String>(asset.valuationMode),
      currency: Value<String>(asset.currency),
      originalPriceText: Value<String>(_decimalText(asset.originalPrice)),
      totalInterestText: Value<String>(_decimalText(asset.totalInterest)),
      totalPayableText: Value<String>(_decimalText(asset.totalPayable)),
      paidAmountText: Value<String>(_decimalText(asset.paidAmount)),
      remainingAmountText: Value<String>(_decimalText(asset.remainingAmount)),
      installmentPlanJson: Value<String>(jsonEncode(asset.installmentPlan)),
      valuationDate: Value<String>(asset.valuationDate),
      marketValueText: Value<String>(_decimalText(asset.marketValue)),
      marketValueDate: Value<String>(asset.marketValueDate),
      valuationSource: Value<String>(asset.valuationSource),
      loanBalanceText: Value<String>(_decimalText(asset.loanBalance)),
      loanAsOfDate: Value<String>(asset.loanAsOfDate),
      paidAmountToDateText: Value<String>(_decimalText(asset.paidAmountToDate)),
      ownershipSharePctText: Value<String>(_decimalText(asset.ownershipSharePct)),
      country: Value<String>(asset.country),
      location: Value<String>(asset.location),
      inflationRateText: Value<String>(_decimalText(asset.inflationRateAnnual)),
      estimatedCurrentValueText: Value<String>(
        _decimalText(asset.estimatedCurrentValue),
      ),
      description: Value<String>(asset.description),
      noZakat: Value<bool>(asset.noZakat),
      yearlyGrowthRateText: Value<String?>(_decimalText(asset.yearlyGrowthRate)),
      createdAt: Value<String>(_timestampOrFallback(asset.createdAt)),
      updatedAt: Value<String>(_timestampOrFallback(updatedAt ?? asset.createdAt)),
      deletedAt: Value<String?>(deletedAt),
    );
  }

  model.InvestmentAsset fromRow(db.Investment row) {
    return model.InvestmentAsset(
      id: row.id,
      investmentType: row.investmentType,
      assetSubtype: row.assetSubtype,
      ownershipType: row.ownershipType,
      valuationMode: row.valuationMode,
      currency: row.currency,
      originalPrice: _toDouble(row.originalPriceText),
      totalInterest: _toDouble(row.totalInterestText),
      totalPayable: _toDouble(row.totalPayableText),
      paidAmount: _toDouble(row.paidAmountText),
      remainingAmount: _toDouble(row.remainingAmountText),
      installmentPlan: _decodeInstallmentPlan(row.installmentPlanJson),
      valuationDate: row.valuationDate,
      marketValue: _toDouble(row.marketValueText),
      marketValueDate: row.marketValueDate,
      valuationSource: row.valuationSource,
      loanBalance: _toDouble(row.loanBalanceText),
      loanAsOfDate: row.loanAsOfDate,
      paidAmountToDate: _toDouble(row.paidAmountToDateText),
      ownershipSharePct: _toDouble(row.ownershipSharePctText),
      country: row.country,
      location: row.location,
      inflationRateAnnual: _toDouble(row.inflationRateText),
      estimatedCurrentValue: _toDouble(row.estimatedCurrentValueText),
      description: row.description,
      noZakat: row.noZakat,
      createdAt: row.createdAt,
      yearlyGrowthRate: _toDouble(row.yearlyGrowthRateText ?? '0'),
    );
  }

  List<Map<String, dynamic>> _decodeInstallmentPlan(String raw) {
    if (raw.trim().isEmpty) return const <Map<String, dynamic>>[];
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! List) return const <Map<String, dynamic>>[];
    return decoded
        .whereType<Map>()
        .map((Map<dynamic, dynamic> item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  double _toDouble(String value) => double.tryParse(value) ?? 0;

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
