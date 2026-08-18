package com.zakahwealth.app.widgets

import android.content.Context
import android.content.res.Configuration
import android.graphics.Color as AndroidColor
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.zakahwealth.app.MainActivity
import com.zakahwealth.app.R
import android.os.Build
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.actionStartActivity
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale
import kotlin.math.abs

private const val SNAPSHOT_KEY = "zakah_wealth_widget_snapshot"

class ZakahWealthGlanceAppWidget : GlanceAppWidget() {
  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    provideContent {
      val summary = WidgetSummarySnapshot.fromPreferences(currentState<HomeWidgetGlanceState>().preferences)
      val dark = isDarkMode(context)
      val palette = WidgetPalette.forMode(dark)
      WidgetContent(context = context, summary = summary, palette = palette, compact = false)
    }
  }
}

class ZakahWealthSmallGlanceAppWidget : GlanceAppWidget() {
  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    provideContent {
      val summary = WidgetSummarySnapshot.fromPreferences(currentState<HomeWidgetGlanceState>().preferences)
      val dark = isDarkMode(context)
      val palette = WidgetPalette.forMode(dark)
      WidgetContent(context = context, summary = summary, palette = palette, compact = true)
    }
  }
}

private data class WidgetSpendingItem(
    val currencyCode: String,
    val amount: Double,
)

