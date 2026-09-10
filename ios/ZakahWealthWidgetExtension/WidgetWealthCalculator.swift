import Foundation

struct WidgetWealthCalculator {
    private static let goldPurities: [String: Double] = [
        "24": 1.0,
        "22": 0.916,
        "21": 0.875,
        "18": 0.75,
        "14": 0.5833,
        "12": 0.50,
        "9": 0.375
    ]

    static func calculate(
        snapshot: WidgetPortfolioSnapshot,
        rates: WidgetMarketRates,
        isArabic: Bool
    ) -> WidgetSummary {
        let baseCurrency = snapshot.baseCurrency
        let baseRateToEgp = rates.ratesToEgp[baseCurrency] ?? 1.0

        // 1. Cash in EGP
        var totalCashEgp = 0.0
        for (currency, amount) in snapshot.cash {
            let rate = rates.ratesToEgp[currency.uppercased()] ?? 1.0
            totalCashEgp += amount * rate
        }

        // 2. Investments in EGP (currency-valued)
        var totalInvestmentsEgp = 0.0
        for (currency, amount) in snapshot.investments {
            let rate = rates.ratesToEgp[currency.uppercased()] ?? 1.0
            totalInvestmentsEgp += amount * rate
        }

        // 3. Gold in EGP
        var totalGold24kGrams = 0.0
        for (karat, grams) in snapshot.goldGramsByKarat {
            let purity = goldPurities[karat] ?? (Double(karat) ?? 24.0) / 24.0
            totalGold24kGrams += grams * purity
        }
        let goldValueEgp = totalGold24kGrams * rates.goldPrice24kEgp

        // 4. Silver in EGP
        let silverValueEgp = snapshot.silverGrams * rates.silverPriceEgp

        // 5. Non-market wealth in EGP
        let nonMarketWealthEgp = snapshot.nonMarketWealthBaseCurrency * baseRateToEgp

        // 6. Total Wealth (before liabilities) for Nisab checks
        let totalWealthEgp = totalCashEgp + goldValueEgp + silverValueEgp + totalInvestmentsEgp + nonMarketWealthEgp

        // 7. Liabilities in EGP
        var totalLiabilitiesEgp = 0.0
        for (currency, amount) in snapshot.liabilities {
            let rate = rates.ratesToEgp[currency.uppercased()] ?? 1.0
            totalLiabilitiesEgp += amount * rate
        }

        // 8. Net Assets
        let netAssetsEgp = totalWealthEgp - totalLiabilitiesEgp
        let netAssetsBase = baseRateToEgp > 0 ? netAssetsEgp / baseRateToEgp : 0.0

        // 9. Nisab Threshold calculation
        let thresholdEgp: Double
        if snapshot.nisabBasis == "silver595" {
            thresholdEgp = 595.0 * rates.silverPriceEgp
        } else {
            thresholdEgp = 85.0 * rates.goldPrice24kEgp
        }
        let nisabMet = totalWealthEgp >= thresholdEgp

        // 10. Daily Net Assets Change Percent
        var netAssetsChangePercentToday = 0.0
        if let yesterdayBase = snapshot.yesterdayNetWorthBaseCurrency, yesterdayBase > 0.01 {
            netAssetsChangePercentToday = ((netAssetsBase - yesterdayBase) / yesterdayBase) * 100.0
        }

        // 11. Format Zakah status
        let statusText = isArabic
            ? (nisabMet ? "فوق النصاب" : "تحت النصاب")
            : (nisabMet ? "Above Nisab" : "Below Nisab")

        let currencySymbol: String
        switch baseCurrency {
        case "SAR": currencySymbol = "⃁"
        case "USD": currencySymbol = "$"
        case "EUR": currencySymbol = "€"
        case "GBP": currencySymbol = "£"
        case "EGP": currencySymbol = "E£"
        case "AED": currencySymbol = "د.إ"
        case "QAR": currencySymbol = "ر.ق"
        case "KWD": currencySymbol = "د.ك"
        case "BHD": currencySymbol = "د.ب"
        case "OMR": currencySymbol = "ر.ع"
        case "JOD": currencySymbol = "د.ا"
        case "TRY": currencySymbol = "₺"
        case "MYR": currencySymbol = "RM"
        case "PKR": currencySymbol = "Rs"
        case "IDR": currencySymbol = "Rp"
        default: currencySymbol = baseCurrency
        }

        // Monthly savings (income - expenses)
        let incomeBase = snapshot.monthlyIncomeBaseCurrency
        let expensesBase = snapshot.monthlyExpensesBaseCurrency

        // Resolve Zakah Countdown label
        let nextZakahText = snapshot.nextZakahText ?? (isArabic ? "غير مجدول" : "Not scheduled")
        let nextZakahDays = snapshot.nextZakahDays

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: isArabic ? "ar" : "en")
        dateFormatter.dateFormat = "h:mm a"
        let fetchedAtStr = dateFormatter.string(from: rates.fetchedAt)
        let lastUpdatedStr = isArabic ? "تحديث \(fetchedAtStr)" : "Updated \(fetchedAtStr)"

        return WidgetSummary(
            hasData: true,
            appName: snapshot.appName ?? "Zakah Wealth",
            languageCode: isArabic ? "ar" : "en",
            currencySymbol: currencySymbol,
            netAssets: netAssetsBase,
            netAssetsChangePercentToday: netAssetsChangePercentToday,
            todaySpendingMain: snapshot.todaySpendingMain ?? 0.0,
            todaySpendingBreakdown: snapshot.todaySpendingBreakdown ?? [],
            todaySpendingOtherCurrenciesCount: snapshot.todaySpendingOtherCurrenciesCount ?? 0,
            zakahStatus: statusText,
            totalExpensesThisMonth: expensesBase,
            incomeThisMonth: incomeBase,
            expensesThisMonth: expensesBase,
            pendingSmsCount: snapshot.pendingSmsCount,
            upcomingObligationsCount: snapshot.upcomingObligationsCount,
            nextZakahText: nextZakahText,
            nextZakahDays: nextZakahDays,
            recentActivitySummary: "",
            lastUpdated: lastUpdatedStr
        )
    }
}

// Extension to allow decodable to handle missing optional fields safely
extension WidgetPortfolioSnapshot {
    var appName: String? { return "Zakah Wealth" }
}
