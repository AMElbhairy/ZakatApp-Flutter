import 'dart:convert';

import '../models/investment_asset.dart';

class LegacyMigrationReport {
  const LegacyMigrationReport({
    required this.state,
    required this.warnings,
    required this.unsupportedFields,
  });

  final Map<String, dynamic> state;
  final List<String> warnings;
  final List<String> unsupportedFields;
}

class LegacyBackupMigrationService {
  static const List<String> _unsupportedRootFields = <String>[
    'syncHealth',
    'marketHistory',
  ];

  Map<String, dynamic> parseAndMigrate(String rawJson) {
    return parseAndMigrateWithReport(rawJson).state;
  }

  LegacyMigrationReport parseAndMigrateWithReport(String rawJson) {
    final dynamic decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw const FormatException('Backup payload must be a JSON object.');
    }
    final Map<String, dynamic> root = Map<String, dynamic>.from(decoded);

    final List<String> warnings = <String>[];
    final List<String> unsupportedFields = <String>[];

    Map<String, dynamic> state = _unwrapState(root, warnings);

    for (final String field in _unsupportedRootFields) {
      if (state.containsKey(field)) {
        state.remove(field);
        unsupportedFields.add(field);
      }
    }
    if (unsupportedFields.isNotEmpty) {
      warnings.add(
        'Dropped unsupported fields: ${unsupportedFields.join(', ')}',
      );
    }

    final String mainCurrency = (state['mainCurrency'] ?? 'EGP').toString();

    state['transactions'] = _normalizeTransactions(
      state['transactions'],
      warnings,
    );
    state['savings'] = _normalizeSavings(
      state['savings'],
      mainCurrency,
      warnings,
    );
    state['investments'] = _normalizeInvestments(
      state['investments'],
      warnings,
    );
    state['financialPlans'] = _normalizeFinancialPlans(
      state['financialPlans'],
      warnings,
    );
    state['recurringTransactions'] = _normalizeRecurringTransactions(
      state['recurringTransactions'],
      warnings,
    );
    state['lastRollover'] = _normalizeLastRollover(
      state['lastRollover'],
      warnings,
    );

    if (state['categories'] is! Map) {
      state['categories'] = <String, dynamic>{
        'income': <String>[],
        'expense': <String>[],
      };
      warnings.add('Missing categories. Applied empty categories.');
    }

