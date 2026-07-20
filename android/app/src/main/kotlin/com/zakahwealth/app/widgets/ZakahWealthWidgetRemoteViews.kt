package com.zakahwealth.app.widgets

import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color as AndroidColor
import android.os.Build
import android.net.Uri
import android.widget.RemoteViews
import com.zakahwealth.app.MainActivity
import com.zakahwealth.app.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale
import kotlin.math.abs

internal const val WIDGET_SNAPSHOT_KEY = "zakah_wealth_widget_snapshot"
internal const val WIDGET_SMALL_LAUNCH_URI = "zakahwealth://widget/small"
internal const val WIDGET_MEDIUM_LAUNCH_URI = "zakahwealth://widget/summary?family=medium"

internal object ZakahWealthWidgetRemoteViews {
  fun createSmall(context: Context, widgetData: SharedPreferences): RemoteViews {
    val snapshot = WidgetSnapshotData.fromPreferences(widgetData)
    val localizedContext = getLocalizedContext(context, snapshot.languageCode)
    val palette = RemoteWidgetPalette.forMode(isDarkMode(context))
    return RemoteViews(context.packageName, R.layout.zakah_wealth_widget_small).apply {
      bindSmall(context = localizedContext, snapshot = snapshot, palette = palette)
    }
  }

  fun createMedium(context: Context, widgetData: SharedPreferences): RemoteViews {
    val snapshot = WidgetSnapshotData.fromPreferences(widgetData)
    val localizedContext = getLocalizedContext(context, snapshot.languageCode)
    val palette = RemoteWidgetPalette.forMode(isDarkMode(context))
    return RemoteViews(context.packageName, R.layout.zakah_wealth_widget_medium).apply {
      bindMedium(context = localizedContext, snapshot = snapshot, palette = palette)
    }
  }