private data class WidgetSummarySnapshot(
    val hasData: Boolean,
    val appName: String,
    val languageCode: String,
    val currencySymbol: String,
    val netAssets: Double,
    val netAssetsChangePercentToday: Double,
    val todaySpendingMain: Double,
    val todaySpendingBreakdown: List<WidgetSpendingItem>,
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

  fun amountText(value: Double): String {
    val sign = if (value < 0) "-" else ""
    val absValue = abs(value)
    val amount = when {
      absValue >= 1_000_000_000 -> "${(absValue / 1_000_000_000).toStringAsFixed(1)}B"
      absValue >= 1_000_000 -> "${(absValue / 1_000_000).toStringAsFixed(1)}M"
      absValue >= 1_000 -> "${(absValue / 1_000).toStringAsFixed(1)}K"
      else -> absValue.toStringAsFixed(2)
    }
    return "$sign$currencySymbol $amount"
  }

  fun compactAmountText(value: Double): String {
    val sign = if (value < 0) "-" else ""
    val absValue = abs(value)
    val amount = when {
      absValue >= 1_000_000_000 -> "${(absValue / 1_000_000_000).toStringAsFixed(1)}B"
      absValue >= 1_000_000 -> "${(absValue / 1_000_000).toStringAsFixed(1)}M"
      absValue >= 1_000 -> "${(absValue / 1_000).toStringAsFixed(1)}K"
      else -> absValue.toStringAsFixed(1)
    }
    return "$sign$currencySymbol $amount"
  }

  fun percentText(value: Double): String = "${abs(value).toStringAsFixed(1)}%"

  companion object {
    fun placeholder(): WidgetSummarySnapshot {
      return WidgetSummarySnapshot(
          hasData = false,
          appName = "Zakah Wealth",
          languageCode = "en",
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

    fun fromPreferences(prefs: android.content.SharedPreferences): WidgetSummarySnapshot {
      val raw = prefs.getString(SNAPSHOT_KEY, null).orEmpty()
      if (raw.isBlank()) return placeholder()
      return try {
        val root = JSONObject(raw)
        WidgetSummarySnapshot(
            hasData = root.optBoolean("hasData", false),
            appName = root.optString("appName", "Zakah Wealth"),
            languageCode = root.optString("languageCode", "en"),
            currencySymbol = root.optString("currencySymbol", "E£"),
            netAssets = root.optDouble("netAssets", 0.0),
            netAssetsChangePercentToday = root.optDouble(
                "netAssetsChangePercentToday",
                0.0,
            ),
            todaySpendingMain = root.optDouble("todaySpendingMain", 0.0),
            todaySpendingBreakdown = readSpending(root.optJSONArray("todaySpendingBreakdown")),
            todaySpendingOtherCurrenciesCount = root.optInt("todaySpendingOtherCurrenciesCount", 0),
            zakahStatus = root.optString("zakahStatus", "Open app to sync"),
            totalExpensesThisMonth = root.optDouble("totalExpensesThisMonth", 0.0),
            incomeThisMonth = root.optDouble("incomeThisMonth", 0.0),
            expensesThisMonth = root.optDouble("expensesThisMonth", 0.0),
            pendingSmsCount = root.optInt("pendingSmsCount", 0),
            upcomingObligationsCount = root.optInt("upcomingObligationsCount", 0),
            nextZakahText = root.optString("nextZakahText", "Open app to sync"),
            nextZakahDays = if (root.has("nextZakahDays") && !root.isNull("nextZakahDays")) {
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

    private fun readSpending(arr: JSONArray?): List<WidgetSpendingItem> {
      if (arr == null) return emptyList()
      return (0 until arr.length()).mapNotNull { index ->
        val item = arr.optJSONObject(index) ?: return@mapNotNull null
        WidgetSpendingItem(
            currencyCode = item.optString("currencyCode", "EGP"),
            amount = item.optDouble("amount", 0.0),
        )
      }
    }
  }
}

private data class WidgetPalette(
    val background: Int,
    val surface: Int,
    val card: Int,
    val primaryText: Int,
    val mutedText: Int,
    val success: Int,
    val successSoft: Int,
    val danger: Int,
    val gold: Int,
) {
  companion object {
    fun forMode(dark: Boolean): WidgetPalette {
      return if (dark) {
        WidgetPalette(
            background = AndroidColor.parseColor("#04110F"),
            surface = AndroidColor.parseColor("#0D221D"),
            card = AndroidColor.parseColor("#123126"),
            primaryText = AndroidColor.parseColor("#F3F4F6"),
            mutedText = AndroidColor.parseColor("#A3B0BF"),
            success = AndroidColor.parseColor("#10B981"),
            successSoft = AndroidColor.parseColor("#123F32"),
            danger = AndroidColor.parseColor("#F87171"),
            gold = AndroidColor.parseColor("#D4AF37"),
        )
      } else {
        WidgetPalette(
            background = AndroidColor.parseColor("#F9F8F3"),
            surface = AndroidColor.parseColor("#FFFFFF"),
            card = AndroidColor.parseColor("#F4F2EA"),
            primaryText = AndroidColor.parseColor("#111111"),
            mutedText = AndroidColor.parseColor("#7F8C87"),
            success = AndroidColor.parseColor("#047857"),
            successSoft = AndroidColor.parseColor("#D1FAE5"),
            danger = AndroidColor.parseColor("#DC2626"),
            gold = AndroidColor.parseColor("#C8A75B"),
        )
      }
    }
  }
}

@Composable
private fun WidgetContent(
    context: Context,
    summary: WidgetSummarySnapshot,
    palette: WidgetPalette,
    compact: Boolean,
) {
  val rootClick = actionStartActivity<MainActivity>(
      context,
      Uri.parse(
          if (compact) {
            "zakahwealth://widget/small"
          } else {
            "zakahwealth://widget/summary?family=medium"
          },
      ),
  )

  Box(
      modifier =
          GlanceModifier.fillMaxSize()
              .background(ColorProvider(Color(palette.background)))
              .padding(8.dp)
              .clickable(onClick = rootClick),
  ) {
    Column(
        modifier =
            GlanceModifier.fillMaxSize()
                .background(ColorProvider(Color(palette.surface)))
                .padding(horizontal = if (compact) 14.dp else 12.dp, vertical = if (compact) 14.dp else 12.dp),
  ) {
      if (!compact) {
        Box(
            modifier =
                GlanceModifier.fillMaxWidth()
                    .height(3.dp)
                    .padding(horizontal = 18.dp)
                    .background(ColorProvider(Color(AndroidColor.parseColor("#0F3D2E")))),
        ) {}
        Spacer(modifier = GlanceModifier.height(7.dp))
      }
      if (compact) {
        SmallWidget(summary, palette)
      } else {
        MediumWidget(summary, palette)
      }
    }
  }
}

@Composable
private fun WidgetIcon(size: androidx.compose.ui.unit.Dp) {
  Image(
      provider = ImageProvider(R.drawable.app_icon),
      contentDescription = null,
      modifier = GlanceModifier.width(size).height(size),
  )
}

@Composable
private fun SmallWidget(summary: WidgetSummarySnapshot, palette: WidgetPalette) {
  Row(
      modifier = GlanceModifier.fillMaxWidth(),
      verticalAlignment = Alignment.Vertical.CenterVertically,
  ) {
    WidgetIcon(22.dp)
    Spacer(modifier = GlanceModifier.width(8.dp))
    Column(modifier = GlanceModifier.fillMaxWidth()) {
      Text(
          text = summary.appName,
          style = TextStyle(
              color = ColorProvider(Color(palette.primaryText)),
              fontSize = 13.sp,
              fontWeight = FontWeight.Bold,
          ),
          maxLines = 1,
      )
    }
  }

  Spacer(modifier = GlanceModifier.height(10.dp))
  Text(
      text = if (summary.isArabic) "اليوم" else "TODAY",
      style = TextStyle(
          color = ColorProvider(Color(palette.mutedText)),
          fontSize = 9.5.sp,
          fontWeight = FontWeight.Medium,
      ),
      maxLines = 1,
  )
  Text(
      text = if (summary.hasData) {
        summary.amountText(summary.todaySpendingMain)
      } else {
        if (summary.isArabic) "افتح التطبيق للمزامنة" else "Open app to sync"
      },
      style = TextStyle(
          color = ColorProvider(Color(palette.primaryText)),
          fontSize = 24.sp,
          fontWeight = FontWeight.Bold,
      ),
      maxLines = 1,
  )
  Text(
      text = smallBreakdownText(summary),
      style = TextStyle(
          color = ColorProvider(Color(palette.mutedText)),
          fontSize = 10.5.sp,
          fontWeight = FontWeight.Medium,
      ),
      maxLines = 1,
  )
  Spacer(modifier = GlanceModifier.height(10.dp))
  SmallStatusStack(summary, palette)
}

@Composable
private fun SmallStatusStack(summary: WidgetSummarySnapshot, palette: WidgetPalette) {
  Column(modifier = GlanceModifier.fillMaxWidth()) {
    PlainStatusRow(
        text = smallNisabStatusText(summary),
        iconText = if (summary.hasData && isAboveNisabStatus(smallNisabStatusText(summary))) "۞" else "!",
        textColor = if (summary.hasData && isAboveNisabStatus(smallNisabStatusText(summary))) {
          palette.success
        } else {
          palette.gold
        },
    )
    Spacer(modifier = GlanceModifier.height(6.dp))
    PlainStatusRow(
        text = smallCountdownText(summary),
        iconText = "⌛",
        textColor = palette.gold,
    )
  }
}

@Composable
private fun PlainStatusRow(text: String, iconText: String, textColor: Int) {
  Row(
      verticalAlignment = Alignment.Vertical.CenterVertically,
      modifier = GlanceModifier.fillMaxWidth(),
  ) {
    Text(
        text = iconText,
        style = TextStyle(
            color = ColorProvider(Color(textColor)),
            fontSize = 9.sp,
            fontWeight = FontWeight.Bold,
        ),
        maxLines = 1,
        modifier = GlanceModifier.width(14.dp).height(14.dp),
    )
    Spacer(modifier = GlanceModifier.width(6.dp))
    Text(
        text = text,
        style = TextStyle(
            color = ColorProvider(Color(textColor)),
            fontSize = 10.5.sp,
            fontWeight = FontWeight.Medium,
        ),
        maxLines = 1,
    )
  }
}

@Composable
private fun MediumWidget(summary: WidgetSummarySnapshot, palette: WidgetPalette) {
  Row(
      modifier = GlanceModifier.fillMaxWidth(),
      verticalAlignment = Alignment.Vertical.CenterVertically,
  ) {
    Row(verticalAlignment = Alignment.Vertical.CenterVertically) {
      WidgetIcon(26.dp)
      Spacer(modifier = GlanceModifier.width(8.dp))
      Column {
        Text(
            text = summary.appName,
            style = TextStyle(
                color = ColorProvider(Color(palette.primaryText)),
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
            ),
            maxLines = 1,
        )
      }
    }
    Spacer(modifier = GlanceModifier.fillMaxWidth())
    WidgetStatusChip(
        text = mediumStatusText(summary),
        iconText = if (isAboveNisabStatus(mediumStatusText(summary))) "۞" else "✓",
        accent = if (summary.hasData && isAboveNisabStatus(mediumStatusText(summary))) {
          palette.success
        } else {
          palette.gold
        },
    )
  }

  Spacer(modifier = GlanceModifier.height(4.dp))
  Text(
      text = if (summary.isArabic) "صافي الثروة" else "NET WORTH",
      style = TextStyle(
          color = ColorProvider(Color(palette.mutedText)),
          fontSize = 8.6.sp,
          fontWeight = FontWeight.Medium,
      ),
      maxLines = 1,
  )
  Row(
      modifier = GlanceModifier.fillMaxWidth(),
      verticalAlignment = Alignment.Vertical.CenterVertically,
  ) {
    Text(
        text = if (summary.hasData) {
          summary.amountText(summary.netAssets)
        } else {
          if (summary.isArabic) "افتح التطبيق للمزامنة" else "Open app to sync"
        },
        style = TextStyle(
            color = ColorProvider(Color(palette.primaryText)),
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
        ),
        maxLines = 1,
    )
    Spacer(modifier = GlanceModifier.fillMaxWidth())
    WidgetChangeChip(summary, palette)
  }

  Spacer(modifier = GlanceModifier.height(4.dp))
  DividerLine(palette)
  Spacer(modifier = GlanceModifier.height(4.dp))

  Text(
      text = if (summary.isArabic) "هذا الشهر" else "THIS MONTH",
      style = TextStyle(
          color = ColorProvider(Color(palette.mutedText)),
          fontSize = 8.6.sp,
          fontWeight = FontWeight.Medium,
      ),
      maxLines = 1,
  )
  Spacer(modifier = GlanceModifier.height(3.dp))

  Row(modifier = GlanceModifier.fillMaxWidth()) {
    MetricColumn(
        modifier = GlanceModifier.width(88.dp),
        title = if (summary.isArabic) "الدخل" else "Income",
        value = if (summary.hasData) {
          summary.amountText(summary.incomeThisMonth)
        } else {
          if (summary.isArabic) "مزامنة" else "Sync"
        },
        accent = palette.success,
    )
    Spacer(modifier = GlanceModifier.width(8.dp))
    MetricColumn(
        modifier = GlanceModifier.width(88.dp),
        title = if (summary.isArabic) "المصروفات" else "Expenses",
        value = if (summary.hasData) {
          summary.amountText(summary.expensesThisMonth)
        } else {
          if (summary.isArabic) "مزامنة" else "Sync"
        },
        accent = palette.danger,
    )
    Spacer(modifier = GlanceModifier.width(8.dp))
    MetricColumn(
        modifier = GlanceModifier.width(88.dp),
        title = if (summary.isArabic) "صافي التدفق" else "Net Flow",
        value = if (summary.hasData) {
          summary.amountText(summary.incomeThisMonth - summary.expensesThisMonth)
        } else {
          if (summary.isArabic) "مزامنة" else "Sync"
        },
        accent = if ((summary.incomeThisMonth - summary.expensesThisMonth) >= 0) palette.success else palette.danger,
    )
  }

  Spacer(modifier = GlanceModifier.height(4.dp))
  DividerLine(palette)
  Spacer(modifier = GlanceModifier.height(3.dp))
  Box(modifier = GlanceModifier.fillMaxWidth()) {
    WidgetBadge(
        text = smallCountdownText(summary),
        iconText = "⌛",
        textColor = palette.gold,
        backgroundColor = AndroidColor.parseColor("#F5E7BE"),
    )
  }
}

@Composable
private fun WidgetStatusChip(text: String, iconText: String, accent: Int) {
  Row(
      verticalAlignment = Alignment.Vertical.CenterVertically,
      modifier =
          GlanceModifier.background(ColorProvider(Color(accent).copy(alpha = 0.12f)))
              .padding(horizontal = 8.dp, vertical = 4.dp),
  ) {
    Text(
        text = iconText,
        style = TextStyle(
            color = ColorProvider(Color(accent)),
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
        ),
        maxLines = 1,
    )
    Spacer(modifier = GlanceModifier.width(5.dp))
    Text(
        text = text,
        style = TextStyle(
            color = ColorProvider(Color(accent)),
            fontSize = 11.5.sp,
            fontWeight = FontWeight.Bold,
        ),
        maxLines = 1,
    )
  }
}

@Composable
private fun WidgetBadge(
    text: String,
    iconText: String,
    textColor: Int,
    backgroundColor: Int,
) {
  Row(
      verticalAlignment = Alignment.Vertical.CenterVertically,
      modifier =
          GlanceModifier.background(ColorProvider(Color(backgroundColor)))
              .padding(horizontal = 8.dp, vertical = 4.dp),
  ) {
    Text(
      text = iconText,
      style = TextStyle(
          color = ColorProvider(Color(textColor)),
            fontSize = 9.sp,
            fontWeight = FontWeight.Bold,
        ),
        maxLines = 1,
    )
    Spacer(modifier = GlanceModifier.width(5.dp))
    Text(
        text = text,
        style = TextStyle(
            color = ColorProvider(Color(textColor)),
            fontSize = 9.sp,
            fontWeight = FontWeight.Bold,
        ),
        maxLines = 1,
    )
  }
}

@Composable
private fun WidgetChangeChip(summary: WidgetSummarySnapshot, palette: WidgetPalette) {
  val up = summary.netAssetsChangePercentToday >= 0
  val text = "${if (up) "▲" else "▼"} ${summary.percentText(summary.netAssetsChangePercentToday)}"
  Box(
      modifier =
          GlanceModifier.background(ColorProvider(Color(palette.successSoft)))
              .padding(horizontal = 8.dp, vertical = 4.dp),
  ) {
    Text(
        text = text,
        style = TextStyle(
            color = ColorProvider(Color(if (up) palette.success else palette.danger)),
            fontSize = 9.sp,
            fontWeight = FontWeight.Bold,
        ),
        maxLines = 1,
    )
  }
}

@Composable
private fun MetricColumn(modifier: GlanceModifier, title: String, value: String, accent: Int) {
  Column(
      modifier = modifier,
  ) {
    Text(
        text = title,
        style = TextStyle(
            color = ColorProvider(Color(AndroidColor.parseColor("#7F8C87"))),
            fontSize = 8.2.sp,
            fontWeight = FontWeight.Medium,
        ),
        maxLines = 1,
    )
    Spacer(modifier = GlanceModifier.height(3.dp))
    Text(
        text = value,
        style = TextStyle(
            color = ColorProvider(Color(accent)),
            fontSize = 12.5.sp,
            fontWeight = FontWeight.Bold,
        ),
        maxLines = 1,
    )
  }
}

@Composable
private fun DividerLine(palette: WidgetPalette) {
  Box(
      modifier =
          GlanceModifier.fillMaxWidth()
              .height(1.dp)
              .background(ColorProvider(Color(AndroidColor.parseColor("#E1E0D8")))),
  ) {}
}

private fun smallNisabStatusText(summary: WidgetSummarySnapshot): String {
  if (!summary.hasData) {
    return if (summary.isArabic) "افتح التطبيق للمزامنة" else "Open app to sync"
  }
  val value = summary.zakahStatus.trim()
  return if (value.isEmpty()) {
    if (summary.isArabic) "فوق النصاب" else "Above Nisab"
  } else {
    value
  }
}

private fun mediumStatusText(summary: WidgetSummarySnapshot): String {
  if (!summary.hasData) {
    return if (summary.isArabic) "افتح التطبيق" else "Open app"
  }
  val value = summary.zakahStatus.trim()
  return if (value.isEmpty()) {
    if (summary.isArabic) "فوق النصاب" else "Above Nisab"
  } else {
    value
  }
}

private fun smallCountdownText(summary: WidgetSummarySnapshot): String {
  if (!summary.hasData) {
    return if (summary.isArabic) "افتح التطبيق للمزامنة" else "Open app to sync"
  }
  summary.nextZakahDays?.let { days ->
    if (days <= 0) {
      return if (summary.isArabic) "اليوم" else "Due today"
    }
    return if (summary.isArabic) {
      "$days يوم حتى الزكاة"
    } else {
      "$days days to Zakah"
    }
  }
  val text = summary.nextZakahText.trim()
  if (text.isEmpty()) {
    return if (summary.isArabic) "الزكاة غير مجدولة" else "Zakah not scheduled"
  }
  val lowered = text.lowercase(Locale.ROOT)
  return when {
    lowered.contains("due today") -> if (summary.isArabic) "اليوم" else "Due today"
    lowered.contains("not scheduled") -> if (summary.isArabic) "الزكاة غير مجدولة" else "Zakah not scheduled"
    else -> text
  }
}

private fun smallBreakdownText(summary: WidgetSummarySnapshot): String {
  if (!summary.hasData) {
    return if (summary.isArabic) "افتح التطبيق للمزامنة" else "Open app to sync"
  }

  val visibleItems = summary.todaySpendingBreakdown.sortedByDescending { it.amount }.take(3)
  if (visibleItems.isEmpty()) {
    return if (summary.isArabic) "لا مصروفات اليوم" else "No spending today"
  }

  val segments = visibleItems.map { item ->
    "${currencyDisplayLabel(item.currencyCode)} ${summary.compactAmountText(item.amount)}"
  }.toMutableList()

  val extraCount = maxOf(0, summary.todaySpendingBreakdown.size - visibleItems.size) +
      maxOf(0, summary.todaySpendingOtherCurrenciesCount)
  if (extraCount > 0) {
    segments += "+$extraCount"
  }

  return if (visibleItems.size == 1) {
    if (summary.isArabic) {
      "في ${segments[0]}"
    } else {
      "In ${segments[0]}"
    }
  } else {
    segments.joinToString(separator = " • ")
  }
}

  private fun currencyDisplayLabel(currency: String): String {
  val code = currency.trim().uppercase(Locale.ROOT)
  return when (code) {
    "", "—" -> "—"
    "$", "USD" -> "$"
    "€", "EUR" -> "€"
    "£", "GBP" -> "£"
    "AUD" -> "A$"
    "CAD" -> "C$"
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
  return if (Build.VERSION.SDK_INT >= 36) "⃁" else "SAR"
}

private fun isAboveNisabStatus(text: String): Boolean {
  val lowered = text.lowercase(Locale.ROOT)
  return lowered.contains("above") || lowered.contains("فوق")
}

@Composable
private fun isDarkMode(context: Context): Boolean {
  val nightMask = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
  return nightMask == Configuration.UI_MODE_NIGHT_YES
}

private fun Double.toStringAsFixed(fractionDigits: Int): String {
  return "%.${fractionDigits}f".format(Locale.US, this)
}
