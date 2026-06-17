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
    this.activityType,
    this.costBasis,
    this.saleValue,
    this.realizedGain,
    this.realizedGainLossCurrency,
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
  final String? activityType;
  final double? costBasis;
  final double? saleValue;
  final double? realizedGain;
  final String? realizedGainLossCurrency;

  bool get isTransferActivity {
    final String normalizedCategory = category.trim().toLowerCase();
    final String normalizedDescription = description.trim().toLowerCase();
    return activityType?.trim().toLowerCase() == 'transfer' ||
        normalizedCategory == 'currency exchange' ||
        normalizedCategory == 'precious metals purchase' ||
        normalizedCategory == 'gold purchase' ||
        normalizedCategory == 'gold sale' ||
        normalizedCategory == 'silver purchase' ||
        normalizedCategory == 'silver sale' ||
        normalizedCategory == 'cash transfer' ||
        normalizedCategory == 'wallet transfer' ||
        normalizedCategory == 'account transfer' ||
        normalizedCategory == 'cash wallet transfer' ||
        normalizedCategory == 'internal asset conversion' ||
        normalizedDescription.startsWith('currency exchange out:') ||
        normalizedDescription.startsWith('currency exchange in:');
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString().trim().toLowerCase(),
      date: (json['date'] ?? '').toString(),
      amount: _asDouble(json['amount']),
      currency: (json['currency'] ?? '').toString().trim().toUpperCase(),
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
      activityType: json['activityType']?.toString().trim().toLowerCase(),
      costBasis: json['costBasis'] == null
          ? null
          : _asDouble(json['costBasis']),
      saleValue: json['saleValue'] == null
          ? null
          : _asDouble(json['saleValue']),
      realizedGain: json['realizedGain'] == null
          ? null
          : _asDouble(json['realizedGain']),
      realizedGainLossCurrency: json['realizedGainLossCurrency']?.toString(),
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
      if (activityType != null) 'activityType': activityType,
      if (costBasis != null) 'costBasis': costBasis,
      if (saleValue != null) 'saleValue': saleValue,
      if (realizedGain != null) 'realizedGain': realizedGain,
      if (realizedGainLossCurrency != null)
        'realizedGainLossCurrency': realizedGainLossCurrency,
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
