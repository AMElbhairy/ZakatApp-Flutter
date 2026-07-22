import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/amount_parser.dart';
import '../core/services/zakat_engine.dart';
import '../core/services/zakat_schedule_service.dart';
import '../core/utils/category_visuals.dart';
import '../models/app_state.dart';
import '../models/financial_plan.dart';
import '../models/investment_asset.dart';
import '../models/market_snapshot.dart';
import '../models/merchant_rule.dart';
import '../models/pending_transaction.dart';
import '../models/saving.dart';
import '../models/transaction.dart';

class WidgetDataService {
  WidgetDataService._();

  static const String appGroupId = 'group.com.zakahwealth.app';
  static const String widgetDataKey = 'zakah_wealth_widget_snapshot';
  static const String wealthHistoryKey =
      'zakah_wealth_widget_net_worth_history_v2';
  static const String legacyWealthHistoryKey =
      'zakah_wealth_widget_wealth_history_v1';
  static const String smartCaptureStateKey =
      'zakah_wealth_smart_capture_state_v1';
  static const String iosWidgetKind = 'ZakahWealthWidget';
  static const String iosSmallWidgetKind = 'ZakahWealthSmallWidget';
  static const String iosAccessoryKind = 'ZakahWealthAccessoryWidget';
  static const String androidWidgetClass =
      'com.zakahwealth.app.widgets.ZakahWealthWidgetReceiver';
  static const String androidMediumWidgetClass =
      'com.zakahwealth.app.widgets.ZakahWealthMediumWidgetReceiver';
  static const List<String> _wealthHistoryCurrencies = <String>[
    'EGP',
    'USD',
    'SAR',
    'AED',
    'KWD',
    'QAR',
    'EUR',
    'GBP',
    'BHD',
    'OMR',
    'JOD',
    'TRY',
    'MYR',
    'PKR',
    'IDR',
  ];
  static const MethodChannel _widgetRefreshChannel = MethodChannel(
    'com.zakahwealth.widgets',
  );

