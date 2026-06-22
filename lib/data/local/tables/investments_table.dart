import 'package:drift/drift.dart';

class Investments extends Table {
  TextColumn get id => text()();
  TextColumn get investmentType => text().named('investment_type')();
  TextColumn get assetSubtype => text().named('asset_subtype')();
  TextColumn get ownershipType => text().named('ownership_type')();
  TextColumn get valuationMode => text().named('valuation_mode')();
  TextColumn get currency => text()();
  TextColumn get originalPriceText => text().named('original_price_text')();
  TextColumn get totalInterestText => text().named('total_interest_text')();
  TextColumn get totalPayableText => text().named('total_payable_text')();
  TextColumn get paidAmountText => text().named('paid_amount_text')();
  TextColumn get remainingAmountText => text().named('remaining_amount_text')();
  TextColumn get installmentPlanJson =>
      text().named('installment_plan_json')();
  TextColumn get valuationDate => text().named('valuation_date')();
  TextColumn get marketValueText => text().named('market_value_text')();
  TextColumn get marketValueDate => text().named('market_value_date')();
  TextColumn get valuationSource => text().named('valuation_source')();
  TextColumn get loanBalanceText => text().named('loan_balance_text')();
  TextColumn get loanAsOfDate => text().named('loan_as_of_date')();
  TextColumn get paidAmountToDateText =>
      text().named('paid_amount_to_date_text')();
  TextColumn get ownershipSharePctText =>
      text().named('ownership_share_pct_text')();
  TextColumn get country => text()();
  TextColumn get location => text()();
  TextColumn get inflationRateText => text().named('inflation_rate_text')();
  TextColumn get estimatedCurrentValueText =>
      text().named('estimated_current_value_text')();
  TextColumn get description => text()();
  BoolColumn get noZakat =>
      boolean().named('no_zakat').withDefault(const Constant(true))();
  TextColumn get yearlyGrowthRateText =>
      text().named('yearly_growth_rate_text').nullable()();
  TextColumn get createdAt => text().named('created_at')();
  TextColumn get updatedAt => text().named('updated_at')();
  TextColumn get deletedAt => text().named('deleted_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
