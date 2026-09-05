import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/theme/app_radii.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../models/investment_asset.dart';
import '../../models/credit_card.dart';
import '../../models/saving.dart';
import '../../models/transaction.dart';
import '../../services/app_state_controller.dart';
import 'category_details_screen.dart';
import 'credit_cards_screen.dart';
import 'metals_screen.dart';
import '../account/notifications_screen.dart';
import '../../models/pending_transaction.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key, this.onViewAllActivity});

  final VoidCallback? onViewAllActivity;

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  String _selectedDateFilter = 'All Time';
  DateTimeRange? _customDateRange;
  late final PageController _pageController;
  int _selectedPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _getFlagEmoji(String currency) {
    switch (currency.trim().toUpperCase()) {
      case 'USD':
        return '🇺🇸';
      case 'EGP':
        return '🇪🇬';
      case 'SAR':
        return '🇸🇦';
      case 'AED':
        return '🇦🇪';
      case 'KWD':
        return '🇰🇼';
      case 'QAR':
        return '🇶🇦';
      case 'EUR':
        return '🇪🇺';
      case 'GBP':
        return '🇬🇧';
      default:
        return '🏳️';
    }
  }

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]) ?? DateTime.now().year;
        final m = int.tryParse(parts[1]) ?? DateTime.now().month;
        final d = int.tryParse(parts[2]) ?? DateTime.now().day;
        return DateTime(y, m, d);
      }
      return null;
    }
  }

  Future<void> _selectCustomRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange:
          _customDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedDateFilter = 'Custom';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double navSafeBottomPadding =
        112 + MediaQuery.paddingOf(context).bottom;
    final AppStateController controller = context.watch<AppStateController>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color borderColor = isDark
        ? const Color(0xFFFFC928).withValues(alpha: 0.45)
        : const Color(0xFFC5A059).withValues(alpha: 0.65);
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;
    final Alignment gradientBegin = isRtl
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final Alignment gradientEnd = isRtl
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final List<Saving> savings = controller.state.savings;
    final List<InvestmentAsset> investments = controller.state.investments;
    final List<Transaction> transactions = controller.state.transactions;
    final MarketData market = MarketData.fromJson(controller.state.marketData);

    final String mainCurrency = controller.state.mainCurrency.trim().isEmpty
        ? 'EGP'
        : controller.state.mainCurrency.trim();

    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

    // Calculate balancesHidden globally
    final bool balancesHidden =
        controller.state.aiSettings?['privacyMode'] == true ||
        controller.state.aiSettings?['hideBalances'] == true ||
        controller.state.aiSettings?['balancesHidden'] == true;

    // Filter Items by Date for Categories
    final DateTime now = DateTime.now();
    List<Saving> filteredSavings = savings;
    List<InvestmentAsset> filteredInvestments = investments;

    if (_selectedDateFilter != 'All Time') {
      filteredSavings = savings.where((s) {
        final DateTime? date = _parseDate(s.dateAcquired);
        if (date == null) return true;
        if (_selectedDateFilter == '30D') {
          return date.isAfter(now.subtract(const Duration(days: 30))) ||
              date.isAtSameMomentAs(now.subtract(const Duration(days: 30)));
        } else if (_selectedDateFilter == '90D') {
          return date.isAfter(now.subtract(const Duration(days: 90))) ||
              date.isAtSameMomentAs(now.subtract(const Duration(days: 90)));
        } else if (_selectedDateFilter == 'YTD') {
          return date.year == now.year;
        } else if (_selectedDateFilter == 'Custom' &&
            _customDateRange != null) {
          return (date.isAfter(_customDateRange!.start) ||
                  date.isAtSameMomentAs(_customDateRange!.start)) &&
              (date.isBefore(_customDateRange!.end) ||
                  date.isAtSameMomentAs(_customDateRange!.end));
        }
        return true;
      }).toList();

      filteredInvestments = investments.where((a) {
        final DateTime? date = _parseDate(a.valuationDate);
        if (date == null) return true;
        if (_selectedDateFilter == '30D') {
          return date.isAfter(now.subtract(const Duration(days: 30))) ||
              date.isAtSameMomentAs(now.subtract(const Duration(days: 30)));
        } else if (_selectedDateFilter == '90D') {
          return date.isAfter(now.subtract(const Duration(days: 90))) ||
              date.isAtSameMomentAs(now.subtract(const Duration(days: 90)));
        } else if (_selectedDateFilter == 'YTD') {
          return date.year == now.year;
        } else if (_selectedDateFilter == 'Custom' &&
            _customDateRange != null) {
          return (date.isAfter(_customDateRange!.start) ||
                  date.isAtSameMomentAs(_customDateRange!.start)) &&
              (date.isBefore(_customDateRange!.end) ||
                  date.isAtSameMomentAs(_customDateRange!.end));
        }
        return true;
      }).toList();
    }

    // Totals calculations (Always overall, asnet worth is absolute)
    final double totalWealthEgp = ZakatEngineService.calculateTotalWealthEgp(
      transactions: transactions,
      savings: savings,
      investments: investments,
      marketData: market,
      lastRollover: controller.state.lastRollover,
    );
    final double totalLiabilitiesEgp =
        ZakatEngineService.calculateTotalLiabilitiesEgp(
          transactions: transactions,
          savings: savings,
          investments: investments,
          marketData: market,
          lastRollover: controller.state.lastRollover,
        ) +
        controller.state.creditCards
            .where(
              (CreditCard card) =>
                  !card.isArchived && card.parentCardId == null,
            )
            .fold<double>(
              0,
              (double sum, CreditCard card) =>
                  sum +
                  ZakatEngineService.convertToEgp(
                    card.openingBalance,
                    card.currency,
                    market,
                  ),
            );

    final double totalWealthMain = ZakatEngineService.convertFromEgp(
      totalWealthEgp,
      mainCurrency,
      market,
    );
    final double totalLiabilitiesMain = ZakatEngineService.convertFromEgp(
      totalLiabilitiesEgp,
      mainCurrency,
      market,
    );

    // Alternative currency calculation
    String altCurrency = 'USD';
    if (mainCurrency == 'USD') altCurrency = 'SAR';
    final double altCurrencyVal = ZakatEngineService.convertFromEgp(
      totalWealthEgp,
      altCurrency,
      market,
    );

    // Dynamic Growth calculation
    final DateTime startOfYear = DateTime(now.year, 1, 1);
    final double startOfYearWealth =
        ZakatEngineService.calculateTotalWealthEgpAt(
          asOf: startOfYear,
          transactions: transactions,
          savings: savings,
          investments: investments,
          marketData: market,
          lastRollover: controller.state.lastRollover,
        );
    final double changePct = startOfYearWealth > 0
        ? ((totalWealthEgp - startOfYearWealth) / startOfYearWealth) * 100
        : 0.0;

    final int totalAssetsCount = savings.length + investments.length;

    // Unique currencies count (Cash savings currencies + Income transaction currencies + Investment currencies + Main currency)
    final Set<String> uniqueCurrencies = {
      mainCurrency,
      ...savings
          .where((s) => s.assetType == 'cash')
          .map((s) => s.unit.trim().toUpperCase()),
      ...transactions
          .where((t) => t.type == 'income')
          .map((t) => t.currency.trim().toUpperCase()),
      ...investments.map((a) => a.currency.trim().toUpperCase()),
    }.where((c) => c.isNotEmpty).toSet();
    final int uniqueCurrenciesCount = uniqueCurrencies.length;

    // Category Values (Filtered)
    // 1. Cash & Currencies
    // Also filter transactions by date if needed
    List<Transaction> filteredTransactions = List<Transaction>.from(
      transactions,
    );
    if (_selectedDateFilter != 'All Time') {
      filteredTransactions = filteredTransactions.where((t) {
        final DateTime? date = _parseDate(t.date);
        if (date == null) return true;
        if (_selectedDateFilter == '30D') {
          return date.isAfter(now.subtract(const Duration(days: 30))) ||
              date.isAtSameMomentAs(now.subtract(const Duration(days: 30)));
        } else if (_selectedDateFilter == '90D') {
          return date.isAfter(now.subtract(const Duration(days: 90))) ||
              date.isAtSameMomentAs(now.subtract(const Duration(days: 90)));
        } else if (_selectedDateFilter == 'YTD') {
          return date.year == now.year;
        } else if (_selectedDateFilter == 'Custom' &&
            _customDateRange != null) {
          return (date.isAfter(_customDateRange!.start) ||
                  date.isAtSameMomentAs(_customDateRange!.start)) &&
              (date.isBefore(_customDateRange!.end) ||
                  date.isAtSameMomentAs(_customDateRange!.end));
        }
        return true;
      }).toList();
    }

    final Map<String, double> cashByCurrency = _selectedDateFilter == 'All Time'
        ? controller.cashByCurrency
        : ZakatEngineService.calculateCashByCurrency(
            transactions: filteredTransactions,
            savings: filteredSavings,
            marketData: market,
            lastRollover: controller.state.lastRollover,
          );
    final double cashTotalEgp = cashByCurrency.entries.fold<double>(
      0,
      (double sum, MapEntry<String, double> entry) =>
          sum + ZakatEngineService.convertToEgp(entry.value, entry.key, market),
    );
    final double cashTotalMain = ZakatEngineService.convertFromEgp(
      cashTotalEgp,
      mainCurrency,
      market,
    );

    // 2. Gold
    final List<Saving> goldList = filteredSavings
        .where((s) => s.assetType == 'gold')
        .toList();
    final double gold24k = goldList.fold<double>(
      0,
      (sum, s) =>
          sum + ZakatEngineService.convertToGold24k(s.remainingAmount, s.unit),
    );
    final double goldTotalEgp = gold24k * market.goldPrice24kEgp;
    final double goldTotalMain = ZakatEngineService.convertFromEgp(
      goldTotalEgp,
      mainCurrency,
      market,
    );

    // 3. Silver
    final List<Saving> silverList = filteredSavings
        .where((s) => s.assetType == 'silver')
        .toList();
    final double silverGrams = silverList.fold<double>(
      0,
      (sum, s) =>
          sum + ZakatEngineService.convertToSilverGrams(s.remainingAmount),
    );
    final double silverTotalEgp = silverGrams * market.silverPriceEgp;
    final double silverTotalMain = ZakatEngineService.convertFromEgp(
      silverTotalEgp,
      mainCurrency,
      market,
    );

    // 4. Investments
    final List<InvestmentAsset> investmentList = filteredInvestments
        .where(
          (a) => ZakatEngineService.isCompanyInvestmentType(a.investmentType),
        )
        .toList();
    final double investmentsTotalEgp = investmentList.fold<double>(0, (sum, a) {
      final double share = 1.0;
      return sum +
          ZakatEngineService.convertToEgp(
            a.marketValue * share,
            a.currency,
            market,
          );
    });
    final double investmentsTotalMain = ZakatEngineService.convertFromEgp(
      investmentsTotalEgp,
      mainCurrency,
      market,
    );

    // 5. Real Estate
    final List<InvestmentAsset> propertyList = filteredInvestments
        .where(
          (a) =>
              ZakatEngineService.normaliseInvestmentType(a.investmentType) ==
              'real_estate',
        )
        .toList();
    final double propertyTotalEgp = propertyList.fold<double>(0, (sum, a) {
      final double share = 1.0;
      return sum +
          ZakatEngineService.convertToEgp(
            a.marketValue * share,
            a.currency,
            market,
          );
    });
    final double propertyTotalMain = ZakatEngineService.convertFromEgp(
      propertyTotalEgp,
      mainCurrency,
      market,
    );

    // 6. Vehicles
    final List<InvestmentAsset> vehicleAssetsList = filteredInvestments
        .where(
          (InvestmentAsset asset) =>
              ZakatEngineService.normaliseInvestmentType(
                asset.investmentType,
              ) ==
              'car',
        )
        .toList();
    final double vehicleAssetsTotalEgp = vehicleAssetsList.fold<double>(0, (
      sum,
      asset,
    ) {
      final double value =
          ZakatEngineService.calculateInvestmentEstimatedValueEgp(
            asset: asset,
            marketData: market,
          );
      return sum + value;
    });
    final double vehicleAssetsTotalMain = ZakatEngineService.convertFromEgp(
      vehicleAssetsTotalEgp,
      mainCurrency,
      market,
    );

    // Percentages of total wealth
    double pct(double catEgp) => totalWealthEgp > 0
        ? ((catEgp / totalWealthEgp) * 100).clamp(0, 100)
        : 0.0;

    final tokens = context.premiumTokens;
    final bool compact = ResponsiveLayout.isCompact(context);
    final bool veryCompact = ResponsiveLayout.isVeryCompact(context);

    return Container(
      color: tokens.colors.background,
      child: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  ResponsiveLayout.compactHorizontalPadding(context),
                  20,
                  ResponsiveLayout.compactHorizontalPadding(context),
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _AssetsHeader(
                      title: context.l10n.tr('assets'),
                      balancesHidden: balancesHidden,
                      onTogglePrivacy: () => controller.togglePrivacyMode(),
                      hasNotifications: controller.state.pendingTransactions
                          .any((t) => t.status == CaptureStatus.pendingReview),
                      onTapNotifications: () {
                        Navigator.of(context).push(NotificationsScreen.route());
                      },
                    ),
                    const SizedBox(height: 18),

                    // Redesigned Green Hero Card
                    PremiumCard(
                      hero: true,
                      padding: EdgeInsets.zero,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: AppRadii.hero,
                          border: Border.all(color: borderColor, width: 1.5),
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: <Color>[
                              Color(0xFF01332B),
                              Color(0xFF00221C),
                            ],
                          ),
                        ),
                        child: Stack(
                          children: <Widget>[
                            Positioned.fill(
                              child: IgnorePointer(
                                child: ShaderMask(
                                  shaderCallback: (Rect bounds) {
                                    return LinearGradient(
                                      begin: gradientBegin,
                                      end: gradientEnd,
                                      colors: <Color>[
                                        Colors.white.withValues(
                                          alpha: isDark ? 0.18 : 0.34,
                                        ),
                                        Colors.white.withValues(
                                          alpha: isDark ? 0.0 : 0.04,
                                        ),
                                      ],
                                      stops: const <double>[0.0, 1.0],
                                    ).createShader(bounds);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: Image.asset(
                                    'assets/images/hero_pattern_watermark.png',
                                    fit: BoxFit.cover,
                                    alignment: AlignmentDirectional.topEnd,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(
                                compact ? (veryCompact ? 14 : 16) : 20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      // Left Column
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              context.l10n
                                                  .tr('total_assets')
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                color: Color(0xFFFFC928),
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1.0,
                                                fontSize: 11,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: AlignmentDirectional
                                                  .centerStart,
                                              child: Text(
                                                balancesHidden
                                                    ? '••••••'
                                                    : ZakatEngineService.formatCurrency(
                                                        totalWealthMain,
                                                        mainCurrency,
                                                        isArabic: isArabic,
                                                      ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              balancesHidden
                                                  ? '≈ ••••••'
                                                  : '≈ ${ZakatEngineService.formatCurrency(altCurrencyVal, altCurrency, isArabic: isArabic)}',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.75,
                                                ),
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              context.l10n
                                                  .tr('liabilities')
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                color: Color(0xFFFFC928),
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1.0,
                                                fontSize: 9,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: AlignmentDirectional
                                                  .centerStart,
                                              child: Text(
                                                balancesHidden
                                                    ? '••••••'
                                                    : ZakatEngineService.formatCurrency(
                                                        totalLiabilitiesMain,
                                                        mainCurrency,
                                                        isArabic: isArabic,
                                                      ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Right Column
                                      Container(
                                        padding:
                                            const EdgeInsetsDirectional.only(
                                              start: 12,
                                            ),
                                        decoration: const BoxDecoration(
                                          border: BorderDirectional(
                                            start: BorderSide(
                                              color: Colors.white24,
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Row(
                                              children: <Widget>[
                                                Icon(
                                                  changePct >= 0
                                                      ? Icons.trending_up
                                                      : Icons.trending_down,
                                                  color: changePct >= 0
                                                      ? Colors.greenAccent
                                                      : Colors.redAccent,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(1)}%',
                                                  style: TextStyle(
                                                    color: changePct >= 0
                                                        ? Colors.greenAccent
                                                        : Colors.redAccent,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              context.l10n.tr('this_year'),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.75,
                                                ),
                                                fontSize: 11,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: <Widget>[
                                                Icon(
                                                  Icons.layers_outlined,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.75),
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '$totalAssetsCount ${context.l10n.tr('assets')}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: <Widget>[
                                                Icon(
                                                  Icons.public_outlined,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.75),
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '$uniqueCurrenciesCount ${context.l10n.tr('currency')}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date Filters Row
                    LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  Icons.calendar_month_outlined,
                                  size: 20,
                                  color: tokens.colors.textPrimary,
                                ),
                                SizedBox(width: compact ? 6 : 8),
                                ...<String>[
                                  'All Time',
                                  '30D',
                                  '90D',
                                  'YTD',
                                  'Custom',
                                ].map((filter) {
                                  final bool isSelected =
                                      _selectedDateFilter == filter;
                                  String label = filter;
                                  if (filter == 'All Time') {
                                    label = context.l10n.tr('all_time');
                                  } else if (filter == '30D') {
                                    label = context.l10n.tr('period_30d');
                                  } else if (filter == '90D') {
                                    label = context.l10n.tr('period_90d');
                                  } else if (filter == 'YTD') {
                                    label = context.l10n.tr('period_ytd');
                                  } else if (filter == 'Custom') {
                                    label = context.l10n.tr('period_custom');
                                  }
                                  if (filter == 'Custom' &&
                                      _customDateRange != null &&
                                      _selectedDateFilter == 'Custom') {
                                    final String startStr =
                                        '${_customDateRange!.start.day}/${_customDateRange!.start.month}';
                                    final String endStr =
                                        '${_customDateRange!.end.day}/${_customDateRange!.end.month}';
                                    label = '$startStr-$endStr';
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: ChoiceChip(
                                      labelPadding: EdgeInsets.zero,
                                      padding: ResponsiveLayout.chipPadding(
                                        context,
                                      ),
                                      visualDensity: const VisualDensity(
                                        horizontal: -1,
                                        vertical: -1,
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      labelStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      label: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          label,
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      selected: isSelected,
                                      onSelected: (bool selected) {
                                        if (filter == 'Custom') {
                                          _selectCustomRange(context);
                                        } else {
                                          setState(() {
                                            _selectedDateFilter = filter;
                                          });
                                        }
                                      },
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    _buildPageSelector(context),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ];
        },
        body: PageView(
          controller: _pageController,
          onPageChanged: (int page) {
            if (mounted && _selectedPage != page) {
              setState(() => _selectedPage = page);
            }
          },
          children: <Widget>[
            // 1. Assets Tab (5 Categories: Cash, Metals, Company Shares, Properties, Vehicles)
            ListView(
              padding: EdgeInsets.fromLTRB(
                ResponsiveLayout.compactHorizontalPadding(context),
                0,
                ResponsiveLayout.compactHorizontalPadding(context),
                navSafeBottomPadding,
              ),
              children: <Widget>[
                // 1. Cash Card
                _buildCategoryCard(
                  context,
                  title: context.l10n.tr('cash'),
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: const Color(0xFF047857),
                  iconBg: const Color(0xFFD1FAE5),
                  subtitle:
                      '${cashByCurrency.length} ${context.l10n.tr('currency')}',
                  value: cashTotalMain,
                  percentage: pct(cashTotalEgp),
                  balancesHidden: balancesHidden,
                  mainCurrency: mainCurrency,
                  isArabic: isArabic,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const CategoryDetailsScreen(categoryType: 'cash'),
                    ),
                  ),
                  extra: cashByCurrency.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: <Widget>[
                              ...cashByCurrency.entries.take(3).map((entry) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tokens.colors.background,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_getFlagEmoji(entry.key)),
                                      const SizedBox(width: 4),
                                      Text(
                                        balancesHidden
                                            ? '••'
                                            : ZakatEngineService.formatCurrency(
                                                entry.value,
                                                entry.key,
                                                isArabic: isArabic,
                                              ),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: tokens.colors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              if (cashByCurrency.length > 3)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tokens.colors.background,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '+${cashByCurrency.length - 3}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: tokens.colors.textSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : null,
                ),

                // 2. Metals Card (Gold & Silver combined)
                _buildCategoryCard(
                  context,
                  title: context.l10n.tr('metals'),
                  icon: Icons.auto_awesome,
                  iconColor: const Color(0xFFB7791F),
                  iconBg: const Color(0xFFFEF3C7),
                  subtitle: context.l10n.tr('gold_and_silver'),
                  value: goldTotalMain + silverTotalMain,
                  percentage: pct(goldTotalEgp + silverTotalEgp),
                  balancesHidden: balancesHidden,
                  mainCurrency: mainCurrency,
                  isArabic: isArabic,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MetalsScreen(),
                    ),
                  ),
                ),

                // 3. Company Shares Card
                _buildCategoryCard(
                  context,
                  title: context.l10n.tr('company_shares'),
                  icon: Icons.show_chart,
                  iconColor: const Color(0xFF6B21A8),
                  iconBg: const Color(0xFFF3E8FF),
                  subtitle: context.l10n.tr('stocks_funds_etc'),
                  value: investmentsTotalMain,
                  percentage: pct(investmentsTotalEgp),
                  balancesHidden: balancesHidden,
                  mainCurrency: mainCurrency,
                  isArabic: isArabic,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CategoryDetailsScreen(
                        categoryType: 'investments',
                      ),
                    ),
                  ),
                ),

                // 4. Properties Card (Renamed from Property)
                _buildCategoryCard(
                  context,
                  title: context.l10n.tr('properties'),
                  icon: Icons.home_outlined,
                  iconColor: const Color(0xFFC2410C),
                  iconBg: const Color(0xFFFFEDD5),
                  subtitle:
                      '${propertyList.length} ${context.l10n.tr('properties')}',
                  value: propertyTotalMain,
                  percentage: pct(propertyTotalEgp),
                  balancesHidden: balancesHidden,
                  mainCurrency: mainCurrency,
                  isArabic: isArabic,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const CategoryDetailsScreen(categoryType: 'property'),
                    ),
                  ),
                ),

                // 5. Vehicles Card (Renamed from Other Assets)
                _buildCategoryCard(
                  context,
                  title: context.l10n.tr('vehicles'),
                  icon: Icons.directions_car_outlined,
                  iconColor: const Color(0xFF0369A1),
                  iconBg: const Color(0xFFE0F2FE),
                  subtitle:
                      '${vehicleAssetsList.length} ${context.l10n.tr('entries')}',
                  value: vehicleAssetsTotalMain,
                  percentage: pct(vehicleAssetsTotalEgp),
                  balancesHidden: balancesHidden,
                  mainCurrency: mainCurrency,
                  isArabic: isArabic,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CategoryDetailsScreen(
                        categoryType: 'other_assets',
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),

            // 2. Liabilities Tab (Exactly TWO Cards: Credit Cards & Other Liabilities)
            ListView(
              padding: EdgeInsets.fromLTRB(
                ResponsiveLayout.compactHorizontalPadding(context),
                0,
                ResponsiveLayout.compactHorizontalPadding(context),
                navSafeBottomPadding,
              ),
              children: <Widget>[
                _buildLiabilitiesPage(
                  context,
                  controller: controller,
                  mainCurrency: mainCurrency,
                  isArabic: isArabic,
                  balancesHidden: balancesHidden,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String subtitle,
    required double value,
    required double percentage,
    required bool balancesHidden,
    required String mainCurrency,
    required bool isArabic,
    required VoidCallback onTap,
    Widget? extra,
  }) {
    final formattedValue = ZakatEngineService.formatCurrency(
      value,
      mainCurrency,
      isArabic: isArabic,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: iconBg,
                  radius: 20,
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: ResponsiveLayout.isCompact(context) ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text(
                        balancesHidden ? '••••••' : formattedValue,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      '${percentage.toStringAsFixed(1)}% ${context.l10n.tr('of_total')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).hintColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).hintColor,
                  size: 20,
                ),
              ],
            ),
            // ignore: use_null_aware_elements
            if (extra != null) extra,
          ],
        ),
      ),
    );
  }

  Widget _buildPageSelector(BuildContext context) {
    final tokens = context.premiumTokens;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          _pageSelectorItem(context, 0, context.l10n.tr('assets')),
          _pageSelectorItem(context, 1, context.l10n.tr('liabilities')),
        ],
      ),
    );
  }

  Widget _pageSelectorItem(BuildContext context, int page, String label) {
    final tokens = context.premiumTokens;
    final bool selected = _selectedPage == page;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: () {
            _pageController.animateToPage(
              page,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: selected ? tokens.colors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? Border.all(
                      color: tokens.colors.gold.withValues(alpha: 0.55),
                    )
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? tokens.colors.gold
                    : tokens.colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiabilitiesPage(
    BuildContext context, {
    required AppStateController controller,
    required String mainCurrency,
    required bool isArabic,
    required bool balancesHidden,
  }) {
    final MarketData market = MarketData.fromJson(controller.state.marketData);
    final List<CreditCard> cards = controller.state.creditCards
        .where((CreditCard card) => !card.isArchived)
        .toList(growable: false);
    double normalized(double amount, String currency) =>
        ZakatEngineService.convertFromEgp(
          ZakatEngineService.convertToEgp(amount, currency, market),
          mainCurrency,
          market,
        );
    final double owed = cards.fold<double>(
      0,
      (double sum, CreditCard card) => card.parentCardId == null
          ? sum + normalized(card.openingBalance, card.currency)
          : sum,
    );
    final double otherLiabilities = _loanLiabilityMain(
      controller,
      mainCurrency,
    );
    final double displayedLiabilitiesTotal = owed + otherLiabilities;
    double liabilityPercentage(double value) => displayedLiabilitiesTotal > 0
        ? ((value.abs() / displayedLiabilitiesTotal) * 100).clamp(0, 100)
        : 0;
    final String owedFormatted = ZakatEngineService.formatCurrency(
      owed,
      mainCurrency,
      isArabic: isArabic,
    );
    final double limit = cards.fold<double>(
      0,
      (double sum, CreditCard card) => card.parentCardId == null
          ? sum + normalized(card.creditLimit, card.currency)
          : sum,
    );
    final double available = (limit - owed).clamp(0, double.infinity);
    final String availableFormatted = ZakatEngineService.formatCurrency(
      available,
      mainCurrency,
      isArabic: isArabic,
    );

    return Column(
      children: <Widget>[
        _buildLiabilityCard(
          context,
          title: context.l10n.tr('credit_cards'),
          icon: Icons.credit_card_outlined,
          iconColor: const Color(0xFFB91C1C),
          iconBg: const Color(0xFFFEE2E2),
          subtitle: '${cards.length} ${context.l10n.tr('cards')}',
          primaryValue: balancesHidden ? '••••••' : '-$owedFormatted',
          primaryLabel: context.l10n.tr('owed'),
          secondaryValue: balancesHidden
              ? '••••••'
              : '$availableFormatted ${context.l10n.tr('available_credit')}',
          percentage: liabilityPercentage(owed),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CreditCardsScreen()),
          ),
        ),
        _buildLiabilityCard(
          context,
          title: context.l10n.tr('other_liabilities'),
          icon: Icons.receipt_long_outlined,
          iconColor: const Color(0xFFB45309),
          iconBg: const Color(0xFFFEF3C7),
          subtitle: _loanCount(context, controller),
          primaryValue: balancesHidden
              ? '••••••'
              : '-${ZakatEngineService.formatCurrency(otherLiabilities, mainCurrency, isArabic: isArabic)}',
          primaryLabel: context.l10n.tr('total_other_liabilities'),
          percentage: liabilityPercentage(otherLiabilities),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const CategoryDetailsScreen(categoryType: 'liabilities'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiabilityCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String subtitle,
    required String primaryValue,
    required String primaryLabel,
    String? secondaryValue,
    required double percentage,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: iconBg,
              radius: 20,
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: ResponsiveLayout.isCompact(context) ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    primaryValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: iconColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  primaryLabel,
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 11,
                  ),
                ),
                if (secondaryValue != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondaryValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF047857),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  '${percentage.toStringAsFixed(1)}% ${context.l10n.tr('of_total')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).hintColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _loanCount(BuildContext context, AppStateController controller) {
    final int count = controller.state.investments
        .where(
          (InvestmentAsset asset) =>
              ZakatEngineService.normaliseInvestmentType(
                asset.investmentType,
              ) ==
              'liability',
        )
        .length;
    return '$count ${context.l10n.tr('entries')}';
  }

  double _loanLiabilityMain(
    AppStateController controller,
    String mainCurrency,
  ) {
    final MarketData market = MarketData.fromJson(controller.state.marketData);
    final double egp = controller.state.investments
        .where(
          (InvestmentAsset asset) =>
              ZakatEngineService.normaliseInvestmentType(
                asset.investmentType,
              ) ==
              'liability',
        )
        .fold<double>(0, (double sum, InvestmentAsset asset) {
          final double value = asset.installmentPlan.isNotEmpty
              ? asset.installmentPlan
                    .where(
                      (Map<String, dynamic> item) => item['isPaid'] != true,
                    )
                    .fold<double>(
                      0,
                      (double subtotal, Map<String, dynamic> item) =>
                          subtotal +
                          ZakatEngineService.convertToEgp(
                            ((item['amount'] ?? 0) as num).toDouble(),
                            item['currency']?.toString() ?? asset.currency,
                            market,
                          ),
                    )
              : ZakatEngineService.convertToEgp(
                  asset.loanBalance > 0
                      ? asset.loanBalance
                      : asset.remainingAmount,
                  asset.currency,
                  market,
                );
          return sum + value;
        });
    return ZakatEngineService.convertFromEgp(egp, mainCurrency, market);
  }
}

class _AssetsHeader extends StatelessWidget {
  const _AssetsHeader({
    required this.title,
    required this.balancesHidden,
    required this.onTogglePrivacy,
    required this.hasNotifications,
    required this.onTapNotifications,
  });

  final String title;
  final bool balancesHidden;
  final VoidCallback onTogglePrivacy;
  final bool hasNotifications;
  final VoidCallback onTapNotifications;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final textTheme = Theme.of(context).textTheme;
    final bool compact = ResponsiveLayout.isCompact(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.headlineMedium?.copyWith(
              color: tokens.colors.textPrimary,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _HeaderCircleButton(
              icon: balancesHidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              iconColor: tokens.colors.textPrimary,
              onPressed: onTogglePrivacy,
            ),
            SizedBox(width: compact ? 8 : 10),
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                _HeaderCircleButton(
                  icon: Icons.notifications_none_rounded,
                  iconColor: tokens.colors.textPrimary,
                  onPressed: onTapNotifications,
                ),
                if (hasNotifications)
                  PositionedDirectional(
                    end: 7,
                    top: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: tokens.colors.gold,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: tokens.colors.background,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({
    required this.icon,
    required this.iconColor,
    required this.onPressed,
  });

  final IconData icon;
  final Color iconColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final bool compact = ResponsiveLayout.isCompact(context);
    return Material(
      color: dark
          ? Colors.white.withValues(alpha: 0.03)
          : Colors.white.withValues(alpha: 0.74),
      shape: const CircleBorder(),
      elevation: dark ? 0 : 5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: SizedBox(
        width: compact ? 48 : 52,
        height: compact ? 48 : 52,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: iconColor, size: compact ? 22 : 24),
          splashRadius: compact ? 22 : 24,
        ),
      ),
    );
  }
}