  static bool _initialized = false;
  static String? _lastSnapshotJson;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await HomeWidget.setAppGroupId(appGroupId);
    } catch (e) {
      debugPrint('WidgetDataService.initialize failed: $e');
    }
    _initialized = true;
  }

  static Future<void> syncFromState(AppStateModel state) async {
    try {
      await initialize();

      final MarketSnapshot marketSnapshot = MarketSnapshot.fromAppStateJson(
        state.marketData,
      );
      debugPrint(
        'WidgetDataService.syncFromState start: '
        'transactions=${state.transactions.length}, '
        'savings=${state.savings.length}, '
        'investments=${state.investments.length}, '
        'pending=${state.pendingTransactions.length}, '
        'plans=${state.financialPlans.length}',
      );
      final WidgetSummary snapshot = await _buildWidgetSummary(
        state: state,
        marketSnapshot: marketSnapshot,
      );
      late final String encoded;
      try {
        encoded = jsonEncode(snapshot.toJson());
      } catch (error, stackTrace) {
        debugPrint('WidgetDataService JSON encode failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        rethrow;
      }
      late final String smartCaptureEncoded;
      try {
        smartCaptureEncoded = jsonEncode(
          _buildSmartCaptureSnapshot(state).toJson(),
        );
      } catch (error, stackTrace) {
        debugPrint('WidgetDataService smart capture encode failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        rethrow;
      }
      if (_lastSnapshotJson == encoded) {
        debugPrint(
          'WidgetDataService.syncFromState skipped: snapshot unchanged',
        );
      }
      _lastSnapshotJson = encoded;

      try {
        await HomeWidget.saveWidgetData<String>(
          widgetDataKey,
          encoded,
          appGroupId: appGroupId,
        );
        await HomeWidget.saveWidgetData<String>(
          smartCaptureStateKey,
          smartCaptureEncoded,
          appGroupId: appGroupId,
        );
      } catch (error, stackTrace) {
        debugPrint('WidgetDataService App Group save failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        rethrow;
      }
      debugPrint(
        'WidgetDataService.syncFromState wrote snapshot: '
        'hasData=${snapshot.hasData}, '
        'language=${snapshot.languageCode}, '
        'currency=${snapshot.currencySymbol}',
      );

      unawaited(_updateWidgetFamily(iosWidgetKind));
      unawaited(_updateWidgetFamily(iosSmallWidgetKind));
      unawaited(_updateWidgetFamily(iosAccessoryKind));
      unawaited(_updateAndroidWidgets());
      unawaited(_reloadAllTimelines());
    } catch (e) {
      debugPrint('WidgetDataService.syncFromState failed: $e');
    }
  }

  static Future<void> clearAll() async {
    try {
      await initialize();
      _lastSnapshotJson = null;
      await Future.wait(<Future<void>>[
        HomeWidget.saveWidgetData<String>(
          widgetDataKey,
          null,
          appGroupId: appGroupId,
        ).then((_) {}),
        HomeWidget.saveWidgetData<String>(
          smartCaptureStateKey,
          null,
          appGroupId: appGroupId,
        ).then((_) {}),
        HomeWidget.saveWidgetData<String>(
          wealthHistoryKey,
          null,
          appGroupId: appGroupId,
        ).then((_) {}),
      ]);
    } catch (error, stackTrace) {
      debugPrint('WidgetDataService.clearAll failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> _updateWidgetFamily(String widgetKind) async {
    try {
      await HomeWidget.updateWidget(
        name: widgetKind,
        iOSName: widgetKind,
        qualifiedAndroidName: androidWidgetClass,
      );
      debugPrint('WidgetDataService requested widget refresh: $widgetKind');
    } catch (error, stackTrace) {
      debugPrint(
        'WidgetDataService widget refresh failed for $widgetKind: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> _updateAndroidWidgets() async {
    try {
      await HomeWidget.updateWidget(
        name: androidMediumWidgetClass,
        qualifiedAndroidName: androidMediumWidgetClass,
      );
      debugPrint(
        'WidgetDataService requested Android widget refresh: $androidMediumWidgetClass',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'WidgetDataService Android widget refresh failed for $androidMediumWidgetClass: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> _reloadAllTimelines() async {
    if (!Platform.isIOS) {
      debugPrint('Widget timeline reload skipped on Android');
      return;
    }
    try {
      await _widgetRefreshChannel.invokeMethod<void>('reloadAllTimelines');
      debugPrint('Widget timeline reload requested');
    } catch (error, stackTrace) {
      debugPrint('Widget timeline reload skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static _SmartCaptureSnapshot _buildSmartCaptureSnapshot(AppStateModel state) {
    return _SmartCaptureSnapshot(
      smartCaptureAutoApproveEnabled: state.smartCaptureAutoApproveEnabled,
      languagePreference: state.languagePreference,
      merchantAliases: state.merchantAliases,
      merchantRules: state.merchantRules.map(
        (String key, MerchantRule rule) =>
            MapEntry<String, dynamic>(key, rule.toJson()),
      ),
    );
  }

  static Future<WidgetSummary> _buildWidgetSummary({
    required AppStateModel state,
    required MarketSnapshot marketSnapshot,
  }) async {
    final bool isArabic = _widgetLanguageCode(state) == 'ar';
    final String mainCurrency = state.mainCurrency.trim().isEmpty
        ? 'EGP'
        : state.mainCurrency.trim().toUpperCase();
    final bool hasAppData =
        state.transactions.isNotEmpty ||
        state.savings.isNotEmpty ||
        state.investments.isNotEmpty ||
        state.pendingTransactions.isNotEmpty ||
        state.financialPlans.isNotEmpty;
    if (!hasAppData) {
      return WidgetSummary.placeholder().copyWith(
        appName: 'Zakah Wealth',
        currencySymbol: _currencySymbol(mainCurrency),
        languageCode: _widgetLanguageCode(state),
        zakahStatus: _widgetCopy(
          isArabic,
          'Open app to sync',
          'افتح التطبيق للمزامنة',
        ),
        nextZakahText: _widgetCopy(
          isArabic,
          'Open app to sync',
          'افتح التطبيق للمزامنة',
        ),
        recentActivitySummary: _widgetCopy(
          isArabic,
          'Open app to sync',
          'افتح التطبيق للمزامنة',
        ),
      );
    }

    final String currencySymbol = _currencySymbol(mainCurrency);
    final DateTime now = DateTime.now();
    final DateTime today = DateUtils.dateOnly(now);
    final DateTime monthStart = _financialMonthStart(state, today);

    final bool hasMarketData = marketSnapshot.hasRequiredData;
    final MarketData marketData = _toMarketData(marketSnapshot);
    final double currentWealthEgp = hasMarketData
        ? _finiteOrZero(
            ZakatEngineService.calculateTotalWealthEgp(
              transactions: state.transactions,
              savings: state.savings,
              investments: state.investments,
              marketData: marketData,
              lastRollover: state.lastRollover,
            ),
            'currentWealthEgp',
          )
        : 0;
    final double currentNetWorthEgp = hasMarketData
        ? _finiteOrZero(
            ZakatEngineService.calculateNetWorthEgp(
              transactions: state.transactions,
              savings: state.savings,
              investments: state.investments,
              marketData: marketData,
              lastRollover: state.lastRollover,
            ),
            'currentNetWorthEgp',
          )
        : 0;
    final double currentNetWorthMain = _convertEgpToMain(
      amountEgp: currentNetWorthEgp,
      currency: mainCurrency,
      marketSnapshot: marketSnapshot,
    );
    final double mainCurrencyRateToEgp = _mainCurrencyRateToEgp(
      mainCurrency,
      marketSnapshot,
    );
    final _WealthDeltaSnapshot wealthDelta = await _resolveDailyWealthDelta(
      currentWealthEgp: currentNetWorthEgp,
      currentCurrency: mainCurrency,
      currentCurrencyRateToEgp: mainCurrencyRateToEgp,
      marketSnapshot: marketSnapshot,
      today: today,
    );
    _logWealthDelta(
      context: 'summary',
      currentWealthMain: currentNetWorthMain,
      yesterdayWealthMain: wealthDelta.yesterdayWealthMain,
      delta: wealthDelta.delta,
      percent: wealthDelta.percent,
    );

    final List<_MonthlyTotals> currentMonthTotals = _sumTransactions(
      transactions: state.transactions,
      start: monthStart,
      endExclusive: DateTime(today.year, today.month + 1, 1),
      marketSnapshot: marketSnapshot,
      currency: mainCurrency,
    );
    final double incomeThisMonth = _finiteOrZero(
      currentMonthTotals
          .where((item) => item.isIncome)
          .fold<double>(0, (double sum, item) => sum + item.amountMain),
      'incomeThisMonth',
    );
    final double expensesThisMonth = _finiteOrZero(
      currentMonthTotals
          .where((item) => !item.isIncome)
          .fold<double>(0, (double sum, item) => sum + item.amountMain),
      'expensesThisMonth',
    );

    final _TodaySpendingSummary todaySpending = _buildTodaySpending(
      transactions: state.transactions,
      marketSnapshot: marketSnapshot,
      mainCurrency: mainCurrency,
      today: today,
    );

    final bool nisabMet = hasMarketData
        ? ZakatEngineService.checkCashNisab(
            currentWealthEgp,
            marketData,
            zakatNisabBasis: state.zakatNisabBasis,
          )
        : false;

    final List<Map<String, dynamic>> schedule = hasMarketData
        ? _buildZakatSchedule(state: state, marketData: marketData)
        : const <Map<String, dynamic>>[];
    final _WidgetZakahCountdown? nextZakahInfo = _findNextUnpaidZakatDate(
      schedule,
      state.zakatPaidMonths.toSet(),
      today: today,
      isArabic: isArabic,
    );

    final int pendingSmartCaptureCount = state.pendingTransactions
        .where(
          (PendingTransaction tx) =>
              tx.status == CaptureStatus.pendingReview &&
              tx.source.trim().toLowerCase() == PendingTransactionSource.sms,
        )
        .length;
    final int upcomingObligationsCount = _buildUpcomingObligationCount(
      state,
      schedule,
      today,
    );

    final List<WidgetRecentItem> recentActivity = _buildRecentActivity(
      transactions: state.transactions,
      marketSnapshot: marketSnapshot,
      currency: mainCurrency,
      start: today.subtract(const Duration(days: 14)),
      isArabic: isArabic,
    );
    final String recentActivitySummary = recentActivity.isEmpty
        ? _widgetCopy(isArabic, 'No recent activity', 'لا توجد أنشطة حديثة')
        : recentActivity
              .take(3)
              .map(
                (WidgetRecentItem item) =>
                    '${_localizeWidgetCategory(item.title, isArabic)} ${_formatSummaryAmount(item.amountMain, currencySymbol)}',
              )
              .join('\n');

    return WidgetSummary(
      hasData: true,
      appName: 'Zakah Wealth',
      currencySymbol: currencySymbol,
      languageCode: _widgetLanguageCode(state),
      mainCurrencyCode: mainCurrency,
      mainCurrencyRateToEgp: mainCurrencyRateToEgp,
      netAssets: currentNetWorthMain,
      netAssetsChangePercentToday: wealthDelta.percent,
      todaySpendingMain: todaySpending.totalMain,
      todaySpendingBreakdown: todaySpending.items,
      todaySpendingOtherCurrenciesCount: todaySpending.otherCurrencyCount,
      zakahStatus: _widgetCopy(
        isArabic,
        nisabMet ? 'Above Nisab' : 'Below Nisab',
        nisabMet ? 'فوق النصاب' : 'تحت النصاب',
      ),
      totalExpensesThisMonth: expensesThisMonth,
      incomeThisMonth: incomeThisMonth,
      expensesThisMonth: expensesThisMonth,
      pendingSmsCount: pendingSmartCaptureCount,
      upcomingObligationsCount: upcomingObligationsCount,
      nextZakahText:
          nextZakahInfo?.dateLabel ??
          _widgetCopy(isArabic, 'Not scheduled', 'غير مجدول'),
      nextZakahDays: nextZakahInfo?.daysRemaining,
      recentActivitySummary: recentActivitySummary,
      lastUpdated: now.toUtc().toIso8601String(),
    );
  }

  static String _widgetLanguageCode(AppStateModel state) {
    return state.languagePreference.trim().toLowerCase() == 'ar' ? 'ar' : 'en';
  }

  static String _widgetCopy(bool isArabic, String english, String arabic) {
    return isArabic ? arabic : english;
  }

  static void _logWealthDelta({
    required String context,
    required double currentWealthMain,
    double? yesterdayWealthMain,
    required double delta,
    required double percent,
  }) {
    final String yesterdayText = yesterdayWealthMain == null
        ? 'unavailable'
        : yesterdayWealthMain.toStringAsFixed(2);
    debugPrint(
      'WidgetDataService.$context net worth delta: '
      'current=${currentWealthMain.toStringAsFixed(2)}, '
      'yesterday=$yesterdayText, '
      'delta=${delta.toStringAsFixed(2)}, '
      'percent=${percent.toStringAsFixed(2)}%',
    );
  }

  static Future<_WealthDeltaSnapshot> _resolveDailyWealthDelta({
    required double currentWealthEgp,
    required String currentCurrency,
    required double currentCurrencyRateToEgp,
    required MarketSnapshot marketSnapshot,
    required DateTime today,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(legacyWealthHistoryKey)) {
      await prefs.remove(legacyWealthHistoryKey);
    }
    final Map<String, _WealthHistoryEntry> history = _loadWealthHistory(
      prefs.getString(wealthHistoryKey),
    );
    final String todayKey = _dayKey(today);
    final String yesterdayKey = _dayKey(
      today.subtract(const Duration(days: 1)),
    );
    final _WealthHistoryEntry? yesterdayWealthEntry = history[yesterdayKey];
    final double currentWealthMain = _convertEgpToMain(
      amountEgp: currentWealthEgp,
      currency: currentCurrency,
      marketSnapshot: marketSnapshot,
    );
    final double? yesterdayWealthMain = yesterdayWealthEntry?.amountForCurrency(
      currencyCode: currentCurrency,
      marketSnapshot: marketSnapshot,
    );
    final double delta = yesterdayWealthMain == null
        ? 0
        : _finiteOrZero(
            currentWealthMain - yesterdayWealthMain,
            'dailyWealthDelta',
          );
    final double percent =
        yesterdayWealthMain == null || yesterdayWealthMain.abs() < 0.01
        ? 0
        : _finiteOrZero(
            (delta / yesterdayWealthMain.abs()) * 100,
            'dailyWealthDeltaPct',
          );

    history[todayKey] = _WealthHistoryEntry(
      amountEgp: currentWealthEgp,
      currencyCode: currentCurrency,
      rateToEgp: currentCurrencyRateToEgp,
      amountsByCurrency: _buildWealthAmountsByCurrency(
        currentWealthEgp,
        marketSnapshot,
      ),
    );
    await prefs.setString(
      wealthHistoryKey,
      jsonEncode(_serializeWealthHistory(history)),
    );

    if (yesterdayWealthMain == null) {
      debugPrint(
        'WidgetDataService.daily wealth history missing for $yesterdayKey; '
        'stored today snapshot only.',
      );
    } else {
      debugPrint(
        'WidgetDataService.daily wealth snapshot: '
        'todayKey=$todayKey current=${currentWealthMain.toStringAsFixed(2)} $currentCurrency, '
        'yesterdayKey=$yesterdayKey yesterday=${yesterdayWealthMain.toStringAsFixed(2)} $currentCurrency, '
        'delta=${delta.toStringAsFixed(2)}, '
        'percent=${percent.toStringAsFixed(2)}%',
      );
    }
    debugPrint(
      'WidgetDataService.daily wealth currency series: '
      'mainCurrency=$currentCurrency, '
      'mainRateToEgp=${currentCurrencyRateToEgp.toStringAsFixed(6)}, '
      'todayEntryCurrencies=${history[todayKey]?.amountsByCurrency.keys.join(",") ?? "none"}, '
      'yesterdayEntryCurrencies=${yesterdayWealthEntry?.amountsByCurrency.keys.join(",") ?? "none"}',
    );

    return _WealthDeltaSnapshot(
      yesterdayWealthMain: yesterdayWealthMain,
      delta: delta,
      percent: percent,
    );
  }

  static Map<String, _WealthHistoryEntry> _loadWealthHistory(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, _WealthHistoryEntry>{};
    }
    try {
      final Object decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, _WealthHistoryEntry>{};
      final Map<String, _WealthHistoryEntry> parsed =
          <String, _WealthHistoryEntry>{};
      for (final MapEntry<dynamic, dynamic> entry in decoded.entries) {
        final String normalizedKey = entry.key.toString().trim();
        final Object? value = entry.value;
        if (value is Map) {
          final Map<String, dynamic> entryMap = Map<String, dynamic>.from(
            value,
          );
          final double amountEgp = _finiteOrZero(
            entryMap['amountEgp'] is num
                ? (entryMap['amountEgp'] as num).toDouble()
                : double.tryParse(entryMap['amountEgp']?.toString() ?? '') ?? 0,
            'wealthHistory.amountEgp',
          );
          final String currencyCode = (entryMap['currencyCode'] ?? 'EGP')
              .toString()
              .trim()
              .toUpperCase();
          final double rateToEgp = _finiteOrZero(
            entryMap['rateToEgp'] is num
                ? (entryMap['rateToEgp'] as num).toDouble()
                : double.tryParse(entryMap['rateToEgp']?.toString() ?? '') ?? 1,
            'wealthHistory.rateToEgp',
          );
          final Map<String, double> amountsByCurrency = _parseAmountsByCurrency(
            entryMap['amountsByCurrency'],
          );
          parsed[normalizedKey] = _WealthHistoryEntry(
            amountEgp: amountEgp,
            currencyCode: currencyCode.isEmpty ? 'EGP' : currencyCode,
            rateToEgp: rateToEgp <= 0 ? 1 : rateToEgp,
            amountsByCurrency: amountsByCurrency.isEmpty
                ? <String, double>{
                    currencyCode.isEmpty ? 'EGP' : currencyCode: _finiteOrZero(
                      rateToEgp <= 0 ? amountEgp : amountEgp / rateToEgp,
                      'wealthHistory.legacyAmountMain',
                    ),
                    'EGP': amountEgp,
                  }
                : amountsByCurrency,
          );
          continue;
        }
        if (value is num) {
          parsed[normalizedKey] = _WealthHistoryEntry(
            amountEgp: value.toDouble(),
            currencyCode: 'EGP',
            rateToEgp: 1,
            amountsByCurrency: <String, double>{'EGP': value.toDouble()},
          );
          continue;
        }
        final double parsedValue = double.tryParse(value.toString()) ?? 0;
        parsed[normalizedKey] = _WealthHistoryEntry(
          amountEgp: parsedValue,
          currencyCode: 'EGP',
          rateToEgp: 1,
          amountsByCurrency: <String, double>{'EGP': parsedValue},
        );
      }
      return parsed;
    } catch (error, stackTrace) {
      debugPrint('WidgetDataService.load wealth history failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return <String, _WealthHistoryEntry>{};
    }
  }

  static Map<String, dynamic> _serializeWealthHistory(
    Map<String, _WealthHistoryEntry> history,
  ) {
    final List<String> orderedKeys = history.keys.toList()..sort();
    final Map<String, dynamic> pruned = <String, dynamic>{};
    final int start = orderedKeys.length > 14 ? orderedKeys.length - 14 : 0;
    for (final String key in orderedKeys.sublist(start)) {
      final _WealthHistoryEntry? entry = history[key];
      if (entry != null) {
        pruned[key] = entry.toJson();
      }
    }
    return pruned;
  }

  static Map<String, double> _parseAmountsByCurrency(dynamic raw) {
    if (raw is! Map) {
      return <String, double>{};
    }
    final Map<String, double> parsed = <String, double>{};
    for (final MapEntry<dynamic, dynamic> entry in raw.entries) {
      final String currencyCode = entry.key.toString().trim().toUpperCase();
      if (currencyCode.isEmpty) continue;
      final double amount = entry.value is num
          ? (entry.value as num).toDouble()
          : double.tryParse(entry.value?.toString() ?? '') ?? 0;
      parsed[currencyCode] = amount;
    }
    return parsed;
  }

  static DateTime _financialMonthStart(AppStateModel state, DateTime value) {
    final DateTime local = value.toLocal();
    final String cycle = state.financialMonthCycle.trim().toLowerCase();
    final int startDay = state.financialMonthStartDay.clamp(1, 28);
    if (cycle != 'custom' || startDay <= 1) {
      return DateTime(local.year, local.month, 1);
    }
    return local.day >= startDay
        ? DateTime(local.year, local.month, startDay)
        : DateTime(local.year, local.month - 1, startDay);
  }

  static String _localizeWidgetCategory(String category, bool isArabic) {
    if (!isArabic) return _displayCategory(category);
    switch (_normalizedCategory(category).toLowerCase()) {
      case 'salary':
        return 'الراتب';
      case 'food & dining':
        return 'الطعام والمطاعم';
      case 'transportation':
        return 'المواصلات';
      case 'shopping':
        return 'التسوق';
      case 'groceries':
        return 'البقالة';
      case 'utilities':
        return 'المرافق';
      case 'rent':
        return 'الإيجار';
      case 'transfer':
        return 'تحويل';
      case 'cash':
        return 'نقد';
      case 'investment':
        return 'استثمار';
      case 'loan':
        return 'قرض';
      case 'subscription':
      case 'subscriptions':
        return 'اشتراك';
      case 'insurance':
        return 'التأمين';
      case 'healthcare':
        return 'الرعاية الصحية';
      case 'education':
        return 'التعليم';
      case 'entertainment':
        return 'الترفيه';
      case 'charity':
        return 'صدقة';
      case 'zakat':
        return 'الزكاة';
      case 'other':
        return 'أخرى';
      default:
        return _displayCategory(category);
    }
  }

  static String _currencySymbol(String currency) {
    final String code = currency.trim().toUpperCase();
    switch (code) {
      case 'SAR':
        return _androidSaudiRiyalSymbol();
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'EGP':
        return 'E£';
      case 'AED':
        return 'د.إ';
      case 'QAR':
        return 'ر.ق';
      case 'KWD':
        return 'د.ك';
      case 'BHD':
        return 'د.ب';
      case 'OMR':
        return 'ر.ع';
      case 'JOD':
        return 'د.ا';
      case 'TRY':
        return '₺';
      case 'MYR':
        return 'RM';
      case 'PKR':
        return 'Rs';
      case 'IDR':
        return 'Rp';
      default:
        return code;
    }
  }

  static String _androidSaudiRiyalSymbol() {
    if (!Platform.isAndroid) {
      return '⃁';
    }
    final Match? match = RegExp(r'Android (\d+)').firstMatch(
      Platform.operatingSystemVersion,
    );
    final int androidVersion = int.tryParse(match?.group(1) ?? '') ?? 0;
    return androidVersion >= 16 ? '⃁' : 'SR';
  }

  static String _formatSummaryAmount(double value, String currencySymbol) {
    final String sign = value < 0 ? '-' : '';
    final double absValue = value.abs();
    final String amount = absValue >= 1_000_000_000
        ? '${(absValue / 1_000_000_000).toStringAsFixed(1)}B'
        : absValue >= 1_000_000
        ? '${(absValue / 1_000_000).toStringAsFixed(1)}M'
        : absValue >= 1_000
        ? '${(absValue / 1_000).toStringAsFixed(1)}K'
        : absValue.toStringAsFixed(1);
    return '$sign$currencySymbol $amount';
  }

  // ignore: unused_element
  static WidgetSnapshot _buildSnapshot({
    required AppStateModel state,
    required MarketSnapshot marketSnapshot,
  }) {
    final bool isArabic = _widgetLanguageCode(state) == 'ar';
    final String mainCurrency = state.mainCurrency.trim().isEmpty
        ? 'EGP'
        : state.mainCurrency.trim().toUpperCase();
    final bool hideBalances = state.biometricHideWealthEnabled;
    final DateTime now = DateTime.now();
    final DateTime today = DateUtils.dateOnly(now);
    final DateTime yesterday = today.subtract(const Duration(days: 1));
    final DateTime monthStart = _financialMonthStart(state, today);
    final DateTime previousMonthStart = DateTime(
      monthStart.year,
      monthStart.month - 1,
      1,
    );
    final DateTime currentThirtyDayStart = today.subtract(
      const Duration(days: 29),
    );

    final bool hasMarketData = marketSnapshot.hasRequiredData;
    final MarketData marketData = _toMarketData(marketSnapshot);
    final double currentWealthEgp = hasMarketData
        ? ZakatEngineService.calculateTotalWealthEgp(
            transactions: state.transactions,
            savings: state.savings,
            investments: state.investments,
            marketData: marketData,
            lastRollover: state.lastRollover,
          )
        : 0;
    final double currentNetWorthEgp = hasMarketData
        ? ZakatEngineService.calculateNetWorthEgp(
            transactions: state.transactions,
            savings: state.savings,
            investments: state.investments,
            marketData: marketData,
            lastRollover: state.lastRollover,
          )
        : 0;
    final double yesterdayNetWorthAtEgp = hasMarketData
        ? ZakatEngineService.calculateNetWorthEgpAt(
            asOf: yesterday,
            transactions: state.transactions,
            savings: state.savings,
            investments: state.investments,
            marketData: marketData,
            lastRollover: state.lastRollover,
          )
        : 0;
    final double currentNetWorthMain = _convertEgpToMain(
      amountEgp: currentNetWorthEgp,
      currency: mainCurrency,
      marketSnapshot: marketSnapshot,
    );
    final double mainCurrencyRateToEgp = _mainCurrencyRateToEgp(
      mainCurrency,
      marketSnapshot,
    );
    final double yesterdayNetWorthMain = _convertEgpToMain(
      amountEgp: yesterdayNetWorthAtEgp,
      currency: mainCurrency,
      marketSnapshot: marketSnapshot,
    );
    final double netAssetDelta = currentNetWorthMain - yesterdayNetWorthMain;
    final double netAssetDeltaPct = yesterdayNetWorthMain.abs() < 0.01
        ? 0
        : (netAssetDelta / yesterdayNetWorthMain.abs()) * 100;
    _logWealthDelta(
      context: 'snapshot',
      currentWealthMain: currentNetWorthMain,
      yesterdayWealthMain: yesterdayNetWorthMain,
      delta: netAssetDelta,
      percent: netAssetDeltaPct,
    );

    final bool nisabMet = hasMarketData
        ? ZakatEngineService.checkCashNisab(
            currentWealthEgp,
            marketData,
            zakatNisabBasis: state.zakatNisabBasis,
          )
        : false;
    final double nisabThresholdEgp = hasMarketData
        ? ZakatEngineService.cashNisabThresholdEgp(
            marketData,
            zakatNisabBasis: state.zakatNisabBasis,
          )
        : 0;

    final List<Map<String, dynamic>> schedule = hasMarketData
        ? _buildZakatSchedule(state: state, marketData: marketData)
        : const <Map<String, dynamic>>[];
    final _WidgetZakahCountdown? nextZakahInfo = _findNextUnpaidZakatDate(
      schedule,
      state.zakatPaidMonths.toSet(),
      today: today,
      isArabic: isArabic,
    );

    final List<_MonthlyTotals> currentMonthTotals = _sumTransactions(
      transactions: state.transactions,
      start: monthStart,
      endExclusive: DateTime(today.year, today.month + 1, 1),
      marketSnapshot: marketSnapshot,
      currency: mainCurrency,
    );
    final List<_MonthlyTotals> previousMonthTotals = _sumTransactions(
      transactions: state.transactions,
      start: previousMonthStart,
      endExclusive: monthStart,
      marketSnapshot: marketSnapshot,
      currency: mainCurrency,
    );
    final double incomeThisMonth = currentMonthTotals
        .where((item) => item.isIncome)
        .fold<double>(0, (double sum, item) => sum + item.amountMain);
    final double expensesThisMonth = currentMonthTotals
        .where((item) => !item.isIncome)
        .fold<double>(0, (double sum, item) => sum + item.amountMain);
    final double incomePreviousMonth = previousMonthTotals
        .where((item) => item.isIncome)
        .fold<double>(0, (double sum, item) => sum + item.amountMain);
    final double expensesPreviousMonth = previousMonthTotals
        .where((item) => !item.isIncome)
        .fold<double>(0, (double sum, item) => sum + item.amountMain);

    final List<WidgetCategoryItem> topCategories = _buildTopCategories(
      transactions: state.transactions,
      marketSnapshot: marketSnapshot,
      currency: mainCurrency,
      start: currentThirtyDayStart,
      endExclusive: DateTime(today.year, today.month, today.day + 1),
    );
    final List<WidgetAllocationItem> allocation = _buildAllocation(
      savings: state.savings,
      investments: state.investments,
      marketSnapshot: marketSnapshot,
      currency: mainCurrency,
    );
    final List<WidgetTrendPoint> trend = _buildTrend(
      transactions: state.transactions,
      marketSnapshot: marketSnapshot,
      currency: mainCurrency,
      start: currentThirtyDayStart,
      days: 30,
    );
    final List<WidgetRecentItem> recentActivity = _buildRecentActivity(
      transactions: state.transactions,
      marketSnapshot: marketSnapshot,
      currency: mainCurrency,
      start: currentThirtyDayStart,
      isArabic: isArabic,
    );

    final int pendingSmartCaptureCount = state.pendingTransactions
        .where(
          (PendingTransaction tx) =>
              tx.status == CaptureStatus.pendingReview &&
              tx.source.trim().toLowerCase() == PendingTransactionSource.sms,
        )
        .length;
    final int upcomingObligationsCount = _buildUpcomingObligationCount(
      state,
      schedule,
      today,
    );

    final String periodLabel = DateFormat(
      'MMM yyyy',
      isArabic ? 'ar' : 'en_US',
    ).format(monthStart);
    final double expenseDeltaPct = expensesPreviousMonth.abs() < 0.01
        ? 0
        : ((expensesThisMonth - expensesPreviousMonth) /
                  expensesPreviousMonth.abs()) *
              100;

    return WidgetSnapshot(
      appName: 'Zakah Wealth',
      mainCurrency: mainCurrency,
      mainCurrencyRateToEgp: mainCurrencyRateToEgp,
      hideBalances: hideBalances,
      balancesHiddenLabel: '$mainCurrency ••••••',
      netAssetsEgp: currentNetWorthEgp,
      netAssetsMain: currentNetWorthMain,
      netAssetDeltaMain: netAssetDelta,
      netAssetDeltaPct: netAssetDeltaPct,
      nisabMet: nisabMet,
      nisabThresholdEgp: nisabThresholdEgp,
      zakahStatusLabel: _widgetCopy(
        isArabic,
        nisabMet ? 'Above Nisab' : 'Below Nisab',
        nisabMet ? 'فوق النصاب' : 'تحت النصاب',
      ),
      nextZakahDueLabel:
          nextZakahInfo?.dateLabel ??
          _widgetCopy(isArabic, 'Not scheduled', 'غير مجدول'),
      incomeThisMonthMain: incomeThisMonth,
      expensesThisMonthMain: expensesThisMonth,
      incomePreviousMonthMain: incomePreviousMonth,
      expensesPreviousMonthMain: expensesPreviousMonth,
      expenseDeltaPct: expenseDeltaPct,
      pendingSmartCaptureCount: pendingSmartCaptureCount,
      upcomingObligationsCount: upcomingObligationsCount,
      periodLabel: periodLabel,
      assetAllocation: allocation,
      topCategories: topCategories,
      expenseTrend: trend,
      recentActivity: recentActivity,
    );
  }

  static List<Map<String, dynamic>> _buildZakatSchedule({
    required AppStateModel state,
    required MarketData marketData,
  }) {
    if (state.zakatMethod == 'annual') {
      return ZakatScheduleService.calculateAnnualZakatSchedule(
        zakatAnnualDate: state.zakatAnnualDate,
        transactions: state.transactions.map((e) => e.toJson()).toList(),
        savings: state.savings.map((e) => e.toJson()).toList(),
        investments: state.investments.map((e) => e.toJson()).toList(),
        marketData: marketData,
        lastRollover: state.lastRollover,
        zakatNisabBasis: state.zakatNisabBasis,
      );
    }

    return <Map<String, dynamic>>[
      ...ZakatScheduleService.calculateMonthlyZakatSchedule(
        transactions: state.transactions.map((e) => e.toJson()).toList(),
        savings: state.savings.map((e) => e.toJson()).toList(),
        marketData: marketData,
        lastRollover: state.lastRollover,
        zakatNisabBasis: state.zakatNisabBasis,
      ),
      ...ZakatScheduleService.calculateSavingsZakatSchedule(
        savings: state.savings.map((e) => e.toJson()).toList(),
        transactions: state.transactions.map((e) => e.toJson()).toList(),
        marketData: marketData,
        lastRollover: state.lastRollover,
        zakatNisabBasis: state.zakatNisabBasis,
      ),
    ];
  }

  static int _buildUpcomingObligationCount(
    AppStateModel state,
    List<Map<String, dynamic>> schedule,
    DateTime today,
  ) {
    final int nextZakat = schedule.where((Map<String, dynamic> item) {
      final String monthKey = (item['monthKey'] ?? '').toString().trim();
      if (monthKey.isEmpty || state.zakatPaidMonths.contains(monthKey)) {
        return false;
      }
      final String rawDate = (item['paymentDate'] ?? '').toString().trim();
      final DateTime? parsed = DateTime.tryParse(normalizeDateText(rawDate));
      return parsed != null && !parsed.isBefore(today);
    }).length;

    final int activePlans = state.financialPlans
        .where((FinancialPlan plan) => plan.isActive)
        .length;
    return nextZakat + activePlans;
  }

  static double _convertEgpToMain({
    required double amountEgp,
    required String currency,
    required MarketSnapshot marketSnapshot,
  }) {
    if (currency.toUpperCase().trim().isEmpty || currency == 'EGP') {
      return amountEgp;
    }
    final MarketData marketData = MarketData(
      goldPrice24kEgp: marketSnapshot.gold24kPricePerGramEgp,
      silverPriceEgp: marketSnapshot.silverPricePerGramEgp,
      usdToEgp: marketSnapshot.usdToEgp,
      sarToEgp: marketSnapshot.sarToEgp,
      ratesToEgp: <String, double>{
        'USD': marketSnapshot.usdToEgp,
        'SAR': marketSnapshot.sarToEgp,
        'AED': marketSnapshot.aedToEgp,
        'KWD': marketSnapshot.kwdToEgp,
        'QAR': marketSnapshot.qarToEgp,
        'EUR': marketSnapshot.eurToEgp,
        'GBP': marketSnapshot.gbpToEgp,
        'BHD': marketSnapshot.bhdToEgp,
        'OMR': marketSnapshot.omrToEgp,
        'JOD': marketSnapshot.jodToEgp,
        'TRY': marketSnapshot.tryToEgp,
        'MYR': marketSnapshot.myrToEgp,
        'PKR': marketSnapshot.pkrToEgp,
        'IDR': marketSnapshot.idrToEgp,
      },
    );
    final double converted = ZakatEngineService.convertFromEgp(
      amountEgp,
      currency,
      marketData,
    );
    if (converted.isFinite) return converted;
    debugPrint(
      'WidgetDataService._convertEgpToMain non-finite conversion '
      'for currency=$currency; falling back to amountEgp',
    );
    return amountEgp.isFinite ? amountEgp : 0;
  }

  static double _mainCurrencyRateToEgp(
    String currency,
    MarketSnapshot marketSnapshot,
  ) {
    final String normalized = currency.trim().toUpperCase();
    switch (normalized) {
      case '':
      case 'EGP':
        return 1;
      case 'USD':
        return marketSnapshot.usdToEgp;
      case 'SAR':
        return marketSnapshot.sarToEgp;
      case 'AED':
        return marketSnapshot.aedToEgp;
      case 'KWD':
        return marketSnapshot.kwdToEgp;
      case 'QAR':
        return marketSnapshot.qarToEgp;
      case 'EUR':
        return marketSnapshot.eurToEgp;
      case 'GBP':
        return marketSnapshot.gbpToEgp;
      case 'BHD':
        return marketSnapshot.bhdToEgp;
      case 'OMR':
        return marketSnapshot.omrToEgp;
      case 'JOD':
        return marketSnapshot.jodToEgp;
      case 'TRY':
        return marketSnapshot.tryToEgp;
      case 'MYR':
        return marketSnapshot.myrToEgp;
      case 'PKR':
        return marketSnapshot.pkrToEgp;
      case 'IDR':
        return marketSnapshot.idrToEgp;
      default:
        return 0;
    }
  }

  static Map<String, double> _buildWealthAmountsByCurrency(
    double amountEgp,
    MarketSnapshot marketSnapshot,
  ) {
    final Map<String, double> values = <String, double>{};
    for (final String code in _wealthHistoryCurrencies) {
      final double converted = _convertEgpToMain(
        amountEgp: amountEgp,
        currency: code,
        marketSnapshot: marketSnapshot,
      );
      values[code] = converted;
    }
    return values;
  }

  static List<_MonthlyTotals> _sumTransactions({
    required List<Transaction> transactions,
    required DateTime start,
    required DateTime endExclusive,
    required MarketSnapshot marketSnapshot,
    required String currency,
  }) {
    final List<_MonthlyTotals> out = <_MonthlyTotals>[];
    final MarketData marketData = _toMarketData(marketSnapshot);
    for (final Transaction tx in transactions) {
      if (tx.isTransferActivity) continue;
      final DateTime? parsed = DateTime.tryParse(normalizeDateText(tx.date));
      if (parsed == null) continue;
      final DateTime day = DateUtils.dateOnly(parsed);
      if (day.isBefore(start) || !day.isBefore(endExclusive)) {
        continue;
      }
      final double amountEgp =
          ZakatEngineService.tryConvertToEgp(
            tx.amount,
            tx.currency,
            marketData,
          ) ??
          0;
      final double amountMain = _finiteOrZero(
        ZakatEngineService.convertFromEgp(amountEgp, currency, marketData),
        'sumTransactions.amountMain',
      );
      out.add(
        _MonthlyTotals(
          date: day,
          amountMain: amountMain,
          isIncome: tx.type == 'income',
          category: tx.category,
          transaction: tx,
        ),
      );
    }
    return out;
  }

  static List<WidgetCategoryItem> _buildTopCategories({
    required List<Transaction> transactions,
    required MarketSnapshot marketSnapshot,
    required String currency,
    required DateTime start,
    required DateTime endExclusive,
  }) {
    final MarketData marketData = _toMarketData(marketSnapshot);
    final Map<String, double> totals = <String, double>{};
    for (final Transaction tx in transactions) {
      if (tx.type != 'expense') continue;
      if (tx.isTransferActivity) continue;
      final DateTime? parsed = DateTime.tryParse(normalizeDateText(tx.date));
      if (parsed == null) continue;
      final DateTime day = DateUtils.dateOnly(parsed);
      if (day.isBefore(start) || !day.isBefore(endExclusive)) continue;
      final String key = _normalizedCategory(tx.category);
      final double amountEgp =
          ZakatEngineService.tryConvertToEgp(
            tx.amount,
            tx.currency,
            marketData,
          ) ??
          0;
      totals[key] =
          (totals[key] ?? 0) +
          ZakatEngineService.convertFromEgp(amountEgp, currency, marketData);
    }

    if (totals.isEmpty) {
      return const <WidgetCategoryItem>[];
    }

    final List<MapEntry<String, double>> sorted = totals.entries.toList()
      ..sort(
        (MapEntry<String, double> a, MapEntry<String, double> b) =>
            b.value.compareTo(a.value),
      );

    final double total = sorted.fold<double>(
      0,
      (double sum, MapEntry<String, double> entry) => sum + entry.value,
    );
    final List<WidgetCategoryItem> items = <WidgetCategoryItem>[];
    double remainder = total;
    for (final MapEntry<String, double> entry in sorted.take(5)) {
      remainder -= entry.value;
      items.add(
        WidgetCategoryItem(
          name: _displayCategory(entry.key),
          amountMain: entry.value,
          percentage: total <= 0 ? 0 : (entry.value / total) * 100,
          colorValue: _categoryColor(entry.key),
          iconKey: _categoryIcon(entry.key),
        ),
      );
    }
    if (sorted.length > 5 && remainder > 0.01) {
      items.add(
        WidgetCategoryItem(
          name: 'Other',
          amountMain: remainder,
          percentage: (remainder / total) * 100,
          colorValue: 0xFF94A3B8,
          iconKey: 'other',
        ),
      );
    }

    // If "Other" already exists, make sure it is folded into one row.
    final Map<String, WidgetCategoryItem> merged =
        <String, WidgetCategoryItem>{};
    for (final WidgetCategoryItem item in items) {
      final String key = item.name.trim().toLowerCase() == 'other'
          ? 'other'
          : item.name.trim().toLowerCase();
      final WidgetCategoryItem? existing = merged[key];
      if (existing == null) {
        merged[key] = item;
      } else {
        merged[key] = existing.copyWith(
          amountMain: existing.amountMain + item.amountMain,
          percentage: existing.percentage + item.percentage,
        );
      }
    }
    final List<WidgetCategoryItem> mergedItems = merged.values.toList()
      ..sort(
        (WidgetCategoryItem a, WidgetCategoryItem b) =>
            b.amountMain.compareTo(a.amountMain),
      );
    return mergedItems.take(6).toList(growable: false);
  }

  static List<WidgetAllocationItem> _buildAllocation({
    required List<Saving> savings,
    required List<InvestmentAsset> investments,
    required MarketSnapshot marketSnapshot,
    required String currency,
  }) {
    final MarketData marketData = _toMarketData(marketSnapshot);
    final Map<String, double> totals = <String, double>{};

    for (final Saving saving in savings) {
      final double egp =
          ZakatEngineService.tryConvertToEgp(
            saving.remainingAmount,
            saving.unit,
            marketData,
          ) ??
          0;
      final double value = _finiteOrZero(
        ZakatEngineService.convertFromEgp(egp, currency, marketData),
        'buildAllocation.value',
      );
      final String assetType = ZakatEngineService.normaliseAssetType(
        saving.assetType,
      );
      totals[_allocationKeyForAssetType(assetType)] =
          (totals[_allocationKeyForAssetType(assetType)] ?? 0) + value;
    }

    for (final InvestmentAsset asset in investments) {
      final String investmentType = ZakatEngineService.normaliseInvestmentType(
        asset.investmentType,
      );
      final double egp =
          ZakatEngineService.tryConvertToEgp(
            asset.estimatedCurrentValue > 0
                ? asset.estimatedCurrentValue
                : (asset.marketValue > 0
                      ? asset.marketValue
                      : asset.originalPrice),
            asset.currency,
            marketData,
          ) ??
          0;
      final double value = ZakatEngineService.convertFromEgp(
        egp,
        currency,
        marketData,
      );
      totals[_allocationKeyForInvestmentType(
            investmentType,
            asset.assetSubtype,
          )] =
          (totals[_allocationKeyForInvestmentType(
                investmentType,
                asset.assetSubtype,
              )] ??
              0) +
          value;
    }

    final double total = totals.values.fold<double>(
      0,
      (double sum, double next) => sum + next,
    );
    if (total <= 0) {
      return const <WidgetAllocationItem>[];
    }

    final List<MapEntry<String, double>> sorted = totals.entries.toList()
      ..sort(
        (MapEntry<String, double> a, MapEntry<String, double> b) =>
            b.value.compareTo(a.value),
      );
    final List<WidgetAllocationItem> items = sorted
        .map((entry) {
          final String key = entry.key;
          return WidgetAllocationItem(
            name: _displayCategory(key),
            amountMain: entry.value,
            percentage: _finiteOrZero(
              (entry.value / total) * 100,
              'allocation.percentage',
            ),
            colorValue: _allocationColor(key),
            iconKey: _allocationIcon(key),
          );
        })
        .toList(growable: false);
    return items;
  }

  static List<WidgetTrendPoint> _buildTrend({
    required List<Transaction> transactions,
    required MarketSnapshot marketSnapshot,
    required String currency,
    required DateTime start,
    required int days,
  }) {
    final MarketData marketData = _toMarketData(marketSnapshot);
    final Map<String, double> dailyTotals = <String, double>{};
    for (int i = 0; i < days; i++) {
      final DateTime day = start.add(Duration(days: i));
      final String key = _dayKey(day);
      dailyTotals[key] = 0;
    }
    for (final Transaction tx in transactions) {
      if (tx.type != 'expense') continue;
      if (tx.isTransferActivity) continue;
      final DateTime? parsed = DateTime.tryParse(normalizeDateText(tx.date));
      if (parsed == null) continue;
      final DateTime day = DateUtils.dateOnly(parsed);
      if (day.isBefore(start) || day.isAfter(start.add(Duration(days: days)))) {
        continue;
      }
      final String key = _dayKey(day);
      final double egp =
          ZakatEngineService.tryConvertToEgp(
            tx.amount,
            tx.currency,
            marketData,
          ) ??
          0;
      final double value = _finiteOrZero(
        ZakatEngineService.convertFromEgp(egp, currency, marketData),
        'buildTrend.valueMain',
      );
      dailyTotals[key] = (dailyTotals[key] ?? 0) + value;
    }

    return dailyTotals.entries
        .map((MapEntry<String, double> entry) {
          final DateTime parsed = DateTime.parse(normalizeDateText(entry.key));
          return WidgetTrendPoint(
            dateKey: entry.key,
            label: DateFormat('d MMM', 'en_US').format(parsed),
            valueMain: entry.value,
          );
        })
        .toList(growable: false)
      ..sort(
        (WidgetTrendPoint a, WidgetTrendPoint b) =>
            a.dateKey.compareTo(b.dateKey),
      );
  }

  static List<WidgetRecentItem> _buildRecentActivity({
    required List<Transaction> transactions,
    required MarketSnapshot marketSnapshot,
    required String currency,
    required DateTime start,
    required bool isArabic,
  }) {
    final MarketData marketData = _toMarketData(marketSnapshot);
    final List<WidgetRecentItem> items = <WidgetRecentItem>[];
    for (final Transaction tx in transactions) {
      if (tx.isTransferActivity) continue;
      final DateTime? parsed = DateTime.tryParse(normalizeDateText(tx.date));
      if (parsed == null) continue;
      final DateTime day = DateUtils.dateOnly(parsed);
      if (day.isBefore(start)) continue;
      final double egp =
          ZakatEngineService.tryConvertToEgp(
            tx.amount,
            tx.currency,
            marketData,
          ) ??
          0;
      final double value = _finiteOrZero(
        ZakatEngineService.convertFromEgp(egp, currency, marketData),
        'buildRecentActivity.valueMain',
      );
      items.add(
        WidgetRecentItem(
          title: _localizeWidgetCategory(tx.category, isArabic),
          subtitle: tx.description.trim().isEmpty
              ? DateFormat('d MMM yyyy', isArabic ? 'ar' : 'en_US').format(day)
              : tx.description,
          amountMain: value,
          dateKey: _dayKey(day),
          colorValue: _categoryColor(tx.category),
          iconKey: _categoryIcon(tx.category),
        ),
      );
    }
    items.sort((WidgetRecentItem a, WidgetRecentItem b) {
      final int byAmount = b.amountMain.abs().compareTo(a.amountMain.abs());
      if (byAmount != 0) return byAmount;
      return b.dateKey.compareTo(a.dateKey);
    });
    return items.take(5).toList(growable: false);
  }

  static MarketData _toMarketData(MarketSnapshot marketSnapshot) {
    return MarketData(
      goldPrice24kEgp: marketSnapshot.gold24kPricePerGramEgp,
      silverPriceEgp: marketSnapshot.silverPricePerGramEgp,
      usdToEgp: marketSnapshot.usdToEgp,
      sarToEgp: marketSnapshot.sarToEgp,
      ratesToEgp: <String, double>{
        'USD': marketSnapshot.usdToEgp,
        'SAR': marketSnapshot.sarToEgp,
        'AED': marketSnapshot.aedToEgp,
        'KWD': marketSnapshot.kwdToEgp,
        'QAR': marketSnapshot.qarToEgp,
        'EUR': marketSnapshot.eurToEgp,
        'GBP': marketSnapshot.gbpToEgp,
        'BHD': marketSnapshot.bhdToEgp,
        'OMR': marketSnapshot.omrToEgp,
        'JOD': marketSnapshot.jodToEgp,
        'TRY': marketSnapshot.tryToEgp,
        'MYR': marketSnapshot.myrToEgp,
        'PKR': marketSnapshot.pkrToEgp,
        'IDR': marketSnapshot.idrToEgp,
      },
    );
  }

  static String _normalizedCategory(String category) {
    final String clean = category.trim();
    final String lower = clean.toLowerCase();
    if (lower.startsWith('other')) return 'Other';
    if (lower.contains('subscription')) return 'Subscriptions';
    if (lower.contains('loan')) return 'Loan';
    if (lower.contains('grocer')) return 'Groceries';
    if (lower.contains('shopping')) return 'Shopping';
    if (lower.contains('invest')) return 'Investment';
    return clean.isEmpty ? 'Other' : clean;
  }

  static String _displayCategory(String category) {
    final String normalized = _normalizedCategory(category);
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  static String _allocationKeyForAssetType(String assetType) {
    switch (assetType) {
      case 'cash':
        return 'Cash';
      case 'gold':
        return 'Gold';
      case 'silver':
        return 'Silver';
      default:
        return 'Other';
    }
  }

  static String _allocationKeyForInvestmentType(
    String investmentType,
    String assetSubtype,
  ) {
    final String subtype = assetSubtype.trim().toLowerCase();
    if (investmentType == 'real_estate' || subtype.contains('property')) {
      return 'Real Estate';
    }
    if (investmentType == 'company_investment' || subtype.contains('stock')) {
      return 'Investments';
    }
    if (subtype.contains('gold')) return 'Gold';
    if (subtype.contains('silver')) return 'Silver';
    return 'Other';
  }

  static int _allocationColor(String key) {
    switch (key) {
      case 'Cash':
        return 0xFF16A34A;
      case 'Investments':
        return 0xFFC62828;
      case 'Real Estate':
        return 0xFFD4AF37;
      case 'Gold':
        return 0xFFF97316;
      case 'Silver':
        return 0xFF7C3AED;
      default:
        return 0xFF64748B;
    }
  }

  static String _allocationIcon(String key) {
    switch (key) {
      case 'Cash':
        return 'cash';
      case 'Investments':
        return 'investment';
      case 'Real Estate':
        return 'home';
      case 'Gold':
        return 'gold';
      case 'Silver':
        return 'silver';
      default:
        return 'other';
    }
  }

  static int _categoryColor(String key) {
    final String lower = key.trim().toLowerCase();
    if (lower.contains('investment')) return 0xFFC62828;
    if (lower.contains('shopping')) return 0xFFF97316;
    if (lower.contains('grocer')) return 0xFF16A34A;
    if (lower.contains('loan')) return 0xFF2563EB;
    if (lower.contains('subscription')) return 0xFF7C3AED;
    if (lower.contains('other')) return 0xFF64748B;
    if (lower.contains('cash')) return 0xFF0F766E;
    return CategoryVisuals.resolveCategoryVisual(
          categories: AppCategories(
            income: const <String>[],
            expense: const <String>[],
          ),
          type: 'expense',
          categoryName: key,
        ).colorValue ??
        0xFF64748B;
  }

  static String _categoryIcon(String key) {
    final String lower = key.trim().toLowerCase();
    if (lower.contains('investment')) return 'investment';
    if (lower.contains('shopping')) return 'shopping';
    if (lower.contains('grocer')) return 'groceries';
    if (lower.contains('loan')) return 'loan';
    if (lower.contains('subscription')) return 'subscription';
    if (lower.contains('home')) return 'home';
    if (lower.contains('cash')) return 'cash';
    return 'expense';
  }

  static String _dayKey(DateTime date) {
    final DateTime day = DateUtils.dateOnly(date);
    final String y = day.year.toString();
    final String m = day.month.toString().padLeft(2, '0');
    final String d = day.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static _WidgetZakahCountdown? _findNextUnpaidZakatDate(
    List<Map<String, dynamic>> schedule,
    Set<String> paidMonths, {
    required DateTime today,
    required bool isArabic,
  }) {
    DateTime? best;
    for (final Map<String, dynamic> item in schedule) {
      final String monthKey = (item['monthKey'] ?? '').toString().trim();
      if (monthKey.isEmpty || paidMonths.contains(monthKey)) continue;
      final String raw = (item['paymentDate'] ?? '').toString().trim();
      if (raw.isEmpty) continue;
      final DateTime? parsed = DateTime.tryParse(normalizeDateText(raw));
      if (parsed == null) continue;
      if (best == null || parsed.isBefore(best)) {
        best = parsed;
      }
    }
    if (best == null) return null;
    final DateTime bestDay = DateUtils.dateOnly(best);
    final int daysRemaining = bestDay
        .difference(DateUtils.dateOnly(today))
        .inDays;
    return _WidgetZakahCountdown(
      dateLabel: DateFormat(
        'dd MMM yyyy',
        isArabic ? 'ar' : 'en_US',
      ).format(bestDay),
      daysRemaining: daysRemaining,
    );
  }

  static _TodaySpendingSummary _buildTodaySpending({
    required List<Transaction> transactions,
    required MarketSnapshot marketSnapshot,
    required String mainCurrency,
    required DateTime today,
  }) {
    final MarketData marketData = _toMarketData(marketSnapshot);
    final DateTime start = DateUtils.dateOnly(today);
    final DateTime endExclusive = start.add(const Duration(days: 1));
    final Map<String, _TodaySpendingCurrencyBucket> totals =
        <String, _TodaySpendingCurrencyBucket>{};
    double totalMain = 0;

    for (final Transaction tx in transactions) {
      if (tx.type != 'expense') continue;
      if (tx.isTransferActivity) continue;
      final DateTime? parsed = DateTime.tryParse(normalizeDateText(tx.date));
      if (parsed == null) continue;
      final DateTime day = DateUtils.dateOnly(parsed);
      if (day.isBefore(start) || !day.isBefore(endExclusive)) continue;

      final double amountEgp =
          ZakatEngineService.tryConvertToEgp(
            tx.amount,
            tx.currency,
            marketData,
          ) ??
          0;
      final double amountMain = _finiteOrZero(
        ZakatEngineService.convertFromEgp(amountEgp, mainCurrency, marketData),
        'todaySpending.amountMain',
      );
      totalMain += amountMain;

      final String currency = tx.currency.trim().toUpperCase();
      final _TodaySpendingCurrencyBucket existing =
          totals[currency] ??
          _TodaySpendingCurrencyBucket(
            currencyCode: currency,
            amount: 0,
            amountMain: 0,
          );
      totals[currency] = existing.copyWith(
        amount: existing.amount + (tx.amount.isFinite ? tx.amount : 0),
        amountMain: existing.amountMain + amountMain,
      );
    }

    final List<_TodaySpendingCurrencyBucket> sorted = totals.values.toList()
      ..sort(
        (_TodaySpendingCurrencyBucket a, _TodaySpendingCurrencyBucket b) =>
            b.amountMain.compareTo(a.amountMain),
      );

    final int shownCount = sorted.length.clamp(0, 4);
    return _TodaySpendingSummary(
      totalMain: _finiteOrZero(totalMain, 'todaySpending.totalMain'),
      items: sorted
          .take(4)
          .map(
            (_TodaySpendingCurrencyBucket bucket) => WidgetCurrencySpendingItem(
              currencyCode: bucket.currencyCode,
              amount: bucket.amount,
              amountMain: bucket.amountMain,
            ),
          )
          .toList(growable: false),
      otherCurrencyCount: sorted.length > shownCount
          ? sorted.length - shownCount
          : 0,
    );
  }
}

class _WidgetZakahCountdown {
  const _WidgetZakahCountdown({
    required this.dateLabel,
    required this.daysRemaining,
  });

  final String dateLabel;
  final int daysRemaining;
}

class _TodaySpendingSummary {
  const _TodaySpendingSummary({
    required this.totalMain,
    required this.items,
    required this.otherCurrencyCount,
  });

  final double totalMain;
  final List<WidgetCurrencySpendingItem> items;
  final int otherCurrencyCount;
}

class _TodaySpendingCurrencyBucket {
  const _TodaySpendingCurrencyBucket({
    required this.currencyCode,
    required this.amount,
    required this.amountMain,
  });

  final String currencyCode;
  final double amount;
  final double amountMain;

  _TodaySpendingCurrencyBucket copyWith({
    String? currencyCode,
    double? amount,
    double? amountMain,
  }) {
    return _TodaySpendingCurrencyBucket(
      currencyCode: currencyCode ?? this.currencyCode,
      amount: amount ?? this.amount,
      amountMain: amountMain ?? this.amountMain,
    );
  }
}

class WidgetCurrencySpendingItem {
  const WidgetCurrencySpendingItem({
    required this.currencyCode,
    required this.amount,
    required this.amountMain,
  });

  final String currencyCode;
  final double amount;
  final double amountMain;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'currencyCode': currencyCode,
      'amount': amount,
      'amountMain': amountMain,
    };
  }
}

class WidgetSnapshot {
  WidgetSnapshot({
    required this.appName,
    required this.mainCurrency,
    required this.mainCurrencyRateToEgp,
    required this.hideBalances,
    required this.balancesHiddenLabel,
    required this.netAssetsEgp,
    required this.netAssetsMain,
    required this.netAssetDeltaMain,
    required this.netAssetDeltaPct,
    required this.nisabMet,
    required this.nisabThresholdEgp,
    required this.zakahStatusLabel,
    required this.nextZakahDueLabel,
    required this.incomeThisMonthMain,
    required this.expensesThisMonthMain,
    required this.incomePreviousMonthMain,
    required this.expensesPreviousMonthMain,
    required this.expenseDeltaPct,
    required this.pendingSmartCaptureCount,
    required this.upcomingObligationsCount,
    required this.periodLabel,
    required this.assetAllocation,
    required this.topCategories,
    required this.expenseTrend,
    required this.recentActivity,
  });

  final String appName;
  final String mainCurrency;
  final double mainCurrencyRateToEgp;
  final bool hideBalances;
  final String balancesHiddenLabel;
  final double netAssetsEgp;
  final double netAssetsMain;
  final double netAssetDeltaMain;
  final double netAssetDeltaPct;
  final bool nisabMet;
  final double nisabThresholdEgp;
  final String zakahStatusLabel;
  final String nextZakahDueLabel;
  final double incomeThisMonthMain;
  final double expensesThisMonthMain;
  final double incomePreviousMonthMain;
  final double expensesPreviousMonthMain;
  final double expenseDeltaPct;
  final int pendingSmartCaptureCount;
  final int upcomingObligationsCount;
  final String periodLabel;
  final List<WidgetAllocationItem> assetAllocation;
  final List<WidgetCategoryItem> topCategories;
  final List<WidgetTrendPoint> expenseTrend;
  final List<WidgetRecentItem> recentActivity;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'appName': appName,
      'mainCurrency': mainCurrency,
      'mainCurrencyRateToEgp': mainCurrencyRateToEgp,
      'hideBalances': hideBalances,
      'balancesHiddenLabel': balancesHiddenLabel,
      'netAssetsEgp': netAssetsEgp,
      'netAssetsMain': netAssetsMain,
      'netAssetDeltaMain': netAssetDeltaMain,
      'netAssetDeltaPct': netAssetDeltaPct,
      'nisabMet': nisabMet,
      'nisabThresholdEgp': nisabThresholdEgp,
      'zakahStatusLabel': zakahStatusLabel,
      'nextZakahDueLabel': nextZakahDueLabel,
      'incomeThisMonthMain': incomeThisMonthMain,
      'expensesThisMonthMain': expensesThisMonthMain,
      'incomePreviousMonthMain': incomePreviousMonthMain,
      'expensesPreviousMonthMain': expensesPreviousMonthMain,
      'expenseDeltaPct': expenseDeltaPct,
      'pendingSmartCaptureCount': pendingSmartCaptureCount,
      'upcomingObligationsCount': upcomingObligationsCount,
      'periodLabel': periodLabel,
      'assetAllocation': assetAllocation.map((e) => e.toJson()).toList(),
      'topCategories': topCategories.map((e) => e.toJson()).toList(),
      'expenseTrend': expenseTrend.map((e) => e.toJson()).toList(),
      'recentActivity': recentActivity.map((e) => e.toJson()).toList(),
    };
  }
}

class WidgetAllocationItem {
  const WidgetAllocationItem({
    required this.name,
    required this.amountMain,
    required this.percentage,
    required this.colorValue,
    required this.iconKey,
  });

  final String name;
  final double amountMain;
  final double percentage;
  final int colorValue;
  final String iconKey;

  WidgetAllocationItem copyWith({
    String? name,
    double? amountMain,
    double? percentage,
    int? colorValue,
    String? iconKey,
  }) {
    return WidgetAllocationItem(
      name: name ?? this.name,
      amountMain: amountMain ?? this.amountMain,
      percentage: percentage ?? this.percentage,
      colorValue: colorValue ?? this.colorValue,
      iconKey: iconKey ?? this.iconKey,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'amountMain': amountMain,
      'percentage': percentage,
      'colorValue': colorValue,
      'iconKey': iconKey,
    };
  }
}

class WidgetCategoryItem {
  const WidgetCategoryItem({
    required this.name,
    required this.amountMain,
    required this.percentage,
    required this.colorValue,
    required this.iconKey,
  });

  final String name;
  final double amountMain;
  final double percentage;
  final int colorValue;
  final String iconKey;

  WidgetCategoryItem copyWith({
    String? name,
    double? amountMain,
    double? percentage,
    int? colorValue,
    String? iconKey,
  }) {
    return WidgetCategoryItem(
      name: name ?? this.name,
      amountMain: amountMain ?? this.amountMain,
      percentage: percentage ?? this.percentage,
      colorValue: colorValue ?? this.colorValue,
      iconKey: iconKey ?? this.iconKey,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'amountMain': amountMain,
      'percentage': percentage,
      'colorValue': colorValue,
      'iconKey': iconKey,
    };
  }
}

class WidgetTrendPoint {
  const WidgetTrendPoint({
    required this.dateKey,
    required this.label,
    required this.valueMain,
  });

  final String dateKey;
  final String label;
  final double valueMain;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'dateKey': dateKey,
      'label': label,
      'valueMain': valueMain,
    };
  }
}

class WidgetRecentItem {
  const WidgetRecentItem({
    required this.title,
    required this.subtitle,
    required this.amountMain,
    required this.dateKey,
    required this.colorValue,
    required this.iconKey,
  });

  final String title;
  final String subtitle;
  final double amountMain;
  final String dateKey;
  final int colorValue;
  final String iconKey;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'subtitle': subtitle,
      'amountMain': amountMain,
      'dateKey': dateKey,
      'colorValue': colorValue,
      'iconKey': iconKey,
    };
  }
}

class WidgetSummary {
  const WidgetSummary({
    required this.hasData,
    required this.appName,
    required this.languageCode,
    required this.mainCurrencyCode,
    required this.mainCurrencyRateToEgp,
    required this.currencySymbol,
    required this.netAssets,
    required this.netAssetsChangePercentToday,
    required this.todaySpendingMain,
    required this.todaySpendingBreakdown,
    required this.todaySpendingOtherCurrenciesCount,
    required this.zakahStatus,
    required this.totalExpensesThisMonth,
    required this.incomeThisMonth,
    required this.expensesThisMonth,
    required this.pendingSmsCount,
    required this.upcomingObligationsCount,
    required this.nextZakahText,
    required this.nextZakahDays,
    required this.recentActivitySummary,
    required this.lastUpdated,
  });

  final bool hasData;
  final String appName;
  final String languageCode;
  final String mainCurrencyCode;
  final double mainCurrencyRateToEgp;
  final String currencySymbol;
  final double netAssets;
  final double netAssetsChangePercentToday;
  final double todaySpendingMain;
  final List<WidgetCurrencySpendingItem> todaySpendingBreakdown;
  final int todaySpendingOtherCurrenciesCount;
  final String zakahStatus;
  final double totalExpensesThisMonth;
  final double incomeThisMonth;
  final double expensesThisMonth;
  final int pendingSmsCount;
  final int upcomingObligationsCount;
  final String nextZakahText;
  final int? nextZakahDays;
  final String recentActivitySummary;
  final String lastUpdated;

  String amountText(double value) {
    final String sign = value < 0 ? '-' : '';
    final double absValue = value.abs();
    final String amount = absValue >= 100
        ? absValue.toStringAsFixed(0)
        : absValue.toStringAsFixed(2);
    return '$sign$currencySymbol $amount';
  }

  String percentText(double value) => '${value.abs().toStringAsFixed(1)}%';

  bool get isArabic => languageCode.toLowerCase().startsWith('ar');

  WidgetSummary copyWith({
    bool? hasData,
    String? appName,
    String? languageCode,
    String? mainCurrencyCode,
    double? mainCurrencyRateToEgp,
    String? currencySymbol,
    double? netAssets,
    double? netAssetsChangePercentToday,
    double? todaySpendingMain,
    List<WidgetCurrencySpendingItem>? todaySpendingBreakdown,
    int? todaySpendingOtherCurrenciesCount,
    String? zakahStatus,
    double? totalExpensesThisMonth,
    double? incomeThisMonth,
    double? expensesThisMonth,
    int? pendingSmsCount,
    int? upcomingObligationsCount,
    String? nextZakahText,
    int? nextZakahDays,
    String? recentActivitySummary,
    String? lastUpdated,
  }) {
    return WidgetSummary(
      hasData: hasData ?? this.hasData,
      appName: appName ?? this.appName,
      languageCode: languageCode ?? this.languageCode,
      mainCurrencyCode: mainCurrencyCode ?? this.mainCurrencyCode,
      mainCurrencyRateToEgp:
          mainCurrencyRateToEgp ?? this.mainCurrencyRateToEgp,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      netAssets: netAssets ?? this.netAssets,
      netAssetsChangePercentToday:
          netAssetsChangePercentToday ?? this.netAssetsChangePercentToday,
      todaySpendingMain: todaySpendingMain ?? this.todaySpendingMain,
      todaySpendingBreakdown:
          todaySpendingBreakdown ?? this.todaySpendingBreakdown,
      todaySpendingOtherCurrenciesCount:
          todaySpendingOtherCurrenciesCount ??
          this.todaySpendingOtherCurrenciesCount,
      zakahStatus: zakahStatus ?? this.zakahStatus,
      totalExpensesThisMonth:
          totalExpensesThisMonth ?? this.totalExpensesThisMonth,
      incomeThisMonth: incomeThisMonth ?? this.incomeThisMonth,
      expensesThisMonth: expensesThisMonth ?? this.expensesThisMonth,
      pendingSmsCount: pendingSmsCount ?? this.pendingSmsCount,
      upcomingObligationsCount:
          upcomingObligationsCount ?? this.upcomingObligationsCount,
      nextZakahText: nextZakahText ?? this.nextZakahText,
      nextZakahDays: nextZakahDays ?? this.nextZakahDays,
      recentActivitySummary:
          recentActivitySummary ?? this.recentActivitySummary,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  factory WidgetSummary.placeholder() {
    return const WidgetSummary(
      hasData: false,
      appName: 'Zakah Wealth',
      languageCode: 'en',
      mainCurrencyCode: 'EGP',
      mainCurrencyRateToEgp: 1,
      currencySymbol: 'E£',
      netAssets: 0,
      netAssetsChangePercentToday: 0,
      todaySpendingMain: 0,
      todaySpendingBreakdown: <WidgetCurrencySpendingItem>[],
      todaySpendingOtherCurrenciesCount: 0,
      zakahStatus: 'Open app to sync',
      totalExpensesThisMonth: 0,
      incomeThisMonth: 0,
      expensesThisMonth: 0,
      pendingSmsCount: 0,
      upcomingObligationsCount: 0,
      nextZakahText: 'Open app to sync',
      nextZakahDays: null,
      recentActivitySummary: 'Open app to sync',
      lastUpdated: '',
    );
  }

  WidgetSummary copyWithPlaceholderText(String message) {
    return WidgetSummary(
      hasData: hasData,
      appName: appName,
      languageCode: languageCode,
      mainCurrencyCode: mainCurrencyCode,
      mainCurrencyRateToEgp: mainCurrencyRateToEgp,
      currencySymbol: currencySymbol,
      netAssets: netAssets,
      netAssetsChangePercentToday: netAssetsChangePercentToday,
      todaySpendingMain: todaySpendingMain,
      todaySpendingBreakdown: todaySpendingBreakdown,
      todaySpendingOtherCurrenciesCount: todaySpendingOtherCurrenciesCount,
      zakahStatus: message,
      totalExpensesThisMonth: totalExpensesThisMonth,
      incomeThisMonth: incomeThisMonth,
      expensesThisMonth: expensesThisMonth,
      pendingSmsCount: pendingSmsCount,
      upcomingObligationsCount: upcomingObligationsCount,
      nextZakahText: message,
      nextZakahDays: nextZakahDays,
      recentActivitySummary: message,
      lastUpdated: lastUpdated,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'hasData': hasData,
      'appName': appName,
      'languageCode': languageCode,
      'mainCurrencyCode': mainCurrencyCode,
      'mainCurrencyRateToEgp': mainCurrencyRateToEgp,
      'currencySymbol': currencySymbol,
      'netAssets': netAssets,
      'netAssetsChangePercentToday': netAssetsChangePercentToday,
      'todaySpendingMain': todaySpendingMain,
      'todaySpendingBreakdown': todaySpendingBreakdown
          .map((WidgetCurrencySpendingItem e) => e.toJson())
          .toList(),
      'todaySpendingOtherCurrenciesCount': todaySpendingOtherCurrenciesCount,
      'zakahStatus': zakahStatus,
      'totalExpensesThisMonth': totalExpensesThisMonth,
      'incomeThisMonth': incomeThisMonth,
      'expensesThisMonth': expensesThisMonth,
      'pendingSmsCount': pendingSmsCount,
      'upcomingObligationsCount': upcomingObligationsCount,
      'nextZakahText': nextZakahText,
      'nextZakahDays': nextZakahDays,
      'recentActivitySummary': recentActivitySummary,
      'lastUpdated': lastUpdated,
    };
  }
}

double _finiteOrZero(double value, String label) {
  if (value.isFinite) return value;
  debugPrint('WidgetDataService sanitized non-finite value at $label');
  return 0;
}

class _SmartCaptureSnapshot {
  const _SmartCaptureSnapshot({
    required this.smartCaptureAutoApproveEnabled,
    required this.languagePreference,
    required this.merchantAliases,
    required this.merchantRules,
  });

  final bool smartCaptureAutoApproveEnabled;
  final String languagePreference;
  final Map<String, String> merchantAliases;
  final Map<String, dynamic> merchantRules;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'smartCaptureAutoApproveEnabled': smartCaptureAutoApproveEnabled,
      'languagePreference': languagePreference,
      'merchantAliases': merchantAliases,
      'merchantRules': merchantRules,
    };
  }
}

class _MonthlyTotals {
  const _MonthlyTotals({
    required this.date,
    required this.amountMain,
    required this.isIncome,
    required this.category,
    required this.transaction,
  });

  final DateTime date;
  final double amountMain;
  final bool isIncome;
  final String category;
  final Transaction transaction;
}

class _WealthHistoryEntry {
  const _WealthHistoryEntry({
    required this.amountEgp,
    required this.currencyCode,
    required this.rateToEgp,
    required this.amountsByCurrency,
  });

  final double amountEgp;
  final String currencyCode;
  final double rateToEgp;
  final Map<String, double> amountsByCurrency;

  double amountForCurrency({
    required String currencyCode,
    required MarketSnapshot marketSnapshot,
  }) {
    final String normalized = currencyCode.trim().toUpperCase();
    final double? stored = amountsByCurrency[normalized];
    if (stored != null && stored.isFinite) {
      return stored;
    }
    return WidgetDataService._convertEgpToMain(
      amountEgp: amountEgp,
      currency: normalized,
      marketSnapshot: marketSnapshot,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'amountEgp': amountEgp,
      'currencyCode': currencyCode,
      'rateToEgp': rateToEgp,
      'amountsByCurrency': amountsByCurrency,
    };
  }
}

class _WealthDeltaSnapshot {
  const _WealthDeltaSnapshot({
    required this.yesterdayWealthMain,
    required this.delta,
    required this.percent,
  });

  final double? yesterdayWealthMain;
  final double delta;
  final double percent;
}
