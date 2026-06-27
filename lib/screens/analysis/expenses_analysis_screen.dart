import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/motion/app_motion.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/utils/category_visuals.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/compact_dropdown.dart';
import '../../models/app_state.dart';
import '../../models/investment_asset.dart';
import '../../models/saving.dart';
import '../../models/transaction.dart';
import '../../services/app_state_controller.dart';

const double _kAnalyticsCardRadius = 24;
const double _kAnalyticsIconBoxSize = 38;
const double _kAnalyticsIconRadius = 12;

class ExpenseAnalysisScreen extends StatefulWidget {
  const ExpenseAnalysisScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const ExpenseAnalysisScreen(),
    );
  }

  @override
  State<ExpenseAnalysisScreen> createState() => _ExpenseAnalysisScreenState();
}

class _ExpenseAnalysisScreenState extends State<ExpenseAnalysisScreen> {
  String _selectedPeriod = '30D';
  String _selectedGrouping = 'category';
  String _trendGranularity = 'Daily';
  DateTimeRange? _customRange;

  Future<void> _selectCustomRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange:
          _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _selectedPeriod = 'Custom';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStateController controller = context.watch<AppStateController>();
    final AppStateModel state = controller.state;
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final bool balancesHidden = _isBalanceHidden(state);
    final MarketData market = MarketData.fromJson(state.marketData);
    final List<Transaction> transactions = state.transactions;
    final List<Saving> savings = state.savings;
    final List<InvestmentAsset> investments = state.investments;
    final ExpenseAnalysisData data = _buildAnalysisData(
      transactions: transactions,
      savings: savings,
      investments: investments,
      categories: state.categories,
      market: market,
      selectedPeriod: _selectedPeriod,
      customRange: _customRange,
      grouping: _selectedGrouping,
    );

