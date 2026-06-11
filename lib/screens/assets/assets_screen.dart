import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/theme/app_radii.dart';
import '../../models/investment_asset.dart';
import '../../models/saving.dart';
import '../../models/transaction.dart';
import '../../services/app_state_controller.dart';
import 'category_details_screen.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key, this.onViewAllActivity});

  final VoidCallback? onViewAllActivity;

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  String _selectedDateFilter = 'All Time';
  DateTimeRange? _customDateRange;

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
      final double share = (a.ownershipSharePct / 100).clamp(0, 1);
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
          (a) => !ZakatEngineService.isCompanyInvestmentType(a.investmentType),
        )
        .toList();
    final double propertyTotalEgp = propertyList.fold<double>(0, (sum, a) {
      final double share = (a.ownershipSharePct / 100).clamp(0, 1);
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

    // Percentages of total wealth
    double pct(double catEgp) => totalWealthEgp > 0
        ? ((catEgp / totalWealthEgp) * 100).clamp(0, 100)
        : 0.0;

    final tokens = context.premiumTokens;

    return Container(
      color: tokens.colors.background,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 20, 16, navSafeBottomPadding),
        children: <Widget>[
          _AssetsHeader(
            title: context.l10n.tr('assets'),
            balancesHidden: balancesHidden,
            onTogglePrivacy: () => controller.togglePrivacyMode(),
            hasNotifications: false,
            onTapNotifications: () {},
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
                  colors: <Color>[Color(0xFF01332B), Color(0xFF00221C)],
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
                                alpha: isDark ? 0.20 : 0.38,
                              ),
                              Colors.white.withValues(
                                alpha: isDark ? 0.01 : 0.05,
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
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            // Left Column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                  Text(
                                    balancesHidden
                                        ? '••••••'
                                        : ZakatEngineService.formatCurrency(
                                            totalWealthMain,
                                            mainCurrency,
                                            isArabic: isArabic,
                                          ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    balancesHidden
                                        ? '≈ ••••••'
                                        : '≈ ${ZakatEngineService.formatCurrency(altCurrencyVal, altCurrency, isArabic: isArabic)}',
                                    style: const TextStyle(
                                      color: Colors.white70,
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
                                  Text(
                                    balancesHidden
                                        ? '••••••'
                                        : ZakatEngineService.formatCurrency(
                                            totalLiabilitiesMain,
                                            mainCurrency,
                                            isArabic: isArabic,
                                          ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Right Column
                            Container(
                              padding: const EdgeInsetsDirectional.only(
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: <Widget>[
                                      const Icon(
                                        Icons.layers_outlined,
                                        color: Colors.white70,
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
                                      const Icon(
                                        Icons.public_outlined,
                                        color: Colors.white70,
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
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 20,
                        color: tokens.colors.textPrimary,
                      ),
                      const SizedBox(width: 8),
                      ...<String>[
                        'All Time',
                        '30D',
                        '90D',
                        'YTD',
                        'Custom',
                      ].map((filter) {
                        final bool isSelected = _selectedDateFilter == filter;
                        String label = filter;
                        if (filter == 'All Time') {
                          label = context.l10n.tr('all');
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
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: ChoiceChip(
                            labelPadding: EdgeInsets.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
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

          // 1. Cash Card
          _buildCategoryCard(
            context,
            title: context.l10n.tr('cash'),
            icon: Icons.account_balance_wallet_outlined,
            iconColor: const Color(0xFF047857),
            iconBg: const Color(0xFFD1FAE5),
            subtitle: '${cashByCurrency.length} ${context.l10n.tr('currency')}',
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

          // 2. Gold Card
          _buildCategoryCard(
            context,
            title: context.l10n.tr('gold'),
            icon: Icons.auto_awesome,
            iconColor: const Color(0xFFB7791F),
            iconBg: const Color(0xFFFEF3C7),
            subtitle: '${gold24k.toStringAsFixed(2)} g',
            value: goldTotalMain,
            percentage: pct(goldTotalEgp),
            balancesHidden: balancesHidden,
            mainCurrency: mainCurrency,
            isArabic: isArabic,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const CategoryDetailsScreen(categoryType: 'gold'),
              ),
            ),
          ),

          // 3. Silver Card
          _buildCategoryCard(
            context,
            title: context.l10n.tr('silver'),
            icon: Icons.layers,
            iconColor: const Color(0xFF4B5563),
            iconBg: const Color(0xFFF3F4F6),
            subtitle:
                '${silverList.fold<double>(0, (sum, s) => sum + s.remainingAmount).toStringAsFixed(1)} g',
            value: silverTotalMain,
            percentage: pct(silverTotalEgp),
            balancesHidden: balancesHidden,
            mainCurrency: mainCurrency,
            isArabic: isArabic,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const CategoryDetailsScreen(categoryType: 'silver'),
              ),
            ),
          ),

          // 4. Investments Card
          _buildCategoryCard(
            context,
            title: context.l10n.tr('company_shares'),
            icon: Icons.show_chart,
            iconColor: const Color(0xFF6B21A8),
            iconBg: const Color(0xFFF3E8FF),
            subtitle: 'Stocks, Funds, etc.',
            value: investmentsTotalMain,
            percentage: pct(investmentsTotalEgp),
            balancesHidden: balancesHidden,
            mainCurrency: mainCurrency,
            isArabic: isArabic,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const CategoryDetailsScreen(categoryType: 'investments'),
              ),
            ),
          ),

          // 5. Real Estate Card
          _buildCategoryCard(
            context,
            title: context.l10n.tr('property'),
            icon: Icons.home_outlined,
            iconColor: const Color(0xFFC2410C),
            iconBg: const Color(0xFFFFEDD5),
            subtitle: '${propertyList.length} Property',
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

          // Empty space at bottom of ListView
          const SizedBox(height: 16),
        ],
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
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      balancesHidden ? '••••••' : formattedValue,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${percentage.toStringAsFixed(1)}% of total',
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Text(
            title,
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
            const SizedBox(width: 10),
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
    return Material(
      color: dark
          ? Colors.white.withValues(alpha: 0.03)
          : Colors.white.withValues(alpha: 0.74),
      shape: const CircleBorder(),
      elevation: dark ? 0 : 5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: SizedBox(
        width: 52,
        height: 52,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: iconColor, size: 24),
          splashRadius: 24,
        ),
      ),
    );
  }
}
