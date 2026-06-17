enum CaptureStatus { pendingReview, autoApproved, manuallyApproved, ignored }

enum ApprovalSource { auto, manual }

class PendingTransactionSource {
  PendingTransactionSource._();
  static const String sms = 'sms';
  static const String shortcut = 'shortcut';
  static const String share = 'share';
  static const String manual = 'manual';
}

class PendingTransaction {
  const PendingTransaction({
    required this.id,
    required this.source,
    this.sourceIdentifier,
    required this.rawMessage,
    required this.createdAt,
    this.reviewedAt,
    required this.suggestedType,
    this.suggestedAmount,
    this.suggestedCurrency,
    this.suggestedDescription,
    this.merchantName,
    this.suggestedCategory,
    required this.confidence,
    required this.status,
    this.approvalSource,
    this.merchantRuleUsed,
    this.merchantRuleSource,
    this.ignoreReason,
    this.parserVersion,
    this.detectedBank,
    this.requiresReview = true,
    this.isRead = false,
    this.linkedTransactionId,
  });

  final String id;
  final String source;
  final String? sourceIdentifier;
  final String rawMessage;
  final String createdAt;
  final String? reviewedAt;
  final String suggestedType;
  final double? suggestedAmount;
  final String? suggestedCurrency;
  final String? suggestedDescription;
  final String? merchantName;
  final String? suggestedCategory;
  final double confidence;
  final CaptureStatus status;
  final ApprovalSource? approvalSource;
  final String? merchantRuleUsed;
  final String? merchantRuleSource;
  final String? ignoreReason;
  final String? parserVersion;
  final String? detectedBank;
  final bool requiresReview;
  final bool isRead;
  final String? linkedTransactionId;

  String get sourceDisplayLabel {
    switch (source) {
      case PendingTransactionSource.sms:
        return 'SMS Import';
      case PendingTransactionSource.shortcut:
        return 'Apple Automation';
      case PendingTransactionSource.share:
        return 'Shared Message';
      case PendingTransactionSource.manual:
        return 'Manual Entry';
      default:
        return source;
    }
  }

  PendingTransaction copyWith({
    String? id,
    String? source,
    String? sourceIdentifier,
    String? rawMessage,
    String? createdAt,
    String? reviewedAt,
    String? suggestedType,
    double? suggestedAmount,
    String? suggestedCurrency,
    String? suggestedDescription,
    String? merchantName,
    String? suggestedCategory,
    double? confidence,
    CaptureStatus? status,
    ApprovalSource? approvalSource,
    String? merchantRuleUsed,
    String? merchantRuleSource,
    String? ignoreReason,
    String? parserVersion,
    String? detectedBank,
    bool? requiresReview,
    bool? isRead,
    String? linkedTransactionId,
    bool clearReviewedAt = false,
    bool clearApprovalSource = false,
    bool clearLinkedTransactionId = false,
  }) {
    return PendingTransaction(
      id: id ?? this.id,
      source: source ?? this.source,
      sourceIdentifier: sourceIdentifier ?? this.sourceIdentifier,
      rawMessage: rawMessage ?? this.rawMessage,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: clearReviewedAt ? null : reviewedAt ?? this.reviewedAt,
      suggestedType: suggestedType ?? this.suggestedType,
      suggestedAmount: suggestedAmount ?? this.suggestedAmount,
      suggestedCurrency: suggestedCurrency ?? this.suggestedCurrency,
      suggestedDescription: suggestedDescription ?? this.suggestedDescription,
      merchantName: merchantName ?? this.merchantName,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      confidence: confidence ?? this.confidence,
      status: status ?? this.status,
      approvalSource: clearApprovalSource
          ? null
          : approvalSource ?? this.approvalSource,
      merchantRuleUsed: merchantRuleUsed ?? this.merchantRuleUsed,
      merchantRuleSource: merchantRuleSource ?? this.merchantRuleSource,
      ignoreReason: ignoreReason ?? this.ignoreReason,
      parserVersion: parserVersion ?? this.parserVersion,
      detectedBank: detectedBank ?? this.detectedBank,
      requiresReview: requiresReview ?? this.requiresReview,
      isRead: isRead ?? this.isRead,
      linkedTransactionId: clearLinkedTransactionId
          ? null
          : linkedTransactionId ?? this.linkedTransactionId,
    );
  }