  private fun RemoteViews.bindSmall(
      context: Context,
      snapshot: WidgetSnapshotData,
      palette: RemoteWidgetPalette,
  ) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
      val direction = if (snapshot.isArabic) android.view.View.LAYOUT_DIRECTION_RTL else android.view.View.LAYOUT_DIRECTION_LTR
      setInt(R.id.widget_root, "setLayoutDirection", direction)
    }
    setInt(R.id.widget_root, "setBackgroundResource", palette.cardBackground)
    setImageViewResource(R.id.widget_header_icon, R.drawable.app_icon)
    setTextViewText(R.id.widget_header_title, snapshot.appName)
    setTextColor(R.id.widget_header_title, palette.primaryText)

    setTextViewText(
        R.id.widget_today_label,
        context.getString(R.string.widget_today_label),
    )
    setTextColor(R.id.widget_today_label, palette.mutedText)

    setTextViewText(
        R.id.widget_today_amount,
        if (snapshot.hasData) {
          snapshot.formatMainAmount(snapshot.todaySpendingMain)
        } else {
          context.getString(R.string.widget_open_app_to_sync)
        },
    )
    setTextColor(R.id.widget_today_amount, palette.primaryText)

    setTextViewText(
        R.id.widget_today_breakdown,
        smallBreakdownText(context, snapshot),
    )
    setTextColor(R.id.widget_today_breakdown, palette.mutedText)

    setInt(R.id.widget_nisab_pill, "setBackgroundResource", snapshotNisabBackground(snapshot, palette))
    setTextViewText(R.id.widget_nisab_icon, snapshotNisabIcon(snapshot))
    setTextColor(R.id.widget_nisab_icon, snapshotNisabColor(snapshot, palette))
    setTextViewText(R.id.widget_nisab_text, snapshotNisabText(context, snapshot))
    setTextColor(R.id.widget_nisab_text, snapshotNisabColor(snapshot, palette))

    setInt(
        R.id.widget_countdown_pill,
        "setBackgroundResource",
        palette.goldPillBackground,
    )
    setTextViewText(R.id.widget_countdown_icon, "⌛")
    setTextColor(R.id.widget_countdown_icon, palette.goldText)
    setTextViewText(R.id.widget_countdown_text, countdownText(context, snapshot))
    setTextColor(R.id.widget_countdown_text, palette.goldText)

    setOnClickPendingIntent(
        R.id.widget_root,
        HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse(WIDGET_SMALL_LAUNCH_URI),
        ),
    )
  }

  private fun RemoteViews.bindMedium(
      context: Context,
      snapshot: WidgetSnapshotData,
      palette: RemoteWidgetPalette,
  ) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
      val direction = if (snapshot.isArabic) android.view.View.LAYOUT_DIRECTION_RTL else android.view.View.LAYOUT_DIRECTION_LTR
      setInt(R.id.widget_root, "setLayoutDirection", direction)
    }
    setInt(R.id.widget_root, "setBackgroundResource", palette.cardBackground)
    setImageViewResource(R.id.widget_header_icon, R.drawable.app_icon)
    setTextViewText(R.id.widget_header_title, snapshot.appName)
    setTextColor(R.id.widget_header_title, palette.primaryText)

    setInt(
        R.id.widget_status_pill,
        "setBackgroundResource",
        snapshotNisabBackground(snapshot, palette),
    )
    setTextViewText(R.id.widget_status_icon, snapshotNisabIcon(snapshot))
    setTextColor(R.id.widget_status_icon, snapshotNisabColor(snapshot, palette))
    setTextViewText(R.id.widget_status_text, mediumStatusText(context, snapshot))
    setTextColor(R.id.widget_status_text, snapshotNisabColor(snapshot, palette))

    setTextViewText(
        R.id.widget_net_worth_label,
        context.getString(R.string.widget_net_worth_label),
    )
    setTextColor(R.id.widget_net_worth_label, palette.mutedText)

    setTextViewText(
        R.id.widget_net_worth_amount,
        if (snapshot.hasData) {
          snapshot.formatCompactCurrency(snapshot.netAssets)
        } else {
          context.getString(R.string.widget_open_app_to_sync)
        },
    )
    setTextColor(R.id.widget_net_worth_amount, palette.primaryText)

    setTextViewText(R.id.widget_change_text, dailyChangeText(context, snapshot))
    setTextColor(
        R.id.widget_change_text,
        if (snapshot.netAssetsChangePercentToday >= 0) palette.successText else palette.dangerText,
    )

    setInt(R.id.widget_divider_top, "setBackgroundResource", palette.dividerDrawable)
    setTextViewText(
        R.id.widget_this_month_label,
        context.getString(R.string.widget_this_month_label),
    )
    setTextColor(R.id.widget_this_month_label, palette.mutedText)

    setTextViewText(R.id.widget_income_title, label(context, "Income", "الدخل"))
    setTextViewText(R.id.widget_expenses_title, label(context, "Expenses", "المصروفات"))
    setTextViewText(R.id.widget_net_flow_title, label(context, "Net Flow", "صافي التدفق"))
    setTextColor(R.id.widget_income_title, palette.mutedText)
    setTextColor(R.id.widget_expenses_title, palette.mutedText)
    setTextColor(R.id.widget_net_flow_title, palette.mutedText)

    setTextViewText(
        R.id.widget_income_value,
        if (snapshot.hasData) snapshot.formatCompactCurrency(snapshot.incomeThisMonth) else context.getString(
            R.string.widget_open_app,
        ),
    )
    setTextViewText(
        R.id.widget_expenses_value,
        if (snapshot.hasData) snapshot.formatCompactCurrency(snapshot.expensesThisMonth) else context.getString(
            R.string.widget_open_app,
        ),
    )
    setTextViewText(
        R.id.widget_net_flow_value,
        if (snapshot.hasData) snapshot.formatCompactCurrency(snapshot.incomeThisMonth - snapshot.expensesThisMonth) else context.getString(
            R.string.widget_open_app,
        ),
    )
    setTextColor(R.id.widget_income_value, palette.successText)
    setTextColor(R.id.widget_expenses_value, palette.dangerText)
    setTextColor(
        R.id.widget_net_flow_value,
        if ((snapshot.incomeThisMonth - snapshot.expensesThisMonth) >= 0) palette.successText else palette.dangerText,
    )

    setInt(R.id.widget_divider_bottom, "setBackgroundResource", palette.dividerDrawable)
    setInt(R.id.widget_footer_pill, "setBackgroundResource", palette.goldPillBackground)
    setTextViewText(R.id.widget_footer_icon, "⌛")
    setTextColor(R.id.widget_footer_icon, palette.goldText)
    setTextViewText(R.id.widget_footer_text, countdownText(context, snapshot))
    setTextColor(R.id.widget_footer_text, palette.goldText)

    setOnClickPendingIntent(
        R.id.widget_root,
        HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse(WIDGET_MEDIUM_LAUNCH_URI),
        ),
    )
  }

  private fun snapshotNisabText(context: Context, snapshot: WidgetSnapshotData): String {
    if (!snapshot.hasData) {
      return context.getString(R.string.widget_open_app_to_sync)
    }
    val value = snapshot.zakahStatus.trim()
    return if (value.isEmpty()) context.getString(R.string.widget_above_nisab) else value
  }

  private fun mediumStatusText(context: Context, snapshot: WidgetSnapshotData): String {
    if (!snapshot.hasData) {
      return context.getString(R.string.widget_open_app)
    }
    val value = snapshot.zakahStatus.trim()
    return if (value.isEmpty()) context.getString(R.string.widget_above_nisab) else value
  }

  private fun snapshotNisabIcon(snapshot: WidgetSnapshotData): String {
    if (!snapshot.hasData) {
      return "!"
    }
    return if (isBelowNisab(snapshot.zakahStatus)) "!" else "۞"
  }

  private fun snapshotNisabColor(snapshot: WidgetSnapshotData, palette: RemoteWidgetPalette): Int {
    if (!snapshot.hasData) {
      return palette.goldText
    }
    return if (isBelowNisab(snapshot.zakahStatus)) palette.goldText else palette.successText
  }

  private fun snapshotNisabBackground(snapshot: WidgetSnapshotData, palette: RemoteWidgetPalette): Int {
    if (!snapshot.hasData) {
      return palette.goldPillBackground
    }
    return if (isBelowNisab(snapshot.zakahStatus)) palette.goldPillBackground else palette.successPillBackground
  }

  private fun countdownText(context: Context, snapshot: WidgetSnapshotData): String {
    if (!snapshot.hasData) {
      return context.getString(R.string.widget_open_app_to_sync)
    }
    snapshot.nextZakahDays?.let { days ->
      return when {
        days <= 0 -> context.getString(R.string.widget_due_today)
        snapshot.isArabic -> context.getString(R.string.widget_days_to_zakah, days)
        else -> context.getString(R.string.widget_days_to_zakah, days)
      }
    }
    val text = snapshot.nextZakahText.trim()
    if (text.isEmpty()) {
      return context.getString(R.string.widget_zakah_not_scheduled)
    }
    val lowered = text.lowercase(Locale.ROOT)
    return when {
      lowered.contains("due today") -> context.getString(R.string.widget_due_today)
      lowered.contains("not scheduled") -> context.getString(R.string.widget_zakah_not_scheduled)
      else -> text
    }
  }

  private fun dailyChangeText(context: Context, snapshot: WidgetSnapshotData): String {
    if (!snapshot.hasData) {
      return context.getString(R.string.widget_open_app)
    }
    val sign = if (snapshot.netAssetsChangePercentToday >= 0) "▲" else "▼"
    val percent = snapshot.percentText(snapshot.netAssetsChangePercentToday)
    return "$sign $percent ${context.getString(R.string.widget_today_label).lowercase(Locale.ROOT)}"
  }

  private fun smallBreakdownText(context: Context, snapshot: WidgetSnapshotData): String {
    if (!snapshot.hasData) {
      return context.getString(R.string.widget_open_app_to_sync)
    }

    val visibleItems = snapshot.todaySpendingBreakdown.sortedByDescending { it.amount }.take(3)
    if (visibleItems.isEmpty()) {
      return context.getString(R.string.widget_no_spending_today)
    }

  val segments = visibleItems.map { item ->
    "${currencyDisplayLabel(item.currencyCode)} ${snapshot.compactBreakdownAmount(item.amount)}"
  }.toMutableList()

    val extraCount =
        maxOf(0, snapshot.todaySpendingBreakdown.size - visibleItems.size) +
            maxOf(0, snapshot.todaySpendingOtherCurrenciesCount)
    if (extraCount > 0) {
      segments += "+$extraCount"
    }

    return if (visibleItems.size == 1) {
      context.getString(R.string.widget_in_currency, segments[0])
    } else {
      segments.joinToString(separator = " • ")
    }
  }

  private fun label(context: Context, english: String, arabic: String): String {
    return if (isArabic(context)) arabic else english
  }

  private fun isBelowNisab(text: String): Boolean {
    val lowered = text.lowercase(Locale.ROOT)
    return lowered.contains("below") || lowered.contains("تحت")
  }

  private fun currencyDisplayLabel(currency: String): String {
    val code = currency.trim().uppercase(Locale.ROOT)
    return when (code) {
      "", "—" -> "—"
      "$", "USD" -> "$"
      "€", "EUR" -> "€"
      "£", "GBP" -> "£"
      "E£", "EGP" -> "E£"
      "SAR" -> saudiRiyalSymbol()
      "AED" -> "د.إ"
      "QAR" -> "ر.ق"
      "KWD" -> "د.ك"
      "BHD" -> "د.ب"
      "OMR" -> "ر.ع"
      "JOD" -> "د.ا"
      "TRY" -> "₺"
      "MYR" -> "RM"
      "PKR" -> "Rs"
      "IDR" -> "Rp"
      else -> code
    }
  }

  private fun saudiRiyalSymbol(): String {
    return if (Build.VERSION.SDK_INT >= 36) "⃁" else "SR"
  }

  private fun isDarkMode(context: Context): Boolean {
    val mode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
    return mode == Configuration.UI_MODE_NIGHT_YES
  }

  private fun isArabic(context: Context): Boolean {
    return context.resources.configuration.locales[0].language.lowercase(Locale.ROOT).startsWith("ar")
  }

  private fun getLocalizedContext(context: Context, languageCode: String): Context {
    val locale = Locale(languageCode.lowercase(Locale.ROOT).substringBefore("-"))
    Locale.setDefault(locale)
    val config = Configuration(context.resources.configuration)
    config.setLocale(locale)
    return context.createConfigurationContext(config)
  }
}

