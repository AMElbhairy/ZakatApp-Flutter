import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../models/financial_plan.dart';
import '../app_database.dart' as db;

class FinancialPlanMapper {
  const FinancialPlanMapper();

  db.FinancialPlansCompanion toCompanion(
    FinancialPlan plan, {
    String? updatedAt,
    String? deletedAt,
  }) {
    final String resolvedUpdatedAt = _timestampOrFallback(
      updatedAt ?? plan.createdAt,
    );
    return db.FinancialPlansCompanion(
      id: Value<String>(plan.id),
      name: Value<String>(plan.name),
      startDate: Value<String>(plan.startDate),
      projectionCurrency: Value<String>(plan.projectionCurrency),
      startingBalanceText: Value<String>(_decimalText(plan.startingBalance)),
      startingBalanceDate: Value<String>(plan.startingBalanceDate),
      startingBalanceMode: Value<String>(plan.startingBalanceMode),
      snapshotWealthCurrency: Value<String>(plan.snapshotWealthCurrency),
      startingAssetBreakdownJson: Value<String>(
        jsonEncode(plan.startingAssetBreakdown),
      ),
      monthlyIncomeText: Value<String>(_decimalText(plan.monthlyIncome)),
      monthlyExpensesText: Value<String>(_decimalText(plan.monthlyExpenses)),
      includeInstallments: Value<bool>(plan.includeInstallments),
      includeZakat: Value<bool>(plan.includeZakat),
      durationYears: Value<int>(plan.durationYears),
      createdAt: Value<String>(_timestampOrFallback(plan.createdAt)),
      isActive: Value<bool>(plan.isActive),
      startingAssetsText: Value<String>(_decimalText(plan.startingAssets)),
      startingLiabilitiesText: Value<String>(
        _decimalText(plan.startingLiabilities),
      ),
      startingNetWorthText: Value<String>(_decimalText(plan.startingNetWorth)),
      startingNisabSnapshotText: Value<String>(
        _decimalText(plan.startingNisabSnapshot),
      ),
      startingGoldPriceSnapshotText: Value<String>(
        _decimalText(plan.startingGoldPriceSnapshot),
      ),
      startingFxSnapshotJson: Value<String>(jsonEncode(plan.startingFxSnapshot)),
      updatedAt: Value<String>(resolvedUpdatedAt),
      deletedAt: Value<String?>(deletedAt),
    );
  }

  FinancialPlan fromRow(db.FinancialPlan row) {
    return FinancialPlan(
      id: row.id,
      name: row.name,
      startDate: row.startDate,
      projectionCurrency: row.projectionCurrency,
      startingBalance: _toDouble(row.startingBalanceText),
      startingBalanceDate: row.startingBalanceDate,
      startingBalanceMode: row.startingBalanceMode,
      snapshotWealthCurrency: row.snapshotWealthCurrency,
      startingAssetBreakdown: _decodeMap(row.startingAssetBreakdownJson),
      monthlyIncome: _toDouble(row.monthlyIncomeText),
      monthlyExpenses: _toDouble(row.monthlyExpensesText),
      includeInstallments: row.includeInstallments,
      includeZakat: row.includeZakat,
      durationYears: row.durationYears,
      createdAt: row.createdAt,
      isActive: row.isActive,
      startingAssets: _toDouble(row.startingAssetsText),
      startingLiabilities: _toDouble(row.startingLiabilitiesText),
      startingNetWorth: _toDouble(row.startingNetWorthText),
      startingNisabSnapshot: _toDouble(row.startingNisabSnapshotText),
      startingGoldPriceSnapshot: _toDouble(row.startingGoldPriceSnapshotText),
      startingFxSnapshot: _decodeMap(row.startingFxSnapshotJson),
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

  Map<String, double> _decodeMap(String raw) {
    if (raw.trim().isEmpty) return <String, double>{};
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map) return <String, double>{};
    return decoded.map(
      (dynamic key, dynamic value) => MapEntry<String, double>(
        key.toString(),
        value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0,
      ),
    );
  }
}
