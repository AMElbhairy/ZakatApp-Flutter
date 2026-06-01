import '../models/app_state.dart';

class IncomeLot {
  const IncomeLot({
    required this.id,
    required this.date,
    required this.originalAmount,
    required this.remainingAmount,
    required this.rolledOver,
    required this.currency,
    this.category,
    this.description,
  });

  final String id;
  final String date;
  final double originalAmount;
  final double remainingAmount;
  final bool rolledOver;
  final String currency;
  final String? category;
  final String? description;
}

class SavingDeduction {
  const SavingDeduction({required this.savingId, required this.deduction});

  final String savingId;
  final double deduction;
}

class ReconciliationResult {
  const ReconciliationResult({
    required this.state,
    required this.modified,
  });

  final AppStateModel state;
  final bool modified;
}

class ReconciliationService {
  static const double minAmount = 0.005;

  ReconciliationResult reconcileExpensesWithSavings(AppStateModel input) {
    final Map<String, dynamic> state = input.toJson();
    final List<Map<String, dynamic>> transactions = _asMapList(state['transactions']);
    final List<Map<String, dynamic>> savings = _asMapList(state['savings']);

    final List<Map<String, dynamic>> normalizedTransactions = transactions
        .asMap()
        .entries
        .map((MapEntry<int, Map<String, dynamic>> entry) {
      final Map<String, dynamic> tx = Map<String, dynamic>.from(entry.value);
      tx['createdAt'] = _stableCreatedAt(tx['createdAt'], tx['date'], entry.key);
      tx['rolledOver'] = _asBool(tx['rolledOver']);
      return tx;
    }).toList(growable: false);

    final List<Map<String, dynamic>> normalizedSavings = savings
        .asMap()
        .entries
        .map((MapEntry<int, Map<String, dynamic>> entry) {
      final Map<String, dynamic> s = Map<String, dynamic>.from(entry.value);
      s['createdAt'] = _stableCreatedAt(s['createdAt'], s['dateAcquired'], entry.key);
      final double amount = _asDouble(s['amount']);
      s['remainingAmount'] = amount;
      return s;
    }).toList(growable: false);

    final Set<String> currencies = <String>{
      ...normalizedTransactions.map((Map<String, dynamic> e) => (e['currency'] ?? '').toString()),
      ...normalizedSavings.map((Map<String, dynamic> e) => (e['unit'] ?? '').toString()),
    }..removeWhere((String e) => e.trim().isEmpty);

    final Set<String> processedExpenseIds = <String>{};

    for (final String currency in currencies) {
      double runningBalance = 0;
      final List<Map<String, dynamic>> txForCurrency = _sortTransactionsForLotMatching(
        normalizedTransactions
            .where((Map<String, dynamic> tx) => (tx['currency'] ?? '').toString() == currency)
            .toList(growable: false),
      );

      for (final Map<String, dynamic> tx in txForCurrency) {
        final String type = (tx['type'] ?? '').toString();
        final double amount = _asDouble(tx['amount']);
        if (type == 'income') {
          if (_asBool(tx['rolledOver']) && _asDouble(tx['rolledAmount']) > 0) {
            runningBalance += (amount - _asDouble(tx['rolledAmount'])).clamp(0, double.infinity);
          } else {
            runningBalance += amount;
          }
          continue;
        }
        if (type != 'expense') continue;

        runningBalance -= amount;

        if (runningBalance < -minAmount) {
          final double overflow = -runningBalance;
          final DeductResult deduct = deductExpenseFromSavings(
            savings: normalizedSavings,
            currency: currency,
            overflowAmount: overflow,
          );
          final double covered = deduct.deductions.fold<double>(
            0,
            (double sum, SavingDeduction d) => sum + d.deduction,
          );
          runningBalance += covered;
        }
        final String expenseId = (tx['id'] ?? '').toString();
        if (expenseId.trim().isNotEmpty) {
          processedExpenseIds.add(expenseId);
        }
      }
    }

    state['transactions'] = normalizedTransactions;
    state['savings'] = normalizedSavings;
    state['processedExpenseIds'] = processedExpenseIds.toList(growable: false);

    final AppStateModel next = AppStateModel.fromJson(state);
    final bool modified = _stateChanged(input.toJson(), next.toJson());
    return ReconciliationResult(state: next, modified: modified);
  }

