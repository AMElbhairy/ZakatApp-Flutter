import 'package:drift/drift.dart';

class PendingTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get source => text()();
  TextColumn get sourceIdentifier =>
      text().named('source_identifier').nullable()();
  TextColumn get rawMessage => text().named('raw_message')();
  TextColumn get createdAt => text().named('created_at')();
  TextColumn get reviewedAt => text().named('reviewed_at').nullable()();
  TextColumn get suggestedType => text().named('suggested_type')();
  TextColumn get suggestedAmountText =>
      text().named('suggested_amount_text').nullable()();
  TextColumn get suggestedCurrency =>
      text().named('suggested_currency').nullable()();
  TextColumn get suggestedDescription =>
      text().named('suggested_description').nullable()();
  TextColumn get merchantName => text().named('merchant_name').nullable()();
  TextColumn get suggestedCategory =>
      text().named('suggested_category').nullable()();
  TextColumn get confidenceText => text().named('confidence_text')();
  TextColumn get status => text()();
  TextColumn get approvalSource =>
      text().named('approval_source').nullable()();
  TextColumn get merchantRuleUsed =>
      text().named('merchant_rule_used').nullable()();
  TextColumn get merchantRuleSource =>
      text().named('merchant_rule_source').nullable()();
  TextColumn get ignoreReason => text().named('ignore_reason').nullable()();
  TextColumn get parserVersion => text().named('parser_version').nullable()();
  TextColumn get detectedBank => text().named('detected_bank').nullable()();
  BoolColumn get requiresReview =>
      boolean().named('requires_review').withDefault(const Constant(true))();
  BoolColumn get isRead =>
      boolean().named('is_read').withDefault(const Constant(false))();
  TextColumn get linkedTransactionId =>
      text().named('linked_transaction_id').nullable()();
  TextColumn get updatedAt => text().named('updated_at')();
  TextColumn get deletedAt => text().named('deleted_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