internal data class WidgetSnapshotData(
    val hasData: Boolean,
    val appName: String,
    val languageCode: String,
    val mainCurrencyCode: String,
    val mainCurrencyRateToEgp: Double,
    val currencySymbol: String,
    val netAssets: Double,
    val netAssetsChangePercentToday: Double,
    val todaySpendingMain: Double,
    val todaySpendingBreakdown: List<WidgetSpendingItemData>,
    val todaySpendingOtherCurrenciesCount: Int,
    val zakahStatus: String,
    val totalExpensesThisMonth: Double,
    val incomeThisMonth: Double,
    val expensesThisMonth: Double,
    val pendingSmsCount: Int,
    val upcomingObligationsCount: Int,
    val nextZakahText: String,
    val nextZakahDays: Int?,
    val recentActivitySummary: String,
    val lastUpdated: String,
) {
  val isArabic: Boolean
    get() = languageCode.lowercase(Locale.ROOT).startsWith("ar")

  fun formatMainAmount(value: Double): String = formatCurrency(value)

  fun formatCompactCurrency(value: Double): String = formatCurrency(value, compact = true)

  fun percentText(value: Double): String = "${abs(value).toStringAsFixed(1)}%"

  fun compactBreakdownAmount(value: Double): String {
    val sign = if (value < 0) "-" else ""
    val absValue = abs(value)
    val amount = when {
      absValue >= 1_000_000_000 -> "${(absValue / 1_000_000_000).toStringAsFixed(1)}B"
      absValue >= 1_000_000 -> "${(absValue / 1_000_000).toStringAsFixed(1)}M"
      absValue >= 1_000 -> "${(absValue / 1_000).toStringAsFixed(1)}K"
      else -> absValue.toStringAsFixed(1)
    }
    return "$sign$amount"
  }

  private fun formatCurrency(value: Double, compact: Boolean = false): String {
    val sign = if (value < 0) "-" else ""
    val absValue = abs(value)
    val amount = if (compact) {
      when {
        absValue >= 1_000_000_000 -> "${(absValue / 1_000_000_000).toStringAsFixed(1)}B"
        absValue >= 1_000_000 -> "${(absValue / 1_000_000).toStringAsFixed(1)}M"
        absValue >= 1_000 -> "${(absValue / 1_000).toStringAsFixed(1)}K"
        else -> absValue.toStringAsFixed(2)
      }
    } else {
      absValue.toStringAsFixed(2)
    }
    return "$sign$currencySymbol $amount"
  }

  companion object {
    fun placeholder(): WidgetSnapshotData {
      return WidgetSnapshotData(
          hasData = false,
          appName = "Zakah Wealth",
          languageCode = "en",
          mainCurrencyCode = "EGP",
          mainCurrencyRateToEgp = 1.0,
          currencySymbol = "E£",
          netAssets = 0.0,
          netAssetsChangePercentToday = 0.0,
          todaySpendingMain = 0.0,
          todaySpendingBreakdown = emptyList(),
          todaySpendingOtherCurrenciesCount = 0,
          zakahStatus = "Open app to sync",
          totalExpensesThisMonth = 0.0,
          incomeThisMonth = 0.0,
          expensesThisMonth = 0.0,
          pendingSmsCount = 0,
          upcomingObligationsCount = 0,
          nextZakahText = "Open app to sync",
          nextZakahDays = null,
          recentActivitySummary = "Open app to sync",
          lastUpdated = "",
      )
    }

    fun fromPreferences(prefs: SharedPreferences): WidgetSnapshotData {
      val raw = prefs.getString(WIDGET_SNAPSHOT_KEY, null).orEmpty()
      if (raw.isBlank()) {
        return placeholder()
      }
      return try {
        val root = JSONObject(raw)
        val mainCurrencyCode = root.optString("mainCurrencyCode", "EGP").ifBlank { "EGP" }
        WidgetSnapshotData(
            hasData = root.optBoolean("hasData", false),
            appName = root.optString("appName", "Zakah Wealth"),
            languageCode = root.optString("languageCode", "en"),
            mainCurrencyCode = mainCurrencyCode,
            mainCurrencyRateToEgp = root.optDouble("mainCurrencyRateToEgp", 1.0),
            currencySymbol = root.optString("currencySymbol", currencySymbolFor(mainCurrencyCode)),
            netAssets = root.optDouble("netAssets", 0.0),
            netAssetsChangePercentToday = root.optDouble("netAssetsChangePercentToday", 0.0),
            todaySpendingMain = root.optDouble("todaySpendingMain", 0.0),
            todaySpendingBreakdown = readSpending(root.optJSONArray("todaySpendingBreakdown")),
            todaySpendingOtherCurrenciesCount =
                root.optInt("todaySpendingOtherCurrenciesCount", 0),
            zakahStatus = root.optString("zakahStatus", "Open app to sync"),
            totalExpensesThisMonth = root.optDouble("totalExpensesThisMonth", 0.0),
            incomeThisMonth = root.optDouble("incomeThisMonth", 0.0),
            expensesThisMonth = root.optDouble("expensesThisMonth", 0.0),
            pendingSmsCount = root.optInt("pendingSmsCount", 0),
            upcomingObligationsCount = root.optInt("upcomingObligationsCount", 0),
            nextZakahText = root.optString("nextZakahText", "Open app to sync"),
            nextZakahDays =
                if (root.has("nextZakahDays") && !root.isNull("nextZakahDays")) {
                  root.optInt("nextZakahDays")
                } else {
                  null
                },
            recentActivitySummary = root.optString("recentActivitySummary", "Open app to sync"),
            lastUpdated = root.optString("lastUpdated", ""),
        )
      } catch (_: Throwable) {
        placeholder()
      }
    }

    private fun currencySymbolFor(currencyCode: String): String {
      return when (currencyCode.trim().uppercase(Locale.ROOT)) {
        "$", "USD" -> "$"
      "€", "EUR" -> "€"
      "£", "GBP" -> "£"
      "E£", "EGP" -> "E£"
      "SAR" -> "SR"
      "AED" -> "د.إ"
        "QAR" -> "ر.ق"
        "KWD" -> "د.ك"
        "BHD" -> "د.ب"
        "OMR" -> "ر.ع"
        "JOD" -> "د.ا"
        "TRY" -> "₺"
        "MYR" -> "RM"
        "PKR" -> "Rs"
        "IDR" -> "Rp"
        else -> currencyCode.trim().uppercase(Locale.ROOT)
      }
    }

    private fun readSpending(arr: JSONArray?): List<WidgetSpendingItemData> {
      if (arr == null) return emptyList()
      return (0 until arr.length()).mapNotNull { index ->
        val item = arr.optJSONObject(index) ?: return@mapNotNull null
        WidgetSpendingItemData(
            currencyCode = item.optString("currencyCode", "EGP"),
            amount = item.optDouble("amount", 0.0),
        )
      }
    }
  }
}

