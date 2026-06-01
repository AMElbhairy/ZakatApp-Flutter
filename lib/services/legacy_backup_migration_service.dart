import 'dart:convert';

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
    'aiSettings',
    'lastRollover',
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
      warnings.add('Dropped unsupported fields: ${unsupportedFields.join(', ')}');
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
    state['recurringTransactions'] = _normalizeList(state['recurringTransactions']);

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

  Map<String, dynamic> _unwrapState(Map<String, dynamic> root, List<String> warnings) {
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

  List<Map<String, dynamic>> _normalizeTransactions(dynamic value, List<String> warnings) {
    final List<dynamic> items = _normalizeList(value);
    return items.asMap().entries.map((MapEntry<int, dynamic> entry) {
      final int index = entry.key;
      final Map<String, dynamic> tx = _asMap(entry.value);
      tx['id'] = _ensureString(tx['id'], 'tx_$index');
      tx['description'] = (tx['description'] ?? '').toString();
      tx['createdAt'] = _ensureCreatedAt(tx['createdAt'], tx['date'], index);

      // Preserve known dynamic metadata from old app.
      _preserveString(tx, 'exchangePairId');
      _preserveString(tx, 'sourceIncomeId');
      _preserveBool(tx, 'rolledOver');
      _preserveNum(tx, 'rolledAmount');
      _preserveString(tx, 'linkedCashEntryId');
      if (tx['zakatExpenseIds'] is List) {
        tx['zakatExpenseIds'] = List<dynamic>.from(tx['zakatExpenseIds'] as List);
      }

      final String desc = tx['description'].toString().toLowerCase();
      if (desc.startsWith('savings exchange:')) {
        tx['internalTransferType'] = tx['internalTransferType'] ?? 'savings_exchange';
      }
      if (desc.startsWith('currency exchange out:')) {
        tx['internalTransferType'] = tx['internalTransferType'] ?? 'currency_exchange_out';
      }

      return tx;
    }).toList(growable: false);
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
      final String assetType = (saving['assetType'] ?? '').toString().toLowerCase();
      saving['assetType'] = assetType;

      final String description = (saving['description'] ?? '').toString();
      saving['description'] = description;

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
      saving['createdAt'] = _ensureCreatedAt(saving['createdAt'], saving['dateAcquired'], i);

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
                ? mainCurrency
                : (saving['currency'] ?? '').toString();
        saving['purchaseCurrency'] = fallbackCurrency;
      }
      result.add(saving);
    }
    return result;
  }

  List<Map<String, dynamic>> _normalizeInvestments(dynamic value, List<String> warnings) {
    final List<dynamic> items = _normalizeList(value);
    return items.asMap().entries.map((MapEntry<int, dynamic> entry) {
      final int index = entry.key;
      final Map<String, dynamic> inv = _asMap(entry.value);
      inv['id'] = _ensureString(inv['id'], 'inv_$index');
      inv['description'] = (inv['description'] ?? '').toString();
      inv['createdAt'] = _ensureCreatedAt(inv['createdAt'], inv['valuationDate'], index);

      final num totalPayable = _asNum(inv['totalPayable']);
      final num paidAmount = _asNum(inv['paidAmount']);
      inv['paidAmount'] = paidAmount;
      inv['remainingAmount'] = inv['remainingAmount'] ?? (totalPayable - paidAmount);
      inv['loanBalance'] = inv['loanBalance'] ?? inv['remainingAmount'] ?? 0;

      final dynamic installmentPlan = inv['installmentPlan'];
      if (installmentPlan is String && installmentPlan.trim().isNotEmpty) {
        try {
          final dynamic parsed = jsonDecode(installmentPlan);
          if (parsed is List) {
            inv['installmentPlan'] = parsed
                .map((dynamic e) => e is Map
                    ? Map<String, dynamic>.from(e)
                    : <String, dynamic>{})
                .toList(growable: false);
            warnings.add('Parsed stringified investment.installmentPlan.');
          }
        } catch (_) {
          inv['installmentPlan'] = <Map<String, dynamic>>[];
          warnings.add('Invalid stringified investment.installmentPlan replaced with empty list.');
        }
      }
      return inv;
    }).toList(growable: false);
  }

  List<Map<String, dynamic>> _normalizeFinancialPlans(dynamic value, List<String> warnings) {
    final List<dynamic> items = _normalizeList(value);
    return items.asMap().entries.map((MapEntry<int, dynamic> entry) {
      final int index = entry.key;
      final Map<String, dynamic> plan = _asMap(entry.value);
      plan['id'] = _ensureString(plan['id'], 'plan_$index');
      plan['createdAt'] = _ensureCreatedAt(plan['createdAt'], plan['startDate'], index);
      if (plan['context'] != null && plan['context'] is! Map) {
        plan['context'] = <String, dynamic>{};
        warnings.add('FinancialPlan.context had invalid shape; reset to empty map.');
      }
      if (plan['context'] is Map) {
        plan['context'] = Map<String, dynamic>.from(plan['context'] as Map);
      }
      return plan;
    }).toList(growable: false);
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
        return localDate.toUtc().add(Duration(seconds: index)).toIso8601String();
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(index * 1000, isUtc: true)
        .toIso8601String();
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
}
