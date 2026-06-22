class InvestmentAsset {
  const InvestmentAsset({
    required this.id,
    required this.investmentType,
    required this.assetSubtype,
    required this.ownershipType,
    required this.valuationMode,
    required this.currency,
    required this.originalPrice,
    required this.totalInterest,
    required this.totalPayable,
    required this.paidAmount,
    required this.remainingAmount,
    required this.installmentPlan,
    required this.valuationDate,
    required this.marketValue,
    required this.marketValueDate,
    required this.valuationSource,
    required this.loanBalance,
    required this.loanAsOfDate,
    required this.paidAmountToDate,
    required this.ownershipSharePct,
    required this.country,
    required this.location,
    required this.inflationRateAnnual,
    required this.estimatedCurrentValue,
    required this.description,
    required this.noZakat,
    required this.createdAt,
    this.yearlyGrowthRate = 0.0,
  });

  final String id;
  final String investmentType;
  final String assetSubtype;
  final String ownershipType;
  final String valuationMode;
  final String currency;
  final double originalPrice;
  final double totalInterest;
  final double totalPayable;
  final double paidAmount;
  final double remainingAmount;
  final List<Map<String, dynamic>> installmentPlan;
  final String valuationDate;
  final double marketValue;
  final String marketValueDate;
  final String valuationSource;
  final double loanBalance;
  final String loanAsOfDate;
  final double paidAmountToDate;
  final double ownershipSharePct;
  final String country;
  final String location;
  final double inflationRateAnnual;
  final double estimatedCurrentValue;
  final String description;
  final bool noZakat;
  final String createdAt;
  final double yearlyGrowthRate;

  factory InvestmentAsset.fromJson(Map<String, dynamic> json) {
    return InvestmentAsset(
      id: (json['id'] ?? '').toString(),
      investmentType: (json['investmentType'] ?? '').toString(),
      assetSubtype: (json['assetSubtype'] ?? '').toString(),
      ownershipType: (json['ownershipType'] ?? '').toString(),
      valuationMode: (json['valuationMode'] ?? '').toString(),
      currency: (json['currency'] ?? '').toString().trim().toUpperCase(),
      originalPrice: _asDouble(json['originalPrice']),
      totalInterest: _asDouble(json['totalInterest']),
      totalPayable: _asDouble(json['totalPayable']),
      paidAmount: _asDouble(json['paidAmount']),
      remainingAmount: _asDouble(json['remainingAmount']),
      installmentPlan: normalizeInstallmentPlan(json['installmentPlan']),
      valuationDate: (json['valuationDate'] ?? '').toString(),
      marketValue: _asDouble(json['marketValue']),
      marketValueDate: (json['marketValueDate'] ?? '').toString(),
      valuationSource: (json['valuationSource'] ?? '').toString(),
      loanBalance: _asDouble(json['loanBalance']),
      loanAsOfDate: (json['loanAsOfDate'] ?? '').toString(),
      paidAmountToDate: _asDouble(json['paidAmountToDate']),
      ownershipSharePct: _asDouble(json['ownershipSharePct']),
      country: (json['country'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      inflationRateAnnual: _asDouble(json['inflationRateAnnual']),
      estimatedCurrentValue: _asDouble(json['estimatedCurrentValue']),
      description: (json['description'] ?? '').toString(),
      noZakat: json['noZakat'] == null ? true : _asBool(json['noZakat']),
      createdAt: (json['createdAt'] ?? '').toString(),
      yearlyGrowthRate: _asDouble(json['yearlyGrowthRate']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'investmentType': investmentType,
      'assetSubtype': assetSubtype,
      'ownershipType': ownershipType,
      'valuationMode': valuationMode,
      'currency': currency,
      'originalPrice': originalPrice,
      'totalInterest': totalInterest,
      'totalPayable': totalPayable,
      'paidAmount': paidAmount,
      'remainingAmount': remainingAmount,
      'installmentPlan': installmentPlan,
      'valuationDate': valuationDate,
      'marketValue': marketValue,
      'marketValueDate': marketValueDate,
      'valuationSource': valuationSource,
      'loanBalance': loanBalance,
      'loanAsOfDate': loanAsOfDate,
      'paidAmountToDate': paidAmountToDate,
      'ownershipSharePct': ownershipSharePct,
      'country': country,
      'location': location,
      'inflationRateAnnual': inflationRateAnnual,
      'estimatedCurrentValue': estimatedCurrentValue,
      'description': description,
      'noZakat': noZakat,
      'createdAt': createdAt,
      'yearlyGrowthRate': yearlyGrowthRate,
    };
  }

  static List<Map<String, dynamic>> normalizeInstallmentPlan(dynamic value) {
    if (value is List) {
      return value
          .map((dynamic e) {
            final Map<String, dynamic> item = e is Map
                ? Map<String, dynamic>.from(e)
                : <String, dynamic>{};
            final String dueDate = _firstNonEmpty(item, <String>[
              'recurrenceDate',
              'date',
              'dueDate',
              'paymentDate',
            ]);
            if (dueDate.isNotEmpty) {
              item['recurrenceDate'] = dueDate;
              item['date'] = dueDate;
            }
            if (item['amount'] != null) {
              item['amount'] = _asDouble(item['amount']);
            }
            if (item['isPaid'] != null) {
              item['isPaid'] = _asBool(item['isPaid']);
            }
            return item;
          })
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  static String installmentDueDate(Map<String, dynamic> item) {
    return _firstNonEmpty(item, const <String>[
      'recurrenceDate',
      'date',
      'dueDate',
      'paymentDate',
    ]);
  }

  static String _firstNonEmpty(Map<String, dynamic> item, List<String> keys) {
    for (final String key in keys) {
      final String value = (item[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
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