    return LegacyMigrationReport(
      state: state,
      warnings: warnings,
      unsupportedFields: unsupportedFields,
    );
  }

  Map<String, dynamic> _unwrapState(
    Map<String, dynamic> root,
    List<String> warnings,
  ) {
    if (root['appName'] == 'ZakatApp' && root['appState'] is Map) {
      return Map<String, dynamic>.from(root['appState'] as Map);
    }

    if (root['version'] != null && root['data'] is String) {
      warnings.add('Detected legacy backup V1. Unwrapped stringified data.');
      final dynamic parsed = jsonDecode(root['data'] as String);
      if (parsed is! Map) {
        throw const FormatException('Legacy V1 data is not a JSON object.');
      }
      return Map<String, dynamic>.from(parsed);
    }

    if (root['schema'] == 'zakatapp.backup' && root['data'] is Map) {
      warnings.add('Detected legacy backup V2. Unwrapped nested data.');
      return Map<String, dynamic>.from(root['data'] as Map);
    }

    throw const FormatException('Unrecognized backup schema.');
  }

  List<Map<String, dynamic>> _normalizeTransactions(
    dynamic value,
    List<String> warnings,
  ) {
    final List<dynamic> items = _normalizeList(value);
    return items
        .asMap()
        .entries
        .map((MapEntry<int, dynamic> entry) {
          final int index = entry.key;
          final Map<String, dynamic> tx = _asMap(entry.value);
          final String rawType = _firstNonEmpty(tx, <String>[
            'type',
            'transactionType',
            'entryType',
            'kind',
          ]).toLowerCase();
          String type = _normalizeTransactionType(rawType);

          num amount = _firstNum(tx, <String>[
            'amount',
            'value',
            'incomeAmount',
            'expenseAmount',
            'totalAmount',
          ]);
          if (type.isEmpty) {
            if (tx['incomeAmount'] != null) {
              type = 'income';
            } else if (tx['expenseAmount'] != null) {
              type = 'expense';
            } else if (amount < 0) {
              type = 'expense';
            }
          }
          if (amount < 0) amount = amount.abs();

          tx['type'] = type == 'expense' ? 'expense' : 'income';
          tx['amount'] = amount;
          tx['currency'] = _normaliseCurrency(
            _firstNonEmpty(tx, <String>['currency', 'unit', 'currencyCode']),
          );
          if ((tx['currency'] ?? '').toString().isEmpty) {
            tx['currency'] = 'EGP';
            warnings.add('Backfilled transaction.currency with EGP.');
          }
          tx['date'] = _normaliseDate(
            _firstNonEmpty(tx, <String>[
              'date',
              'transactionDate',
              'dateAcquired',
              'createdDate',
            ]),
          );
          if ((tx['date'] ?? '').toString().isEmpty) {
            tx['date'] = '1970-01-01';
            warnings.add('Backfilled transaction.date with 1970-01-01.');
          }
          tx['category'] = _firstNonEmpty(tx, <String>['category', 'source']);
          if ((tx['category'] ?? '').toString().isEmpty) {
            tx['category'] = tx['type'] == 'income' ? 'Income' : 'Expense';
          }
          tx['id'] = _ensureString(tx['id'], 'tx_$index');
          tx['description'] = (tx['description'] ?? '').toString();
          tx['createdAt'] = _ensureCreatedAt(
            tx['createdAt'],
            tx['date'],
            index,
          );

          // Preserve known dynamic metadata from old app.
          _preserveString(tx, 'exchangePairId');
          _preserveString(tx, 'sourceIncomeId');
          _preserveBool(tx, 'rolledOver');
          _preserveNum(tx, 'rolledAmount');
          _preserveString(tx, 'linkedCashEntryId');
          if (tx['zakatExpenseIds'] is List) {
            tx['zakatExpenseIds'] = List<dynamic>.from(
              tx['zakatExpenseIds'] as List,
            );
          }

          final String desc = tx['description'].toString().toLowerCase();
          if (desc.startsWith('savings exchange:')) {
            tx['internalTransferType'] =
                tx['internalTransferType'] ?? 'savings_exchange';
          }
          if (desc.startsWith('currency exchange out:')) {
            tx['internalTransferType'] =
                tx['internalTransferType'] ?? 'currency_exchange_out';
          }
          final String category = (tx['category'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (category == 'currency exchange' ||
              category == 'precious metals purchase' ||
              desc.startsWith('currency exchange out:') ||
              desc.startsWith('currency exchange in:')) {
            tx['activityType'] = 'transfer';
          }

          return tx;
        })
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _normalizeSavings(
    dynamic value,
    String mainCurrency,
    List<String> warnings,
  ) {
    final List<dynamic> items = _normalizeList(value);
    final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
    for (int i = 0; i < items.length; i++) {
      final Map<String, dynamic> saving = _asMap(items[i]);
      final String assetType = _normalizeAssetType(saving['assetType']);
      saving['assetType'] = assetType;
      saving['dateAcquired'] = _normaliseDate(
        _firstNonEmpty(saving, <String>[
          'dateAcquired',
          'date',
          'createdDate',
          'createdAt',
        ]),
      );

      final String description = (saving['description'] ?? '').toString();
      saving['description'] = description;

      if (assetType == 'cash') {
        final String unit = _normaliseCurrency(
          _firstNonEmpty(saving, <String>[
            'unit',
            'currency',
            'purchaseCurrency',
          ]),
        );
        saving['unit'] = unit.isEmpty ? mainCurrency : unit;
      }

      if (assetType == 'cash' &&
          (saving['unit'] ?? '').toString() == 'EGP' &&
          description == 'Auto-transfer from monthly surplus') {
        warnings.add('Filtered legacy buggy auto-transfer cash saving.');
        continue;
      }

      if (assetType == 'gold') {
        final String unit = (saving['unit'] ?? '').toString();
        final String normalized = unit.toLowerCase().replaceAll('k', '').trim();
        if (normalized != unit && normalized.isNotEmpty) {
          saving['unit'] = normalized;
          warnings.add('Normalized gold karat value "$unit" -> "$normalized".');
        }
      }

      saving['id'] = _ensureString(saving['id'], 'sav_$i');
      _preserveString(saving, 'sourceIncomeId');
      _preserveString(saving, 'linkedCashEntryId');
      _preserveString(saving, 'exchangeSourceSavingId');
      _preserveString(saving, 'exchangeSourceIncomeId');
      saving['createdAt'] = _ensureCreatedAt(
        saving['createdAt'],
        saving['dateAcquired'],
        i,
      );

      final num amount = _asNum(saving['amount']);
      if (saving['remainingAmount'] == null) {
        saving['remainingAmount'] = amount;
        warnings.add('Backfilled saving.remainingAmount from amount.');
      }
      if ((saving['purchaseAmount'] == null)) {
        saving['purchaseAmount'] = amount;
      }
      if ((saving['purchaseCurrency'] ?? '').toString().trim().isEmpty) {
        final String fallbackCurrency =
            (saving['currency'] ?? '').toString().trim().isEmpty
            ? (assetType == 'cash' ? saving['unit'].toString() : mainCurrency)
            : (saving['currency'] ?? '').toString();
        saving['purchaseCurrency'] = _normaliseCurrency(fallbackCurrency);
      } else {
        saving['purchaseCurrency'] = _normaliseCurrency(
          saving['purchaseCurrency'].toString(),
        );
      }
      result.add(saving);
    }
    return result;
  }

  List<Map<String, dynamic>> _normalizeInvestments(
    dynamic value,
    List<String> warnings,
  ) {
    final List<dynamic> items = _normalizeList(value);
    return items
        .asMap()
        .entries
        .map((MapEntry<int, dynamic> entry) {
          final int index = entry.key;
          final Map<String, dynamic> inv = _asMap(entry.value);
          inv['id'] = _ensureString(inv['id'], 'inv_$index');
          inv['description'] = (inv['description'] ?? '').toString();
          inv['createdAt'] = _ensureCreatedAt(
            inv['createdAt'],
            inv['valuationDate'],
            index,
          );

          final num totalPayable = _asNum(inv['totalPayable']);
          final num paidAmount = _asNum(inv['paidAmount']);
          inv['paidAmount'] = paidAmount;
          inv['remainingAmount'] =
              inv['remainingAmount'] ?? (totalPayable - paidAmount);
          inv['loanBalance'] =
              inv['loanBalance'] ?? inv['remainingAmount'] ?? 0;

          final dynamic installmentPlan = inv['installmentPlan'];
          if (installmentPlan is String && installmentPlan.trim().isNotEmpty) {
            try {
              final dynamic parsed = jsonDecode(installmentPlan);
              if (parsed is List) {
                inv['installmentPlan'] =
                    InvestmentAsset.normalizeInstallmentPlan(parsed);
                warnings.add('Parsed stringified investment.installmentPlan.');
              }
            } catch (_) {
              inv['installmentPlan'] = <Map<String, dynamic>>[];
              warnings.add(
                'Invalid stringified investment.installmentPlan replaced with empty list.',
              );
            }
          } else {
            inv['installmentPlan'] = InvestmentAsset.normalizeInstallmentPlan(
              installmentPlan,
            );
          }
          return inv;
        })
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _normalizeRecurringTransactions(
    dynamic value,
    List<String> warnings,
  ) {
    final List<dynamic> items = _normalizeList(value);
    return items
        .asMap()
        .entries
        .map((MapEntry<int, dynamic> entry) {
          final int index = entry.key;
          final Map<String, dynamic> tx = _asMap(entry.value);
          tx['id'] = _ensureString(tx['id'], 'rec_$index');
          tx['name'] = _firstNonEmpty(tx, <String>['name', 'title']);
          tx['type'] = _normalizeTransactionType(
            _firstNonEmpty(tx, <String>[
              'type',
              'transactionType',
              'entryType',
              'kind',
            ]),
          );
          if (tx['type'] != 'expense') tx['type'] = 'income';
          tx['amount'] = _firstNum(tx, <String>['amount', 'value']);
          tx['currency'] = _normaliseCurrency(
            _firstNonEmpty(tx, <String>['currency', 'unit', 'currencyCode']),
          );
          if ((tx['currency'] ?? '').toString().isEmpty) {
            tx['currency'] = 'EGP';
            warnings.add('Backfilled recurring transaction currency with EGP.');
          }
          tx['category'] = _firstNonEmpty(tx, <String>['category', 'source']);
          if ((tx['category'] ?? '').toString().isEmpty) {
            tx['category'] = tx['type'] == 'income' ? 'Income' : 'Expense';
          }
          tx['description'] = (tx['description'] ?? '').toString();
          if ((tx['frequency'] ?? '').toString().trim().isEmpty) {
            tx['frequency'] = 'monthly';
          }
          tx['lastProcessed'] = _normaliseDate(
            (tx['lastProcessed'] ?? '').toString(),
          );
          tx['skipMonth'] = (tx['skipMonth'] ?? '').toString();
          _preserveBool(tx, 'enabled');
          tx['createdAt'] = _ensureCreatedAt(
            tx['createdAt'],
            tx['lastProcessed'],
            index,
          );
          return tx;
        })
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _normalizeFinancialPlans(
    dynamic value,
    List<String> warnings,
  ) {
    final List<dynamic> items = _normalizeList(value);
    return items
        .asMap()
        .entries
        .map((MapEntry<int, dynamic> entry) {
          final int index = entry.key;
          final Map<String, dynamic> plan = _asMap(entry.value);
          plan['id'] = _ensureString(plan['id'], 'plan_$index');
          plan['createdAt'] = _ensureCreatedAt(
            plan['createdAt'],
            plan['startDate'],
            index,
          );
          if (plan['context'] != null && plan['context'] is! Map) {
            plan['context'] = <String, dynamic>{};
            warnings.add(
              'FinancialPlan.context had invalid shape; reset to empty map.',
            );
          }
          if (plan['context'] is Map) {
            plan['context'] = Map<String, dynamic>.from(plan['context'] as Map);
          }
          return plan;
        })
        .toList(growable: false);
  }

  String _ensureString(dynamic value, String fallback) {
    final String raw = (value ?? '').toString().trim();
    return raw.isEmpty ? fallback : raw;
  }

  String _ensureCreatedAt(dynamic createdAt, dynamic dateLike, int index) {
    final String existing = (createdAt ?? '').toString().trim();
    if (existing.isNotEmpty) return existing;

    final String date = (dateLike ?? '').toString().trim();
    if (date.isNotEmpty) {
      final DateTime? dt = DateTime.tryParse(date);
      if (dt != null) {
        return dt.toUtc().add(Duration(seconds: index)).toIso8601String();
      }
      final DateTime? localDate = DateTime.tryParse('${date}T00:00:00Z');
      if (localDate != null) {
        return localDate
            .toUtc()
            .add(Duration(seconds: index))
            .toIso8601String();
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(
      index * 1000,
      isUtc: true,
    ).toIso8601String();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<dynamic> _normalizeList(dynamic value) {
    if (value is List) return value;
    return <dynamic>[];
  }

  num _asNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse((value ?? '').toString()) ?? 0;
  }

  num _firstNum(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = map[key];
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      return _asNum(value);
    }
    return 0;
  }

  String _firstNonEmpty(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final String value = (map[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _normaliseCurrency(String value) {
    return value.trim().toUpperCase();
  }

  String _normalizeTransactionType(String value) {
    final String type = value.trim().toLowerCase();
    if (type == 'cash_in' ||
        type == 'cashin' ||
        type == 'deposit' ||
        type == 'credit' ||
        type == 'earning') {
      return 'income';
    }
    if (type == 'cash_out' ||
        type == 'cashout' ||
        type == 'withdrawal' ||
        type == 'debit' ||
        type == 'spending') {
      return 'expense';
    }
    return type;
  }

  String _normalizeAssetType(dynamic value) {
    final String raw = (value ?? '').toString().trim().toLowerCase();
    if (raw == 'cash & currencies' || raw == 'currency' || raw == 'wallet') {
      return 'cash';
    }
    if (raw == 'precious_metal' || raw == 'precious metals') {
      return 'gold';
    }
    return raw;
  }

  String _normaliseDate(String value) {
    final String raw = value.trim();
    if (raw.isEmpty) return '';
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return parsed.toIso8601String().split('T').first;
  }

  void _preserveString(Map<String, dynamic> map, String key) {
    if (map[key] != null) map[key] = map[key].toString();
  }

  void _preserveBool(Map<String, dynamic> map, String key) {
    final dynamic value = map[key];
    if (value is bool) return;
    if (value is num) {
      map[key] = value != 0;
      return;
    }
    if (value != null) {
      final String raw = value.toString().toLowerCase();
      map[key] = raw == 'true' || raw == '1';
    }
  }

  void _preserveNum(Map<String, dynamic> map, String key) {
    if (map[key] is num || map[key] == null) return;
    map[key] = num.tryParse(map[key].toString());
  }

  String _normalizeLastRollover(dynamic value, List<String> warnings) {
    if (value == null) return '';
    final String raw = value.toString().trim();
    if (raw.isEmpty) return '';

    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      return parsed.toIso8601String().split('T').first;
    }

    final List<String> parts = raw.split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      final Map<String, int> months = <String, int>{
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };

      String? yearStr;
      String? monthStr;
      String? dayStr;

      for (final String part in parts) {
        final String clean = part.replaceAll(',', '').toLowerCase();
        if (months.containsKey(clean)) {
          monthStr = clean;
        } else if (RegExp(r'^\d{4}$').hasMatch(clean)) {
          yearStr = clean;
        } else if (RegExp(r'^\d{1,2}$').hasMatch(clean)) {
          dayStr = clean;
        }
      }

      if (yearStr != null && monthStr != null && dayStr != null) {
        final int year = int.parse(yearStr);
        final int month = months[monthStr]!;
        final int day = int.parse(dayStr);
        final String m = month.toString().padLeft(2, '0');
        final String d = day.toString().padLeft(2, '0');
        return '$year-$m-$d';
      }
    }

    warnings.add('Unable to parse lastRollover date: "$raw". Keeping as is.');
    return raw;
  }
}
