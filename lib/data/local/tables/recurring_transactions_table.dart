import 'package:drift/drift.dart';

class RecurringTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get amountText => text().named('amount_text')();
  TextColumn get currency => text()();
  TextColumn get category => text()();
  TextColumn get description => text()();
  IntColumn get dayOfMonth => integer().named('day_of_month')();
  TextColumn get frequency => text()();
  TextColumn get lastProcessed => text().named('last_processed').nullable()();
  BoolColumn get enabled => boolean()();
  TextColumn get skipMonth => text().named('skip_month')();
  TextColumn get createdAt => text().named('created_at')();
  TextColumn get updatedAt => text().named('updated_at')();
  TextColumn get deletedAt => text().named('deleted_at').nullable()();
  BoolColumn get autoAdd => boolean().withDefault(const Constant(true))();
  BoolColumn get reminderEnabled => boolean().withDefault(const Constant(false))();
  IntColumn get reminderDayOffset => integer().withDefault(const Constant(0))();
  TextColumn get reminderTime => text().withDefault(const Constant('09:00'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
