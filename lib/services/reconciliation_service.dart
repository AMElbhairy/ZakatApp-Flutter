import '../models/app_state.dart';
import '../core/services/zakat_engine.dart';

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

  ReconciliationResult toggleInstallmentPaid({
    required AppStateModel input,
    required String assetId,
    required int installmentIndex,
    required String paymentCategory,
    required MarketData marketData,
  }) {
    final Map<String, dynamic> state = input.toJson();
    final List<Map<String, dynamic>> investments = _asMapList(state['investments']);
    final List<Map<String, dynamic>> transactions = _asMapList(state['transactions']);
    final List<String> processedExpenseIds = _asStringList(state['processedExpenseIds']);

    final int assetIdx = investments.indexWhere((Map<String, dynamic> a) => a['id'] == assetId);
    if (assetIdx == -1) return ReconciliationResult(state: input, modified: false);

    final Map<String, dynamic> asset = Map<String, dynamic>.from(investments[assetIdx]);
    final List<Map<String, dynamic>> plan = _asMapList(asset['installmentPlan']);

    if (installmentIndex < 0 || installmentIndex >= plan.length) {
      return ReconciliationResult(state: input, modified: false);
    }

    final Map<String, dynamic> installment = Map<String, dynamic>.from(plan[installmentIndex]);
    final bool isPaid = _asBool(installment['isPaid']);

    if (!isPaid) {
      if (paymentCategory.isEmpty) {
        throw Exception('Payment category is required to mark as paid.');
      }

      final String installmentCurrency = (installment['currency']?.toString().isNotEmpty == true)
          ? installment['currency'].toString()
          : (asset['currency']?.toString() ?? 'EGP');

      final String today = DateTime.now().toUtc().toIso8601String().split('T').first;
      final String assetLabel = asset['location']?.toString().isNotEmpty == true
          ? asset['location'].toString()
          : (asset['assetSubtype']?.toString() ?? 'Asset');

      final String txId = 'tx_${DateTime.now().millisecondsSinceEpoch}_inst';

      final Map<String, dynamic> expense = <String, dynamic>{
        'id': txId,
        'type': 'expense',
        'date': today,
        'amount': _asDouble(installment['amount']),
        'currency': installmentCurrency,
        'category': paymentCategory,
        'description': 'Installment payment - $assetLabel',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };

      transactions.add(expense);
      processedExpenseIds.add(txId);

      installment['isPaid'] = true;
      installment['paymentCategory'] = paymentCategory;
      installment['paidExpenseId'] = txId;
    } else {
      final String paidExpenseId = (installment['paidExpenseId'] ?? '').toString();
      if (paidExpenseId.isNotEmpty) {
        transactions.removeWhere((Map<String, dynamic> tx) => tx['id'] == paidExpenseId);
        processedExpenseIds.removeWhere((String id) => id == paidExpenseId);
      }

      installment['isPaid'] = false;
      installment['paymentCategory'] = '';
      installment['paidExpenseId'] = '';
    }

    plan[installmentIndex] = installment;
    asset['installmentPlan'] = plan;

    _syncAssetInstallmentProgress(asset, marketData);

    investments[assetIdx] = asset;
    state['investments'] = investments;
    state['transactions'] = transactions;
    state['processedExpenseIds'] = processedExpenseIds;

    final AppStateModel next = AppStateModel.fromJson(state);
    return ReconciliationResult(state: next, modified: true);
  }

  void _syncAssetInstallmentProgress(Map<String, dynamic> asset, MarketData marketData) {
    if ((asset['ownershipType'] ?? '') != 'installment') return;
    final List<Map<String, dynamic>> plan = _asMapList(asset['installmentPlan']);
    if (plan.isEmpty) return;

    final String assetCurrency = (asset['currency'] ?? 'EGP').toString();
    double totalInstallments = 0.0;
    double paidInstallments = 0.0;

    for (final Map<String, dynamic> item in plan) {
      final String itemCurrency = (item['currency']?.toString().isNotEmpty == true)
          ? item['currency'].toString()
          : assetCurrency;
      final double amount = _asDouble(item['amount']);

      final double amountEgp = ZakatEngineService.convertToEgp(amount, itemCurrency, marketData);
      final double inAssetCur = ZakatEngineService.convertFromEgp(amountEgp, assetCurrency, marketData);
      final double normAmount = _round6(_max(0, inAssetCur));

      totalInstallments = _round6(totalInstallments + normAmount);
      if (_asBool(item['isPaid'])) {
        paidInstallments = _round6(paidInstallments + normAmount);
      }
    }

    final double storedTotalPayable = _max(0, _asDouble(asset['totalPayable']));
    final double upfrontPaid = _max(0, storedTotalPayable - totalInstallments);
    final double paidTotal = upfrontPaid + paidInstallments;

    asset['paidAmount'] = _max(0.0, paidTotal);
    asset['remainingAmount'] = _max(0.0, totalInstallments - paidInstallments);
    asset['totalPayable'] = _max(0.0, paidTotal + _asDouble(asset['remainingAmount']));
    asset['paidAmountToDate'] = asset['paidAmount'];
    asset['loanBalance'] = asset['remainingAmount'];
  }

  ReconciliationResult executeCurrencyExchange({
    required AppStateModel input,
    required String date,
    required String sourceType, // 'savings', 'income', 'both'
    required String sourceCurrency,
    required String targetCurrency,
    required double sourceAmount,
    required double targetAmount,
  }) {
    final Map<String, dynamic> state = input.toJson();
    final List<Map<String, dynamic>> transactions = _asMapList(state['transactions']);
    final List<Map<String, dynamic>> savings = _asMapList(state['savings']);
    final List<String> processedExpenseIds = _asStringList(state['processedExpenseIds']);

    final List<Map<String, dynamic>> lots = <Map<String, dynamic>>[];

    if (sourceType == 'savings' || sourceType == 'both') {
      final Iterable<Map<String, dynamic>> cashSavings = savings.where((Map<String, dynamic> s) =>
          _normalizeAssetType(s['assetType']) == 'cash' &&
          (s['unit'] ?? '').toString() == sourceCurrency &&
          _asDouble(s['remainingAmount']) >= minAmount);
      for (final Map<String, dynamic> s in cashSavings) {
        lots.add(<String, dynamic>{
          'sourceType': 'savings',
          'id': s['id'],
          'date': s['dateAcquired'],
          'createdAt': s['createdAt'],
          'availableAmount': _asDouble(s['remainingAmount']),
          'ref': s,
        });
      }
    }

    if (sourceType == 'income' || sourceType == 'both') {
      final Iterable<IncomeLot> incomeLots = getNetIncomeLotsForCurrency(
        transactions: transactions,
        currency: sourceCurrency,
      ).where((IncomeLot l) => l.remainingAmount >= minAmount);

      for (final IncomeLot l in incomeLots) {
        lots.add(<String, dynamic>{
          'sourceType': 'income',
          'id': l.id,
          'date': l.date,
          'createdAt': l.date,
          'availableAmount': l.remainingAmount,
          'ref': <String, dynamic>{'sourceIncomeId': l.id},
        });
      }
    }

    lots.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final DateTime da = DateTime.tryParse('${a['date']}') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final DateTime db = DateTime.tryParse('${b['date']}') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final int comp = da.compareTo(db);
      if (comp != 0) return comp;
      final DateTime ca = DateTime.tryParse('${a['createdAt']}') ?? da;
      final DateTime cb = DateTime.tryParse('${b['createdAt']}') ?? db;
      return ca.compareTo(cb);
    });

    final double totalAvailable = lots.fold<double>(0, (double sum, Map<String, dynamic> l) => sum + _asDouble(l['availableAmount']));
    if (sourceAmount <= 0 || sourceAmount - totalAvailable > minAmount) {
      throw Exception('Invalid exchange amount');
    }

    final List<Map<String, dynamic>> deductions = <Map<String, dynamic>>[];
    double remaining = sourceAmount;
    for (final Map<String, dynamic> lot in lots) {
      if (remaining <= minAmount) break;
      final double d = _min(_asDouble(lot['availableAmount']), remaining);
      if (d <= minAmount) continue;
      deductions.add(<String, dynamic>{
        ...lot,
        'deductedAmount': _round6(d),
      });
      remaining = _round6(remaining - d);
    }

    if (remaining > minAmount) {
      throw Exception('Not enough funds to exchange');
    }

    final String exchangePairId = 'exch_${DateTime.now().millisecondsSinceEpoch}';

    for (final Map<String, dynamic> d in deductions) {
      if (d['sourceType'] == 'savings') {
        final Map<String, dynamic> s = savings.firstWhere((Map<String, dynamic> x) => x['id'] == d['id']);
        s['amount'] = _round6(_asDouble(s['amount']) - _asDouble(d['deductedAmount']));
        s['remainingAmount'] = _round6(_asDouble(s['remainingAmount']) - _asDouble(d['deductedAmount']));
        if (_asDouble(s['amount']) < minAmount) s['amount'] = 0.0;
        if (_asDouble(s['remainingAmount']) < minAmount) s['remainingAmount'] = 0.0;
      } else {
        final String outId = 'tx_${DateTime.now().millisecondsSinceEpoch}_${d['id']}_out';
        final Map<String, dynamic> outTx = <String, dynamic>{
          'id': outId,
          'type': 'expense',
          'date': date,
          'amount': d['deductedAmount'],
          'currency': sourceCurrency,
          'category': 'Currency Exchange',
          'description': 'Currency exchange out: ${d['deductedAmount']} $sourceCurrency → $targetCurrency',
          'sourceIncomeId': d['id'],
          'exchangePairId': exchangePairId,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        };
        transactions.add(outTx);
        processedExpenseIds.add(outId);
      }
    }

    savings.removeWhere((Map<String, dynamic> s) =>
        _normalizeAssetType(s['assetType']) == 'cash' &&
        (s['unit'] ?? '').toString() == sourceCurrency &&
        _asDouble(s['amount']) < minAmount &&
        _asDouble(s['remainingAmount']) < minAmount);

    double remainingTarget = _round6(targetAmount);
    for (int i = 0; i < deductions.length; i++) {
      final Map<String, dynamic> d = deductions[i];
      double alloc = (i == deductions.length - 1)
          ? remainingTarget
          : _round6((targetAmount * _asDouble(d['deductedAmount'])) / sourceAmount);
      if (alloc > remainingTarget) alloc = remainingTarget;

      if (d['sourceType'] == 'savings') {
        final Map<String, dynamic> ns = <String, dynamic>{
          'id': 'sav_${DateTime.now().millisecondsSinceEpoch}_$i',
          'assetType': 'cash',
          'dateAcquired': d['date'],
          'amount': alloc,
          'remainingAmount': alloc,
          'unit': targetCurrency,
          'description': 'Savings exchange: ${d['deductedAmount']} $sourceCurrency → $alloc $targetCurrency',
          'internalTransfer': true,
          'internalTransferType': 'savings_currency_exchange',
          'exchangeSourceSavingId': d['id'],
          'sourceIncomeId': d['ref']?['sourceIncomeId'],
          'createdAt': d['createdAt'] ?? DateTime.now().toUtc().toIso8601String(),
        };
        savings.add(ns);
      } else {
        final Map<String, dynamic> inTx = <String, dynamic>{
          'id': 'tx_${DateTime.now().millisecondsSinceEpoch}_${d['id']}_in',
          'type': 'income',
          'date': date,
          'amount': alloc,
          'currency': targetCurrency,
          'category': 'Currency Exchange',
          'description': 'Currency exchange in: ${d['deductedAmount']} $sourceCurrency → $alloc $targetCurrency',
          'exchangeSourceIncomeId': d['id'],
          'exchangePairId': exchangePairId,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        };
        transactions.add(inTx);
      }
      remainingTarget = _round6(remainingTarget - alloc);
    }

    state['transactions'] = transactions;
    state['savings'] = savings;
    state['processedExpenseIds'] = processedExpenseIds;

    final AppStateModel next = AppStateModel.fromJson(state);
    return ReconciliationResult(state: next, modified: true);
  }

  ReconciliationResult toggleZakatPaid({
    required AppStateModel input,
    required String monthKey,
    required double zakatAmountMainCurrency,
    required String mainCurrency,
    required String paymentDate,
  }) {
    final Map<String, dynamic> state = input.toJson();
    final List<Map<String, dynamic>> transactions = _asMapList(state['transactions']);
    final List<String> zakatPaidMonths = _asStringList(state['zakatPaidMonths']);
    final List<String> processedExpenseIds = _asStringList(state['processedExpenseIds']);
    final Map<String, dynamic> zakatExpenseIds = Map<String, dynamic>.from(state['zakatExpenseIds'] ?? <String, dynamic>{});

    final bool wasPaid = zakatPaidMonths.contains(monthKey);

    if (!wasPaid) {
      if (zakatAmountMainCurrency > 0) {
        final String today = DateTime.now().toUtc().toIso8601String().split('T').first;
        final String payDate = paymentDate.compareTo(today) > 0 ? today : paymentDate;

        final String txId = 'tx_${DateTime.now().millisecondsSinceEpoch}_zakat';

        final Map<String, dynamic> tx = <String, dynamic>{
          'id': txId,
          'type': 'expense',
          'date': payDate,
          'amount': zakatAmountMainCurrency,
          'currency': mainCurrency,
          'category': 'Zakat',
          'description': 'Zakat payment - $monthKey',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        };

        transactions.add(tx);
        processedExpenseIds.add(txId);
        zakatExpenseIds[monthKey] = txId;
      }
      zakatPaidMonths.add(monthKey);
    } else {
      final String expId = (zakatExpenseIds[monthKey] ?? '').toString();
      if (expId.isNotEmpty) {
        transactions.removeWhere((Map<String, dynamic> tx) => tx['id'] == expId);
        processedExpenseIds.removeWhere((String id) => id == expId);
        zakatExpenseIds.remove(monthKey);
      }
      zakatPaidMonths.remove(monthKey);
    }

    state['transactions'] = transactions;
    state['zakatPaidMonths'] = zakatPaidMonths;
    state['processedExpenseIds'] = processedExpenseIds;
    state['zakatExpenseIds'] = zakatExpenseIds;

    final AppStateModel next = AppStateModel.fromJson(state);
    return ReconciliationResult(state: next, modified: true);
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
        .toList(growable: true);
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

  List<String> _asStringList(dynamic value) {
    if (value is! List) return <String>[];
    return value.map((dynamic e) => e.toString()).toList(growable: true);
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

  double _max(double a, double b) => a > b ? a : b;
}

class DeductResult {
  const DeductResult({
    required this.savings,
    required this.deductions,
  });

  final List<Map<String, dynamic>> savings;
  final List<SavingDeduction> deductions;
}
