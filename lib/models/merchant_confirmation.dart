class MerchantConfirmation {
  const MerchantConfirmation({
    required this.merchantName,
    required this.categoryId,
    required this.confirmations,
    required this.corrections,
  });

  final String merchantName;
  final String categoryId;
  final int confirmations;
  final int corrections;

  factory MerchantConfirmation.fromJson(Map<String, dynamic> json) {
    return MerchantConfirmation(
      merchantName: (json['merchantName'] ?? '').toString(),
      categoryId: (json['categoryId'] ?? '').toString(),
      confirmations: json['confirmations'] is int ? json['confirmations'] as int : 0,
      corrections: json['corrections'] is int ? json['corrections'] as int : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'merchantName': merchantName,
      'categoryId': categoryId,
      'confirmations': confirmations,
      'corrections': corrections,
    };
  }

  MerchantConfirmation copyWith({
    String? merchantName,
    String? categoryId,
    int? confirmations,
    int? corrections,
  }) {
    return MerchantConfirmation(
      merchantName: merchantName ?? this.merchantName,
      categoryId: categoryId ?? this.categoryId,
      confirmations: confirmations ?? this.confirmations,
      corrections: corrections ?? this.corrections,
    );
  }
}
