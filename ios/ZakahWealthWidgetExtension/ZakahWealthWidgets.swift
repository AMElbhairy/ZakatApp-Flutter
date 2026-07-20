import WidgetKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private let smallWidgetLaunchURL = URL(string: "zakahwealth://widget/small")!
private let mediumWidgetLaunchURL = URL(string: "zakahwealth://widget/summary?family=medium")!

struct ZakahWealthEntry: TimelineEntry {
    let date: Date
    let summary: WidgetSummary
}

private func widgetLog(_ message: String) {
    NSLog("[WidgetKit] %@", message)
}

struct ZakahWealthProvider: TimelineProvider {
    func placeholder(in context: Context) -> ZakahWealthEntry {
        widgetLog("placeholder requested family=\(context.family) preview=\(context.isPreview)")
        return ZakahWealthEntry(date: Date(), summary: .placeholder())
    }

    func getSnapshot(in context: Context, completion: @escaping (ZakahWealthEntry) -> Void) {
        widgetLog("getSnapshot start family=\(context.family) preview=\(context.isPreview)")
        let summary = WidgetDataStore.loadSummary()
        widgetLog("getSnapshot finished family=\(context.family) hasData=\(summary.hasData)")
        completion(ZakahWealthEntry(date: Date(), summary: summary))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZakahWealthEntry>) -> Void) {
        widgetLog("getTimeline start family=\(context.family) preview=\(context.isPreview)")
        let summary = WidgetDataStore.loadSummary()
        widgetLog("getTimeline loaded summary family=\(context.family) hasData=\(summary.hasData)")
        let entry = ZakahWealthEntry(date: Date(), summary: summary)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300))))
    }
}

struct ZakahWealthWidgetView: View {
    let entry: ZakahWealthEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    private var summary: WidgetSummary { entry.summary }
    private var dark: Bool { colorScheme == .dark }
    private var rtl: Bool { summary.isArabic }
    private var leadingAlignment: Alignment {
        rtl ? .topTrailing : .topLeading
    }
    private var monthlySavings: Double {
        summary.incomeThisMonth - summary.expensesThisMonth
    }
    private var monthlySavingsColor: Color {
        monthlySavings >= 0 ? WidgetPalette.success : WidgetPalette.danger
    }
    private var todaySpendingBreakdownItems: [WidgetCurrencySpendingItem] {
        summary.todaySpendingBreakdown ?? []
    }
    private var todaySpendingExtraCount: Int {
        summary.todaySpendingOtherCurrenciesCount ?? 0
    }
    private var todaySpendingValue: Double {
        summary.todaySpendingMain ?? 0
    }
    private var recentActivityLines: [String] {
        Array(
            summary.recentActivitySummary
                .split(whereSeparator: { $0.isNewline })
                .map { String($0) }
                .prefix(2)
        )
    }

