import 'package:drift/drift.dart';

class MerchantConfirmations extends Table {
  TextColumn get id => text()();
  TextColumn get merchantName => text().named('merchant_name')();
  TextColumn get categoryId => text().named('category_id')();
  IntColumn get confirmations => integer()();
  IntColumn get corrections => integer()();
  TextColumn get updatedAt => text().named('updated_at')();
  TextColumn get deletedAt => text().named('deleted_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