    final ColorScheme colors = Theme.of(context).colorScheme;
    final double bottomInset = 112 + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: context.premiumTokens.colors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset),
          children: <Widget>[
            _AnalysisHeader(
              isArabic: isArabic,
              balancesHidden: balancesHidden,
              onBack: () => Navigator.of(context).maybePop(),
              onTogglePrivacy: controller.togglePrivacyMode,
              onOpenFilters: () => _selectCustomRange(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isArabic ? 'تحليل المصروفات' : 'Expenses Analysis',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isArabic
                  ? 'افهم أنماط الإنفاق لديك'
                  : 'Understand your spending patterns',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            _PeriodFilterRow(
              selectedPeriod: _selectedPeriod,
              isArabic: isArabic,
              onCalendarTap: () => _selectCustomRange(context),
              onSelected: (String value) {
                setState(() => _selectedPeriod = value);
              },
            ),
            const SizedBox(height: 16),
            AnimatedSection(
              child: _HeroSummaryCard(
                data: data,
                balancesHidden: balancesHidden,
                selectedGrouping: _selectedGrouping,
                selectedPeriod: _selectedPeriod,
                onGroupingChanged: (String value) {
                  setState(() => _selectedGrouping = value);
                },
                isArabic: isArabic,
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSection(
              delay: const Duration(milliseconds: 35),
              child: _CategoryBreakdownCard(
                data: data,
                balancesHidden: balancesHidden,
                isArabic: isArabic,
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSection(
              delay: const Duration(milliseconds: 70),
              child: _TrendCard(
                data: data,
                balancesHidden: balancesHidden,
                isArabic: isArabic,
                granularity: _trendGranularity,
                onGranularityChanged: (String value) {
                  setState(() => _trendGranularity = value);
                },
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSection(
              delay: const Duration(milliseconds: 105),
              child: _InsightsCard(
                data: data,
                balancesHidden: balancesHidden,
                isArabic: isArabic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _isBalanceHidden(AppStateModel state) {
    return state.aiSettings?['privacyMode'] == true ||
        state.aiSettings?['hideBalances'] == true ||
        state.aiSettings?['balancesHidden'] == true;
  }

  static ExpenseAnalysisData _buildAnalysisData({
    required List<Transaction> transactions,
    required List<Saving> savings,
    required List<InvestmentAsset> investments,
    required AppCategories categories,
    required MarketData market,
    required String selectedPeriod,
    required DateTimeRange? customRange,
    required String grouping,
  }) {
    final DateTime now = DateTime.now();
    final List<Transaction> expenseTxs = transactions
        .where(
          (Transaction tx) => tx.type == 'expense' && !tx.isTransferActivity,
        )
        .toList(growable: false);
    final List<_DatedExpense> datedExpenses = expenseTxs
        .map(
          (Transaction tx) => _DatedExpense(
            tx: tx,
            date: _parseDate(tx.date) ?? now,
            amountEgp: ZakatEngineService.convertToEgp(
              tx.amount,
              tx.currency,
              market,
            ),
          ),
        )
        .where((expense) => expense.amountEgp.isFinite && expense.amountEgp > 0)
        .toList(growable: false);

    final DateTimeRange range = _selectedRange(
      selectedPeriod: selectedPeriod,
      customRange: customRange,
      datedExpenses: datedExpenses,
      now: now,
    );
    final DateTime previousStart = range.start.subtract(
      range.end.difference(range.start),
    );
    final DateTime previousEnd = range.start.subtract(const Duration(days: 1));

    final List<_DatedExpense> currentExpenses = datedExpenses
        .where((expense) {
          return !expense.date.isBefore(range.start) &&
              !expense.date.isAfter(range.end.add(const Duration(days: 1)));
        })
        .toList(growable: false);

    final List<_DatedExpense> previousExpenses = datedExpenses
        .where((expense) {
          return !expense.date.isBefore(previousStart) &&
              !expense.date.isAfter(previousEnd.add(const Duration(days: 1)));
        })
        .toList(growable: false);

    final double totalCurrent = currentExpenses.fold<double>(
      0,
      (double total, _DatedExpense expense) => total + expense.amountEgp,
    );
    final double totalPrevious = previousExpenses.fold<double>(
      0,
      (double total, _DatedExpense expense) => total + expense.amountEgp,
    );
    final double changePct = totalPrevious <= 0
        ? 0
        : ((totalCurrent - totalPrevious) / totalPrevious) * 100;

    final Map<DateTime, double> dailyTotals = <DateTime, double>{};
    for (final _DatedExpense expense in currentExpenses) {
      final DateTime key = DateTime(
        expense.date.year,
        expense.date.month,
        expense.date.day,
      );
      dailyTotals[key] = (dailyTotals[key] ?? 0) + expense.amountEgp;
    }

    final List<DateTime> days = _daysBetween(range.start, range.end);
    final List<double> trendValues = days
        .map(
          (DateTime day) =>
              dailyTotals[DateTime(day.year, day.month, day.day)] ?? 0,
        )
        .toList(growable: false);
    final double averageDaily = days.isEmpty ? 0 : totalCurrent / days.length;

    DateTime highestDay = range.start;
    double highestDayValue = 0;
    for (final MapEntry<DateTime, double> entry in dailyTotals.entries) {
      if (entry.value > highestDayValue) {
        highestDay = entry.key;
        highestDayValue = entry.value;
      }
    }

    final Map<String, double> groupTotals = <String, double>{};
    final Map<String, CategoryVisual> groupVisuals = <String, CategoryVisual>{};
    for (final _DatedExpense expense in currentExpenses) {
      final String groupKey = grouping == 'merchant'
          ? _merchantLabel(expense.tx)
          : _categoryLabel(expense.tx);
      final CategoryVisual visual = CategoryVisuals.resolveCategoryVisual(
        categories: categories,
        type: 'expense',
        categoryName: groupKey,
      );
      groupTotals[groupKey] = (groupTotals[groupKey] ?? 0) + expense.amountEgp;
      groupVisuals[groupKey] = visual;
    }

    final List<ExpenseGroup> groups =
        groupTotals.entries
            .map(
              (MapEntry<String, double> entry) => ExpenseGroup(
                label: entry.key,
                amountEgp: entry.value,
                visual:
                    groupVisuals[entry.key] ??
                    CategoryVisuals.resolveTypeFallback('expense'),
              ),
            )
            .toList(growable: false)
          ..sort(
            (ExpenseGroup a, ExpenseGroup b) =>
                b.amountEgp.compareTo(a.amountEgp),
          );

    final double averagePerTransaction = currentExpenses.isEmpty
        ? 0
        : totalCurrent / currentExpenses.length;

    final List<MerchantSpend> merchantSpends = <MerchantSpend>[];
    final Map<String, double> merchantTotals = <String, double>{};
    for (final _DatedExpense expense in currentExpenses) {
      final String merchant = _merchantLabel(expense.tx);
      merchantTotals[merchant] =
          (merchantTotals[merchant] ?? 0) + expense.amountEgp;
    }
    merchantTotals.forEach(
      (String label, double amount) =>
          merchantSpends.add(MerchantSpend(label: label, amountEgp: amount)),
    );
    merchantSpends.sort((a, b) => b.amountEgp.compareTo(a.amountEgp));

    final List<CategoryDelta> deltas = _categoryDeltas(
      currentExpenses: currentExpenses,
      previousExpenses: previousExpenses,
    );

    return ExpenseAnalysisData(
      totalCurrent: totalCurrent,
      totalPrevious: totalPrevious,
      changePct: changePct,
      averageDaily: averageDaily,
      highestDay: highestDay,
      highestDayValue: highestDayValue,
      transactionCount: currentExpenses.length,
      averagePerTransaction: averagePerTransaction,
      range: range,
      trendValues: trendValues,
      groups: groups,
      merchantSpends: merchantSpends,
      categoryDeltas: deltas,
      selectedPeriod: selectedPeriod,
      investments: investments,
      savings: savings,
      market: market,
    );
  }

  static List<CategoryDelta> _categoryDeltas({
    required List<_DatedExpense> currentExpenses,
    required List<_DatedExpense> previousExpenses,
  }) {
    final Map<String, double> current = <String, double>{};
    final Map<String, double> previous = <String, double>{};
    for (final _DatedExpense expense in currentExpenses) {
      final String key = _categoryLabel(expense.tx);
      current[key] = (current[key] ?? 0) + expense.amountEgp;
    }
    for (final _DatedExpense expense in previousExpenses) {
      final String key = _categoryLabel(expense.tx);
      previous[key] = (previous[key] ?? 0) + expense.amountEgp;
    }
    final Set<String> keys = <String>{...current.keys, ...previous.keys};
    final List<CategoryDelta> deltas = <CategoryDelta>[];
    for (final String key in keys) {
      final double currentValue = current[key] ?? 0;
      final double previousValue = previous[key] ?? 0;
      final double pct = previousValue <= 0
          ? (currentValue > 0 ? 100 : 0)
          : ((currentValue - previousValue) / previousValue) * 100;
      deltas.add(
        CategoryDelta(
          label: key,
          currentValue: currentValue,
          previousValue: previousValue,
          pct: pct,
        ),
      );
    }
    deltas.sort((a, b) => b.currentValue.compareTo(a.currentValue));
    return deltas;
  }

  static DateTimeRange _selectedRange({
    required String selectedPeriod,
    required DateTimeRange? customRange,
    required List<_DatedExpense> datedExpenses,
    required DateTime now,
  }) {
    if (selectedPeriod == 'Custom' && customRange != null) {
      return customRange;
    }
    switch (selectedPeriod) {
      case 'All':
        final DateTime start = datedExpenses.isEmpty
            ? now.subtract(const Duration(days: 30))
            : datedExpenses
                  .map((e) => e.date)
                  .reduce((a, b) => a.isBefore(b) ? a : b);
        final DateTime end = datedExpenses.isEmpty
            ? now
            : datedExpenses
                  .map((e) => e.date)
                  .reduce((a, b) => a.isAfter(b) ? a : b);
        return DateTimeRange(start: start, end: end);
      case '90D':
        return DateTimeRange(
          start: now.subtract(const Duration(days: 90)),
          end: now,
        );
      case '6M':
        return DateTimeRange(
          start: DateTime(now.year, now.month - 6, now.day),
          end: now,
        );
      case 'YTD':
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
      case '30D':
      default:
        return DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );
    }
  }

  static List<DateTime> _daysBetween(DateTime start, DateTime end) {
    final DateTime startDay = DateTime(start.year, start.month, start.day);
    final DateTime endDay = DateTime(end.year, end.month, end.day);
    final int count = endDay.difference(startDay).inDays;
    return List<DateTime>.generate(
      math.max(1, count + 1),
      (int index) => startDay.add(Duration(days: index)),
    );
  }

  static DateTime? _parseDate(String value) {
    if (value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static String _categoryLabel(Transaction tx) {
    final String category = tx.category.trim();
    if (category.isNotEmpty) return category;
    final String description = tx.description.trim();
    if (description.isNotEmpty) return description;
    return 'Other';
  }

  static String _merchantLabel(Transaction tx) {
    final String description = tx.description.trim();
    if (description.isNotEmpty) {
      final List<String> parts = description.split(RegExp(r'\s+'));
      if (parts.isNotEmpty) return _titleCase(parts.first);
    }
    return _categoryLabel(tx);
  }

  static String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }
}

class _AnalysisHeader extends StatelessWidget {
  const _AnalysisHeader({
    required this.isArabic,
    required this.balancesHidden,
    required this.onBack,
    required this.onTogglePrivacy,
    required this.onOpenFilters,
  });

  final bool isArabic;
  final bool balancesHidden;
  final VoidCallback onBack;
  final VoidCallback onTogglePrivacy;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _CircleActionButton(icon: Icons.arrow_back_rounded, onPressed: onBack),
        const Spacer(),
        _CircleActionButton(
          icon: balancesHidden
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          onPressed: onTogglePrivacy,
        ),
        const SizedBox(width: 12),
        _CircleActionButton(
          icon: Icons.filter_alt_outlined,
          onPressed: onOpenFilters,
        ),
      ],
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Material(
      color: tokens.colors.surface,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, size: 22, color: tokens.colors.textPrimary),
        ),
      ),
    );
  }
}

class _PeriodFilterRow extends StatelessWidget {
  const _PeriodFilterRow({
    required this.selectedPeriod,
    required this.isArabic,
    required this.onCalendarTap,
    required this.onSelected,
  });

  final String selectedPeriod;
  final bool isArabic;
  final VoidCallback onCalendarTap;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final List<String> periods = <String>[
      'All',
      '30D',
      '90D',
      '6M',
      'YTD',
      'Custom',
    ];
    return Row(
      children: <Widget>[
        _CircleActionButton(
          icon: Icons.calendar_month_outlined,
          onPressed: onCalendarTap,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: periods
                  .map((String period) {
                    final bool selected = selectedPeriod == period;
                    final String label = switch (period) {
                      'All' => isArabic ? 'الكل' : 'All',
                      '30D' => '30D',
                      '90D' => '90D',
                      '6M' => '6M',
                      'YTD' => 'YTD',
                      'Custom' => isArabic ? 'مخصص' : 'Custom',
                      _ => period,
                    };
                    return Padding(
                      padding: const EdgeInsetsDirectional.only(end: 10),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: selected ? 1 : 0.98,
                          end: selected ? 1 : 0.98,
                        ),
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        builder:
                            (
                              BuildContext context,
                              double scale,
                              Widget? child,
                            ) {
                              return Transform.scale(
                                scale: scale,
                                child: child,
                              );
                            },
                        child: Material(
                          color: selected
                              ? tokens.colors.emerald.withValues(alpha: 0.14)
                              : tokens.colors.surface,
                          elevation: selected ? 2 : 0,
                          shadowColor: Colors.black.withValues(
                            alpha: selected ? 0.14 : 0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: BorderSide(
                              color: selected
                                  ? tokens.colors.emerald.withValues(alpha: 0.4)
                                  : tokens.colors.divider.withValues(
                                      alpha: 0.65,
                                    ),
                            ),
                          ),
                          child: ChoiceChip(
                            selected: selected,
                            onSelected: (_) => onSelected(period),
                            label: Text(label),
                            labelStyle: TextStyle(
                              color: selected
                                  ? tokens.colors.emerald
                                  : tokens.colors.textPrimary,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                              side: BorderSide(color: Colors.transparent),
                            ),
                            backgroundColor: Colors.transparent,
                            selectedColor: Colors.transparent,
                            showCheckmark: false,
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroSummaryCard extends StatelessWidget {
  const _HeroSummaryCard({
    required this.data,
    required this.balancesHidden,
    required this.selectedGrouping,
    required this.selectedPeriod,
    required this.onGroupingChanged,
    required this.isArabic,
  });

  final ExpenseAnalysisData data;
  final bool balancesHidden;
  final String selectedGrouping;
  final String selectedPeriod;
  final ValueChanged<String> onGroupingChanged;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color borderColor = dark
        ? const Color(0xFFFFC928).withValues(alpha: 0.45)
        : const Color(0xFFC5A059).withValues(alpha: 0.65);
    final List<HeroMetric> metrics = <HeroMetric>[
      HeroMetric(
        icon: Icons.show_chart_rounded,
        title: isArabic ? 'المتوسط اليومي' : 'Daily Average',
        value: balancesHidden ? '••••••' : _money(data.averageDaily),
        subtitle: '',
        iconColor: tokens.colors.danger,
      ),
      HeroMetric(
        icon: Icons.emoji_events_outlined,
        title: isArabic ? 'أعلى يوم' : 'Highest Day',
        value: balancesHidden ? '••••••' : _money(data.highestDayValue),
        subtitle: _dateLabel(data.highestDay, isArabic),
        iconColor: tokens.colors.gold,
      ),
      HeroMetric(
        icon: Icons.receipt_long_outlined,
        title: isArabic ? 'المعاملات' : 'Transactions',
        value: isArabic
            ? _arabicDigits(data.transactionCount.toString())
            : data.transactionCount.toString(),
        subtitle: isArabic ? 'الإجمالي' : 'Total',
        iconColor: tokens.colors.gold,
      ),
      HeroMetric(
        icon: Icons.account_balance_wallet_outlined,
        title: isArabic ? 'المتوسط لكل معاملة' : 'Per Transaction',
        value: balancesHidden ? '••••••' : _money(data.averagePerTransaction),
        subtitle: isArabic ? 'المتوسط' : 'Average',
        iconColor: tokens.colors.emerald,
      ),
    ];

    return PremiumCard(
      hero: true,
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: AppRadii.hero,
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    final bool isRtl = Directionality.of(context).name == 'rtl';
                    return LinearGradient(
                      begin: isRtl
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      end: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                      colors: <Color>[
                        AppColors.white.withValues(alpha: dark ? 0.1 : 0.2),
                        AppColors.white.withValues(alpha: dark ? 0 : 0.02),
                      ],
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          isArabic ? 'إجمالي المصروفات' : 'TOTAL EXPENSES',
                          style: TextStyle(
                            color: tokens.colors.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      CompactDropdownButton<String>(
                        value: selectedGrouping == 'merchant'
                            ? (isArabic ? 'بالبائع' : 'By Merchant')
                            : (isArabic ? 'بالفئة' : 'By Category'),
                        labelText: isArabic ? 'التجميع' : 'Grouping',
                        items: <String>[
                          isArabic ? 'بالفئة' : 'By Category',
                          isArabic ? 'بالبائع' : 'By Merchant',
                        ],
                        itemLabel: (String value) => value,
                        onChanged: (String value) {
                          onGroupingChanged(
                            value.contains('Merchant') ||
                                    value.contains('بالبائع')
                                ? 'merchant'
                                : 'category',
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      balancesHidden ? '••••••' : _money(data.totalCurrent),
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Icon(
                        data.changePct >= 0
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 18,
                        color: data.changePct >= 0
                            ? tokens.colors.danger
                            : tokens.colors.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${data.changePct >= 0 ? '+' : ''}${data.changePct.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: data.changePct >= 0
                              ? tokens.colors.danger
                              : tokens.colors.success,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isArabic
                              ? 'مقارنة بالفترة السابقة'
                              : 'vs previous ${_periodLabel(selectedPeriod)}',
                          style: TextStyle(
                            color: AppColors.white.withValues(alpha: 0.67),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final double tileWidth = constraints.maxWidth >= 700
                              ? (constraints.maxWidth - 24) / 4
                              : (constraints.maxWidth - 12) / 2;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: metrics
                                .map<Widget>(
                                  (HeroMetric metric) => SizedBox(
                                    width: tileWidth,
                                    child: _HeroMetricTile(metric: metric),
                                  ),
                                )
                                .toList(growable: false),
                          );
                        },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetricTile extends StatelessWidget {
  const _HeroMetricTile({required this.metric});

  final HeroMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.16)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: _kAnalyticsIconBoxSize,
                height: _kAnalyticsIconBoxSize,
                decoration: BoxDecoration(
                  color: metric.iconColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(_kAnalyticsIconRadius),
                ),
                child: Icon(metric.icon, size: 20, color: metric.iconColor),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            metric.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.white.withValues(alpha: 0.68),
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              metric.value,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          if (metric.subtitle.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              metric.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.64),
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({
    required this.data,
    required this.balancesHidden,
    required this.isArabic,
  });

  final ExpenseAnalysisData data;
  final bool balancesHidden;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.pie_chart_outline_rounded,
                color: tokens.colors.emerald,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic ? 'المصروفات حسب الفئة' : 'Expenses by Category',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tokens.colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool stacked = constraints.maxWidth < 540;
              final Widget chart = SizedBox(
                height: 208,
                child: Center(
                  child: _DonutChart(
                    groups: data.topGroups,
                    progress: 1,
                    emptyColor: dark
                        ? tokens.colors.divider.withValues(alpha: 0.45)
                        : tokens.colors.divider,
                  ),
                ),
              );
              final Widget list = SizedBox(
                height: 220,
                child: ListView.separated(
                  itemCount: data.topGroups.length,
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final ExpenseGroup group = data.topGroups[index];
                    return _BreakdownRow(
                      group: group,
                      balancesHidden: balancesHidden,
                      total: data.totalCurrent,
                      isArabic: isArabic,
                    );
                  },
                ),
              );
              if (stacked) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[chart, const SizedBox(height: 10), list],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(child: chart),
                  const SizedBox(width: 16),
                  Expanded(child: list),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            isArabic ? 'عرض أعلى 6 فئات' : 'Showing top 6 categories',
            style: TextStyle(color: tokens.colors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.group,
    required this.balancesHidden,
    required this.total,
    required this.isArabic,
  });

  final ExpenseGroup group;
  final bool balancesHidden;
  final double total;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = CategoryVisuals.colorFromValue(
      group.visual.colorValue,
    );
    final double pct = total <= 0 ? 0 : (group.amountEgp / total) * 100;
    return Row(
      children: <Widget>[
        Container(
          width: _kAnalyticsIconBoxSize,
          height: _kAnalyticsIconBoxSize,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(_kAnalyticsIconRadius),
          ),
          child: Icon(
            CategoryVisuals.iconForKey(group.visual.iconKey),
            size: 20,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                group.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                balancesHidden ? '••••••' : _money(group.amountEgp),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 48,
          child: Text(
            '${pct.toStringAsFixed(1)}%',
            textAlign: TextAlign.end,
            style: TextStyle(
              color: iconColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.data,
    required this.balancesHidden,
    required this.isArabic,
    required this.granularity,
    required this.onGranularityChanged,
  });

  final ExpenseAnalysisData data;
  final bool balancesHidden;
  final bool isArabic;
  final String granularity;
  final ValueChanged<String> onGranularityChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final String comparison = data.changePct >= 0
        ? (isArabic ? 'أعلى من الفترة السابقة' : 'vs previous period')
        : (isArabic ? 'أقل من الفترة السابقة' : 'vs previous period');
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.show_chart_rounded, color: tokens.colors.emerald),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic ? 'اتجاه الإنفاق' : 'Spending Trends',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tokens.colors.textPrimary,
                  ),
                ),
              ),
              CompactDropdownButton<String>(
                value: granularity,
                labelText: isArabic ? 'المدى' : 'Range',
                items: const <String>['Daily', 'Weekly', 'Monthly'],
                itemLabel: (String value) => value,
                onChanged: onGranularityChanged,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      balancesHidden ? '••••••' : _money(data.averageDaily),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: tokens.colors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isArabic ? 'المتوسط اليومي' : 'Average Daily Spending',
                      style: TextStyle(
                        color: tokens.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${data.changePct >= 0 ? '+' : ''}${data.changePct.abs().toStringAsFixed(1)}%  $comparison',
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: data.changePct >= 0
                      ? tokens.colors.danger
                      : tokens.colors.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 245,
            child: _TrendChart(
              values: data.trendValues,
              isArabic: isArabic,
              color: dark ? tokens.colors.danger : tokens.colors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({
    required this.data,
    required this.balancesHidden,
    required this.isArabic,
  });

  final ExpenseAnalysisData data;
  final bool balancesHidden;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final List<Insight> insights = data.insights(
      balancesHidden: balancesHidden,
    );
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.lightbulb_outline_rounded, color: tokens.colors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic ? 'الرؤى' : 'Insights',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tokens.colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double tileWidth = constraints.maxWidth >= 700
                  ? (constraints.maxWidth - 24) / 3
                  : constraints.maxWidth;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: insights
                    .map<Widget>(
                      (Insight insight) => SizedBox(
                        width: tileWidth,
                        child: _InsightTile(insight: insight),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.colors.surface,
        borderRadius: BorderRadius.circular(_kAnalyticsCardRadius),
        border: Border.all(
          color: tokens.colors.divider.withValues(alpha: 0.65),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: _kAnalyticsIconBoxSize,
            height: _kAnalyticsIconBoxSize,
            decoration: BoxDecoration(
              color: insight.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(_kAnalyticsIconRadius),
            ),
            child: Icon(insight.icon, color: insight.color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  insight.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tokens.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  insight.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.colors.textSecondary,
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({
    required this.groups,
    required this.progress,
    required this.emptyColor,
  });

  final List<ExpenseGroup> groups;
  final double progress;
  final Color emptyColor;

  @override
  Widget build(BuildContext context) {
    final double total = groups.fold<double>(
      0,
      (double sum, ExpenseGroup group) => sum + group.amountEgp,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double chartSize = math.min(
          constraints.maxWidth * 0.9,
          constraints.maxHeight * 0.9,
        );
        return Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double animated, Widget? child) {
              return CustomPaint(
                size: Size.square(chartSize),
                painter: _DonutPainter(
                  groups: groups,
                  total: total,
                  progress: animated,
                  emptyColor: emptyColor,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({
    required this.values,
    required this.isArabic,
    required this.color,
  });

  final List<double> values;
  final bool isArabic;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double maxValue = values.isEmpty
        ? 0
        : values.reduce((double a, double b) => a > b ? a : b);
    final List<String> labels = _trendLabels(values.length, isArabic);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: 42,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _AxisLabel(text: _formatAxisValue(maxValue)),
                  _AxisLabel(text: _formatAxisValue(maxValue * 0.75)),
                  _AxisLabel(text: _formatAxisValue(maxValue * 0.5)),
                  _AxisLabel(text: _formatAxisValue(maxValue * 0.25)),
                  _AxisLabel(text: '0'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      builder:
                          (
                            BuildContext context,
                            double progress,
                            Widget? child,
                          ) {
                            return CustomPaint(
                              painter: _TrendPainter(
                                values: values,
                                progress: progress,
                                color: color,
                                maxValue: maxValue,
                              ),
                            );
                          },
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: labels
                        .map(
                          (String label) => Text(
                            label,
                            style: TextStyle(
                              color: context.premiumTokens.colors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.premiumTokens.colors.textSecondary.withValues(
          alpha: 0.72,
        ),
        fontSize: 10,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.values,
    required this.progress,
    required this.color,
    required this.maxValue,
  });

  final List<double> values;
  final double progress;
  final Color color;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final Paint grid = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    final double stepY = size.height / 4;
    for (int i = 0; i <= 4; i++) {
      final double y = i * stepY;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final List<Offset> points = <Offset>[];
    final double denom = values.length <= 1 ? 1 : values.length - 1;
    for (int i = 0; i < values.length; i++) {
      final double x = (i / denom) * size.width;
      final double normalized = maxValue <= 0
          ? 0
          : (values[i] / maxValue).clamp(0, 1);
      final double y = size.height - (normalized * size.height);
      points.add(Offset(x, y));
    }

    final int visiblePoints = (points.length * progress)
        .clamp(2, points.length)
        .toInt();
    final List<Offset> drawnPoints = points
        .take(visiblePoints)
        .toList(growable: false);
    if (drawnPoints.length < 2) return;

    final Path linePath = Path()
      ..moveTo(drawnPoints.first.dx, drawnPoints.first.dy);
    for (int i = 1; i < drawnPoints.length; i++) {
      final Offset previous = drawnPoints[i - 1];
      final Offset current = drawnPoints[i];
      final double controlX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    final Path fillPath = Path.from(linePath)
      ..lineTo(drawnPoints.last.dx, size.height)
      ..lineTo(drawnPoints.first.dx, size.height)
      ..close();

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          color.withValues(alpha: 0.28),
          color.withValues(alpha: 0.02),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);

    final Paint linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.maxValue != maxValue;
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.groups,
    required this.total,
    required this.progress,
    required this.emptyColor,
  });

  final List<ExpenseGroup> groups;
  final double total;
  final double progress;
  final Color emptyColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final double strokeWidth = math.min(size.width, size.height) * 0.145;
    final Rect rect = Offset.zero & size;
    final Paint base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = emptyColor;
    canvas.drawArc(rect.deflate(strokeWidth / 2), 0, math.pi * 2, false, base);

    if (total <= 0) return;
    double start = -math.pi / 2;
    for (final ExpenseGroup group in groups) {
      final double sweep = (group.amountEgp / total) * math.pi * 2 * progress;
      if (sweep <= 0) continue;
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = CategoryVisuals.colorFromValue(group.visual.colorValue);
      canvas.drawArc(rect.deflate(strokeWidth / 2), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.groups != groups ||
        oldDelegate.total != total ||
        oldDelegate.progress != progress ||
        oldDelegate.emptyColor != emptyColor;
  }
}

class ExpenseAnalysisData {
  const ExpenseAnalysisData({
    required this.totalCurrent,
    required this.totalPrevious,
    required this.changePct,
    required this.averageDaily,
    required this.highestDay,
    required this.highestDayValue,
    required this.transactionCount,
    required this.averagePerTransaction,
    required this.range,
    required this.trendValues,
    required this.groups,
    required this.merchantSpends,
    required this.categoryDeltas,
    required this.selectedPeriod,
    required this.investments,
    required this.savings,
    required this.market,
  });

  final double totalCurrent;
  final double totalPrevious;
  final double changePct;
  final double averageDaily;
  final DateTime highestDay;
  final double highestDayValue;
  final int transactionCount;
  final double averagePerTransaction;
  final DateTimeRange range;
  final List<double> trendValues;
  final List<ExpenseGroup> groups;
  final List<MerchantSpend> merchantSpends;
  final List<CategoryDelta> categoryDeltas;
  final String selectedPeriod;
  final List<InvestmentAsset> investments;
  final List<Saving> savings;
  final MarketData market;

  List<ExpenseGroup> get topGroups => groups.take(6).toList(growable: false);

  List<Insight> insights({required bool balancesHidden}) {
    final List<Insight> insights = <Insight>[];
    final tokens = PremiumThemePresets.light.colors;
    final List<CategoryDelta> sortedDeltas = categoryDeltas.toList()
      ..sort((a, b) => b.pct.abs().compareTo(a.pct.abs()));
    if (sortedDeltas.isNotEmpty) {
      final CategoryDelta first = sortedDeltas.first;
      final bool up = first.pct >= 0;
      insights.add(
        Insight(
          title:
              '${first.label} ${up ? 'increased' : 'decreased'} ${first.pct.abs().toStringAsFixed(0)}%',
          subtitle: 'vs previous period',
          icon: up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          color: up ? tokens.danger : tokens.success,
        ),
      );
    }
    if (sortedDeltas.length > 1) {
      final CategoryDelta second = sortedDeltas[1];
      final bool up = second.pct >= 0;
      insights.add(
        Insight(
          title:
              '${second.label} ${up ? 'increased' : 'decreased'} ${second.pct.abs().toStringAsFixed(0)}%',
          subtitle: 'vs previous period',
          icon: up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          color: up ? tokens.danger : tokens.success,
        ),
      );
    }
    if (merchantSpends.isNotEmpty) {
      final MerchantSpend largest = merchantSpends.first;
      insights.add(
        Insight(
          title: 'Largest merchant',
          subtitle: balancesHidden
              ? '••••••'
              : '${largest.label} • ${_money(largest.amountEgp)}',
          icon: Icons.storefront_outlined,
          color: tokens.gold,
        ),
      );
    }
    insights.add(
      Insight(
        title: 'Highest spending day',
        subtitle:
            '${_dateLabel(highestDay, false)} • ${balancesHidden ? '••••••' : _money(highestDayValue)}',
        icon: Icons.calendar_month_outlined,
        color: tokens.warning,
      ),
    );
    if (sortedDeltas.length > 2) {
      final CategoryDelta third = sortedDeltas[2];
      insights.add(
        Insight(
          title: 'Fastest growing category',
          subtitle: '${third.label} • ${third.pct.toStringAsFixed(0)}%',
          icon: Icons.auto_graph_rounded,
          color: tokens.emerald,
        ),
      );
    }
    return insights.take(6).toList(growable: false);
  }
}

class ExpenseGroup {
  const ExpenseGroup({
    required this.label,
    required this.amountEgp,
    required this.visual,
  });

  final String label;
  final double amountEgp;
  final CategoryVisual visual;
}

class HeroMetric {
  const HeroMetric({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color iconColor;
}

class Insight {
  const Insight({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class MerchantSpend {
  const MerchantSpend({required this.label, required this.amountEgp});

  final String label;
  final double amountEgp;
}

class CategoryDelta {
  const CategoryDelta({
    required this.label,
    required this.currentValue,
    required this.previousValue,
    required this.pct,
  });

  final String label;
  final double currentValue;
  final double previousValue;
  final double pct;
}

class _DatedExpense {
  const _DatedExpense({
    required this.tx,
    required this.date,
    required this.amountEgp,
  });

  final Transaction tx;
  final DateTime date;
  final double amountEgp;
}

String _periodLabel(String value) {
  switch (value) {
    case 'All':
      return 'all time';
    case '30D':
      return '30 days';
    case '90D':
      return '90 days';
    case '6M':
      return '6 months';
    case 'YTD':
      return 'year to date';
    case 'Custom':
      return 'selected period';
    default:
      return 'selected period';
  }
}

String _money(double value) {
  return ZakatEngineService.formatCurrency(value, 'EGP');
}

String _dateLabel(DateTime value, bool isArabic) {
  return DateFormat('d MMM yyyy', isArabic ? 'ar' : 'en_US').format(value);
}

String _formatAxisValue(double value) {
  if (value <= 0) return '0';
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(0)}K';
  }
  return value.toStringAsFixed(0);
}

List<String> _trendLabels(int length, bool isArabic) {
  if (length <= 1) return <String>[''];
  final int markers = 5;
  final List<String> labels = List<String>.filled(markers, '');
  final DateTime now = DateTime.now();
  for (int i = 0; i < markers; i++) {
    final int index = ((length - 1) * (i / (markers - 1))).round();
    labels[i] = DateFormat(
      'd MMM',
      isArabic ? 'ar' : 'en_US',
    ).format(now.subtract(Duration(days: math.max(0, length - 1 - index))));
  }
  return labels;
}

String _arabicDigits(String value) {
  const Map<String, String> map = <String, String>{
    '0': '٠',
    '1': '١',
    '2': '٢',
    '3': '٣',
    '4': '٤',
    '5': '٥',
    '6': '٦',
    '7': '٧',
    '8': '٨',
    '9': '٩',
  };
  return value.split('').map((String c) => map[c] ?? c).join();
}
