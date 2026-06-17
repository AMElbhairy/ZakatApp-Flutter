class CorrectionFeedback {
  const CorrectionFeedback({
    required this.id,
    required this.fieldName,
    required this.originalValue,
    required this.correctedValue,
    required this.createdAt,
  });

  final String id;
  final String fieldName; // 'type' | 'merchant' | 'amount' | 'category'
  final String originalValue;
  final String correctedValue;
  final String createdAt;

  factory CorrectionFeedback.fromJson(Map<String, dynamic> json) {
    return CorrectionFeedback(
      id: (json['id'] ?? '').toString(),
      fieldName: (json['fieldName'] ?? '').toString(),
      originalValue: (json['originalValue'] ?? '').toString(),
      correctedValue: (json['correctedValue'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'fieldName': fieldName,
      'originalValue': originalValue,
      'correctedValue': correctedValue,
      'createdAt': createdAt,
    };
  }
}
