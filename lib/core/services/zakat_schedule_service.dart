import 'zakat_engine.dart';
import '../../models/investment_asset.dart';
import '../../models/saving.dart';
import '../../models/transaction.dart';

class ZakatScheduleService {
  ZakatScheduleService._();

  static List<Map<String, dynamic>> calculateMonthlyZakatSchedule({
    required List<Map<String, dynamic>> transactions,
    List<Map<String, dynamic>> savings = const <Map<String, dynamic>>[],
    required MarketData marketData,
    DateTime? now,
    String? lastRollover,
    String? zakatNisabBasis,
  }) {
    final DateTime today = now ?? DateTime.now();
    final DateTime futureLimit = DateTime(
      today.year + 3,
      today.month,
      today.day,
    );
    final List<Transaction> parsedTransactions = transactions
        .map((Map<String, dynamic> tx) => _transactionFromJson(tx))
        .toList(growable: false);
    final List<Map<String, dynamic>> lots = ZakatEngineService.getNetIncomeLots(
      transactions: parsedTransactions,
      marketData: marketData,
      lastRollover: lastRollover,
    );
    final List<SavingLike> parsedSavings = savings
        .map((Map<String, dynamic> s) => SavingLike.fromJson(s))
        .toList(growable: false);
    if (!_combinedPortfolioMeetsNisab(
      lots: lots,
      savings: parsedSavings,
      marketData: marketData,
      zakatNisabBasis: zakatNisabBasis,
    )) {
      return <Map<String, dynamic>>[];
    }

    final List<Saving> savingModels = parsedSavings
        .map((SavingLike s) => s.toSavingModel())
        .toList(growable: false);

    final Set<String> eventDateStrings = <String>{};
    for (final Map<String, dynamic> lot in lots) {
      final String d = (lot['date'] ?? '').toString();
      if (d.isNotEmpty) eventDateStrings.add(d);
    }
    for (final SavingLike s in parsedSavings) {
      if (s.dateAcquired.isNotEmpty) eventDateStrings.add(s.dateAcquired);
      for (final SavingZakatSegment seg in s.zakatSegments()) {
        if (seg.date.isNotEmpty) eventDateStrings.add(seg.date);
      }
    }
    final List<DateTime> eventDates = eventDateStrings
        .map((String s) {
          try {
            return DateTime.parse(s);
          } catch (_) {
            return DateTime(1970);
          }
        })
        .where((d) => d.year > 1970)
        .toList()
      ..sort();

    final Map<String, Map<String, dynamic>> byMonth =
        <String, Map<String, dynamic>>{};

    for (final Map<String, dynamic> lot in lots) {
      final double remainingAmount = _asDouble(lot['remainingAmount']);
      if (remainingAmount < 0.01) continue;

      final DateTime lotDateRaw = _dateOnly((lot['date'] ?? '').toString());
      final DateTime lotDate = ZakatEngineService.getEffectiveZakatStartDate(
        startDate: lotDateRaw,
        lots: lots,
        savings: savingModels,
        marketData: marketData,
        zakatNisabBasis: zakatNisabBasis,
        eventDates: eventDates,
      );

      for (int year = 1; year <= 30; year++) {
        final int daysRequired =
            year * ZakatEngineService.defaultConfig.nisabDays;
        final DateTime dueDateRaw = lotDate.add(Duration(days: daysRequired));
        if (dueDateRaw.isAfter(futureLimit)) break;

        final DateTime paymentDate = DateTime(
          dueDateRaw.year,
          dueDateRaw.month,
          1,
        );
        final String monthKey = _monthKey(paymentDate);

        byMonth.putIfAbsent(monthKey, () {
          return <String, dynamic>{
            'monthKey': monthKey,
            'paymentDate': _yyyyMmDd(paymentDate),
            'totalZakat': 0.0,
            'isPast': paymentDate.isBefore(today),
            'isCurrentMonth':
                paymentDate.year == today.year &&
                paymentDate.month == today.month,
            'entries': <Map<String, dynamic>>[],
          };
        });

        final double zakatAmount =
            remainingAmount * ZakatEngineService.defaultConfig.zakatRate;

        byMonth[monthKey]!['totalZakat'] =
            _asDouble(byMonth[monthKey]!['totalZakat']) + zakatAmount;
        (byMonth[monthKey]!['entries'] as List<Map<String, dynamic>>)
            .add(<String, dynamic>{
              'type': 'income',
              'lotDate': lot['date'],
              'lotAmount': remainingAmount,
              'year': year,
              'zakatAmount': zakatAmount,
              'dueDateRaw': _yyyyMmDd(dueDateRaw),
            });
      }
    }

    final List<Map<String, dynamic>> result = byMonth.values.toList()
      ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        return (a['monthKey'] ?? '').toString().compareTo(
          (b['monthKey'] ?? '').toString(),
        );
      });

    return result;
  }

  static List<Map<String, dynamic>> calculateSavingsZakatSchedule({
    required List<Map<String, dynamic>> savings,
    List<Map<String, dynamic>> transactions = const <Map<String, dynamic>>[],
    required MarketData marketData,
    DateTime? now,
    String? lastRollover,
    String? zakatNisabBasis,
  }) {
    final List<SavingLike> parsedSavings = savings
        .map((Map<String, dynamic> s) => SavingLike.fromJson(s))
        .toList(growable: false);

    final List<Transaction> parsedTransactions = transactions
        .map((Map<String, dynamic> tx) => _transactionFromJson(tx))
        .toList(growable: false);
    final List<Map<String, dynamic>> lots = ZakatEngineService.getNetIncomeLots(
      transactions: parsedTransactions,
      marketData: marketData,
      lastRollover: lastRollover,
    );
    if (!_combinedPortfolioMeetsNisab(
      lots: lots,
      savings: parsedSavings,
      marketData: marketData,
      zakatNisabBasis: zakatNisabBasis,
    )) {
      return <Map<String, dynamic>>[];
    }

    final List<Saving> savingModels = parsedSavings
        .map((SavingLike s) => s.toSavingModel())
        .toList(growable: false);

    final Set<String> eventDateStrings = <String>{};
    for (final Map<String, dynamic> lot in lots) {
      final String d = (lot['date'] ?? '').toString();
      if (d.isNotEmpty) eventDateStrings.add(d);
    }
    for (final SavingLike s in parsedSavings) {
      if (s.dateAcquired.isNotEmpty) eventDateStrings.add(s.dateAcquired);
      for (final SavingZakatSegment seg in s.zakatSegments()) {
        if (seg.date.isNotEmpty) eventDateStrings.add(seg.date);
      }
    }
    final List<DateTime> eventDates = eventDateStrings
        .map((String s) {
          try {
            return DateTime.parse(s);
          } catch (_) {
            return DateTime(1970);
          }
        })
        .where((d) => d.year > 1970)
        .toList()
      ..sort();

    final DateTime today = now ?? DateTime.now();
    final DateTime futureLimit = DateTime(
      today.year + 3,
      today.month,
      today.day,
    );

    final Map<String, Map<String, dynamic>> byMonth =
        <String, Map<String, dynamic>>{};

    for (final SavingLike saving in parsedSavings) {
      final String assetType = ZakatEngineService.normaliseAssetType(
        saving.assetType,
      );

      for (final SavingZakatSegment segment in saving.zakatSegments()) {
        double zakatValueEgp = 0;
        if (assetType == 'cash') {
          zakatValueEgp =
              ZakatEngineService.convertToEgp(
                segment.amount,
                saving.unit,
                marketData,
              ) *
              ZakatEngineService.defaultConfig.zakatRate;
        } else if (assetType == 'gold') {
          zakatValueEgp =
              ZakatEngineService.convertToGold24k(segment.amount, saving.unit) *
              ZakatEngineService.defaultConfig.zakatRate *
              marketData.goldPrice24kEgp;
        } else if (assetType == 'silver') {
          zakatValueEgp =
              ZakatEngineService.convertToSilverGrams(segment.amount) *
              ZakatEngineService.defaultConfig.zakatRate *
              marketData.silverPriceEgp;
        }
        if (zakatValueEgp < 0.01) continue;

        final DateTime savingDateRaw = _dateOnly(segment.date);
        final DateTime savingDate = ZakatEngineService.getEffectiveZakatStartDate(
          startDate: savingDateRaw,
          lots: lots,
          savings: savingModels,
          marketData: marketData,
          zakatNisabBasis: zakatNisabBasis,
          eventDates: eventDates,
        );

        for (int year = 1; year <= 30; year++) {
          final int daysRequired =
              year * ZakatEngineService.defaultConfig.nisabDays;
          final DateTime dueDateRaw = savingDate.add(
            Duration(days: daysRequired),
          );
          if (dueDateRaw.isAfter(futureLimit)) break;

          final DateTime paymentDate = DateTime(
            dueDateRaw.year,
            dueDateRaw.month,
            1,
          );
          final String monthKey = _monthKey(paymentDate);

          byMonth.putIfAbsent(monthKey, () {
            return <String, dynamic>{
              'monthKey': monthKey,
              'paymentDate': _yyyyMmDd(paymentDate),
              'totalZakat': 0.0,
              'isPast': paymentDate.isBefore(today),
              'isCurrentMonth':
                  paymentDate.year == today.year &&
                  paymentDate.month == today.month,
              'entries': <Map<String, dynamic>>[],
            };
          });

          byMonth[monthKey]!['totalZakat'] =
              _asDouble(byMonth[monthKey]!['totalZakat']) + zakatValueEgp;
          (byMonth[monthKey]!['entries'] as List<Map<String, dynamic>>)
              .add(<String, dynamic>{
                'type': 'savings',
                'savingDate': segment.date,
                'assetType': assetType,
                'amount': segment.amount,
                'unit': saving.unit,
                'description': saving.description,
                'fundingSourceId': segment.sourceId,
                'year': year,
                'zakatAmount': zakatValueEgp,
                'dueDateRaw': _yyyyMmDd(dueDateRaw),
              });
        }
      }
    }

    final List<Map<String, dynamic>> result = byMonth.values.toList()
      ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        return (a['monthKey'] ?? '').toString().compareTo(
          (b['monthKey'] ?? '').toString(),
        );
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
    String? lastRollover,
    String? zakatNisabBasis,
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
    final double nisabValueEgp = ZakatEngineService.cashNisabThresholdEgp(
      marketData,
      zakatNisabBasis: zakatNisabBasis,
    );

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
      final DateTime dueDate = DateTime(
        dueGreg.year,
        dueGreg.month,
        dueGreg.day,
      );
      final DateTime todayDate = DateTime(today.year, today.month, today.day);
      final String dateKey = _yyyyMmDd(dueDate);
      final String hijriDate = _hijriDateKey(hy, hm, hd);

      final double totalWealthEgpAtDate =
          ZakatEngineService.calculateTotalWealthEgpAt(
            asOf: dueDate,
            transactions: txModels,
            savings: savingModels
                .map((SavingLike s) => s.toSavingModel())
                .toList(growable: false),
            investments: invModels,
            marketData: marketData,
            lastRollover: lastRollover,
          );

      if (totalWealthEgpAtDate < nisabValueEgp) continue;

      final double zakatAmount =
          totalWealthEgpAtDate * ZakatEngineService.defaultConfig.zakatRate;

      byMonth[dateKey] = <String, dynamic>{
        'monthKey': dateKey,
        'paymentDate': dateKey,
        'totalZakat': zakatAmount,
        'totalWealth': totalWealthEgpAtDate,
        'hijriYear': hy,
        'hijriMonth': hm,
        'hijriDay': hd,
        'hijriDate': hijriDate,
        'isPast': dueDate.isBefore(todayDate),
        'isCurrentMonth': dueDate.isAtSameMomentAs(todayDate),
        'entries': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'annual',
            'totalWealth': totalWealthEgpAtDate,
            'zakatAmount': zakatAmount,
            'dueDateRaw': dateKey,
            'hijriYear': hy,
            'hijriMonth': hm,
            'hijriDay': hd,
            'hijriDate': hijriDate,
          },
        ],
      };
    }

    final List<Map<String, dynamic>> result = byMonth.values.toList()
      ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        return (a['monthKey'] ?? '').toString().compareTo(
          (b['monthKey'] ?? '').toString(),
        );
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

  static String _hijriDateKey(int year, int month, int day) {
    final String mm = month.toString().padLeft(2, '0');
    final String dd = day.toString().padLeft(2, '0');
    return '$year-$mm-$dd';
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

  static bool _combinedPortfolioMeetsNisab({
    required List<Map<String, dynamic>> lots,
    required List<SavingLike> savings,
    required MarketData marketData,
    String? zakatNisabBasis,
  }) {
    final NisabTotals totals = ZakatEngineService.computeNisabTotals(
      savings: savings
          .map((SavingLike s) => s.toSavingModel())
          .toList(growable: false),
      marketData: marketData,
    );
    final double incomeCashEgp = lots.fold<double>(
      0,
      (double sum, Map<String, dynamic> lot) =>
          sum + _asDouble(lot['remainingAmount']),
    );
    return ZakatEngineService.checkCashNisab(
      totals.totalSavingsWealthEgp + incomeCashEgp,
      marketData,
      zakatNisabBasis: zakatNisabBasis,
    );
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
    required this.purchaseAmount,
    this.fundingAllocations = const <Map<String, dynamic>>[],
  });

  final String assetType;
  final String dateAcquired;
  final double amount;
  final double remainingAmount;
  final String unit;
  final String description;
  final double purchaseAmount;
  final List<Map<String, dynamic>> fundingAllocations;

  factory SavingLike.fromJson(Map<String, dynamic> json) {
    final double amount = _toDouble(json['amount']);
    final double remainingAmount = json['remainingAmount'] == null
        ? amount
        : _toDouble(json['remainingAmount']);

    return SavingLike(
      assetType: (json['assetType'] ?? '').toString(),
      dateAcquired: (json['dateAcquired'] ?? '').toString(),
      amount: amount,
      remainingAmount: remainingAmount,
      unit: (json['unit'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      purchaseAmount: _toDouble(json['purchaseAmount']),
      fundingAllocations: _asMapList(json['fundingAllocations']),
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
      purchaseAmount: purchaseAmount,
      createdAt: '',
      sourceIncomeId: null,
      exchangeSourceSavingId: null,
      exchangeSourceIncomeId: null,
      internalTransfer: null,
      internalTransferType: null,
      fundingAllocations: fundingAllocations,
    );
  }

  List<SavingZakatSegment> zakatSegments() {
    final String type = ZakatEngineService.normaliseAssetType(assetType);
    if ((type != 'gold' && type != 'silver') || fundingAllocations.isEmpty) {
      return <SavingZakatSegment>[
        SavingZakatSegment(
          date: dateAcquired,
          amount: remainingAmount,
          sourceId: null,
        ),
      ];
    }

    final double totalFunding = fundingAllocations.fold<double>(
      0,
      (double sum, Map<String, dynamic> allocation) =>
          sum + _toDouble(allocation['amount']),
    );
    if (totalFunding <= 0 || purchaseAmount <= 0) {
      return <SavingZakatSegment>[
        SavingZakatSegment(
          date: dateAcquired,
          amount: remainingAmount,
          sourceId: null,
        ),
      ];
    }

    final List<SavingZakatSegment> segments = <SavingZakatSegment>[];
    double allocatedMetal = 0;
    for (final Map<String, dynamic> allocation in fundingAllocations) {
      final double fundingAmount = _toDouble(allocation['amount']);
      if (fundingAmount <= 0) continue;
      final double metalAmount =
          remainingAmount * (fundingAmount / totalFunding);
      allocatedMetal += metalAmount;
      segments.add(
        SavingZakatSegment(
          date: (allocation['sourceDate'] ?? dateAcquired).toString(),
          amount: metalAmount,
          sourceId: allocation['sourceId']?.toString(),
        ),
      );
    }

    final double residual = remainingAmount - allocatedMetal;
    if (residual > 0.005) {
      segments.add(
        SavingZakatSegment(
          date: dateAcquired,
          amount: residual,
          sourceId: null,
        ),
      );
    }
    return segments;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((Map<dynamic, dynamic> item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}

class SavingZakatSegment {
  const SavingZakatSegment({
    required this.date,
    required this.amount,
    required this.sourceId,
  });

  final String date;
  final double amount;
  final String? sourceId;
}
