import 'zakat_engine.dart';
import '../../models/investment_asset.dart';
import '../../models/saving.dart';
import '../../models/transaction.dart';

class ZakatScheduleService {
  ZakatScheduleService._();

  static List<Map<String, dynamic>> calculateMonthlyZakatSchedule({
    required List<Map<String, dynamic>> transactions,
    required MarketData marketData,
    DateTime? now,
  }) {
    final DateTime today = now ?? DateTime.now();
    final DateTime futureLimit =
        DateTime(today.year + 3, today.month, today.day);
    final double nisabValueEgp =
        ZakatEngineService.defaultConfig.nisabGoldGrams *
            marketData.goldPrice24kEgp;

    final List<Map<String, dynamic>> lots =
        ZakatEngineService.getNetIncomeLots(
      transactions: transactions
          .map((Map<String, dynamic> tx) => _transactionFromJson(tx))
          .toList(growable: false),
      marketData: marketData,
    );

    final Map<String, Map<String, dynamic>> byMonth =
        <String, Map<String, dynamic>>{};

    for (final Map<String, dynamic> lot in lots) {
      final double remainingAmount = _asDouble(lot['remainingAmount']);
      if (remainingAmount < 0.01) continue;
      if (remainingAmount < nisabValueEgp) continue;

      final DateTime lotDate = _dateOnly((lot['date'] ?? '').toString());

      for (int year = 1; year <= 30; year++) {
        final int daysRequired = year * ZakatEngineService.defaultConfig.nisabDays;
        final DateTime dueDateRaw = lotDate.add(Duration(days: daysRequired));
        if (dueDateRaw.isAfter(futureLimit)) break;

        final DateTime paymentDate =
            DateTime(dueDateRaw.year, dueDateRaw.month, 1);
        final String monthKey = _monthKey(paymentDate);

        byMonth.putIfAbsent(monthKey, () {
          return <String, dynamic>{
            'monthKey': monthKey,
            'paymentDate': _yyyyMmDd(paymentDate),
            'totalZakat': 0.0,
            'isPast': paymentDate.isBefore(today),
            'isCurrentMonth':
                paymentDate.year == today.year && paymentDate.month == today.month,
            'entries': <Map<String, dynamic>>[],
          };
        });

        final double zakatAmount =
            remainingAmount * ZakatEngineService.defaultConfig.zakatRate;

        byMonth[monthKey]!['totalZakat'] =
            _asDouble(byMonth[monthKey]!['totalZakat']) + zakatAmount;
        (byMonth[monthKey]!['entries'] as List<Map<String, dynamic>>).add(
          <String, dynamic>{
            'type': 'income',
            'lotDate': lot['date'],
            'lotAmount': remainingAmount,
            'year': year,
            'zakatAmount': zakatAmount,
            'dueDateRaw': _yyyyMmDd(dueDateRaw),
          },
        );
      }
    }

    final List<Map<String, dynamic>> result = byMonth.values.toList()
      ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        return (a['monthKey'] ?? '')
            .toString()
            .compareTo((b['monthKey'] ?? '').toString());
      });

    return result;
  }

  static List<Map<String, dynamic>> calculateSavingsZakatSchedule({
    required List<Map<String, dynamic>> savings,
    required MarketData marketData,
    DateTime? now,
  }) {
    final List<SavingLike> parsedSavings = savings
        .map((Map<String, dynamic> s) => SavingLike.fromJson(s))
        .toList(growable: false);

    final NisabTotals totals = ZakatEngineService.computeNisabTotals(
      savings: parsedSavings
          .map((SavingLike s) => s.toSavingModel())
          .toList(growable: false),
      marketData: marketData,
    );
    final bool portfolioMeetsNisab =
        ZakatEngineService.checkCashNisab(totals.totalSavingsWealthEgp, marketData);
    if (!portfolioMeetsNisab) return <Map<String, dynamic>>[];

    final DateTime today = now ?? DateTime.now();
    final DateTime futureLimit =
        DateTime(today.year + 3, today.month, today.day);

    final Map<String, Map<String, dynamic>> byMonth =
        <String, Map<String, dynamic>>{};

    for (final SavingLike saving in parsedSavings) {
      final String assetType =
          ZakatEngineService.normaliseAssetType(saving.assetType);

      double zakatValueEgp = 0;
      if (assetType == 'cash') {
        zakatValueEgp = ZakatEngineService.convertToEgp(
              saving.remainingAmount,
              saving.unit,
              marketData,
            ) *
            ZakatEngineService.defaultConfig.zakatRate;
      } else if (assetType == 'gold') {
        zakatValueEgp = ZakatEngineService.convertToGold24k(
                  saving.remainingAmount,
                  saving.unit,
                ) *
                ZakatEngineService.defaultConfig.zakatRate *
                marketData.goldPrice24kEgp;
      } else if (assetType == 'silver') {
        zakatValueEgp = ZakatEngineService.convertToSilverGrams(
                  saving.remainingAmount,
                ) *
                ZakatEngineService.defaultConfig.zakatRate *
                marketData.silverPriceEgp;
      }
      if (zakatValueEgp < 0.01) continue;

      final DateTime savingDate = _dateOnly(saving.dateAcquired);

      for (int year = 1; year <= 30; year++) {
        final int daysRequired = year * ZakatEngineService.defaultConfig.nisabDays;
        final DateTime dueDateRaw = savingDate.add(Duration(days: daysRequired));
        if (dueDateRaw.isAfter(futureLimit)) break;

        final DateTime paymentDate =
            DateTime(dueDateRaw.year, dueDateRaw.month, 1);
        final String monthKey = _monthKey(paymentDate);

        byMonth.putIfAbsent(monthKey, () {
          return <String, dynamic>{
            'monthKey': monthKey,
            'paymentDate': _yyyyMmDd(paymentDate),
            'totalZakat': 0.0,
            'isPast': paymentDate.isBefore(today),
            'isCurrentMonth':
                paymentDate.year == today.year && paymentDate.month == today.month,
            'entries': <Map<String, dynamic>>[],
          };
        });

        byMonth[monthKey]!['totalZakat'] =
            _asDouble(byMonth[monthKey]!['totalZakat']) + zakatValueEgp;
        (byMonth[monthKey]!['entries'] as List<Map<String, dynamic>>).add(
          <String, dynamic>{
            'type': 'savings',
            'savingDate': saving.dateAcquired,
            'assetType': assetType,
            'amount': saving.remainingAmount,
            'unit': saving.unit,
            'description': saving.description,
            'year': year,
            'zakatAmount': zakatValueEgp,
            'dueDateRaw': _yyyyMmDd(dueDateRaw),
          },
        );
      }
    }

    final List<Map<String, dynamic>> result = byMonth.values.toList()
      ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        return (a['monthKey'] ?? '')
            .toString()
            .compareTo((b['monthKey'] ?? '').toString());
      });

    return result;
  }

  static List<Map<String, dynamic>> calculateAnnualZakatSchedule({
    required String zakatAnnualDate,
    required List<Map<String, dynamic>> transactions,
    required List<Map<String, dynamic>> savings,
    required List<Map<String, dynamic>> investments,
    required MarketData marketData,
    DateTime? now,
  }) {
    if (zakatAnnualDate.isEmpty || !zakatAnnualDate.contains('-')) {
      return <Map<String, dynamic>>[];
    }

    final List<String> parts = zakatAnnualDate.split('-');
    final int? hm = int.tryParse(parts[0]);
    final int? hd = int.tryParse(parts[1]);
    if (hm == null ||
        hd == null ||
        hm < 1 ||
        hm > 12 ||
        hd < 1 ||
        hd > ZakatEngineService.hijriMonthLength(hm)) {
      return <Map<String, dynamic>>[];
    }

    final DateTime today = now ?? DateTime.now();
    final HijriDate todayH = ZakatEngineService.gregorianToHijri(today);
    final double nisabValueEgp =
        ZakatEngineService.defaultConfig.nisabGoldGrams *
            marketData.goldPrice24kEgp;

    final List<Transaction> txModels = transactions
        .map((Map<String, dynamic> tx) => _transactionFromJson(tx))
        .toList(growable: false);
    final List<SavingLike> savingModels = savings
        .map((Map<String, dynamic> s) => SavingLike.fromJson(s))
        .toList(growable: false);
    final List<InvestmentAsset> invModels = investments
        .map((Map<String, dynamic> inv) => _investmentFromJson(inv))
        .toList(growable: false);

    final Map<String, Map<String, dynamic>> byMonth =
        <String, Map<String, dynamic>>{};

    for (int offset = -3; offset <= 2; offset++) {
      final int hy = todayH.year + offset;
      if (hy < 1) continue;

      final DateTime dueGreg = ZakatEngineService.hijriToGregorian(hy, hm, hd);
      final DateTime payDate = DateTime(dueGreg.year, dueGreg.month, 1);
      final String monthKey = _monthKey(dueGreg);

      final double totalWealthEgpAtDate =
          ZakatEngineService.calculateTotalWealthEgpAt(
        asOf: payDate,
        transactions: txModels,
        savings: savingModels
            .map((SavingLike s) => s.toSavingModel())
            .toList(growable: false),
        investments: invModels,
        marketData: marketData,
      );

      if (totalWealthEgpAtDate < nisabValueEgp) continue;

      final double zakatAmount =
          totalWealthEgpAtDate * ZakatEngineService.defaultConfig.zakatRate;

      byMonth[monthKey] = <String, dynamic>{
        'monthKey': monthKey,
        'paymentDate': _yyyyMmDd(payDate),
        'totalZakat': zakatAmount,
        'totalWealth': totalWealthEgpAtDate,
        'hijriYear': hy,
        'hijriMonth': hm,
        'hijriDay': hd,
        'isPast': payDate.isBefore(today) &&
            !(payDate.year == today.year && payDate.month == today.month),
        'isCurrentMonth': payDate.year == today.year && payDate.month == today.month,
        'entries': <Map<String, dynamic>>[
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
      };
    }

    final List<Map<String, dynamic>> result = byMonth.values.toList()
      ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        return (a['monthKey'] ?? '')
            .toString()
            .compareTo((b['monthKey'] ?? '').toString());
      });

    return result;
  }

  static Transaction _transactionFromJson(Map<String, dynamic> json) {
    return Transaction(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      amount: _asDouble(json['amount']),
      currency: (json['currency'] ?? 'EGP').toString(),
      category: (json['category'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      rolledOver: _asBool(json['rolledOver']),
      rolledAmount: json['rolledAmount'] == null
          ? null
          : _asDouble(json['rolledAmount']),
      sourceIncomeId: json['sourceIncomeId']?.toString(),
      exchangePairId: json['exchangePairId']?.toString(),
      exchangeSourceIncomeId: json['exchangeSourceIncomeId']?.toString(),
      remainingAmount: json['remainingAmount'] == null
          ? null
          : _asDouble(json['remainingAmount']),
    );
  }

  static InvestmentAsset _investmentFromJson(Map<String, dynamic> json) {
    return InvestmentAsset.fromJson(json);
  }

  static DateTime _dateOnly(String date) {
    return DateTime.parse('${date.split('T').first}T00:00:00');
  }

  static String _monthKey(DateTime date) {
    final String mm = date.month.toString().padLeft(2, '0');
    return '${date.year}-$mm';
  }

  static String _yyyyMmDd(DateTime date) {
    final String mm = date.month.toString().padLeft(2, '0');
    final String dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final String raw = (value ?? '').toString().toLowerCase();
    return raw == 'true' || raw == '1';
  }
}

class SavingLike {
  const SavingLike({
    required this.assetType,
    required this.dateAcquired,
    required this.amount,
    required this.remainingAmount,
    required this.unit,
    required this.description,
  });

  final String assetType;
  final String dateAcquired;
  final double amount;
  final double remainingAmount;
  final String unit;
  final String description;

  factory SavingLike.fromJson(Map<String, dynamic> json) {
    final double amount = _toDouble(json['amount']);
    final double remainingAmount =
        json['remainingAmount'] == null ? amount : _toDouble(json['remainingAmount']);

    return SavingLike(
      assetType: (json['assetType'] ?? '').toString(),
      dateAcquired: (json['dateAcquired'] ?? '').toString(),
      amount: amount,
      remainingAmount: remainingAmount,
      unit: (json['unit'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
    );
  }

  Saving toSavingModel() {
    return Saving(
      id: '',
      assetType: assetType,
      dateAcquired: dateAcquired,
      amount: amount,
      remainingAmount: remainingAmount,
      unit: unit,
      description: description,
      linkedCashEntryId: null,
      purchaseCurrency: '',
      purchaseAmount: 0,
      createdAt: '',
      sourceIncomeId: null,
      exchangeSourceSavingId: null,
      exchangeSourceIncomeId: null,
      internalTransfer: null,
      internalTransferType: null,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
