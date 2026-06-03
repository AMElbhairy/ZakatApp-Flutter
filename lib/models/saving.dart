class Saving {
  const Saving({
    required this.id,
    required this.assetType,
    required this.dateAcquired,
    required this.amount,
    required this.remainingAmount,
    required this.unit,
    required this.description,
    this.linkedCashEntryId,
    required this.purchaseCurrency,
    required this.purchaseAmount,
    required this.createdAt,
    this.sourceIncomeId,
    this.exchangeSourceSavingId,
    this.exchangeSourceIncomeId,
    this.internalTransfer,
    this.internalTransferType,
    this.fundingAllocations = const <Map<String, dynamic>>[],
  });

  final String id;
  final String assetType;
  final String dateAcquired;
  final double amount;
  final double remainingAmount;
  final String unit;
  final String description;
  final String? linkedCashEntryId;
  final String purchaseCurrency;
  final double purchaseAmount;
  final String createdAt;
  final String? sourceIncomeId;
  final String? exchangeSourceSavingId;
  final String? exchangeSourceIncomeId;
  final bool? internalTransfer;
  final String? internalTransferType;
  final List<Map<String, dynamic>> fundingAllocations;

  factory Saving.fromJson(Map<String, dynamic> json) {
    return Saving(
      id: (json['id'] ?? '').toString(),
      assetType: (json['assetType'] ?? '').toString(),
      dateAcquired: (json['dateAcquired'] ?? '').toString(),
      amount: _asDouble(json['amount']),
      remainingAmount: json['remainingAmount'] == null
          ? _asDouble(json['amount'])
          : _asDouble(json['remainingAmount']),
      unit: (json['unit'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      linkedCashEntryId: json['linkedCashEntryId']?.toString(),
      purchaseCurrency: (json['purchaseCurrency'] ?? '').toString(),
      purchaseAmount: _asDouble(json['purchaseAmount']),
      createdAt: (json['createdAt'] ?? '').toString(),
      sourceIncomeId: json['sourceIncomeId']?.toString(),
      exchangeSourceSavingId: json['exchangeSourceSavingId']?.toString(),
      exchangeSourceIncomeId: json['exchangeSourceIncomeId']?.toString(),
      internalTransfer: json['internalTransfer'] == null
          ? null
          : _asBool(json['internalTransfer']),
      internalTransferType: json['internalTransferType']?.toString(),
      fundingAllocations: _asMapList(json['fundingAllocations']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'assetType': assetType,
      'dateAcquired': dateAcquired,
      'amount': amount,
      'remainingAmount': remainingAmount,
      'unit': unit,
      'description': description,
      if (linkedCashEntryId != null) 'linkedCashEntryId': linkedCashEntryId,
      'purchaseCurrency': purchaseCurrency,
      'purchaseAmount': purchaseAmount,
      'createdAt': createdAt,
      if (sourceIncomeId != null) 'sourceIncomeId': sourceIncomeId,
      if (exchangeSourceSavingId != null)
        'exchangeSourceSavingId': exchangeSourceSavingId,
      if (exchangeSourceIncomeId != null)
        'exchangeSourceIncomeId': exchangeSourceIncomeId,
      if (internalTransfer != null) 'internalTransfer': internalTransfer,
      if (internalTransferType != null)
        'internalTransferType': internalTransferType,
      if (fundingAllocations.isNotEmpty)
        'fundingAllocations': fundingAllocations,
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

  static List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((Map<dynamic, dynamic> item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}
