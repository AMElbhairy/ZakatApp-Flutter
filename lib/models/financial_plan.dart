class FinancialPlan {
  const FinancialPlan({
    required this.id,
    required this.name,
    required this.startDate,
    required this.currency,
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.includeInstallments,
    required this.includeZakat,
    required this.durationYears,
    this.context,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String startDate;
  final String currency;
  final double monthlyIncome;
  final double monthlyExpenses;
  final bool includeInstallments;
  final bool includeZakat;
  final int durationYears;
  final Map<String, dynamic>? context;
  final String createdAt;

  factory FinancialPlan.fromJson(Map<String, dynamic> json) {
    return FinancialPlan(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      startDate: (json['startDate'] ?? '').toString(),
      currency: (json['currency'] ?? '').toString(),
      monthlyIncome: _asDouble(json['monthlyIncome']),
      monthlyExpenses: _asDouble(json['monthlyExpenses']),
      includeInstallments: _asBool(json['includeInstallments']),
      includeZakat: json['includeZakat'] == null ? true : _asBool(json['includeZakat']),
      durationYears: _asInt(json['durationYears']),
      context: json['context'] is Map
          ? Map<String, dynamic>.from(json['context'] as Map)
          : null,
      createdAt: (json['createdAt'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'startDate': startDate,
      'currency': currency,
      'monthlyIncome': monthlyIncome,
      'monthlyExpenses': monthlyExpenses,
      'includeInstallments': includeInstallments,
      'includeZakat': includeZakat,
      'durationYears': durationYears,
      'context': context,
      'createdAt': createdAt,
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
