import UIKit
import SwiftUI

struct WidgetSummary: Codable {
    let hasData: Bool
    let appName: String
    let languageCode: String?
    let currencySymbol: String
    let netAssets: Double
    let netAssetsChangePercentToday: Double
    let todaySpendingMain: Double?
    let todaySpendingBreakdown: [WidgetCurrencySpendingItem]?
    let todaySpendingOtherCurrenciesCount: Int?
    let zakahStatus: String
    let totalExpensesThisMonth: Double
    let incomeThisMonth: Double
    let expensesThisMonth: Double
    let pendingSmsCount: Int
    let upcomingObligationsCount: Int
    let nextZakahText: String
    let nextZakahDays: Int?
    let recentActivitySummary: String
    let lastUpdated: String

    static func placeholder() -> WidgetSummary {
        let isArabic = Locale.current.language.languageCode?.identifier.lowercased().hasPrefix("ar") == true
        return WidgetSummary(
            hasData: false,
            appName: "Zakah Wealth",
            languageCode: isArabic ? "ar" : "en",
            currencySymbol: "E£",
            netAssets: 0,
            netAssetsChangePercentToday: 0,
            todaySpendingMain: 0,
            todaySpendingBreakdown: [],
            todaySpendingOtherCurrenciesCount: 0,
            zakahStatus: "Open app to sync",
            totalExpensesThisMonth: 0,
            incomeThisMonth: 0,
            expensesThisMonth: 0,
            pendingSmsCount: 0,
            upcomingObligationsCount: 0,
            nextZakahText: "Open app to sync",
            nextZakahDays: nil,
            recentActivitySummary: "Open app to sync",
            lastUpdated: ""
        )
    }

    static func fromLegacy(_ snapshot: WidgetSnapshot) -> WidgetSummary {
        let code = snapshot.mainCurrency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let currencySymbol: String
        switch code {
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
        default: currencySymbol = code
        }
        let recentItems = snapshot.recentActivity.prefix(2).map { item -> String in
            let amount = Self.formatCurrency(item.amountMain, currency: snapshot.mainCurrency, compact: true)
            return "\(item.title) \(amount)"
        }
        return WidgetSummary(
            hasData: true,
            appName: snapshot.appName,
            languageCode: nil,
            currencySymbol: currencySymbol,
            netAssets: snapshot.netAssetsMain,
            netAssetsChangePercentToday: snapshot.netAssetDeltaPct,
            todaySpendingMain: nil,
            todaySpendingBreakdown: [],
            todaySpendingOtherCurrenciesCount: 0,
            zakahStatus: snapshot.zakahStatusLabel,
            totalExpensesThisMonth: snapshot.expensesThisMonthMain,
            incomeThisMonth: snapshot.incomeThisMonthMain,
            expensesThisMonth: snapshot.expensesThisMonthMain,
            pendingSmsCount: snapshot.pendingSmartCaptureCount,
            upcomingObligationsCount: snapshot.upcomingObligationsCount,
            nextZakahText: snapshot.nextZakahDueLabel,
            nextZakahDays: nil,
            recentActivitySummary: recentItems.isEmpty ? "Open app to sync" : recentItems.joined(separator: "\n"),
            lastUpdated: ""
        )
    }

    var isArabic: Bool {
        (languageCode ?? "en").lowercased().hasPrefix("ar")
    }

    static func formatCurrency(_ value: Double, currency: String, compact: Bool = false) -> String {
        let absValue = abs(value)
        let number: String
        if compact {
            switch absValue {
            case 1_000_000_000...:
                number = String(format: "%.1fB", absValue / 1_000_000_000)
            case 1_000_000...:
                number = String(format: "%.1fM", absValue / 1_000_000)
            case 1_000...:
                number = String(format: "%.1fK", absValue / 1_000)
            default:
                number = String(format: "%.1f", absValue)
            }
        } else {
            number = String(format: "%.2f", absValue)
        }

        let code = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let symbol: String
        switch code {
        case "SAR": symbol = "⃁"
        case "USD": symbol = "$"
        case "EUR": symbol = "€"
        case "GBP": symbol = "£"
        case "EGP": symbol = "E£"
        case "AED": symbol = "د.إ"
        case "QAR": symbol = "ر.ق"
        case "KWD": symbol = "د.ك"
        case "BHD": symbol = "د.ب"
        case "OMR": symbol = "ر.ع"
        case "JOD": symbol = "د.ا"
        case "TRY": symbol = "₺"
        case "MYR": symbol = "RM"
        case "PKR": symbol = "Rs"
        case "IDR": symbol = "Rp"
        default: symbol = code
        }
        return "\(symbol) \(number)"
    }
}