  factory PendingTransaction.fromJson(Map<String, dynamic> json) {
    return PendingTransaction(
      id: (json['id'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      sourceIdentifier: json['sourceIdentifier']?.toString(),
      rawMessage: (json['rawMessage'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      reviewedAt: json['reviewedAt']?.toString(),
      suggestedType: (json['suggestedType'] ?? 'unknown').toString(),
      suggestedAmount: json['suggestedAmount'] == null
          ? null
          : _asDouble(json['suggestedAmount']),
      suggestedCurrency: json['suggestedCurrency']?.toString(),
      suggestedDescription: json['suggestedDescription']?.toString(),
      merchantName: json['merchantName']?.toString(),
      suggestedCategory: json['suggestedCategory']?.toString(),
      confidence: _asDouble(json['confidence'] ?? 1.0),
      status: _parseStatus(json['status']),
      approvalSource: _parseApprovalSource(json['approvalSource']),
      merchantRuleUsed: json['merchantRuleUsed']?.toString(),
      merchantRuleSource: json['merchantRuleSource']?.toString(),
      ignoreReason: json['ignoreReason']?.toString(),
      parserVersion: json['parserVersion']?.toString(),
      detectedBank: json['detectedBank']?.toString(),
      requiresReview: _asBool(json['requiresReview'] ?? true),
      isRead: _asBool(json['isRead'] ?? false),
      linkedTransactionId: json['linkedTransactionId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'source': source,
      if (sourceIdentifier != null) 'sourceIdentifier': sourceIdentifier,
      'rawMessage': rawMessage,
      'createdAt': createdAt,
      if (reviewedAt != null) 'reviewedAt': reviewedAt,
      'suggestedType': suggestedType,
      if (suggestedAmount != null) 'suggestedAmount': suggestedAmount,
      if (suggestedCurrency != null) 'suggestedCurrency': suggestedCurrency,
      if (suggestedDescription != null)
        'suggestedDescription': suggestedDescription,
      if (merchantName != null) 'merchantName': merchantName,
      if (suggestedCategory != null) 'suggestedCategory': suggestedCategory,
      'confidence': confidence,
      'status': status.name,
      if (approvalSource != null) 'approvalSource': approvalSource!.name,
      if (merchantRuleUsed != null) 'merchantRuleUsed': merchantRuleUsed,
      if (merchantRuleSource != null) 'merchantRuleSource': merchantRuleSource,
      if (ignoreReason != null) 'ignoreReason': ignoreReason,
      if (parserVersion != null) 'parserVersion': parserVersion,
      if (detectedBank != null) 'detectedBank': detectedBank,
      'requiresReview': requiresReview,
      'isRead': isRead,
      if (linkedTransactionId != null)
        'linkedTransactionId': linkedTransactionId,
    };
  }

  static CaptureStatus _parseStatus(dynamic value) {
    if (value == null) return CaptureStatus.pendingReview;
    final String str = value.toString();
    if (str == 'pending' || str == 'pendingReview') {
      return CaptureStatus.pendingReview;
    }
    if (str == 'autoApproved') return CaptureStatus.autoApproved;
    if (str == 'manuallyApproved' || str == 'approved') {
      return CaptureStatus.manuallyApproved;
    }
    if (str == 'ignored' || str == 'rejected') return CaptureStatus.ignored;
    return CaptureStatus.pendingReview;
  }

  static ApprovalSource? _parseApprovalSource(dynamic value) {
    if (value == null) return null;
    final String str = value.toString();
    if (str == 'auto') return ApprovalSource.auto;
    if (str == 'manual') return ApprovalSource.manual;
    return null;
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final String raw = (value ?? '').toString().toLowerCase();
    return raw == 'true' || raw == '1';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PendingTransaction &&
        other.id == id &&
        other.source == source &&
        other.sourceIdentifier == sourceIdentifier &&
        other.rawMessage == rawMessage &&
        other.createdAt == createdAt &&
        other.reviewedAt == reviewedAt &&
        other.suggestedType == suggestedType &&
        other.suggestedAmount == suggestedAmount &&
        other.suggestedCurrency == suggestedCurrency &&
        other.suggestedDescription == suggestedDescription &&
        other.merchantName == merchantName &&
        other.suggestedCategory == suggestedCategory &&
        other.confidence == confidence &&
        other.status == status &&
        other.approvalSource == approvalSource &&
        other.merchantRuleUsed == merchantRuleUsed &&
        other.merchantRuleSource == merchantRuleSource &&
        other.ignoreReason == ignoreReason &&
        other.parserVersion == parserVersion &&
        other.detectedBank == detectedBank &&
        other.requiresReview == requiresReview &&
        other.isRead == isRead &&
        other.linkedTransactionId == linkedTransactionId;
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      id,
      source,
      sourceIdentifier,
      rawMessage,
      createdAt,
      reviewedAt,
      suggestedType,
      suggestedAmount,
      suggestedCurrency,
      suggestedDescription,
      merchantName,
      suggestedCategory,
      confidence,
      status,
      approvalSource,
      merchantRuleUsed,
      merchantRuleSource,
      ignoreReason,
      parserVersion,
      detectedBank,
      requiresReview,
      isRead,
      linkedTransactionId,
    ]);
  }
}
