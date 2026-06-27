class FinancialPlan {
  const FinancialPlan({
    required this.id,
    required this.name,
    required this.startDate,
    required this.projectionCurrency,
    required this.startingBalance,
    required this.startingBalanceDate,
    required this.startingBalanceMode,
    required this.snapshotWealthCurrency,
    required this.startingAssetBreakdown,
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.includeInstallments,
    required this.includeZakat,
    required this.durationYears,
    required this.createdAt,
    this.isActive = true,
    this.startingAssets = 0.0,
    this.startingLiabilities = 0.0,
    this.startingNetWorth = 0.0,
    this.startingNisabSnapshot = 0.0,
    this.startingGoldPriceSnapshot = 0.0,
    this.startingFxSnapshot = const <String, double>{},
  });

  final String id;
  final String name;
  final String startDate;
  final String projectionCurrency;
  final double startingBalance;
  final String startingBalanceDate;
  final String startingBalanceMode;
  final String snapshotWealthCurrency;
  final Map<String, double> startingAssetBreakdown;
  final double monthlyIncome;
  final double monthlyExpenses;
  final bool includeInstallments;
  final bool includeZakat;
  final int durationYears;
  final String createdAt;
  final bool isActive;
  final double startingAssets;
  final double startingLiabilities;
  final double startingNetWorth;
  final double startingNisabSnapshot;
  final double startingGoldPriceSnapshot;
  final Map<String, double> startingFxSnapshot;

  factory FinancialPlan.fromJson(Map<String, dynamic> json) {
    final Map<String, double> parsedBreakdown = <String, double>{};
    final dynamic breakdownRaw = json['startingAssetBreakdown'];
    if (breakdownRaw is Map) {
      breakdownRaw.forEach((dynamic key, dynamic value) {
        parsedBreakdown[key.toString()] = _asDouble(value);
      });
    }

    final Map<String, double> parsedFx = <String, double>{};
    final dynamic fxRaw = json['startingFxSnapshot'];
    if (fxRaw is Map) {
      fxRaw.forEach((dynamic key, dynamic value) {
        parsedFx[key.toString()] = _asDouble(value);
      });
    }

    final double balance = _asDouble(json['startingBalance'] ?? (json['context'] as Map?)?['startingBalance']);

    return FinancialPlan(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      startDate: (json['startDate'] ?? '').toString(),
      projectionCurrency: (json['projectionCurrency'] ?? json['currency'] ?? 'EGP').toString().trim().toUpperCase(),
      startingBalance: balance,
      startingBalanceDate: (json['startingBalanceDate'] ?? json['startDate'] ?? '').toString(),
      startingBalanceMode: (json['startingBalanceMode'] ?? 'manual').toString(),
      snapshotWealthCurrency: (json['snapshotWealthCurrency'] ?? json['currency'] ?? 'EGP').toString().trim().toUpperCase(),
      startingAssetBreakdown: parsedBreakdown,
      monthlyIncome: _asDouble(json['monthlyIncome']),
      monthlyExpenses: _asDouble(json['monthlyExpenses']),
      includeInstallments: _asBool(json['includeInstallments']),
      includeZakat: json['includeZakat'] == null ? true : _asBool(json['includeZakat']),
      durationYears: _asInt(json['durationYears']),
      createdAt: (json['createdAt'] ?? '').toString(),
      isActive: json['isActive'] == null ? true : _asBool(json['isActive']),
      startingAssets: _asDouble(json['startingAssets'] ?? balance),
      startingLiabilities: _asDouble(json['startingLiabilities']),
      startingNetWorth: _asDouble(json['startingNetWorth'] ?? balance),
      startingNisabSnapshot: _asDouble(json['startingNisabSnapshot']),
      startingGoldPriceSnapshot: _asDouble(json['startingGoldPriceSnapshot']),
      startingFxSnapshot: parsedFx,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'startDate': startDate,
      'projectionCurrency': projectionCurrency,
      'startingBalance': startingBalance,
      'startingBalanceDate': startingBalanceDate,
      'startingBalanceMode': startingBalanceMode,
      'snapshotWealthCurrency': snapshotWealthCurrency,
      'startingAssetBreakdown': startingAssetBreakdown,
      'monthlyIncome': monthlyIncome,
      'monthlyExpenses': monthlyExpenses,
      'includeInstallments': includeInstallments,
      'includeZakat': includeZakat,
      'durationYears': durationYears,
      'createdAt': createdAt,
      'isActive': isActive,
      'startingAssets': startingAssets,
      'startingLiabilities': startingLiabilities,
      'startingNetWorth': startingNetWorth,
      'startingNisabSnapshot': startingNisabSnapshot,
      'startingGoldPriceSnapshot': startingGoldPriceSnapshot,
      'startingFxSnapshot': startingFxSnapshot,
    };
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final String raw = (value ?? '').toString().toLowerCase();
    return raw == 'true' || raw == '1';
  }
}