struct WidgetCurrencySpendingItem: Codable {
    let currencyCode: String
    let amount: Double
    let amountMain: Double
}

struct WidgetSnapshot: Codable {
    struct AllocationItem: Codable {
        let name: String
        let amountMain: Double
        let percentage: Double
        let colorValue: UInt32
        let iconKey: String
    }

    struct TrendItem: Codable {
        let dateKey: String
        let label: String
        let valueMain: Double
    }

    struct RecentItem: Codable {
        let title: String
        let subtitle: String
        let amountMain: Double
        let dateKey: String
        let colorValue: UInt32
        let iconKey: String
    }

    let appName: String
    let mainCurrency: String
    let hideBalances: Bool
    let balancesHiddenLabel: String
    let netAssetsEgp: Double
    let netAssetsMain: Double
    let netAssetDeltaMain: Double
    let netAssetDeltaPct: Double
    let nisabMet: Bool
    let nisabThresholdEgp: Double
    let zakahStatusLabel: String
    let nextZakahDueLabel: String
    let incomeThisMonthMain: Double
    let expensesThisMonthMain: Double
    let incomePreviousMonthMain: Double
    let expensesPreviousMonthMain: Double
    let expenseDeltaPct: Double
    let pendingSmartCaptureCount: Int
    let upcomingObligationsCount: Int
    let periodLabel: String
    let assetAllocation: [AllocationItem]
    let topCategories: [AllocationItem]
    let expenseTrend: [TrendItem]
    let recentActivity: [RecentItem]

    var hiddenOrAmount: String {
        hideBalances ? balancesHiddenLabel : Self.formatCurrency(netAssetsMain, currency: mainCurrency, compact: true)
    }

    func formatAmount(_ value: Double) -> String {
        hideBalances ? balancesHiddenLabel : Self.formatCurrency(value, currency: mainCurrency, compact: true)
    }

    func formatPercent(_ value: Double) -> String {
        Self.formatPercent(value)
    }

    static func formatCurrency(_ value: Double, currency: String, compact: Bool = false) -> String {
        let absValue = abs(value)
        let number: String
        if compact {
            switch absValue {
            case 1_000_000_000...:
                number = String(format: "%.1fB", absValue / 1_000_000_000)
            case 1_000_000...:
                number = String(format: "%.1fM", absValue / 1_000_000)
            case 1_000...:
                number = String(format: "%.1fK", absValue / 1_000)
            default:
                number = String(format: "%.1f", absValue)
            }
        } else {
            number = String(format: "%.2f", absValue)
        }

        let code = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let symbol: String
        switch code {
        case "SAR": symbol = "⃁"
        case "USD": symbol = "$"
        case "EUR": symbol = "€"
        case "GBP": symbol = "£"
        case "EGP": symbol = "E£"
        case "AED": symbol = "د.إ"
        case "QAR": symbol = "ر.ق"
        case "KWD": symbol = "د.ك"
        case "BHD": symbol = "د.ب"
        case "OMR": symbol = "ر.ع"
        case "JOD": symbol = "د.ا"
        case "TRY": symbol = "₺"
        case "MYR": symbol = "RM"
        case "PKR": symbol = "Rs"
        case "IDR": symbol = "Rp"
        default: symbol = code
        }
        return "\(symbol) \(number)"
    }

    static func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    static func placeholder() -> WidgetSnapshot {
        WidgetSnapshot(
            appName: "Zakah Wealth",
            mainCurrency: "EGP",
            hideBalances: false,
            balancesHiddenLabel: "••••••",
            netAssetsEgp: 0,
            netAssetsMain: 0,
            netAssetDeltaMain: 0,
            netAssetDeltaPct: 0,
            nisabMet: true,
            nisabThresholdEgp: 0,
            zakahStatusLabel: "Above Nisab",
            nextZakahDueLabel: "Not scheduled",
            incomeThisMonthMain: 0,
            expensesThisMonthMain: 0,
            incomePreviousMonthMain: 0,
            expensesPreviousMonthMain: 0,
            expenseDeltaPct: 0,
            pendingSmartCaptureCount: 0,
            upcomingObligationsCount: 0,
            periodLabel: "",
            assetAllocation: [],
            topCategories: [],
            expenseTrend: [],
            recentActivity: []
        )
    }
}

