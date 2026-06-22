import 'package:drift/drift.dart';

import '../../../models/correction_feedback.dart';
import '../app_database.dart' as db;

class CorrectionFeedbackMapper {
  const CorrectionFeedbackMapper();

  db.CorrectionFeedbacksCompanion toCompanion(
    CorrectionFeedback item, {
    String? updatedAt,
    String? deletedAt,
  }) {
    final String resolvedUpdatedAt = _timestampOrFallback(
      updatedAt ?? item.createdAt,
    );
    return db.CorrectionFeedbacksCompanion(
      id: Value<String>(item.id),
      fieldName: Value<String>(item.fieldName),
      originalValue: Value<String>(item.originalValue),
      correctedValue: Value<String>(item.correctedValue),
      createdAt: Value<String>(item.createdAt),
      updatedAt: Value<String>(resolvedUpdatedAt),
      deletedAt: Value<String?>(deletedAt),
    );
  }

  CorrectionFeedback fromRow(db.CorrectionFeedback row) {
    return CorrectionFeedback(
      id: row.id,
      fieldName: row.fieldName,
      originalValue: row.originalValue,
      correctedValue: row.correctedValue,
      createdAt: row.createdAt,
    );
  }

  String _timestampOrFallback(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    return DateTime.now().toUtc().toIso8601String();
  }
}
