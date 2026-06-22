import 'package:drift/drift.dart';

import '../../../models/merchant_confirmation.dart';
import '../app_database.dart' as db;

class MerchantConfirmationMapper {
  const MerchantConfirmationMapper();

  db.MerchantConfirmationsCompanion toCompanion(
    MerchantConfirmation item, {
    String? updatedAt,
    String? deletedAt,
  }) {
    final String resolvedUpdatedAt = _timestampOrFallback(updatedAt);
    return db.MerchantConfirmationsCompanion(
      id: Value<String>(_id(item)),
      merchantName: Value<String>(item.merchantName),
      categoryId: Value<String>(item.categoryId),
      confirmations: Value<int>(item.confirmations),
      corrections: Value<int>(item.corrections),
      updatedAt: Value<String>(resolvedUpdatedAt),
      deletedAt: Value<String?>(deletedAt),
    );
  }

  MerchantConfirmation fromRow(db.MerchantConfirmation row) {
    return MerchantConfirmation(
      merchantName: row.merchantName,
      categoryId: row.categoryId,
      confirmations: row.confirmations,
      corrections: row.corrections,
    );
  }

  String _id(MerchantConfirmation item) {
    return '${item.merchantName.toLowerCase().trim()}|${item.categoryId.toLowerCase().trim()}';
  }

  String _timestampOrFallback(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    return DateTime.now().toUtc().toIso8601String();
  }
}
