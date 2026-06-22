import 'package:drift/drift.dart';

class FinancialPlans extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get startDate => text().named('start_date')();
  TextColumn get projectionCurrency => text().named('projection_currency')();
  TextColumn get startingBalanceText => text().named('starting_balance_text')();
  TextColumn get startingBalanceDate => text().named('starting_balance_date')();
  TextColumn get startingBalanceMode => text().named('starting_balance_mode')();
  TextColumn get snapshotWealthCurrency => text().named(
    'snapshot_wealth_currency',
  )();
  TextColumn get startingAssetBreakdownJson => text().named(
    'starting_asset_breakdown_json',
  )();
  TextColumn get monthlyIncomeText => text().named('monthly_income_text')();
  TextColumn get monthlyExpensesText => text().named('monthly_expenses_text')();
  BoolColumn get includeInstallments => boolean().named('include_installments')();
  BoolColumn get includeZakat => boolean().named('include_zakat')();
  IntColumn get durationYears => integer().named('duration_years')();
  TextColumn get createdAt => text().named('created_at')();
  BoolColumn get isActive => boolean().named('is_active')();
  TextColumn get startingAssetsText => text().named('starting_assets_text')();
  TextColumn get startingLiabilitiesText => text().named(
    'starting_liabilities_text',
  )();
  TextColumn get startingNetWorthText => text().named('starting_net_worth_text')();
  TextColumn get startingNisabSnapshotText => text().named(
    'starting_nisab_snapshot_text',
  )();
  TextColumn get startingGoldPriceSnapshotText => text().named(
    'starting_gold_price_snapshot_text',
  )();
  TextColumn get startingFxSnapshotJson => text().named('starting_fx_snapshot_json')();
  TextColumn get updatedAt => text().named('updated_at')();
  TextColumn get deletedAt => text().named('deleted_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