  List<IncomeLot> getNetIncomeLotsForCurrency({
    required List<Map<String, dynamic>> transactions,
    required String currency,
  }) {
    final List<Map<String, dynamic>> sorted = _sortTransactionsForLotMatching(
      transactions
          .asMap()
          .entries
          .where((MapEntry<int, Map<String, dynamic>> entry) =>
              (entry.value['currency'] ?? '').toString() == currency)
          .map((MapEntry<int, Map<String, dynamic>> entry) {
        final Map<String, dynamic> tx = Map<String, dynamic>.from(entry.value);
        tx['createdAt'] = _stableCreatedAt(tx['createdAt'], tx['date'], entry.key);
        return tx;
      }).toList(growable: false),
    );

    final List<Map<String, dynamic>> lots = <Map<String, dynamic>>[];

    for (final Map<String, dynamic> tx in sorted) {
      final String type = (tx['type'] ?? '').toString();
      final double amount = _asDouble(tx['amount']);
      if (type == 'income') {
        double effectiveAmount = amount;
        if (_asBool(tx['rolledOver']) && _asDouble(tx['rolledAmount']) > 0) {
          effectiveAmount = amount - _asDouble(tx['rolledAmount']);
          if (effectiveAmount < minAmount) continue;
        }
        lots.add(<String, dynamic>{
          'id': (tx['id'] ?? '').toString(),
          'date': (tx['date'] ?? '').toString(),
          'originalAmount': effectiveAmount,
          'remainingAmount': effectiveAmount,
          'rolledOver': _asBool(tx['rolledOver']),
          'currency': currency,
          'category': tx['category'],
          'description': tx['description'],
        });
      } else if (type == 'expense') {
        double toDeduct = amount;
        final String sourceIncomeId = (tx['sourceIncomeId'] ?? '').toString();
        if (sourceIncomeId.isNotEmpty) {
          final Map<String, dynamic>? linked = lots.cast<Map<String, dynamic>?>().firstWhere(
                (Map<String, dynamic>? l) => (l?['id'] ?? '').toString() == sourceIncomeId,
                orElse: () => null,
              );
          if (linked != null) {
            final double linkedDeduction =
                _min(_asDouble(linked['remainingAmount']), toDeduct);
            linked['remainingAmount'] = _round6(_asDouble(linked['remainingAmount']) - linkedDeduction);
            toDeduct = _round6(toDeduct - linkedDeduction);
          }
        }

        for (final Map<String, dynamic> lot in lots) {
          if (toDeduct <= 0) break;
          final double deduction = _min(_asDouble(lot['remainingAmount']), toDeduct);
          lot['remainingAmount'] = _round6(_asDouble(lot['remainingAmount']) - deduction);
          toDeduct = _round6(toDeduct - deduction);
        }
      }
    }

    final double transactionBalance = sorted.fold<double>(0, (double sum, Map<String, dynamic> tx) {
      final String type = (tx['type'] ?? '').toString();
      final double amount = _asDouble(tx['amount']);
      if (type == 'income') {
        if (_asBool(tx['rolledOver']) && _asDouble(tx['rolledAmount']) > 0) {
          return sum + (amount - _asDouble(tx['rolledAmount']));
        }
        return sum + amount;
      }
      if (type == 'expense') return sum - amount;
      return sum;
    });

    final double lotsTotal = lots.fold<double>(
      0,
      (double sum, Map<String, dynamic> lot) => sum + _asDouble(lot['remainingAmount']),
    );

    double delta = _round6(transactionBalance - lotsTotal);
    if (delta > minAmount) {
      for (int i = lots.length - 1; i >= 0 && delta > minAmount; i--) {
        lots[i]['remainingAmount'] = _round6(_asDouble(lots[i]['remainingAmount']) + delta);
        delta = 0;
      }
    } else if (delta < -minAmount) {
      double toReduce = delta.abs();
      for (final Map<String, dynamic> lot in lots) {
        if (toReduce <= minAmount) break;
        final double deduction = _min(_asDouble(lot['remainingAmount']), toReduce);
        lot['remainingAmount'] = _round6(_asDouble(lot['remainingAmount']) - deduction);
        toReduce = _round6(toReduce - deduction);
      }
    }

    return lots
        .map((Map<String, dynamic> lot) => IncomeLot(
              id: (lot['id'] ?? '').toString(),
              date: (lot['date'] ?? '').toString(),
              originalAmount: _asDouble(lot['originalAmount']),
              remainingAmount: _asDouble(lot['remainingAmount']),
              rolledOver: _asBool(lot['rolledOver']),
              currency: (lot['currency'] ?? '').toString(),
              category: lot['category']?.toString(),
              description: lot['description']?.toString(),
            ))
        .toList(growable: false);
  }