enum WidgetPalette {
    static let emerald = Color(red: 0.0, green: 0.34, blue: 0.28)
    static let emeraldDark = Color(red: 0.02, green: 0.07, blue: 0.06)
    static let gold = Color(red: 0.83, green: 0.68, blue: 0.22)
    static let success = Color(red: 0.06, green: 0.61, blue: 0.43)
    static let danger = Color(red: 0.86, green: 0.2, blue: 0.2)
    static let purple = Color(red: 0.49, green: 0.24, blue: 0.93)
    static let muted = Color(red: 0.62, green: 0.69, blue: 0.67)
    static let lightBackground = Color(red: 0.98, green: 0.97, blue: 0.95)
    static let lightCard = Color.white
    static let darkCard = Color(red: 0.05, green: 0.13, blue: 0.11)
    static let darkSurface = Color(red: 0.02, green: 0.08, blue: 0.07)

    static func categoryColor(_ key: String) -> Color {
        let lower = key.lowercased()
        if lower.contains("investment") { return Color(red: 0.78, green: 0.15, blue: 0.15) }
        if lower.contains("shopping") { return Color(red: 0.98, green: 0.47, blue: 0.05) }
        if lower.contains("grocer") { return Color(red: 0.09, green: 0.64, blue: 0.27) }
        if lower.contains("loan") { return Color(red: 0.15, green: 0.39, blue: 0.93) }
        if lower.contains("subscription") { return Color(red: 0.49, green: 0.24, blue: 0.93) }
        if lower.contains("other") { return Color(red: 0.39, green: 0.45, blue: 0.54) }
        return emerald
    }
}

struct WidgetDataStore {
    static let suiteName = "group.com.zakahwealth.app"
    static let snapshotKey = "zakah_wealth_widget_snapshot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    private static func snapshotData() -> Data? {
        if let data = defaults.data(forKey: snapshotKey) {
            NSLog("[WidgetKit][loadSummary] raw payload type=Data length=%d", data.count)
            return data
        }

        if let string = defaults.string(forKey: snapshotKey) {
            NSLog("[WidgetKit][loadSummary] raw payload type=String length=%d", string.utf8.count)
            return string.data(using: .utf8)
        }

        if let any = defaults.object(forKey: snapshotKey) {
            NSLog("[WidgetKit][loadSummary] raw payload unsupported type=%@", String(describing: type(of: any)))
        } else {
            NSLog("[WidgetKit][loadSummary] raw payload missing for key=%@", snapshotKey)
        }
        return nil
    }

    static func loadSummary() -> WidgetSummary {
        guard let data = snapshotData() else {
            NSLog("[WidgetKit][loadSummary] missing App Group payload for key=%@", snapshotKey)
            return .placeholder()
        }

        do {
            let summary = try JSONDecoder().decode(WidgetSummary.self, from: data)
            NSLog(
                "[WidgetKit][loadSummary] decoded WidgetSummary hasData=%@",
                summary.hasData ? "true" : "false"
            )
            return summary
        } catch {
            NSLog("[WidgetKit][loadSummary] WidgetSummary decode failed: %@", String(describing: error))
        }

        do {
            let legacy = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
            NSLog("[WidgetKit][loadSummary] decoded legacy WidgetSnapshot")
            return WidgetSummary.fromLegacy(legacy)
        } catch {
            NSLog("[WidgetKit][loadSummary] WidgetSnapshot decode failed: %@", String(describing: error))
        }

        NSLog("[WidgetKit][loadSummary] falling back to placeholder")
        return .placeholder()
    }

    static func loadSnapshot() -> WidgetSnapshot {
        guard let data = snapshotData() else {
            NSLog("[WidgetKit][loadSnapshot] failed to decode snapshot for key=%@", snapshotKey)
            return .placeholder()
        }
        do {
            let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
            NSLog("[WidgetKit][loadSnapshot] decoded snapshot")
            return snapshot
        } catch {
            NSLog("[WidgetKit][loadSnapshot] snapshot decode failed: %@", String(describing: error))
            return .placeholder()
        }
    }
}
