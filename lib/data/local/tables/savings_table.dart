import 'package:drift/drift.dart';

class Savings extends Table {
  TextColumn get id => text()();
  TextColumn get assetType => text().named('asset_type')();
  TextColumn get dateAcquired => text().named('date_acquired')();
  TextColumn get amountText => text().named('amount_text')();
  TextColumn get remainingAmountText => text().named('remaining_amount_text')();
  TextColumn get unit => text()();
  TextColumn get description => text()();
  TextColumn get linkedCashEntryId =>
      text().named('linked_cash_entry_id').nullable()();
  TextColumn get purchaseCurrency => text().named('purchase_currency')();
  TextColumn get purchaseAmountText =>
      text().named('purchase_amount_text')();
  TextColumn get createdAt => text().named('created_at')();
  TextColumn get sourceIncomeId =>
      text().named('source_income_id').nullable()();
  TextColumn get exchangeSourceSavingId =>
      text().named('exchange_source_saving_id').nullable()();
  TextColumn get exchangeSourceIncomeId =>
      text().named('exchange_source_income_id').nullable()();
  BoolColumn get internalTransfer =>
      boolean().named('internal_transfer').nullable()();
  TextColumn get internalTransferType =>
      text().named('internal_transfer_type').nullable()();
  TextColumn get fundingAllocationsJson =>
      text().named('funding_allocations_json')();
  TextColumn get transferActivityId =>
      text().named('transfer_activity_id').nullable()();
  TextColumn get updatedAt => text().named('updated_at')();
  TextColumn get deletedAt => text().named('deleted_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
