class MerchantRule {
  const MerchantRule({
    required this.merchantName,
    required this.categoryId,
    required this.defaultType,
    required this.autoApprove,
    required this.usageCount,
    required this.confidence,
    this.lastUsed,
    required this.source,
    this.aliases = const <String>[],
    this.enabled = true,
    this.isBuiltinOverride = false,
    this.builtinKey,
  });

  final String merchantName;
  final String categoryId;
  final String defaultType;
  final bool autoApprove;
  final int usageCount;
  final double confidence;
  final String? lastUsed;
  final String source; // 'builtin' | 'learned' | 'custom'
  final List<String> aliases;
  final bool enabled;
  final bool isBuiltinOverride;
  final String? builtinKey;

  factory MerchantRule.fromJson(Map<String, dynamic> json) {
    return MerchantRule(
      merchantName: (json['merchantName'] ?? '').toString(),
      categoryId: (json['categoryId'] ?? '').toString(),
      defaultType: (json['defaultType'] ?? 'expense').toString(),
      autoApprove: json['autoApprove'] == true,
      usageCount: json['usageCount'] is int ? json['usageCount'] as int : 0,
      confidence: json['confidence'] is num
          ? (json['confidence'] as num).toDouble()
          : 1.0,
      lastUsed: json['lastUsed']?.toString(),
      source: (json['source'] ?? 'learned').toString(),
      aliases: json['aliases'] is List
          ? (json['aliases'] as List)
                .map((dynamic alias) => alias.toString())
                .toList(growable: false)
          : const <String>[],
      enabled: json['enabled'] != false,
      isBuiltinOverride: json['isBuiltinOverride'] == true,
      builtinKey: json['builtinKey']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'merchantName': merchantName,
      'categoryId': categoryId,
      'defaultType': defaultType,
      'autoApprove': autoApprove,
      'usageCount': usageCount,
      'confidence': confidence,
      if (lastUsed != null) 'lastUsed': lastUsed,
      'source': source,
      'aliases': aliases,
      'enabled': enabled,
      'isBuiltinOverride': isBuiltinOverride,
      if (builtinKey != null) 'builtinKey': builtinKey,
    };
  }

  MerchantRule copyWith({
    String? merchantName,
    String? categoryId,
    String? defaultType,
    bool? autoApprove,
    int? usageCount,
    double? confidence,
    String? lastUsed,
    String? source,
    List<String>? aliases,
    bool? enabled,
    bool? isBuiltinOverride,
    String? builtinKey,
  }) {
    return MerchantRule(
      merchantName: merchantName ?? this.merchantName,
      categoryId: categoryId ?? this.categoryId,
      defaultType: defaultType ?? this.defaultType,
      autoApprove: autoApprove ?? this.autoApprove,
      usageCount: usageCount ?? this.usageCount,
      confidence: confidence ?? this.confidence,
      lastUsed: lastUsed ?? this.lastUsed,
      source: source ?? this.source,
      aliases: aliases ?? this.aliases,
      enabled: enabled ?? this.enabled,
      isBuiltinOverride: isBuiltinOverride ?? this.isBuiltinOverride,
      builtinKey: builtinKey ?? this.builtinKey,
    );
  }
}
