import 'dart:math' as math;

import '../../models/investment_asset.dart';
import '../../models/saving.dart';
import '../../models/transaction.dart';

class ZakatConfig {
  const ZakatConfig({
    this.nisabGoldGrams = 85,
    this.nisabDays = 354,
    this.zakatRate = 0.025,
    this.goldPurity = const <String, double>{
      '24': 1.0,
      '21': 0.875,
      '18': 0.75,
    },
  });

  final double nisabGoldGrams;
  final int nisabDays;
  final double zakatRate;
  final Map<String, double> goldPurity;
}

class MarketData {
  const MarketData({
    required this.goldPrice24kEgp,
    required this.silverPriceEgp,
    required this.usdToEgp,
    required this.sarToEgp,
    required this.ratesToEgp,
  });

  final double goldPrice24kEgp;
  final double silverPriceEgp;
  final double usdToEgp;
  final double sarToEgp;
  final Map<String, double> ratesToEgp;

  factory MarketData.fromJson(Map<String, dynamic> json) {
    final Map<String, double> parsedRates = <String, double>{};
    final dynamic ratesRaw = json['RATES_TO_EGP'];
    if (ratesRaw is Map) {
      ratesRaw.forEach((dynamic key, dynamic value) {
        parsedRates[key.toString()] = _asDouble(value);
      });
    }

    return MarketData(
      goldPrice24kEgp: _asDouble(json['GOLD_PRICE_24K_EGP']),
      silverPriceEgp: _asDouble(json['SILVER_PRICE_EGP']),
      usdToEgp: _asDouble(json['USD_TO_EGP']),
      sarToEgp: _asDouble(json['SAR_TO_EGP']),
      ratesToEgp: parsedRates,
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class NisabTotals {
  const NisabTotals({
    required this.totalCashEgp,
    required this.totalGold24k,
    required this.totalGoldEgp,
    required this.totalSilverGrams,
    required this.totalSilverEgp,
    required this.totalSavingsWealthEgp,
  });

  final double totalCashEgp;
  final double totalGold24k;
  final double totalGoldEgp;
  final double totalSilverGrams;
  final double totalSilverEgp;
  final double totalSavingsWealthEgp;
}

class SavingStatus {
  const SavingStatus({
    required this.status,
    required this.daysElapsed,
    required this.hasCompletedYear,
    required this.zakatDue,
    required this.zakatValueEgp,
    required this.meetsNisab,
  });

  final String status;
  final int daysElapsed;
  final bool hasCompletedYear;
  final double zakatDue;
  final double zakatValueEgp;
  final bool meetsNisab;
}

class HijriDate {
  const HijriDate({
    required this.year,
    required this.month,
    required this.day,
  });

  final int year;
  final int month;
  final int day;
}

class ZakatScheduleEntry {
  const ZakatScheduleEntry({
    required this.monthKey,
    required this.paymentDate,
    required this.totalZakat,
    required this.isPast,
    required this.isCurrentMonth,
    required this.entries,
    this.totalWealth,
    this.hijriYear,
    this.hijriMonth,
    this.hijriDay,
  });

  final String monthKey;
  final String paymentDate;
  final double totalZakat;
  final bool isPast;
  final bool isCurrentMonth;
  final List<Map<String, dynamic>> entries;
  final double? totalWealth;
  final int? hijriYear;
  final int? hijriMonth;
  final int? hijriDay;
}

class ZakatEngineService {
  ZakatEngineService._();

  static const ZakatConfig defaultConfig = ZakatConfig();
  static const double minAmount = 0.005;

  static const List<String> supportedCurrencies = <String>[
    'EGP',
    'USD',
    'SAR',
    'EUR',
    'GBP',
    'AED',
    'KWD',
    'QAR',
    'BHD',
    'OMR',
    'JOD',
    'TRY',
    'MYR',
    'PKR',
    'IDR',
  ];

  static String normaliseAssetType(String? assetType) {
    return (assetType ?? '').trim().toLowerCase();
  }

  static double convertToEgp(double amount, String? currency, MarketData marketData) {
    if (currency == null || currency.isEmpty || currency == 'EGP') return amount;
    final double? rateFromMap = marketData.ratesToEgp[currency];
    final double? fallbackUsd = currency == 'USD' ? marketData.usdToEgp : null;
    final double? fallbackSar = currency == 'SAR' ? marketData.sarToEgp : null;
    final double rate = rateFromMap ?? fallbackUsd ?? fallbackSar ?? 1;
    return amount * rate;
  }

  static double convertFromEgp(double amountEgp, String? currency, MarketData marketData) {
    if (currency == null || currency.isEmpty || currency == 'EGP') return amountEgp;
    final double? rateFromMap = marketData.ratesToEgp[currency];
    final double? fallbackUsd = currency == 'USD' ? marketData.usdToEgp : null;
    final double? fallbackSar = currency == 'SAR' ? marketData.sarToEgp : null;
    final double rate = rateFromMap ?? fallbackUsd ?? fallbackSar ?? 1;
    return rate > 0 ? amountEgp / rate : amountEgp;
  }

  static double convertToGold24k(double weight, String? karat,
      [ZakatConfig config = defaultConfig]) {
    final double purity = config.goldPurity[karat ?? ''] ?? 1.0;
    return weight * purity;
  }

  static double convertToSilverGrams(double weight) {
    return weight;
  }

  static NisabTotals computeNisabTotals({
    required List<Saving> savings,
    required MarketData marketData,
  }) {
    final double totalCashEgp = savings
        .where((Saving s) => normaliseAssetType(s.assetType) == 'cash')
        .fold<double>(
          0,
          (double sum, Saving s) =>
              sum + convertToEgp(s.remainingAmount, s.unit, marketData),
        );

    final double totalGold24k = savings
        .where((Saving s) => normaliseAssetType(s.assetType) == 'gold')
        .fold<double>(
          0,
          (double sum, Saving s) =>
              sum + convertToGold24k(s.remainingAmount, s.unit),
        );

    final double totalSilverGrams = savings
        .where((Saving s) => normaliseAssetType(s.assetType) == 'silver')
        .fold<double>(
            0, (double sum, Saving s) => sum + convertToSilverGrams(s.remainingAmount));

    final double totalGoldEgp = totalGold24k * marketData.goldPrice24kEgp;
    final double totalSilverEgp = totalSilverGrams * marketData.silverPriceEgp;
    final double totalSavingsWealthEgp = totalCashEgp + totalGoldEgp + totalSilverEgp;

    return NisabTotals(
      totalCashEgp: totalCashEgp,
      totalGold24k: totalGold24k,
      totalGoldEgp: totalGoldEgp,
      totalSilverGrams: totalSilverGrams,
      totalSilverEgp: totalSilverEgp,
      totalSavingsWealthEgp: totalSavingsWealthEgp,
    );
  }

  static bool checkCashNisab(
    double amountInEgp,
    MarketData marketData,
  ) {
    final double nisabValueEgp =
        defaultConfig.nisabGoldGrams * marketData.goldPrice24kEgp;
    return amountInEgp >= nisabValueEgp;
  }

  static bool checkGoldNisab(double weight24k) {
    return weight24k >= defaultConfig.nisabGoldGrams;
  }

  static double calculateCashZakat(double amountInEgp) {
    return amountInEgp * defaultConfig.zakatRate;
  }

  static double calculateGoldZakat(double weight24k) {
    return weight24k * defaultConfig.zakatRate;
  }

  static int calculateDaysElapsed(String dateString) {
    final DateTime pastDate = DateTime.parse(dateString);
    final DateTime today = DateTime.now();
    return today.difference(pastDate).inDays;
  }

  static SavingStatus evaluateSavingStatus({
    required Saving saving,
    required List<Saving> savings,
    required MarketData marketData,
    NisabTotals? nisabTotals,
  }) {
    final int daysElapsed = calculateDaysElapsed(saving.dateAcquired);
    final bool hasCompletedYear = daysElapsed >= defaultConfig.nisabDays;
    String status = 'Checking';
    double zakatDue = 0;
    double zakatValueEgp = 0;

    final String assetType = normaliseAssetType(saving.assetType);
    final NisabTotals totals =
        nisabTotals ?? computeNisabTotals(savings: savings, marketData: marketData);

    if (assetType == 'cash') {
      final double amountInEgp =
          convertToEgp(saving.remainingAmount, saving.unit, marketData);
      final bool meetsNisab = checkCashNisab(totals.totalSavingsWealthEgp, marketData);
      if (!meetsNisab) {
        status = 'Nisab Not Met';
      } else if (!hasCompletedYear) {
        status = 'Hawl Not Complete';
      } else {
        status = 'Zakat Due!';
        zakatDue = calculateCashZakat(amountInEgp);
        zakatValueEgp = zakatDue;
      }
    } else if (assetType == 'gold') {
      final double weight24k = convertToGold24k(saving.remainingAmount, saving.unit);
      final bool meetsNisab = checkCashNisab(totals.totalSavingsWealthEgp, marketData);
      if (!meetsNisab) {
        status = 'Nisab Not Met';
      } else if (!hasCompletedYear) {
        status = 'Hawl Not Complete';
      } else {
        status = 'Zakat Due!';
        zakatDue = calculateGoldZakat(weight24k);
        zakatValueEgp = zakatDue * marketData.goldPrice24kEgp;
      }
    } else if (assetType == 'silver') {
      final double silverGrams = convertToSilverGrams(saving.remainingAmount);
      final double silverEgp = silverGrams * marketData.silverPriceEgp;
      final bool meetsNisab = checkCashNisab(totals.totalSavingsWealthEgp, marketData);
      if (!meetsNisab) {
        status = 'Nisab Not Met';
      } else if (!hasCompletedYear) {
        status = 'Hawl Not Complete';
      } else {
        status = 'Zakat Due!';
        zakatDue = silverEgp * defaultConfig.zakatRate;
        zakatValueEgp = zakatDue;
      }
    }

    return SavingStatus(
      status: status,
      daysElapsed: daysElapsed,
      hasCompletedYear: hasCompletedYear,
      zakatDue: zakatDue,
      zakatValueEgp: zakatValueEgp,
      meetsNisab: status != 'Nisab Not Met',
    );
  }

  static double calculateTotalInvestmentsEgp({
    required List<InvestmentAsset> investments,
    required MarketData marketData,
  }) {
    return investments.fold<double>(0, (double sum, InvestmentAsset asset) {
      return sum + calculateInvestmentEstimatedValueEgp(asset: asset, marketData: marketData);
    });
  }

  static double calculateInvestmentEstimatedValueEgp({
    required InvestmentAsset asset,
    required MarketData marketData,
  }) {
    final double fallbackMarketValue = estimateInflationAdjustedValue(
      originalPrice: asset.originalPrice,
      valuationDate: asset.valuationDate,
      inflationRateAnnual: asset.inflationRateAnnual,
      ownershipType: 'fully_owned',
      paidAmount: asset.originalPrice,
    );

    final double mv = asset.marketValue;
    double effectiveMarketValue =
        mv.isFinite ? math.max(0, mv) : math.max(0, fallbackMarketValue);

    final double share = asset.ownershipSharePct.isFinite
        ? math.min(1, math.max(0, asset.ownershipSharePct / 100))
        : 1;
    effectiveMarketValue *= share;

    return convertToEgp(effectiveMarketValue, asset.currency, marketData);
  }

  static double estimateInflationAdjustedValue({
    required double originalPrice,
    required String valuationDate,
    double inflationRateAnnual = 0,
    String ownershipType = 'fully_owned',
    double? paidAmount,
  }) {
    final double basePrincipal = originalPrice;
    final double paidPrincipal = paidAmount?.isFinite == true ? paidAmount! : basePrincipal;
    final double principal = ownershipType == 'installment'
        ? math.min(math.max(0, paidPrincipal), basePrincipal)
        : basePrincipal;
    final double ratePct = inflationRateAnnual;
    if (principal <= 0) return 0;

    DateTime? fromDate;
    try {
      fromDate = DateTime.parse('${valuationDate}T00:00:00');
    } catch (_) {
      fromDate = null;
    }
    if (fromDate == null) return principal;

    final DateTime now = DateTime.now();
    final double years = math.max(
      0,
      now.difference(fromDate).inMilliseconds / (1000 * 60 * 60 * 24 * 365.25),
    );
    return principal * math.pow(1 + (ratePct / 100), years).toDouble();
  }

  static double calculateWalletBalance({
    required List<Transaction> transactions,
    required List<Saving> savings,
    required MarketData marketData,
  }) {
    return supportedCurrencies.fold<double>(0, (double sum, String currency) {
      final double balance = calculateWalletBalanceByCurrency(
        currency: currency,
        transactions: transactions,
        savings: savings,
      );
      return sum + convertToEgp(balance, currency, marketData);
    });
  }

  static double calculateWalletBalanceByCurrency({
    required String currency,
    required List<Transaction> transactions,
    required List<Saving> savings,
  }) {
    final double txnBalance = transactions
        .where((Transaction tx) => tx.currency == currency)
        .fold<double>(0, (double sum, Transaction tx) {
      if (tx.type == 'income') {
        if (tx.rolledOver && tx.rolledAmount != null) {
          return sum + (tx.amount - tx.rolledAmount!);
        }
        return sum + tx.amount;
      }
      return sum - tx.amount;
    });

    final double savingsContribution = savings
        .where((Saving s) =>
            normaliseAssetType(s.assetType) == 'cash' && s.unit == currency)
        .fold<double>(0, (double sum, Saving s) {
      return sum + math.max(0, s.amount - s.remainingAmount);
    });

    return txnBalance + savingsContribution;
  }

  static double calculateTotalWealthEgp({
    required List<Transaction> transactions,
    required List<Saving> savings,
    required List<InvestmentAsset> investments,
    required MarketData marketData,
  }) {
    final double walletEgp = math.max(
      0,
      calculateWalletBalance(
        transactions: transactions,
        savings: savings,
        marketData: marketData,
      ),
    );

    final NisabTotals totals =
        computeNisabTotals(savings: savings, marketData: marketData);

    final double goldEgp = totals.totalGold24k * marketData.goldPrice24kEgp;
    final double silverEgp = totals.totalSilverGrams * marketData.silverPriceEgp;
    final double investmentsEgp =
        calculateTotalInvestmentsEgp(investments: investments, marketData: marketData);

    return walletEgp + totals.totalCashEgp + goldEgp + silverEgp + investmentsEgp;
  }

  static MarketData getMarketDataAtDate(MarketData marketData) {
    return MarketData(
      goldPrice24kEgp: marketData.goldPrice24kEgp,
      silverPriceEgp: marketData.silverPriceEgp,
      usdToEgp: marketData.usdToEgp,
      sarToEgp: marketData.sarToEgp,
      ratesToEgp: marketData.ratesToEgp,
    );
  }

  static double calculateTotalWealthEgpAt({
    required DateTime asOf,
    required List<Transaction> transactions,
    required List<Saving> savings,
    required List<InvestmentAsset> investments,
    required MarketData marketData,
    MarketData? ratesOverride,
  }) {
    final MarketData ratesAtDate = ratesOverride ?? getMarketDataAtDate(marketData);

    double convertToEgpAt(double amount, String currency) {
      if (currency == 'USD') return amount * ratesAtDate.usdToEgp;
      if (currency == 'SAR') return amount * ratesAtDate.sarToEgp;
      return amount;
    }

    final DateTime asOfDate = _dateOnlyDateTime(asOf);

    final double walletEgp = supportedCurrencies.fold<double>(0, (double sum, String currency) {
      final double txnBalance = transactions.where((Transaction tx) {
        return tx.currency == currency && _dateOnly(tx.date).compareTo(asOfDate) <= 0;
      }).fold<double>(0, (double s, Transaction tx) {
        if (tx.type == 'income') {
          final double rolledAmount = tx.rolledAmount ?? 0;
          final double effectiveIncome = tx.rolledOver ? math.max(0, tx.amount - rolledAmount) : tx.amount;
          return s + effectiveIncome;
        }
        return s - tx.amount;
      });
      return sum + convertToEgpAt(txnBalance, currency);
    });

    final double cashEgp = savings.where((Saving s) {
      return normaliseAssetType(s.assetType) == 'cash' &&
          _dateOnly(s.dateAcquired).compareTo(asOfDate) <= 0;
    }).fold<double>(0, (double s, Saving sv) {
      final double amount = sv.remainingAmount.isFinite ? sv.remainingAmount : sv.amount;
      return s + convertToEgpAt(amount, sv.unit);
    });

    final double gold24k = savings.where((Saving s) {
      return normaliseAssetType(s.assetType) == 'gold' &&
          _dateOnly(s.dateAcquired).compareTo(asOfDate) <= 0;
    }).fold<double>(0, (double s, Saving sv) {
      final double amount = sv.remainingAmount.isFinite ? sv.remainingAmount : sv.amount;
      return s + convertToGold24k(amount, sv.unit);
    });

    final double goldEgp = gold24k * ratesAtDate.goldPrice24kEgp;

    final double silverGrams = savings.where((Saving s) {
      return normaliseAssetType(s.assetType) == 'silver' &&
          _dateOnly(s.dateAcquired).compareTo(asOfDate) <= 0;
    }).fold<double>(0, (double s, Saving sv) {
      final double amount = sv.remainingAmount.isFinite ? sv.remainingAmount : sv.amount;
      return s + convertToSilverGrams(amount);
    });

    final double silverEgp = silverGrams *
        ((ratesAtDate.silverPriceEgp != 0)
            ? ratesAtDate.silverPriceEgp
            : marketData.silverPriceEgp);

    final double investmentsEgp = investments.where((InvestmentAsset asset) {
      if (asset.valuationDate.isEmpty) return false;
      final DateTime? valuationDate = _tryDate(asset.valuationDate);
      return valuationDate != null && valuationDate.compareTo(asOfDate) <= 0;
    }).fold<double>(0, (double sum, InvestmentAsset asset) {
      return sum + asset.estimatedCurrentValue;
    });

    return math.max(0, walletEgp) + cashEgp + goldEgp + silverEgp + investmentsEgp;
  }

  static List<Map<String, dynamic>> getNetIncomeLots({
    required List<Transaction> transactions,
    required MarketData marketData,
  }) {
    final List<Transaction> sorted = List<Transaction>.from(transactions)
      ..sort((Transaction a, Transaction b) {
        final DateTime ad = _dateOnly(a.date);
        final DateTime bd = _dateOnly(b.date);
        final int dateComp = ad.compareTo(bd);
        if (dateComp != 0) return dateComp;

        final DateTime ac = _tryDateTime(a.createdAt) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        final DateTime bc = _tryDateTime(b.createdAt) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        final int createdComp = ac.compareTo(bc);
        if (createdComp != 0) return createdComp;

        if (a.type != b.type) return a.type == 'income' ? -1 : 1;
        return 0;
      });

    final List<Map<String, dynamic>> lots = <Map<String, dynamic>>[];

    for (final Transaction tx in sorted) {
      final double amountEgp = convertToEgp(tx.amount, tx.currency, marketData);
      if (tx.type == 'income') {
        double effectiveAmountEgp;
        if (tx.rolledOver && tx.rolledAmount != null) {
          effectiveAmountEgp =
              convertToEgp(tx.amount - tx.rolledAmount!, tx.currency, marketData);
          if (effectiveAmountEgp < minAmount) continue;
        } else {
          effectiveAmountEgp = amountEgp;
        }
        lots.add(<String, dynamic>{
          'id': tx.id,
          'date': tx.date,
          'originalAmount': effectiveAmountEgp,
          'remainingAmount': effectiveAmountEgp,
          'category': tx.category,
          'description': tx.description,
        });
      } else {
        double toDeduct = amountEgp;

        if (tx.sourceIncomeId != null && tx.sourceIncomeId!.isNotEmpty) {
          final int idx =
              lots.indexWhere((Map<String, dynamic> lot) => lot['id'] == tx.sourceIncomeId);
          if (idx != -1) {
            final Map<String, dynamic> linkedLot = lots[idx];
            final double linkedRemain = _asDouble(linkedLot['remainingAmount']);
            final double linkedDeduction = math.min(linkedRemain, toDeduct);
            linkedLot['remainingAmount'] = _round6(linkedRemain - linkedDeduction);
            toDeduct = _round6(toDeduct - linkedDeduction);
          }
        }

        for (final Map<String, dynamic> lot in lots) {
          if (toDeduct <= 0) break;
          final double lotRemaining = _asDouble(lot['remainingAmount']);
          final double deduction = math.min(lotRemaining, toDeduct);
          lot['remainingAmount'] = lotRemaining - deduction;
          toDeduct -= deduction;
        }
      }
    }

    return lots;
  }

  static List<ZakatScheduleEntry> calculateMonthlyZakatSchedule({
    required List<Transaction> transactions,
    required MarketData marketData,
    DateTime? now,
  }) {
    final List<Map<String, dynamic>> lots =
        getNetIncomeLots(transactions: transactions, marketData: marketData);
    final double nisabValueEgp = defaultConfig.nisabGoldGrams * marketData.goldPrice24kEgp;
    final DateTime today = now ?? DateTime.now();
    final DateTime futureLimit = DateTime(today.year + 3, today.month, today.day);

    final Map<String, _ScheduleAccumulator> byMonth = <String, _ScheduleAccumulator>{};

    for (final Map<String, dynamic> lot in lots) {
      final double remainingAmount = _asDouble(lot['remainingAmount']);
      if (remainingAmount < 0.01) continue;
      if (remainingAmount < nisabValueEgp) continue;

      final DateTime lotDate = _dateOnly(lot['date'].toString());

      for (int year = 1; year <= 30; year++) {
        final int daysRequired = year * defaultConfig.nisabDays;
        final DateTime dueDateRaw = lotDate.add(Duration(days: daysRequired));
        if (dueDateRaw.isAfter(futureLimit)) break;

        final DateTime paymentDate = DateTime(dueDateRaw.year, dueDateRaw.month, 1);
        final String monthKey = _monthKey(paymentDate);

        byMonth.putIfAbsent(
          monthKey,
          () => _ScheduleAccumulator(
            monthKey: monthKey,
            paymentDate: _yyyyMmDd(paymentDate),
            totalZakat: 0,
            isPast: paymentDate.isBefore(today),
            isCurrentMonth: paymentDate.year == today.year && paymentDate.month == today.month,
            entries: <Map<String, dynamic>>[],
          ),
        );

        final double zakatAmount = remainingAmount * defaultConfig.zakatRate;
        final _ScheduleAccumulator acc = byMonth[monthKey]!;
        acc.totalZakat += zakatAmount;
        acc.entries.add(<String, dynamic>{
          'type': 'income',
          'lotDate': lot['date'],
          'lotAmount': remainingAmount,
          'year': year,
          'zakatAmount': zakatAmount,
          'dueDateRaw': _yyyyMmDd(dueDateRaw),
        });
      }
    }

    final List<ZakatScheduleEntry> result = byMonth.values
        .map((acc) => acc.toScheduleEntry())
        .toList()
      ..sort((ZakatScheduleEntry a, ZakatScheduleEntry b) =>
          a.monthKey.compareTo(b.monthKey));

    return result;
  }

  static List<ZakatScheduleEntry> calculateSavingsZakatSchedule({
    required List<Saving> savings,
    required MarketData marketData,
    DateTime? now,
  }) {
    final NisabTotals nisabTotals =
        computeNisabTotals(savings: savings, marketData: marketData);
    final bool portfolioMeetsNisab =
        checkCashNisab(nisabTotals.totalSavingsWealthEgp, marketData);
    if (!portfolioMeetsNisab) return const <ZakatScheduleEntry>[];

    final DateTime today = now ?? DateTime.now();
    final DateTime futureLimit = DateTime(today.year + 3, today.month, today.day);

    final Map<String, _ScheduleAccumulator> byMonth = <String, _ScheduleAccumulator>{};

    for (final Saving saving in savings) {
      final String assetType = normaliseAssetType(saving.assetType);

      double zakatValueEgp = 0;
      if (assetType == 'cash') {
        zakatValueEgp =
            convertToEgp(saving.remainingAmount, saving.unit, marketData) * defaultConfig.zakatRate;
      } else if (assetType == 'gold') {
        zakatValueEgp = convertToGold24k(saving.remainingAmount, saving.unit) *
            defaultConfig.zakatRate *
            marketData.goldPrice24kEgp;
      } else if (assetType == 'silver') {
        zakatValueEgp = convertToSilverGrams(saving.remainingAmount) *
            defaultConfig.zakatRate *
            marketData.silverPriceEgp;
      }
      if (zakatValueEgp < 0.01) continue;

      final DateTime savingDate = _dateOnly(saving.dateAcquired);

      for (int year = 1; year <= 30; year++) {
        final int daysRequired = year * defaultConfig.nisabDays;
        final DateTime dueDateRaw = savingDate.add(Duration(days: daysRequired));
        if (dueDateRaw.isAfter(futureLimit)) break;

        final DateTime paymentDate = DateTime(dueDateRaw.year, dueDateRaw.month, 1);
        final String monthKey = _monthKey(paymentDate);

        byMonth.putIfAbsent(
          monthKey,
          () => _ScheduleAccumulator(
            monthKey: monthKey,
            paymentDate: _yyyyMmDd(paymentDate),
            totalZakat: 0,
            isPast: paymentDate.isBefore(today),
            isCurrentMonth: paymentDate.year == today.year && paymentDate.month == today.month,
            entries: <Map<String, dynamic>>[],
          ),
        );

        final _ScheduleAccumulator acc = byMonth[monthKey]!;
        acc.totalZakat += zakatValueEgp;
        acc.entries.add(<String, dynamic>{
          'type': 'savings',
          'savingDate': saving.dateAcquired,
          'assetType': assetType,
          'amount': saving.remainingAmount,
          'unit': saving.unit,
          'description': saving.description,
          'year': year,
          'zakatAmount': zakatValueEgp,
          'dueDateRaw': _yyyyMmDd(dueDateRaw),
        });
      }
    }

    final List<ZakatScheduleEntry> result = byMonth.values
        .map((acc) => acc.toScheduleEntry())
        .toList()
      ..sort((ZakatScheduleEntry a, ZakatScheduleEntry b) =>
          a.monthKey.compareTo(b.monthKey));

    return result;
  }

  static List<ZakatScheduleEntry> calculateAnnualZakatSchedule({
    required String zakatAnnualDate,
    required List<Transaction> transactions,
    required List<Saving> savings,
    required List<InvestmentAsset> investments,
    required MarketData marketData,
    DateTime? now,
  }) {
    if (zakatAnnualDate.isEmpty || !zakatAnnualDate.contains('-')) {
      return const <ZakatScheduleEntry>[];
    }

    final List<String> parts = zakatAnnualDate.split('-');
    final int? hm = int.tryParse(parts[0]);
    final int? hd = int.tryParse(parts[1]);

    if (hm == null || hd == null || hm < 1 || hm > 12 || hd < 1 || hd > hijriMonthLength(hm)) {
      return const <ZakatScheduleEntry>[];
    }

    final DateTime today = now ?? DateTime.now();
    final HijriDate todayH = gregorianToHijri(today);
    final double nisabValueEgp = defaultConfig.nisabGoldGrams * marketData.goldPrice24kEgp;

    final Map<String, ZakatScheduleEntry> byMonth = <String, ZakatScheduleEntry>{};

    for (int offset = -3; offset <= 2; offset++) {
      final int hy = todayH.year + offset;
      if (hy < 1) continue;

      final DateTime dueGreg = hijriToGregorian(hy, hm, hd);
      final DateTime payDate = DateTime(dueGreg.year, dueGreg.month, 1);
      final String monthKey = _monthKey(dueGreg);

      final double totalWealthEgpAtDate = calculateTotalWealthEgpAt(
        asOf: payDate,
        transactions: transactions,
        savings: savings,
        investments: investments,
        marketData: marketData,
      );

      if (totalWealthEgpAtDate < nisabValueEgp) continue;

      final double zakatAmount = totalWealthEgpAtDate * defaultConfig.zakatRate;

      byMonth[monthKey] = ZakatScheduleEntry(
        monthKey: monthKey,
        paymentDate: _yyyyMmDd(payDate),
        totalZakat: zakatAmount,
        totalWealth: totalWealthEgpAtDate,
        hijriYear: hy,
        hijriMonth: hm,
        hijriDay: hd,
        isPast: payDate.isBefore(today) &&
            !(payDate.year == today.year && payDate.month == today.month),
        isCurrentMonth: payDate.year == today.year && payDate.month == today.month,
        entries: <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'annual',
            'totalWealth': totalWealthEgpAtDate,
            'zakatAmount': zakatAmount,
            'dueDateRaw': _yyyyMmDd(dueGreg),
            'hijriYear': hy,
            'hijriMonth': hm,
            'hijriDay': hd,
          }
        ],
      );
    }

    final List<ZakatScheduleEntry> result = byMonth.values.toList()
      ..sort((ZakatScheduleEntry a, ZakatScheduleEntry b) =>
          a.monthKey.compareTo(b.monthKey));

    return result;
  }

  static double getCurrentMonthZakatDue({
    required List<Transaction> transactions,
    required List<String> zakatPaidMonths,
    required MarketData marketData,
    DateTime? now,
  }) {
    final DateTime today = now ?? DateTime.now();
    final String currentMonthKey = _monthKey(today);
    final List<ZakatScheduleEntry> schedule = calculateMonthlyZakatSchedule(
      transactions: transactions,
      marketData: marketData,
      now: today,
    );

    return schedule
        .where((ZakatScheduleEntry m) =>
            m.monthKey.compareTo(currentMonthKey) <= 0 &&
            !zakatPaidMonths.contains(m.monthKey))
        .fold<double>(0, (double sum, ZakatScheduleEntry m) => sum + m.totalZakat);
  }

  static HijriDate gregorianToHijri(DateTime date) {
    final int gy = date.year;
    final int gm = date.month;
    final int gd = date.day;

    final int a = ((14 - gm) / 12).floor();
    final int y = gy + 4800 - a;
    final int m = gm + 12 * a - 3;
    final int jd = gd +
        ((153 * m + 2) / 5).floor() +
        365 * y +
        (y / 4).floor() -
        (y / 100).floor() +
        (y / 400).floor() -
        32045;

    final int l = jd - 1948440 + 10632;
    final int n = ((l - 1) / 10631).floor();
    final int l2 = l - 10631 * n + 354;
    final int j = (((10985 - l2) / 5316).floor() * ((50 * l2) / 17719).floor()) +
        ((l2 / 5670).floor() * ((43 * l2) / 15238).floor());
    final int l3 = l2 -
        (((30 - j) / 15).floor() * ((17719 * j) / 50).floor()) -
        ((j / 16).floor() * ((15238 * j) / 43).floor()) +
        29;
    final int month = ((24 * l3) / 709).floor();
    final int day = l3 - ((709 * month) / 24).floor();
    final int year = 30 * n + j - 30;

    return HijriDate(year: year, month: month, day: day);
  }

  static DateTime hijriToGregorian(int hy, int hm, int hd) {
    final int jd = ((11 * hy + 3) / 30).floor() +
        354 * hy +
        30 * hm -
        ((hm - 1) / 2).floor() +
        hd +
        1948440 -
        385;

    final int l = jd + 68569;
    final int n = ((4 * l) / 146097).floor();
    final int l2 = l - ((146097 * n + 3) / 4).floor();
    final int i = ((4000 * (l2 + 1)) / 1461001).floor();
    final int l3 = l2 - ((1461 * i) / 4).floor() + 31;
    final int j = ((80 * l3) / 2447).floor();
    final int gd = l3 - ((2447 * j) / 80).floor();
    final int l4 = (j / 11).floor();
    final int gm = j + 2 - 12 * l4;
    final int gy = 100 * (n - 49) + i + l4;

    return DateTime(gy, gm, gd);
  }

  static int hijriMonthLength(int month) {
    return (month % 2 == 1 || month == 12) ? 30 : 29;
  }

  static DateTime _dateOnly(String date) {
    return DateTime.parse('${date.split('T').first}T00:00:00');
  }

  static DateTime _dateOnlyDateTime(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  static DateTime? _tryDate(String date) {
    try {
      return _dateOnly(date);
    } catch (_) {
      return null;
    }
  }

  static DateTime? _tryDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return null;
    }
  }

  static String _monthKey(DateTime date) {
    final String m = date.month.toString().padLeft(2, '0');
    return '${date.year}-$m';
  }

  static String _yyyyMmDd(DateTime date) {
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _round6(double v) => (v * 1000000).roundToDouble() / 1000000;
}

class _ScheduleAccumulator {
  _ScheduleAccumulator({
    required this.monthKey,
    required this.paymentDate,
    required this.totalZakat,
    required this.isPast,
    required this.isCurrentMonth,
    required this.entries,
  });

  final String monthKey;
  final String paymentDate;
  double totalZakat;
  final bool isPast;
  final bool isCurrentMonth;
  final List<Map<String, dynamic>> entries;

  ZakatScheduleEntry toScheduleEntry() {
    return ZakatScheduleEntry(
      monthKey: monthKey,
      paymentDate: paymentDate,
      totalZakat: totalZakat,
      isPast: isPast,
      isCurrentMonth: isCurrentMonth,
      entries: entries,
    );
  }
}
