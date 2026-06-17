// ignore_for_file: avoid_print
import 'package:flutter/foundation.dart';

import '../core/utils/amount_parser.dart';
import 'saving.dart';
import 'transaction.dart';

class CurrencyExchangeEditRequest {
  const CurrencyExchangeEditRequest({
    required this.oldActivityId,
    required this.oldTargetSavingIds,
    required this.oldSourceSavingDeductions,
    required this.date,
    required this.sourceCurrency,
    required this.targetCurrency,
    required this.sourceAmount,
    required this.targetAmount,
  });

  final String oldActivityId;
  final List<String> oldTargetSavingIds;
  final Map<String, double> oldSourceSavingDeductions;
  final String date;
  final String sourceCurrency;
  final String targetCurrency;
  final double sourceAmount;
  final double targetAmount;
}

CurrencyExchangeEditRequest? resolveCurrencyExchangeEditRequest({
  required List<Transaction> transactions,
  required List<Saving> savings,
  required Object item,
}) {
  if (kDebugMode) {
    print(
      '[ExchangeDebug][resolveRequest] item=${item.runtimeType}',
    );
  }
  if (item is Transaction) {
    final String activityId = item.exchangePairId ?? '';
    if (activityId.isEmpty) return null;
    return _buildFromActivityId(
      transactions: transactions,
      savings: savings,
      activityId: activityId,
    );
  }

  if (item is Saving) {
    final String activityId = item.transferActivityId ?? '';
    if (activityId.isNotEmpty) {
      return _buildFromActivityId(
        transactions: transactions,
        savings: savings,
        activityId: activityId,
      );
    }

    final _SavingExchangeSource? parsed = _parseSavingExchangeSource(
      item.description,
    );
    final Map<String, double> sourceSavingDeductions = <String, double>{};
    final String? sourceSavingId = item.exchangeSourceSavingId;
    if (sourceSavingId != null &&
        sourceSavingId.isNotEmpty &&
        parsed != null &&
        parsed.amount > 0) {
      sourceSavingDeductions[sourceSavingId] = parsed.amount;
    }

    return CurrencyExchangeEditRequest(
      oldActivityId: '',
      oldTargetSavingIds: <String>[item.id],
      oldSourceSavingDeductions: sourceSavingDeductions,
      date: item.dateAcquired,
      sourceCurrency: parsed?.currency ?? 'USD',
      targetCurrency: item.unit,
      sourceAmount: parsed?.amount ?? 0,
      targetAmount: item.amount,
    );
  }

  return null;
}

CurrencyExchangeEditRequest? resolveCurrencyExchangeEditRequestByActivityId({
  required List<Transaction> transactions,
  required List<Saving> savings,
  required String activityId,
}) {
  final String cleanActivityId = activityId.trim();
  if (cleanActivityId.isEmpty) return null;
  return _buildFromActivityId(
    transactions: transactions,
    savings: savings,
    activityId: cleanActivityId,
  );
}

