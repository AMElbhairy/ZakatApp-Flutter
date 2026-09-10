import 'credit_card_calculator.dart';

enum CreditCardNetwork {
  visa,
  mastercard,
  americanExpress,
  discover,
  unionPay,
  jcb,
  dinersClub,
  mada,
  meeza,
  other,
}

extension CreditCardNetworkJson on CreditCardNetwork {
  String get value {
    switch (this) {
      case CreditCardNetwork.americanExpress:
        return 'american_express';
      case CreditCardNetwork.unionPay:
        return 'union_pay';
      case CreditCardNetwork.dinersClub:
        return 'diners_club';
      default:
        return name;
    }
  }

  String get displayName {
    switch (this) {
      case CreditCardNetwork.visa:
        return 'Visa';
      case CreditCardNetwork.mastercard:
        return 'Mastercard';
      case CreditCardNetwork.americanExpress:
        return 'American Express';
      case CreditCardNetwork.discover:
        return 'Discover';
      case CreditCardNetwork.unionPay:
        return 'UnionPay';
      case CreditCardNetwork.jcb:
        return 'JCB';
      case CreditCardNetwork.dinersClub:
        return 'Diners Club';
      case CreditCardNetwork.mada:
        return 'mada';
      case CreditCardNetwork.meeza:
        return 'Meeza';
      case CreditCardNetwork.other:
        return 'Other';
    }
  }

  static CreditCardNetwork parse(dynamic raw) {
    final String value = (raw ?? '').toString().trim().toLowerCase();
    return CreditCardNetwork.values.firstWhere(
      (CreditCardNetwork network) => network.value == value,
      orElse: () => CreditCardNetwork.other,
    );
  }
}

class CreditCard {
  const CreditCard({
    required this.id,
    required this.bankName,
    required this.cardNickname,
    required this.network,
    required this.last4Digits,
    required this.creditLimit,
    required this.currency,
    required this.openingBalance,
    this.statementDay,
    this.paymentDueDay,
    this.expiryMonth,
    this.expiryYear,
    this.themeId = 'emerald',
    this.notes = '',
    this.minimumPaymentAmount,
    this.paymentReminderEnabled = false,
    this.reminderDaysBefore = 3,
    this.reminderTimeHour = 9,
    this.reminderTimeMinute = 0,
    this.isArchived = false,
    this.createdAt = '',
    this.updatedAt = '',
    this.parentCardId,
  });

  final String id;
  final String bankName;
  final String cardNickname;
  final CreditCardNetwork network;
  final String last4Digits;
  final double creditLimit;
  final String currency;
  final double openingBalance;
  final int? statementDay;
  final int? paymentDueDay;
  final int? expiryMonth;
  final int? expiryYear;
  final String themeId;
  final String notes;
  final double? minimumPaymentAmount;
  final bool paymentReminderEnabled;
  final int reminderDaysBefore;
  final int reminderTimeHour;
  final int reminderTimeMinute;
  final bool isArchived;
  final String createdAt;
  final String updatedAt;
  final String? parentCardId;

  double get availableCredit => CreditCardCalculator.availableCredit(
    creditLimit: creditLimit,
    outstandingBalance: openingBalance,
  );

  double get utilization => CreditCardCalculator.utilization(
    creditLimit: creditLimit,
    outstandingBalance: openingBalance,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'bankName': bankName,
    'cardNickname': cardNickname,
    'network': network.value,
    'last4Digits': last4Digits,
    'creditLimit': creditLimit,
    'currency': currency,
    'openingBalance': openingBalance,
    'statementDay': statementDay,
    'paymentDueDay': paymentDueDay,
    'expiryMonth': expiryMonth,
    'expiryYear': expiryYear,
    'themeId': themeId,
    'notes': notes,
    'minimumPaymentAmount': minimumPaymentAmount,
    'paymentReminderEnabled': paymentReminderEnabled,
    'reminderDaysBefore': reminderDaysBefore,
    'reminderTimeHour': reminderTimeHour,
    'reminderTimeMinute': reminderTimeMinute,
    'isArchived': isArchived,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'parentCardId': parentCardId,
  };