  DeductResult deductExpenseFromSavings({
    required List<Map<String, dynamic>> savings,
    required String currency,
    required double overflowAmount,
  }) {
    final List<Map<String, dynamic>> cashSavings = savings
        .where((Map<String, dynamic> s) =>
            _normalizeAssetType(s['assetType']) == 'cash' &&
            (s['unit'] ?? '').toString() == currency &&
            _asDouble(s['remainingAmount']) > minAmount)
        .toList(growable: false)
      ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        final DateTime da = DateTime.tryParse('${a['dateAcquired'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        final DateTime db = DateTime.tryParse('${b['dateAcquired'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        final int dateComp = da.compareTo(db);
        if (dateComp != 0) return dateComp;
        final DateTime ca = DateTime.tryParse('${a['createdAt'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        final DateTime cb = DateTime.tryParse('${b['createdAt'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        return ca.compareTo(cb);
      });

    double remaining = overflowAmount;
    final List<SavingDeduction> deductions = <SavingDeduction>[];

    for (final Map<String, dynamic> saving in cashSavings) {
      if (remaining <= minAmount) break;
      final double savingRemaining = _asDouble(saving['remainingAmount']);
      final double deduction = _min(savingRemaining, remaining);
      saving['remainingAmount'] = _round6(savingRemaining - deduction);
      remaining = _round6(remaining - deduction);
      deductions.add(
        SavingDeduction(
          savingId: (saving['id'] ?? '').toString(),
          deduction: deduction,
        ),
      );
      if (_asDouble(saving['remainingAmount']) < minAmount) {
        saving['remainingAmount'] = 0.0;
      }
    }

    return DeductResult(savings: savings, deductions: deductions);
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((Map e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _sortTransactionsForLotMatching(
    List<Map<String, dynamic>> transactions,
  ) {
    final List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(transactions);
    list.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final DateTime ad = DateTime.tryParse((a['date'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final DateTime bd = DateTime.tryParse((b['date'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final int dateComp = ad.compareTo(bd);
      if (dateComp != 0) return dateComp;

      final DateTime ac = DateTime.tryParse((a['createdAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final DateTime bc = DateTime.tryParse((b['createdAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final int createdComp = ac.compareTo(bc);
      if (createdComp != 0) return createdComp;

      final String at = (a['type'] ?? '').toString();
      final String bt = (b['type'] ?? '').toString();
      if (at != bt) return at == 'income' ? -1 : 1;
      return 0;
    });
    return list;
  }

  String _stableCreatedAt(dynamic createdAt, dynamic baseDate, int orderIdx) {
    final String existing = (createdAt ?? '').toString().trim();
    final DateTime? createdParsed = DateTime.tryParse(existing);
    if (existing.isNotEmpty && createdParsed != null) {
      return createdParsed.toUtc().toIso8601String();
    }

    final String base = (baseDate ?? '').toString().trim();
    final DateTime? baseParsed = DateTime.tryParse('${base}T00:00:00.000Z');
    final int seed = orderIdx < 0 ? 0 : orderIdx;
    if (baseParsed != null) {
      return baseParsed.toUtc().add(Duration(milliseconds: seed)).toIso8601String();
    }
    return DateTime.fromMillisecondsSinceEpoch(seed % 1000, isUtc: true).toIso8601String();
  }

  bool _stateChanged(Map<String, dynamic> before, Map<String, dynamic> after) {
    final List<Map<String, dynamic>> bSavings = _asMapList(before['savings']);
    final List<Map<String, dynamic>> aSavings = _asMapList(after['savings']);
    if (bSavings.length != aSavings.length) return true;
    for (int i = 0; i < bSavings.length; i++) {
      if (_asDouble(bSavings[i]['remainingAmount']) !=
          _asDouble(aSavings[i]['remainingAmount'])) {
        return true;
      }
    }
    final Set<String> bProcessed = _asStringSet(before['processedExpenseIds']);
    final Set<String> aProcessed = _asStringSet(after['processedExpenseIds']);
    if (bProcessed.length != aProcessed.length) return true;
    if (!bProcessed.containsAll(aProcessed)) return true;
    return false;
  }

  Set<String> _asStringSet(dynamic value) {
    if (value is! List) return <String>{};
    return value.map((dynamic e) => e.toString()).toSet();
  }

  String _normalizeAssetType(dynamic value) {
    return (value ?? '').toString().trim().toLowerCase();
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final String raw = (value ?? '').toString().toLowerCase();
    return raw == 'true' || raw == '1';
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  double _round6(double value) => double.parse(value.toStringAsFixed(6));

  double _min(double a, double b) => a < b ? a : b;
}

class DeductResult {
  const DeductResult({
    required this.savings,
    required this.deductions,
  });

  final List<Map<String, dynamic>> savings;
  final List<SavingDeduction> deductions;
}