    private var breakdownRow: some View {
        let items = todaySpendingBreakdownItems
        let visibleItems = Array(items.prefix(3))
        let segments: [String]
        if visibleItems.isEmpty {
            segments = [label("No spending today", "لا مصروفات اليوم")]
        } else {
            var built = visibleItems.map { item in
                "\(currencyDisplayLabel(item.currencyCode))\(compactWidgetAmount(item.amount))"
            }
            if todaySpendingExtraCount > 0 {
                built.append(label("+\(todaySpendingExtraCount)", "+\(todaySpendingExtraCount)"))
            }
            segments = built
        }

        return HStack(spacing: 4) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                Text(segment)
                    .font(.system(size: 9.2, weight: .medium, design: .rounded))
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity, alignment: rtl ? .trailing : .leading)
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(rtl ? .trailing : .leading)
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                GeometryReader { proxy in
                    smallWidget(size: proxy.size)
                }
            case .systemMedium:
                GeometryReader { proxy in
                    mediumWidget(size: proxy.size)
                }
            default:
                GeometryReader { proxy in
                    smallWidget(size: proxy.size)
                }
            }
        }
    }

    private func smallWidget(size: CGSize) -> some View {
        ZStack {
            smallBackground
            VStack(alignment: .leading, spacing: 0) {
                header(titleFontSize: 13, iconSize: 22)

                Spacer(minLength: 10)

                Text(label("TODAY", "اليوم"))
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .tracking(0.9)
                    .foregroundStyle(sectionLabelColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: rtl ? .trailing : .leading)
                    .multilineTextAlignment(rtl ? .trailing : .leading)

                Text(mainAmountText)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity, alignment: rtl ? .trailing : .leading)
                    .multilineTextAlignment(rtl ? .trailing : .leading)

                breakdownRow

                Spacer(minLength: 10)

                VStack(alignment: .leading, spacing: 4) {
                    plainStatusRow(
                        text: smallNisabStatusText,
                        icon: nisabStatusIconName,
                        accent: WidgetPalette.success
                    )
                    plainStatusRow(
                        text: smallZakahCountdownText,
                        icon: zakahCountdownIconName,
                        accent: WidgetPalette.gold
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
        }
        .widgetContainerBackground { smallBackground }
        .widgetURL(smallWidgetLaunchURL)
    }

    private func plainStatusRow(text: String, icon: String, accent: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accent)
            Text(text)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: rtl ? .trailing : .leading)
    }

    private func mediumWidget(size: CGSize) -> some View {
        ZStack(alignment: leadingAlignment) {
            WidgetBackgroundView(dark: dark)
            VStack(alignment: rtl ? .trailing : .leading, spacing: 0) {
                mediumHeaderRow

                Spacer(minLength: 4)

                Text(label("NET WORTH", "صافي الثروة"))
                    .font(.system(size: 8.6, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(sectionLabelColor)
                    .lineLimit(1)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if rtl {
                        todayChangeView
                        Spacer(minLength: 0)
                        amountBlock(
                            value: summary.netAssets,
                            placeholder: !summary.hasData,
                            fontSize: max(26, min(size.width * 0.102, 30))
                        )
                    } else {
                        amountBlock(
                            value: summary.netAssets,
                            placeholder: !summary.hasData,
                            fontSize: max(26, min(size.width * 0.102, 30))
                        )
                        Spacer(minLength: 0)
                        todayChangeView
                    }
                }

                Spacer(minLength: 4)

                Divider()
                    .overlay(Color.white.opacity(dark ? 0.08 : 0.10))

                Spacer(minLength: 4)

                Text(label("THIS MONTH", "هذا الشهر"))
                    .font(.system(size: 8.6, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(sectionLabelColor)
                    .lineLimit(1)

                Spacer(minLength: 3)

                HStack(alignment: .top, spacing: 8) {
                    if rtl {
                        monthlyMetricColumn(
                            title: label("Net Flow", "صافي التدفق"),
                            value: summary.hasData ? amountText(monthlyNetFlow) : label("Sync", "مزامنة"),
                            accent: monthlyNetFlowColor
                        )
                        monthlyMetricColumn(
                            title: label("Expenses", "المصروفات"),
                            value: summary.hasData ? amountText(summary.expensesThisMonth) : label("Sync", "مزامنة"),
                            accent: WidgetPalette.danger
                        )
                        monthlyMetricColumn(
                            title: label("Income", "الدخل"),
                            value: summary.hasData ? amountText(summary.incomeThisMonth) : label("Sync", "مزامنة"),
                            accent: WidgetPalette.success
                        )
                    } else {
                        monthlyMetricColumn(
                            title: label("Income", "الدخل"),
                            value: summary.hasData ? amountText(summary.incomeThisMonth) : label("Sync", "مزامنة"),
                            accent: WidgetPalette.success
                        )
                        monthlyMetricColumn(
                            title: label("Expenses", "المصروفات"),
                            value: summary.hasData ? amountText(summary.expensesThisMonth) : label("Sync", "مزامنة"),
                            accent: WidgetPalette.danger
                        )
                        monthlyMetricColumn(
                            title: label("Net Flow", "صافي التدفق"),
                            value: summary.hasData ? amountText(monthlyNetFlow) : label("Sync", "مزامنة"),
                            accent: monthlyNetFlowColor
                        )
                    }
                }

                Spacer(minLength: 4)

                Divider()
                    .overlay(Color.white.opacity(dark ? 0.08 : 0.10))

                Spacer(minLength: 3)

                footerZakahRow
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: leadingAlignment)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: leadingAlignment)
        .widgetContainerBackground { WidgetBackgroundView(dark: dark) }
    }

    private func largeWidget(size: CGSize) -> some View {
        ZStack(alignment: leadingAlignment) {
            background
            VStack(alignment: rtl ? .trailing : .leading, spacing: 10) {
                header(titleFontSize: 13, iconSize: 26)

                VStack(alignment: rtl ? .trailing : .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: rtl ? .trailing : .leading, spacing: 6) {
                            Text(label("Net Worth", "صافي الثروة"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(sectionLabelColor)
                                .lineLimit(1)
                            amountBlock(
                                value: summary.netAssets,
                                placeholder: !summary.hasData,
                                fontSize: max(31, min(size.width * 0.11, 41))
                            )
                            changeChip
                        }

                        VStack(alignment: rtl ? .trailing : .leading, spacing: 8) {
                            statChip(
                                title: label("Status", "الحالة"),
                                value: summary.hasData ? summary.zakahStatus : label("Open app", "افتح التطبيق"),
                                accent: summary.hasData ? WidgetPalette.success : WidgetPalette.gold
                            )
                            statChip(
                                title: label("Next Zakah", "الزكاة القادمة"),
                                value: summary.hasData ? summary.nextZakahText : label("Open app", "افتح التطبيق"),
                                accent: WidgetPalette.gold
                            )
                            statChip(
                                title: label("Pending", "المعلّقة"),
                                value: "\(summary.pendingSmsCount)",
                                accent: WidgetPalette.purple
                            )
                        }
                    }

                    HStack(spacing: 8) {
                        statPill(
                            title: label("Income", "الدخل"),
                            value: summary.hasData ? amountText(summary.incomeThisMonth) : label("Open app", "افتح التطبيق"),
                            accent: WidgetPalette.success
                        )
                        statPill(
                            title: label("Expenses", "المصروفات"),
                            value: summary.hasData ? amountText(summary.expensesThisMonth) : label("Open app", "افتح التطبيق"),
                            accent: WidgetPalette.danger
                        )
                        statPill(
                            title: label("Savings", "المدخرات"),
                            value: summary.hasData ? amountText(monthlySavings) : label("Open app", "افتح التطبيق"),
                            accent: monthlySavingsColor
                        )
                    }
                }

                VStack(alignment: rtl ? .trailing : .leading, spacing: 7) {
                    Text(label("At a glance", "نظرة سريعة"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(sectionLabelColor)
                        .lineLimit(1)
                    if summary.hasData && !recentActivityLines.isEmpty {
                        ForEach(Array(recentActivityLines.enumerated()), id: \.offset) { index, line in
                            recentActivityRow(line, highlight: index == 0)
                        }
                    } else {
                        recentActivityRow(label("Open app to sync", "افتح التطبيق للمزامنة"), highlight: false)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
        }
        .widgetContainerBackground { background }
        .widgetURL(mediumWidgetLaunchURL)
    }

    private var smallBackground: some View {
        Group {
            if dark {
                LinearGradient(
                    colors: [
                        Color(red: 0.018, green: 0.028, blue: 0.028),
                        Color(red: 0.012, green: 0.10, blue: 0.09),
                        Color(red: 0.020, green: 0.18, blue: 0.15),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    RadialGradient(
                        colors: [
                            WidgetPalette.emerald.opacity(0.24),
                            Color.clear,
                        ],
                        center: rtl ? .topTrailing : .topLeading,
                        startRadius: 10,
                        endRadius: 150
                    )
                    .blendMode(.screen)
                )
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            WidgetPalette.emerald.opacity(0.08),
                            Color.clear,
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                    .blendMode(.screen)
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.992, green: 0.992, blue: 0.988),
                        Color(red: 0.982, green: 0.985, blue: 0.975),
                        Color(red: 0.970, green: 0.977, blue: 0.967),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    RadialGradient(
                        colors: [
                            WidgetPalette.emerald.opacity(0.11),
                            Color.clear,
                        ],
                        center: rtl ? .topTrailing : .topLeading,
                        startRadius: 12,
                        endRadius: 160
                    )
                    .blendMode(.multiply)
                )
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            WidgetPalette.emerald.opacity(0.05),
                            Color.clear,
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                    .blendMode(.multiply)
                )
            }

        }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: dark
                    ? [WidgetPalette.darkCard, WidgetPalette.darkSurface]
                    : [WidgetPalette.lightCard, Color(red: 0.98, green: 0.98, blue: 0.96)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.black.opacity(dark ? 0.08 : 0.05), lineWidth: 1)
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(WidgetPalette.emerald.opacity(dark ? 0.95 : 0.9))
                    .frame(height: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .padding(.horizontal, 18)
                    .padding(.top, 7)
            }
    }

    private func header(titleFontSize: CGFloat, iconSize: CGFloat) -> some View {
        HStack(spacing: 8) {
            AppIconView()
                .frame(width: iconSize, height: iconSize)
            Text(summary.appName)
                .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
    }

    private var changeChip: some View {
        Text(changeText)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(changeColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(changeColor.opacity(dark ? 0.18 : 0.14), in: Capsule())
    }

    private var placeholderPill: some View {
        Text(label("Open app to sync", "افتح التطبيق للمزامنة"))
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(secondaryTextColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background((dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)), in: Capsule())
    }

    private var changeText: String {
        let sign = summary.netAssetsChangePercentToday >= 0 ? "▲" : "▼"
        return rtl
            ? "\(String(format: "%.1f%%", abs(summary.netAssetsChangePercentToday))) \(sign) \(label("today", "اليوم"))"
            : "\(sign) \(String(format: "%.1f%% today", abs(summary.netAssetsChangePercentToday)))"
    }

    private var changeColor: Color {
        summary.netAssetsChangePercentToday >= 0 ? WidgetPalette.success : WidgetPalette.danger
    }

    private var todayChangeText: String {
        let percent = String(format: "%.1f%%", abs(summary.netAssetsChangePercentToday))
        return rtl ? "\(percent) \(label("today", "اليوم"))" : "\(percent) today"
    }

    private var mediumStatusColor: Color {
        let status = summary.zakahStatus.lowercased()
        let successDark = Color(red: 0.34, green: 0.86, blue: 0.64)
        let successLight = Color(red: 0.06, green: 0.61, blue: 0.43)
        if status.contains("below") || status.contains("تحت") {
            return dark ? successDark.opacity(0.92) : successLight.opacity(0.9)
        }
        return dark ? successDark : successLight
    }

    private var todayChangeView: some View {
        Group {
            if summary.hasData {
                HStack(spacing: 6) {
                    Image(systemName: summary.netAssetsChangePercentToday >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(changeColor)
                    Text(todayChangeText)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(changeColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            } else {
                Text(label("Open app", "افتح التطبيق"))
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)
            }
        }
    }

    private var mainAmountText: String {
        summary.hasData
            ? WidgetSummary.formatCurrency(todaySpendingValue, currency: summary.currencySymbol, compact: false)
            : label("Open app to sync", "افتح التطبيق للمزامنة")
    }

    private var nisabStatusIconName: String {
        let status = summary.zakahStatus.lowercased()
        return status.contains("below") || status.contains("تحت") ? "exclamationmark.triangle.fill" : "checkmark"
    }

    private var zakahCountdownIconName: String {
        summary.nextZakahDays != nil ? "hourglass" : "calendar"
    }

    private func amountBlock(value: Double, placeholder: Bool, fontSize: CGFloat) -> some View {
        Text(placeholder ? label("Open app to sync", "افتح التطبيق للمزامنة") : amountText(value))
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(dark ? .white : .black)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    private func label(_ english: String, _ arabic: String) -> String {
        rtl ? arabic : english
    }

    private func amountText(_ value: Double) -> String {
        let sign = value < 0 ? "-" : ""
        return "\(sign)\(WidgetSummary.formatCurrency(abs(value), currency: summary.currencySymbol, compact: true))"
    }

    private func compactWidgetAmount(_ value: Double) -> String {
        let sign = value < 0 ? "-" : ""
        let absValue = abs(value)

        if absValue >= 1_000_000_000 {
            return "\(sign)\(trimmedDecimal(absValue / 1_000_000_000, maximumFractionDigits: 1))B"
        }
        if absValue >= 1_000_000 {
            return "\(sign)\(trimmedDecimal(absValue / 1_000_000, maximumFractionDigits: 1))M"
        }
        if absValue >= 1_000 {
            return "\(sign)\(trimmedDecimal(absValue / 1_000, maximumFractionDigits: 1))k"
        }
        return "\(sign)\(trimmedDecimal(absValue, maximumFractionDigits: 1))"
    }

    private var monthlyNetFlow: Double {
        summary.incomeThisMonth - summary.expensesThisMonth
    }

    private var monthlyNetFlowColor: Color {
        monthlyNetFlow >= 0 ? WidgetPalette.success : WidgetPalette.danger
    }

    private func isAboveNisabStatus(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return lowered.contains("above") || lowered.contains("فوق")
    }

    private var nisabStatusColor: Color {
        let status = summary.zakahStatus.lowercased()
        let successDark = Color(red: 0.34, green: 0.86, blue: 0.64)
        let successLight = Color(red: 0.06, green: 0.61, blue: 0.43)
        if status.contains("below") || status.contains("تحت") {
            return dark ? successDark.opacity(0.92) : successLight.opacity(0.9)
        }
        return dark ? successDark : successLight
    }

    private var footerZakahRow: some View {
        HStack(alignment: .center) {
            if rtl {
                Spacer(minLength: 0)
            }

            countdownBadge

            if !rtl {
                Spacer(minLength: 0)
            }
        }
    }

    private var statusTitleBadge: some View {
        HStack(spacing: 6) {
            nisabBadgeIcon

            Text(nisabBadgeText)
                .font(.system(size: 9.0, weight: .semibold, design: .rounded))
                .foregroundStyle(nisabStatusColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            nisabStatusColor.opacity(dark ? 0.13 : 0.10),
            in: Capsule(style: .continuous)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(nisabStatusColor.opacity(dark ? 0.30 : 0.20), lineWidth: 1)
        )
        .fixedSize(horizontal: true, vertical: false)
    }

    private var countdownBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: zakahCountdownIconName)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(WidgetPalette.gold.opacity(dark ? 0.95 : 0.9))
                .frame(width: 14, height: 14)
                .background(
                    Circle()
                        .fill(WidgetPalette.gold.opacity(dark ? 0.16 : 0.10))
                )

            Text(nextZakahCountdownText)
                .font(.system(size: 9.0, weight: .semibold, design: .rounded))
                .foregroundStyle(WidgetPalette.gold.opacity(dark ? 0.98 : 0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(WidgetPalette.gold.opacity(dark ? 0.12 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(WidgetPalette.gold.opacity(dark ? 0.34 : 0.20), lineWidth: 1)
        )
        .fixedSize(horizontal: true, vertical: false)
    }

    private var nisabBadgeText: String {
        summary.hasData ? smallNisabStatusText : label("Open app", "افتح التطبيق")
    }

    private var nextZakahCountdownText: String {
        guard summary.hasData else {
            return label("Open app", "افتح التطبيق")
        }

        if let days = summary.nextZakahDays {
            if days <= 0 {
                return label("Due today", "اليوم")
            }
            return rtl ? "\(days) يوم حتى الزكاة" : "\(days) days to Zakah"
        }

        let text = summary.nextZakahText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return label("Not scheduled", "غير مجدولة")
        }
        let lowered = text.lowercased()
        if lowered.contains("due today") {
            return label("Due today", "اليوم")
        }
        if lowered.contains("not scheduled") {
            return label("Not scheduled", "غير مجدولة")
        }
        return text
    }

    private var nisabBadgeIcon: some View {
        Group {
            if summary.hasData && isAboveNisabStatus(smallNisabStatusText) {
                RubElHizbIconView(color: nisabStatusColor, size: 14)
            } else {
                Image(systemName: nisabStatusIconName)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(nisabStatusColor)
                    .frame(width: 14, height: 14)
                    .background(
                        Circle()
                            .fill(nisabStatusColor.opacity(dark ? 0.16 : 0.10))
                    )
            }
        }
    }

    private var mediumHeaderRow: some View {
        HStack(alignment: .center, spacing: 8) {
            headerTitle
            Spacer(minLength: 8)
            mediumStatusText
        }
        .frame(maxWidth: .infinity)
        .frame(height: 27)
    }

    private var headerTitle: some View {
        HStack(spacing: 8) {
            AppIconView()
                .frame(width: 18, height: 18)

            Text(summary.appName)
                .font(.system(size: 12.1, weight: .semibold, design: .rounded))
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var mediumStatusText: some View {
        HStack(spacing: 6) {
            if summary.hasData && isAboveNisabStatus(mediumNisabStatusText) {
                RubElHizbIconView(color: mediumStatusColor, size: 14)
            } else {
                Image(systemName: mediumNisabStatusIconName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(mediumStatusColor)
                    .frame(width: 14, height: 14)
                    .background(
                        Circle()
                            .fill(mediumStatusColor.opacity(dark ? 0.16 : 0.10))
                    )
            }
            Text(mediumNisabStatusText)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(mediumStatusColor)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            mediumStatusColor.opacity(dark ? 0.13 : 0.10),
            in: Capsule(style: .continuous)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(mediumStatusColor.opacity(dark ? 0.30 : 0.20), lineWidth: 1)
        )
        .fixedSize(horizontal: true, vertical: false)
    }

    private var mediumNisabStatusText: String {
        let value = summary.zakahStatus.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? label("Above Nisab", "فوق النصاب") : value
    }

    private var mediumNisabStatusIconName: String {
        let lowered = summary.zakahStatus.lowercased()
        return lowered.contains("below") || lowered.contains("تحت") ? "exclamationmark.triangle.fill" : "checkmark"
    }

    private var smallNisabStatusText: String {
        guard summary.hasData else {
            return label("Open app to sync", "افتح التطبيق للمزامنة")
        }
        let value = summary.zakahStatus.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? label("Above Nisab", "فوق النصاب") : value
    }

    private var smallZakahCountdownText: String {
        guard summary.hasData else {
            return label("Open app to sync", "افتح التطبيق للمزامنة")
        }

        if let days = summary.nextZakahDays {
            if days <= 0 {
                return label("Due today", "اليوم")
            }
            return rtl ? "\(days) يوم حتى الزكاة" : "\(days) days to Zakah"
        }

        let text = summary.nextZakahText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return label("Zakah not scheduled", "الزكاة غير مجدولة")
        }

        let lowered = text.lowercased()
        if lowered.contains("due today") {
            return label("Due today", "اليوم")
        }
        if lowered.contains("not scheduled") {
            return label("Zakah not scheduled", "الزكاة غير مجدولة")
        }
        return text
    }

    private func monthlyMetricColumn(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: rtl ? .trailing : .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 8.2, weight: .medium, design: .rounded))
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity, alignment: rtl ? .trailing : .leading)
        .padding(.vertical, 1)
    }

    private func recentActivityRow(_ text: String, highlight: Bool) -> some View {
        Text(text)
            .font(.system(size: 10, weight: highlight ? .semibold : .medium, design: .rounded))
            .foregroundStyle(highlight ? primaryTextColor : secondaryTextColor)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: rtl ? .trailing : .leading)
            .background(
                highlight
                ? WidgetPalette.emerald.opacity(dark ? 0.28 : 0.10)
                : (dark ? WidgetPalette.darkSurface.opacity(0.72) : Color(red: 0.97, green: 0.96, blue: 0.93)),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
    }

    private func statPill(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: rtl ? .trailing : .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: rtl ? .trailing : .leading)
        .background(
            accent.opacity(dark ? 0.14 : 0.10),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private func statChip(title: String, value: String, accent: Color) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(secondaryTextColor)
            Text(value)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(accent.opacity(dark ? 0.14 : 0.10), in: Capsule())
    }
}

struct RubElHizbIconView: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .center) {
            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .stroke(color, lineWidth: max(1, size * 0.08))
                .frame(width: size * 0.76, height: size * 0.76)

            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .stroke(color, lineWidth: max(1, size * 0.08))
                .rotationEffect(.degrees(45))
                .frame(width: size * 0.76, height: size * 0.76)

            Circle()
                .stroke(color, lineWidth: max(1, size * 0.08))
                .frame(width: size * 0.44, height: size * 0.44)

            Circle()
                .fill(color)
                .frame(width: size * 0.16, height: size * 0.16)
        }
        .frame(width: size, height: size)
    }
}

struct AppIconView: View {
    var body: some View {
        Image("WidgetAppIcon")
            .resizable()
            .scaledToFit()
    }
}

struct SmallWidgetAppIconView: View {
    var body: some View {
        Image("WidgetAppIcon")
            .resizable()
            .scaledToFit()
    }
}

struct ZakahWealthSmallWidgetView: View {
    let entry: ZakahWealthEntry
    @Environment(\.colorScheme) private var colorScheme

    private var summary: WidgetSummary { entry.summary }
    private var dark: Bool { colorScheme == .dark }
    private var rtl: Bool { summary.isArabic }
    private var breakdownItems: [WidgetCurrencySpendingItem] {
        summary.todaySpendingBreakdown ?? []
    }
    private var sortedBreakdownItems: [WidgetCurrencySpendingItem] {
        breakdownItems.sorted { $0.amountMain > $1.amountMain }
    }

    var body: some View {
        VStack(alignment: rtl ? .trailing : .leading, spacing: 0) {
            headerRow

            Spacer(minLength: 7)

            Text(label("TODAY", "اليوم"))
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .tracking(0.9)
                .foregroundStyle(sectionLabelColor)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: rtl ? .trailing : .leading)
                .multilineTextAlignment(rtl ? .trailing : .leading)

            Text(mainAmountText)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: rtl ? .trailing : .leading)
                .multilineTextAlignment(rtl ? .trailing : .leading)

            Spacer(minLength: 5)

            Text(breakdownLine)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: rtl ? .trailing : .leading)
                .multilineTextAlignment(rtl ? .trailing : .leading)

            Spacer(minLength: 6)

            statusTextStack
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .widgetContainerBackground {
            WidgetBackgroundView(dark: dark)
        }
        .widgetURL(mediumWidgetLaunchURL)
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            SmallWidgetAppIconView()
                .frame(width: 18, height: 18)
            Text("Zakah Wealth")
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .frame(height: 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusTextStack: some View {
        VStack(alignment: rtl ? .trailing : .leading, spacing: 4) {
            statusBadgeRow(
                text: nisabStatusText,
                iconName: nisabStatusIconName,
                accent: nisabStatusColor
            )

            statusBadgeRow(
                text: zakahCountdownText,
                iconName: zakahCountdownIconName,
                accent: zakahCountdownColor
            )
        }
    }

    private func statusBadgeRow(text: String, iconName: String, accent: Color) -> some View {
        HStack(spacing: 6) {
            if isAboveNisabStatus(text) {
                RubElHizbIconView(color: accent, size: 14)
            } else {
                Image(systemName: iconName)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 14, height: 14)
                    .background(
                        Circle()
                            .fill(accent.opacity(dark ? 0.18 : 0.12))
                    )
            }

            Text(text)
                .font(.system(size: 10.2, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .fixedSize(horizontal: true, vertical: false)
        .background(
            accent.opacity(dark ? 0.13 : 0.10),
            in: Capsule(style: .continuous)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(accent.opacity(dark ? 0.28 : 0.20), lineWidth: 1)
        )
    }

    private var nisabStatusIconName: String {
        let status = summary.zakahStatus.lowercased()
        return status.contains("below") || status.contains("تحت") ? "exclamationmark.triangle.fill" : "checkmark"
    }

    private var zakahCountdownIconName: String {
        summary.nextZakahDays != nil ? "hourglass" : "calendar"
    }

    private var mainAmountText: String {
        summary.hasData
            ? formattedAmount(
                summary.todaySpendingMain ?? 0,
                currency: summary.currencySymbol
            )
            : label("Open app to sync", "افتح التطبيق للمزامنة")
    }

    private var breakdownLine: String {
        guard summary.hasData else {
            return label("Open app to sync", "افتح التطبيق للمزامنة")
        }

        let visible = Array(sortedBreakdownItems.prefix(2))
        if visible.isEmpty {
            return label("No spending today", "لا مصروفات اليوم")
        }

        var parts: [String] = visible.map { item in
            "\(currencyDisplayCode(item.currencyCode)) \(formatAmount(item.amount))"
        }
        let hiddenCount = max(0, sortedBreakdownItems.count - visible.count) + max(0, summary.todaySpendingOtherCurrenciesCount ?? 0)
        if hiddenCount > 0 {
            parts.append("+\(hiddenCount)")
        }
        if visible.count == 1 {
            return "\(label("In", "في")) \(parts[0])"
        }
        return parts.joined(separator: " • ")
    }

    private var nisabStatusText: String {
        guard summary.hasData else {
            return label("Open app to sync", "افتح التطبيق للمزامنة")
        }

        let value = summary.zakahStatus.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? label("Above Nisab", "فوق النصاب") : value
    }

    private var zakahCountdownText: String {
        guard summary.hasData else {
            return label("Open app to sync", "افتح التطبيق للمزامنة")
        }

        if let days = summary.nextZakahDays {
            if days <= 0 {
                return label("Due today", "اليوم مستحق")
            }
            return rtl ? "\(days) يوم حتى الزكاة" : "\(days) days to Zakah"
        }

        let text = summary.nextZakahText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return label("Zakah not scheduled", "الزكاة غير مجدولة")
        }

        let lowered = text.lowercased()
        if lowered.contains("due today") {
            return label("Due today", "اليوم مستحق")
        }
        if lowered.contains("not scheduled") {
            return label("Zakah not scheduled", "الزكاة غير مجدولة")
        }
        return text
    }

    private func formattedAmount(_ value: Double, currency: String) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""

        if absValue >= 1_000_000_000 {
            return "\(sign)\(currencyDisplayCode(currency)) \(trimmedDecimal(absValue / 1_000_000_000, maximumFractionDigits: 1))B"
        }
        if absValue >= 1_000_000 {
            return "\(sign)\(currencyDisplayCode(currency)) \(trimmedDecimal(absValue / 1_000_000, maximumFractionDigits: 1))M"
        }

        if absValue >= 1_000 {
            return "\(sign)\(currencyDisplayCode(currency)) \(trimmedDecimal(absValue / 1_000, maximumFractionDigits: 1))K"
        }

        return "\(sign)\(currencyDisplayCode(currency)) \(trimmedDecimal(absValue, maximumFractionDigits: 1))"
    }

    private func groupedDecimal(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func trimmedDecimal(_ value: Double, maximumFractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.minimumIntegerDigits = 1
        let fallback = String(format: "%.0f", value)
        switch maximumFractionDigits {
        case 0:
            return fallback
        case 1:
            return String(format: "%.1f", value)
        case 2:
            return String(format: "%.2f", value)
        case 3:
            return String(format: "%.3f", value)
        default:
            return String(format: "%.4f", value)
        }
    }

    private func currencyDisplayCode(_ currency: String) -> String {
        let code = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch code {
        case "", "—":
            return "—"
        case "$", "USD":
            return "$"
        case "€", "EUR":
            return "€"
        case "£", "GBP":
            return "£"
        case "E£", "EGP":
            return "E£"
        case "SAR":
            return "⃁"
        case "AED":
            return "د.إ"
        case "QAR":
            return "ر.ق"
        case "KWD":
            return "د.ك"
        case "BHD":
            return "د.ب"
        case "OMR":
            return "ر.ع"
        case "JOD":
            return "د.ا"
        case "TRY":
            return "₺"
        case "MYR":
            return "RM"
        case "PKR":
            return "Rs"
        case "IDR":
            return "Rp"
        default:
            return code
        }
    }

    private func formatAmount(_ value: Double) -> String {
        let absValue = abs(value)
        if absValue >= 1_000_000_000 {
            return "\(trimmedDecimal(absValue / 1_000_000_000, maximumFractionDigits: 1))B"
        }
        if absValue >= 1_000_000 {
            return "\(trimmedDecimal(absValue / 1_000_000, maximumFractionDigits: 1))M"
        }
        if absValue >= 1_000 {
            return "\(trimmedDecimal(absValue / 1_000, maximumFractionDigits: 1))K"
        }
        return trimmedDecimal(absValue, maximumFractionDigits: 1)
    }

    private func label(_ english: String, _ arabic: String) -> String {
        rtl ? arabic : english
    }

    private var primaryTextColor: Color {
        dark ? .white : Color(red: 0.03, green: 0.11, blue: 0.10)
    }

    private var secondaryTextColor: Color {
        dark ? Color.white.opacity(0.76) : Color(red: 0.39, green: 0.45, blue: 0.44)
    }

    private var sectionLabelColor: Color {
        dark
            ? Color(red: 0.58, green: 0.98, blue: 0.86)
            : Color(red: 0.14, green: 0.47, blue: 0.38)
    }

    private var zakahCountdownColor: Color {
        WidgetPalette.gold.opacity(dark ? 0.98 : 0.92)
    }

    private var nisabStatusColor: Color {
        let status = summary.zakahStatus.lowercased()
        let successDark = Color(red: 0.34, green: 0.86, blue: 0.64)
        let successLight = Color(red: 0.06, green: 0.61, blue: 0.43)
        if status.contains("below") || status.contains("تحت") {
            return dark ? successDark.opacity(0.92) : successLight.opacity(0.9)
        }
        return dark ? successDark : successLight
    }

    private func isAboveNisabStatus(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return lowered.contains("above") || lowered.contains("فوق")
    }
}

struct WidgetBackgroundView: View {
    let dark: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: dark
                ? [
                    Color(red: 0.018, green: 0.028, blue: 0.028),
                    Color(red: 0.012, green: 0.10, blue: 0.09),
                    Color(red: 0.020, green: 0.18, blue: 0.15),
                ]
                : [
                    Color(red: 0.992, green: 0.992, blue: 0.988),
                    Color(red: 0.982, green: 0.985, blue: 0.975),
                    Color(red: 0.970, green: 0.977, blue: 0.967),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        }
    }
}

private extension ZakahWealthWidgetView {
    func shortZakahText(_ value: String) -> String {
        let parts = value.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard parts.count >= 3 else {
            return value
        }
        return parts.dropLast().joined(separator: " ")
    }

    func currencyCodeLabel(_ currency: String) -> String {
        let code = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return code.isEmpty ? "—" : code
    }

    func currencyDisplayLabel(_ currency: String) -> String {
        let code = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch code {
        case "", "—":
            return "—"
        case "$", "USD":
            return "$"
        case "€", "EUR":
            return "€"
        case "£", "GBP":
            return "£"
        case "E£", "EGP":
            return "E£"
        case "SAR":
            return "⃁"
        case "AED":
            return "د.إ"
        case "QAR":
            return "ر.ق"
        case "KWD":
            return "د.ك"
        case "BHD":
            return "د.ب"
        case "OMR":
            return "ر.ع"
        case "JOD":
            return "د.ا"
        case "TRY":
            return "₺"
        case "MYR":
            return "RM"
        case "PKR":
            return "Rs"
        case "IDR":
            return "Rp"
        default:
            return code
        }
    }

    @ViewBuilder
    var statusLineView: some View {
        if summary.hasData {
            HStack(spacing: 0) {
                Text("✓ Above Nisab")
                    .foregroundStyle(WidgetPalette.success)
                Text(" • ")
                    .foregroundStyle(secondaryTextColor)
                Text(zakahCountdownCompactText)
                    .foregroundStyle(WidgetPalette.gold)
            }
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .allowsTightening(true)
        } else {
            Text(label("Open app to sync", "افتح التطبيق للمزامنة"))
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .allowsTightening(true)
        }
    }

    var zakahCountdownCompactText: String {
        if let days = summary.nextZakahDays {
            return "\(days)d to Zakah"
        }
        return shortZakahText(summary.nextZakahText)
    }

    var primaryTextColor: Color {
        dark ? .white : Color(red: 0.03, green: 0.11, blue: 0.10)
    }

    var secondaryTextColor: Color {
        dark ? Color.white.opacity(0.68) : Color(red: 0.39, green: 0.45, blue: 0.44)
    }

    var sectionLabelColor: Color {
        WidgetPalette.emerald.opacity(dark ? 0.95 : 0.9)
    }

    func groupedDecimal(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    func trimmedDecimal(_ value: Double, maximumFractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.minimumIntegerDigits = 1
        let fallback = String(format: "%.0f", value)
        switch maximumFractionDigits {
        case 0:
            return fallback
        case 1:
            return String(format: "%.1f", value)
        case 2:
            return String(format: "%.2f", value)
        case 3:
            return String(format: "%.3f", value)
        default:
            return String(format: "%.4f", value)
        }
    }
}

struct ZakahWealthAppWidget: Widget {
    let kind = "ZakahWealthWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZakahWealthProvider()) { entry in
            ZakahWealthWidgetView(entry: entry)
        }
        .configurationDisplayName("Zakah Wealth")
        .description("Track net assets, obligations, and recent activity.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct ZakahWealthSmallWidget: Widget {
    let kind = "ZakahWealthSmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZakahWealthProvider()) { entry in
            ZakahWealthSmallWidgetView(entry: entry)
        }
        .configurationDisplayName("Zakah Wealth Spending")
        .description("Today’s spending and zakah status at a glance.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

@available(iOS 16.0, *)
struct ZakahWealthAccessoryWidget: Widget {
    let kind = "ZakahWealthAccessoryWidget"

    var body: some WidgetConfiguration {
        let base = StaticConfiguration(kind: kind, provider: ZakahWealthProvider()) { entry in
            ZakahWealthWidgetView(entry: entry)
        }
        .configurationDisplayName("Zakah Wealth Lock Screen")
        .description("Compact zakah status at a glance.")

        if #available(iOS 16.0, *) {
            return applyAccessoryFamilies16(base)
        } else {
            return applyAccessoryFamiliesAny(base)
        }
    }
}

@main
struct ZakahWealthWidgets: WidgetBundle {
    var body: some Widget {
        ZakahWealthSmallWidget()
        ZakahWealthAppWidget()
        if #available(iOS 16.0, *) {
            ZakahWealthAccessoryWidget()
        }
    }
}

@available(iOS 16.0, *)
private func applyAccessoryFamilies16(_ configuration: some WidgetConfiguration) -> some WidgetConfiguration {
    configuration.supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
}

private func applyAccessoryFamiliesAny(_ configuration: some WidgetConfiguration) -> some WidgetConfiguration {
    configuration
}

private extension View {
    @ViewBuilder
    func widgetContainerBackground<Background: View>(@ViewBuilder background: @escaping () -> Background) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) {
                background()
            }
        } else {
            self.background(background())
        }
    }
}