CurrencyExchangeEditRequest? _buildFromActivityId({
  required List<Transaction> transactions,
  required List<Saving> savings,
  required String activityId,
}) {
  final List<Transaction> pair = transactions
      .where((Transaction tx) => tx.exchangePairId == activityId)
      .toList(growable: false);
  final List<Saving> targetSavings = savings
      .where(
        (Saving saving) =>
            saving.transferActivityId == activityId &&
            saving.internalTransferType == 'savings_currency_exchange',
      )
      .toList(growable: false);

  if (pair.isEmpty && targetSavings.isEmpty) return null;

  final Transaction? sourceTransaction = pair
      .where((Transaction tx) => tx.type == 'expense')
      .firstOrNull;
  final Transaction? targetTransaction = pair
      .where((Transaction tx) => tx.type == 'income')
      .firstOrNull;
  final Saving? targetSaving = targetSavings.firstOrNull;

  double savingSourceAmount = 0;
  String savingSourceCurrency = '';
  final Map<String, double> sourceSavingDeductions = <String, double>{};
  for (final Saving saving in targetSavings) {
    final _SavingExchangeSource? parsed = _parseSavingExchangeSource(
      saving.description,
    );
    if (parsed == null) continue;
    savingSourceAmount += parsed.amount;
    if (savingSourceCurrency.isEmpty && parsed.currency.isNotEmpty) {
      savingSourceCurrency = parsed.currency;
    }
    final String? sourceSavingId = saving.exchangeSourceSavingId;
    if (sourceSavingId != null && sourceSavingId.isNotEmpty) {
      sourceSavingDeductions[sourceSavingId] =
          (sourceSavingDeductions[sourceSavingId] ?? 0) + parsed.amount;
    }
  }

  final double sourceAmount =
      pair
          .where((Transaction tx) => tx.type == 'expense')
          .fold<double>(
            0,
            (double total, Transaction tx) => total + tx.amount,
          ) +
      savingSourceAmount;
  final double targetAmount =
      pair
          .where((Transaction tx) => tx.type == 'income')
          .fold<double>(
            0,
            (double total, Transaction tx) => total + tx.amount,
          ) +
      targetSavings.fold<double>(
        0,
        (double total, Saving saving) => total + saving.amount,
      );

  final String sourceCurrency = sourceTransaction?.currency.isNotEmpty == true
      ? sourceTransaction!.currency
      : savingSourceCurrency;
  final String targetCurrency = targetTransaction?.currency.isNotEmpty == true
      ? targetTransaction!.currency
      : (targetSaving?.unit ?? '');
  final String date = _firstNonEmpty(<String?>[
    sourceTransaction?.date,
    targetTransaction?.date,
    targetSaving?.dateAcquired,
    _datePart(sourceTransaction?.createdAt),
    _datePart(targetTransaction?.createdAt),
    _datePart(targetSaving?.createdAt),
    DateTime.now().toUtc().toIso8601String().split('T').first,
  ]);

  if (kDebugMode) {
    print(
      '[ExchangeDebug][resolveRequest] activityId=$activityId '
      'source=${sourceCurrency.isEmpty ? 'null' : sourceCurrency} '
      'target=${targetCurrency.isEmpty ? 'null' : targetCurrency} '
      'date=$date sourceAmount=$sourceAmount targetAmount=$targetAmount '
      'targets=${targetSavings.map((Saving s) => s.id).toList(growable: false)}',
    );
  }

  if (sourceCurrency.isEmpty ||
      targetCurrency.isEmpty ||
      sourceAmount <= 0 ||
      targetAmount <= 0 ||
      date.isEmpty) {
    return null;
  }

  return CurrencyExchangeEditRequest(
    oldActivityId: activityId,
    oldTargetSavingIds: targetSavings
        .map((Saving saving) => saving.id)
        .toList(growable: false),
    oldSourceSavingDeductions: sourceSavingDeductions,
    date: date,
    sourceCurrency: sourceCurrency,
    targetCurrency: targetCurrency,
    sourceAmount: sourceAmount,
    targetAmount: targetAmount,
  );
}

String _firstNonEmpty(List<String?> values) {
  for (final String? value in values) {
    final String clean = (value ?? '').trim();
    if (clean.isNotEmpty) return clean;
  }
  return '';
}

String _datePart(String? value) {
  final String clean = (value ?? '').trim();
  if (clean.isEmpty) return '';
  return clean.split('T').first;
}

class _SavingExchangeSource {
  const _SavingExchangeSource({required this.amount, required this.currency});

  final double amount;
  final String currency;
}

_SavingExchangeSource? _parseSavingExchangeSource(String description) {
  final RegExp pattern = RegExp(
    r'Savings exchange:\s*([0-9.,]+)\s+([A-Z]+)\s*(?:→|->)',
  );
  final Match? match = pattern.firstMatch(description);
  if (match == null) return null;

  return _SavingExchangeSource(
    amount: tryParseAmount(match.group(1) ?? '') ?? 0,
    currency: match.group(2) ?? '',
  );
}
