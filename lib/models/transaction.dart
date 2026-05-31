class Transaction {
  const Transaction({
    required this.id,
    required this.type,
    required this.date,
    required this.amount,
    required this.currency,
    required this.category,
    required this.description,
    required this.createdAt,
    required this.rolledOver,
    this.rolledAmount,
    this.sourceIncomeId,
    this.exchangePairId,
    this.exchangeSourceIncomeId,
    this.remainingAmount,
  });

  final String id;
  final String type;
  final String date;
  final double amount;
  final String currency;
  final String category;
  final String description;
  final String createdAt;
  final bool rolledOver;
  final double? rolledAmount;
  final String? sourceIncomeId;
  final String? exchangePairId;
  final String? exchangeSourceIncomeId;
  final double? remainingAmount;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      amount: _asDouble(json['amount']),
      currency: (json['currency'] ?? '').toString(),
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

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type,
      'date': date,
      'amount': amount,
      'currency': currency,
      'category': category,
      'description': description,
      'createdAt': createdAt,
      'rolledOver': rolledOver,
      if (rolledAmount != null) 'rolledAmount': rolledAmount,
      if (sourceIncomeId != null) 'sourceIncomeId': sourceIncomeId,
      if (exchangePairId != null) 'exchangePairId': exchangePairId,
      if (exchangeSourceIncomeId != null)
        'exchangeSourceIncomeId': exchangeSourceIncomeId,
      if (remainingAmount != null) 'remainingAmount': remainingAmount,
    };
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
