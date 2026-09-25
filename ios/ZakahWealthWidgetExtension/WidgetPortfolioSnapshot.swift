import Foundation

struct WidgetPortfolioSnapshot: Codable {
    let schemaVersion: Int
    let generatedAt: String
    let baseCurrency: String
    let yesterdayNetWorthBaseCurrency: Double?
    let nisabBasis: String
    let hideBalances: Bool
    let zakahAnnualDate: String
    let zakahPaidMonths: [String]
    let cash: [String: Double]
    let investments: [String: Double]
    let liabilities: [String: Double]
    let goldGramsByKarat: [String: Double]
    let silverGrams: Double
    let nonMarketWealthBaseCurrency: Double
    let monthlyIncomeBaseCurrency: Double
    let monthlyExpensesBaseCurrency: Double
    let pendingSmsCount: Int
    let upcomingObligationsCount: Int
    let nextZakahText: String?
    let nextZakahDays: Int?
    let todaySpendingMain: Double?
    let todaySpendingBreakdown: [WidgetCurrencySpendingItem]?
    let todaySpendingOtherCurrenciesCount: Int?
}
