import 'package:drift/drift.dart';

class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get date => text()();
  TextColumn get amountText => text().named('amount_text')();
  TextColumn get currency => text()();
  TextColumn get category => text()();
  TextColumn get description => text()();
  TextColumn get createdAt => text().named('created_at')();
  BoolColumn get rolledOver =>
      boolean().named('rolled_over').withDefault(const Constant(false))();
  TextColumn get rolledAmountText =>
      text().named('rolled_amount_text').nullable()();
  TextColumn get sourceIncomeId =>
      text().named('source_income_id').nullable()();
  TextColumn get exchangePairId =>
      text().named('exchange_pair_id').nullable()();
  TextColumn get exchangeSourceIncomeId =>
      text().named('exchange_source_income_id').nullable()();
  TextColumn get remainingAmountText =>
      text().named('remaining_amount_text').nullable()();
  TextColumn get activityType => text().named('activity_type').nullable()();
  TextColumn get costBasisText => text().named('cost_basis_text').nullable()();
  TextColumn get saleValueText => text().named('sale_value_text').nullable()();
  TextColumn get realizedGainText =>
      text().named('realized_gain_text').nullable()();
  TextColumn get realizedGainLossCurrency =>
      text().named('realized_gain_loss_currency').nullable()();
  TextColumn get metalQuantityText =>
      text().named('metal_quantity_text').nullable()();
  TextColumn get updatedAt => text().named('updated_at')();
  TextColumn get deletedAt => text().named('deleted_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
