import '../core/utils/amount_parser.dart';

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
    this.autoAdd = true,
    this.reminderEnabled = false,
    this.reminderDayOffset = 0,
    this.reminderTime = '09:00',
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
  final bool autoAdd;
  final bool reminderEnabled;
  final int reminderDayOffset;
  final String reminderTime;

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
      lastProcessed: normalizeNullableDateText(
        json['lastProcessed']?.toString(),
      ),
      enabled: json['enabled'] == null ? true : _asBool(json['enabled']),
      skipMonth: (json['skipMonth'] ?? '').toString(),
      createdAt: normalizeTimestampText(json['createdAt']?.toString()),
      autoAdd: json['autoAdd'] == null ? true : _asBool(json['autoAdd']),
      reminderEnabled: json['reminderEnabled'] == null ? false : _asBool(json['reminderEnabled']),
      reminderDayOffset: json['reminderDayOffset'] == null ? 0 : _asInt(json['reminderDayOffset']),
      reminderTime: (json['reminderTime'] ?? '09:00').toString(),
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
      'autoAdd': autoAdd,
      'reminderEnabled': reminderEnabled,
      'reminderDayOffset': reminderDayOffset,
      'reminderTime': reminderTime,
    };
  }

  RecurringTransaction copyWith({
    String? id,
    String? name,
    String? type,
    double? amount,
    String? currency,
    String? category,
    String? description,
    int? dayOfMonth,
    String? frequency,
    String? lastProcessed,
    bool? enabled,
    String? skipMonth,
    String? createdAt,
    bool? autoAdd,
    bool? reminderEnabled,
    int? reminderDayOffset,
    String? reminderTime,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      description: description ?? this.description,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      frequency: frequency ?? this.frequency,
      lastProcessed: lastProcessed ?? this.lastProcessed,
      enabled: enabled ?? this.enabled,
      skipMonth: skipMonth ?? this.skipMonth,
      createdAt: createdAt ?? this.createdAt,
      autoAdd: autoAdd ?? this.autoAdd,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderDayOffset: reminderDayOffset ?? this.reminderDayOffset,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return tryParseAmount(value?.toString()) ?? 0;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(normalizeAmountText(value?.toString())) ?? 0;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final String raw = (value ?? '').toString().toLowerCase();
    return raw == 'true' || raw == '1';
  }
}
