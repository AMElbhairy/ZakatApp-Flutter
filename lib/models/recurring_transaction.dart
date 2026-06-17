class RecurringTransaction {
  const RecurringTransaction({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.currency,
    required this.category,
    required this.description,
    required this.dayOfMonth,
    required this.frequency,
    this.lastProcessed,
    required this.enabled,
    required this.skipMonth,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String type;
  final double amount;
  final String currency;
  final String category;
  final String description;
  final int dayOfMonth;
  final String frequency;
  final String? lastProcessed;
  final bool enabled;
  final String skipMonth;
  final String createdAt;

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) {
    return RecurringTransaction(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      amount: _asDouble(json['amount']),
      currency: (json['currency'] ?? '').toString().trim().toUpperCase(),
      category: (json['category'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      dayOfMonth: _asInt(json['dayOfMonth']),
      frequency: (json['frequency'] ?? '').toString(),
      lastProcessed: json['lastProcessed']?.toString(),
      enabled: json['enabled'] == null ? true : _asBool(json['enabled']),
      skipMonth: (json['skipMonth'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'type': type,
      'amount': amount,
      'currency': currency,
      'category': category,
      'description': description,
      'dayOfMonth': dayOfMonth,
      'frequency': frequency,
      'lastProcessed': lastProcessed,
      'enabled': enabled,
      'skipMonth': skipMonth,
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
