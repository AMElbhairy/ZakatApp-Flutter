import 'package:drift/drift.dart';

class MerchantRules extends Table {
  TextColumn get id => text()();
  TextColumn get merchantName => text().named('merchant_name')();
  TextColumn get categoryId => text().named('category_id')();
  TextColumn get defaultType => text().named('default_type')();
  BoolColumn get autoApprove => boolean().named('auto_approve')();
  IntColumn get usageCount => integer().named('usage_count')();
  TextColumn get confidenceText => text().named('confidence_text')();
  TextColumn get lastUsed => text().named('last_used').nullable()();
  TextColumn get source => text()();
  TextColumn get aliasesJson => text().named('aliases_json')();
  BoolColumn get enabled => boolean()();
  BoolColumn get isBuiltinOverride =>
      boolean().named('is_builtin_override')();
  TextColumn get builtinKey => text().named('builtin_key').nullable()();
  TextColumn get updatedAt => text().named('updated_at')();
  TextColumn get deletedAt => text().named('deleted_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