internal data class WidgetSpendingItemData(
    val currencyCode: String,
    val amount: Double,
)

internal data class RemoteWidgetPalette(
    val cardBackground: Int,
    val dividerDrawable: Int,
    val successPillBackground: Int,
    val goldPillBackground: Int,
    val primaryText: Int,
    val mutedText: Int,
    val successText: Int,
    val dangerText: Int,
    val goldText: Int,
) {
  companion object {
    fun forMode(dark: Boolean): RemoteWidgetPalette {
      return if (dark) {
        RemoteWidgetPalette(
            cardBackground = R.drawable.zakah_wealth_widget_card_dark,
            dividerDrawable = R.drawable.zakah_wealth_widget_divider_dark,
            successPillBackground = R.drawable.zakah_wealth_widget_pill_success_dark,
            goldPillBackground = R.drawable.zakah_wealth_widget_pill_gold_dark,
            primaryText = AndroidColor.parseColor("#F3F4F6"),
            mutedText = AndroidColor.parseColor("#A3B0BF"),
            successText = AndroidColor.parseColor("#34D399"),
            dangerText = AndroidColor.parseColor("#F87171"),
            goldText = AndroidColor.parseColor("#D4AF37"),
        )
      } else {
        RemoteWidgetPalette(
            cardBackground = R.drawable.zakah_wealth_widget_card_light,
            dividerDrawable = R.drawable.zakah_wealth_widget_divider_light,
            successPillBackground = R.drawable.zakah_wealth_widget_pill_success_light,
            goldPillBackground = R.drawable.zakah_wealth_widget_pill_gold_light,
            primaryText = AndroidColor.parseColor("#111111"),
            mutedText = AndroidColor.parseColor("#7F8C87"),
            successText = AndroidColor.parseColor("#047857"),
            dangerText = AndroidColor.parseColor("#DC2626"),
            goldText = AndroidColor.parseColor("#C8A75B"),
        )
      }
    }
  }
}

private fun isDarkMode(context: Context): Boolean {
  val mode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
  return mode == Configuration.UI_MODE_NIGHT_YES
}

private fun isBelowNisab(text: String): Boolean {
  val lowered = text.lowercase(Locale.ROOT)
  return lowered.contains("below") || lowered.contains("تحت")
}

private fun Double.toStringAsFixed(decimals: Int): String = "%.${decimals}f".format(Locale.US, this)