  factory CreditCard.fromJson(Map<String, dynamic> json) {
    double? optionalDouble(dynamic value) =>
        value == null ? null : double.tryParse(value.toString());
    int? optionalInt(dynamic value) =>
        value == null ? null : int.tryParse(value.toString());
    return CreditCard(
      id: (json['id'] ?? '').toString(),
      bankName: (json['bankName'] ?? '').toString(),
      cardNickname: (json['cardNickname'] ?? '').toString(),
      network: CreditCardNetworkJson.parse(json['network']),
      last4Digits: (json['last4Digits'] ?? '').toString(),
      creditLimit: double.tryParse((json['creditLimit'] ?? 0).toString()) ?? 0,
      currency: (json['currency'] ?? '').toString(),
      openingBalance:
          double.tryParse((json['openingBalance'] ?? 0).toString()) ?? 0,
      statementDay: optionalInt(json['statementDay']),
      paymentDueDay: optionalInt(json['paymentDueDay']),
      expiryMonth: optionalInt(json['expiryMonth']),
      expiryYear: optionalInt(json['expiryYear']),
      themeId: (json['themeId'] ?? 'emerald').toString(),
      notes: (json['notes'] ?? '').toString(),
      minimumPaymentAmount: optionalDouble(json['minimumPaymentAmount']),
      paymentReminderEnabled: json['paymentReminderEnabled'] == true,
      reminderDaysBefore: optionalInt(json['reminderDaysBefore']) ?? 3,
      reminderTimeHour: optionalInt(json['reminderTimeHour']) ?? 9,
      reminderTimeMinute: optionalInt(json['reminderTimeMinute']) ?? 0,
      isArchived: json['isArchived'] == true,
      createdAt: (json['createdAt'] ?? '').toString(),
      updatedAt: (json['updatedAt'] ?? '').toString(),
      parentCardId: (json['parentCardId'] ?? '').toString().trim().isEmpty
          ? null
          : (json['parentCardId'] ?? '').toString().trim(),
    );
  }

  CreditCard copyWith({
    String? bankName,
    String? cardNickname,
    CreditCardNetwork? network,
    String? last4Digits,
    double? creditLimit,
    String? currency,
    double? openingBalance,
    int? statementDay,
    int? paymentDueDay,
    int? expiryMonth,
    int? expiryYear,
    String? themeId,
    String? notes,
    double? minimumPaymentAmount,
    bool? paymentReminderEnabled,
    int? reminderDaysBefore,
    int? reminderTimeHour,
    int? reminderTimeMinute,
    bool? isArchived,
    String? updatedAt,
    String? parentCardId,
    bool clearParentCardId = false,
  }) {
    return CreditCard(
      id: id,
      bankName: bankName ?? this.bankName,
      cardNickname: cardNickname ?? this.cardNickname,
      network: network ?? this.network,
      last4Digits: last4Digits ?? this.last4Digits,
      creditLimit: creditLimit ?? this.creditLimit,
      currency: currency ?? this.currency,
      openingBalance: openingBalance ?? this.openingBalance,
      statementDay: statementDay ?? this.statementDay,
      paymentDueDay: paymentDueDay ?? this.paymentDueDay,
      expiryMonth: expiryMonth ?? this.expiryMonth,
      expiryYear: expiryYear ?? this.expiryYear,
      themeId: themeId ?? this.themeId,
      notes: notes ?? this.notes,
      minimumPaymentAmount: minimumPaymentAmount ?? this.minimumPaymentAmount,
      paymentReminderEnabled:
          paymentReminderEnabled ?? this.paymentReminderEnabled,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      reminderTimeHour: reminderTimeHour ?? this.reminderTimeHour,
      reminderTimeMinute: reminderTimeMinute ?? this.reminderTimeMinute,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      parentCardId: clearParentCardId
          ? null
          : parentCardId ?? this.parentCardId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreditCard &&
        other.id == id &&
        other.bankName == bankName &&
        other.cardNickname == cardNickname &&
        other.network == network &&
        other.last4Digits == last4Digits &&
        other.creditLimit == creditLimit &&
        other.currency == currency &&
        other.openingBalance == openingBalance &&
        other.statementDay == statementDay &&
        other.paymentDueDay == paymentDueDay &&
        other.expiryMonth == expiryMonth &&
        other.expiryYear == expiryYear &&
        other.themeId == themeId &&
        other.notes == notes &&
        other.minimumPaymentAmount == minimumPaymentAmount &&
        other.paymentReminderEnabled == paymentReminderEnabled &&
        other.reminderDaysBefore == reminderDaysBefore &&
        other.reminderTimeHour == reminderTimeHour &&
        other.reminderTimeMinute == reminderTimeMinute &&
        other.isArchived == isArchived &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.parentCardId == parentCardId;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    bankName,
    cardNickname,
    network,
    last4Digits,
    creditLimit,
    currency,
    openingBalance,
    statementDay,
    paymentDueDay,
    expiryMonth,
    expiryYear,
    themeId,
    notes,
    minimumPaymentAmount,
    paymentReminderEnabled,
    reminderDaysBefore,
    reminderTimeHour,
    reminderTimeMinute,
    isArchived,
    createdAt,
    updatedAt,
    parentCardId,
  ]);
}
