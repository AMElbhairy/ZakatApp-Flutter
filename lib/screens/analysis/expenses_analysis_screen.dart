import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../widgets/sensitive_content_scope.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/privacy/app_privacy.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/utils/category_visuals.dart';
import '../../models/app_state.dart';
import '../../models/investment_asset.dart';
import '../../models/saving.dart';
import '../../models/transaction.dart';
import '../../services/financial_metrics_service.dart';
import '../../services/app_state_controller.dart';

class ExpenseAnalysisScreen extends StatefulWidget {
  const ExpenseAnalysisScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      settings: const AppPrivacyRouteSettings(
        privacy: ScreenPrivacyClassification.sensitive,
      ),
      builder: (_) => const ExpenseAnalysisScreen(),
    );
  }

  @override
  State<ExpenseAnalysisScreen> createState() => _ExpenseAnalysisScreenState();
}

class _ExpenseAnalysisScreenState extends State<ExpenseAnalysisScreen> {
  String _selectedPeriod = '30D';
  String _summaryGrouping = 'category';
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
    final String locale = Localizations.localeOf(context).toString();
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final bool balancesHidden = _isBalanceHidden(state);
    final String mainCurrency = state.mainCurrency.trim().isEmpty
        ? 'EGP'
        : state.mainCurrency.trim();
    final MarketData market = MarketData.fromJson(state.marketData);
    final ExpenseAnalysisData data = _buildAnalysisData(
      transactions: state.transactions,
      savings: state.savings,
      investments: state.investments,
      categories: state.categories,
      market: market,
      mainCurrency: mainCurrency,
      selectedPeriod: _selectedPeriod,
      customRange: _customRange,
      locale: locale,
    );
    final String breakdownMode =
        data.availableSummaryGroupings.contains(_summaryGrouping)
        ? _summaryGrouping
        : 'category';
    final TrendSeries trendSeries = _buildTrendSeries(data.expenseMetrics);

    final double bottomInset = 112 + MediaQuery.paddingOf(context).bottom;
    final tokens = context.premiumTokens;

    return SensitiveContentScope(
      child: Scaffold(
        backgroundColor: tokens.colors.background,
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(24, 20, 24, bottomInset),
            children: <Widget>[
              _AnalysisHeader(
                isArabic: isArabic,
                balancesHidden: balancesHidden,
                selectedRangeLabel: _summaryPeriodLabel(data.range, isArabic),
                summarySentence: _summarySentence(data, isArabic),
                onBack: () => Navigator.of(context).maybePop(),
                onTogglePrivacy: controller.togglePrivacyMode,
              ),
              const SizedBox(height: 18),
              _PeriodFilterRow(
                selectedPeriod: _selectedPeriod,
                isArabic: isArabic,
                customRangeSelected: _selectedPeriod == 'Custom',
                onCalendarTap: () => _selectCustomRange(context),
                onSelected: (String value) {
                  setState(() => _selectedPeriod = value);
                },
              ),
              const SizedBox(height: 20),
              _SummaryCard(
                data: data,
                trendSeries: trendSeries,
                balancesHidden: balancesHidden,
                isArabic: isArabic,
              ),
              if (data.hasIncomeData) ...<Widget>[
                const SizedBox(height: 16),
                _PeriodSnapshotStrip(
                  data: data,
                  balancesHidden: balancesHidden,
                  isArabic: isArabic,
                ),
              ],
              const SizedBox(height: 24),
              _SectionHeader(
                title: _breakdownTitle(data, breakdownMode, isArabic),
                trailing: _SummaryGroupingDropdown(
                  value: breakdownMode,
                  availableSummaryGroupings: data.availableSummaryGroupings,
                  isArabic: isArabic,
                  onChanged: (String value) {
                    setState(() => _summaryGrouping = value);
                  },
                ),
              ),
              const SizedBox(height: 12),
              _CategoryBreakdownCard(
                data: data,
                balancesHidden: balancesHidden,
                mode: breakdownMode,
                isArabic: isArabic,
              ),
              const SizedBox(height: 24),
              _SectionHeader(
                title: isArabic ? 'اتجاه الإنفاق' : 'Spending Trend',
              ),
              const SizedBox(height: 12),
              _TrendSection(
                data: data,
                series: trendSeries,
                balancesHidden: balancesHidden,
                isArabic: isArabic,
                locale: locale,
                currencyCode: data.currencyCode,
              ),
              const SizedBox(height: 24),
              _SectionHeader(title: isArabic ? 'الرؤى' : 'Insights'),
              const SizedBox(height: 12),
              _InsightsFeed(
                data: data,
                balancesHidden: balancesHidden,
                isArabic: isArabic,
                locale: locale,
              ),
              const SizedBox(height: 24),
              _SectionHeader(
                title: isArabic ? 'المعاملات الأخيرة' : 'Recent Transactions',
              ),
              const SizedBox(height: 12),
              _RecentTransactionsCard(
                data: data,
                balancesHidden: balancesHidden,
                isArabic: isArabic,
                locale: locale,
                currencyCode: data.currencyCode,
              ),
            ],
          ),
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
    required String mainCurrency,
    required String selectedPeriod,
    required DateTimeRange? customRange,
    required String locale,
  }) {
    final DateTime now = DateTime.now();
    final List<Transaction> expenseTxs = transactions
        .where(
          (Transaction tx) => tx.type == 'expense' && !tx.isTransferActivity,
        )
        .toList(growable: false);
    final List<Transaction> incomeTxs = transactions
        .where(
          (Transaction tx) => tx.type == 'income' && !tx.isTransferActivity,
        )
        .toList(growable: false);
    final List<FinancialMetricsRecord<Transaction>> allRecords =
        <FinancialMetricsRecord<Transaction>>[
          ...expenseTxs.map(
            (Transaction tx) => FinancialMetricsRecord<Transaction>(
              source: tx,
              type: FinancialRecordType.expense,
              date: _dayOnly(_parseDate(tx.date) ?? now),
              createdAt: _parseDate(tx.createdAt) ?? now,
              amountEgp: _convertToDisplayCurrency(
                tx.amount,
                tx.currency,
                market,
                mainCurrency,
              ),
              category: _categoryLabel(tx, locale),
              label: _merchantLabel(tx, locale),
              description: tx.description.trim(),
              currencyCode: tx.currency,
            ),
          ),
          ...incomeTxs.map(
            (Transaction tx) => FinancialMetricsRecord<Transaction>(
              source: tx,
              type: FinancialRecordType.income,
              date: _dayOnly(_parseDate(tx.date) ?? now),
              createdAt: _parseDate(tx.createdAt) ?? now,
              amountEgp: _convertToDisplayCurrency(
                tx.amount,
                tx.currency,
                market,
                mainCurrency,
              ),
              category: _categoryLabel(tx, locale),
              label: _merchantLabel(tx, locale),
              description: tx.description.trim(),
              currencyCode: tx.currency,
            ),
          ),
        ];

    final FinancialMetricsResult<Transaction> combinedMetrics =
        FinancialMetricsService.calculate<Transaction>(
          records: allRecords,
          selectedPeriod: selectedPeriod,
          customRange: customRange,
          now: now,
          locale: locale,
        );
    final FinancialMetricsResult<Transaction> expenseMetrics =
        FinancialMetricsService.calculate<Transaction>(
          records: allRecords
              .where(
                (FinancialMetricsRecord<Transaction> record) =>
                    record.type == FinancialRecordType.expense,
              )
              .toList(growable: false),
          selectedPeriod: selectedPeriod,
          customRange: customRange,
          now: now,
          locale: locale,
        );

    final DateTimeRange range = expenseMetrics.range;
    final List<DatedExpense> currentExpenses = expenseMetrics.currentRecords
        .map(
          (FinancialMetricsRecord<Transaction> record) => DatedExpense(
            tx: record.source,
            date: record.date,
            amountEgp: record.amountEgp,
          ),
        )
        .toList(growable: false);
    final List<DatedExpense> previousExpenses = expenseMetrics.previousRecords
        .map(
          (FinancialMetricsRecord<Transaction> record) => DatedExpense(
            tx: record.source,
            date: record.date,
            amountEgp: record.amountEgp,
          ),
        )
        .toList(growable: false);
    final double totalCurrent = expenseMetrics.totalCurrent;
    final double totalPrevious = expenseMetrics.totalPrevious;
    final double incomeCurrent = combinedMetrics.incomeCurrent;
    final double incomePrevious = combinedMetrics.incomePrevious;
    final double changePct = expenseMetrics.changePct;
    final Map<DateTime, double> dailyTotals = expenseMetrics.dailyTotals;
    final double averageDaily = expenseMetrics.averageDailySpending;
    final DateTime highestDay =
        expenseMetrics.highestSpendingDay ?? range.start;
    final double highestDayValue = expenseMetrics.highestSpendingDayValue;

    final Map<String, ExpenseGroup> categoryTotals = <String, ExpenseGroup>{};
    final Map<String, ExpenseGroup> merchantTotals = <String, ExpenseGroup>{};
    final Map<String, ExpenseGroup> sourceTotals = <String, ExpenseGroup>{};
    double sourceCoveredAmount = 0;
    for (final DatedExpense expense in currentExpenses) {
      final String category = _categoryLabel(expense.tx, locale);
      final String merchant = _merchantLabel(expense.tx, locale);
      final String? source = _sourceLabel(expense.tx);
      final CategoryVisual categoryVisual =
          CategoryVisuals.resolveCategoryVisual(
            categories: categories,
            type: 'expense',
            categoryName: category,
          );
      final CategoryVisual merchantVisual =
          CategoryVisuals.resolveCategoryVisual(
            categories: categories,
            type: 'expense',
            categoryName: merchant,
          );

      categoryTotals[category] = ExpenseGroup(
        label: category,
        amountEgp:
            (categoryTotals[category]?.amountEgp ?? 0) + expense.amountEgp,
        visual: categoryVisual,
      );
      merchantTotals[merchant] = ExpenseGroup(
        label: merchant,
        amountEgp:
            (merchantTotals[merchant]?.amountEgp ?? 0) + expense.amountEgp,
        visual: merchantVisual,
      );
      if (source != null) {
        final CategoryVisual sourceVisual =
            CategoryVisuals.resolveCategoryVisual(
              categories: categories,
              type: 'expense',
              categoryName: source,
            );
        sourceTotals[source] = ExpenseGroup(
          label: source,
          amountEgp: (sourceTotals[source]?.amountEgp ?? 0) + expense.amountEgp,
          visual: sourceVisual,
        );
        sourceCoveredAmount += expense.amountEgp;
      }
    }

    final List<ExpenseGroup> categoriesBySpend = categoryTotals.values.toList()
      ..sort(
        (ExpenseGroup a, ExpenseGroup b) => b.amountEgp.compareTo(a.amountEgp),
      );
    final List<ExpenseGroup> merchantsBySpend = merchantTotals.values.toList()
      ..sort(
        (ExpenseGroup a, ExpenseGroup b) => b.amountEgp.compareTo(a.amountEgp),
      );
    final List<ExpenseGroup> sourcesBySpend = sourceTotals.values.toList()
      ..sort(
        (ExpenseGroup a, ExpenseGroup b) => b.amountEgp.compareTo(a.amountEgp),
      );

    final List<ExpenseTransactionItem> largestTransactions =
        currentExpenses
            .map(
              (DatedExpense currentExpense) => ExpenseTransactionItem(
                label: _merchantLabel(currentExpense.tx, locale),
                category: _categoryLabel(currentExpense.tx, locale),
                amountEgp: currentExpense.amountEgp,
                date: currentExpense.date,
                visual: CategoryVisuals.resolveCategoryVisual(
                  categories: categories,
                  type: 'expense',
                  categoryName: _categoryLabel(currentExpense.tx, locale),
                ),
              ),
            )
            .toList(growable: false)
          ..sort(
            (ExpenseTransactionItem a, ExpenseTransactionItem b) =>
                b.amountEgp.compareTo(a.amountEgp),
          );

    final List<ExpenseTransactionItem> recentTransactions =
        currentExpenses
            .map(
              (DatedExpense currentExpense) => ExpenseTransactionItem(
                label: _merchantLabel(currentExpense.tx, locale),
                category: _categoryLabel(currentExpense.tx, locale),
                amountEgp: currentExpense.amountEgp,
                date: currentExpense.date,
                visual: CategoryVisuals.resolveCategoryVisual(
                  categories: categories,
                  type: 'expense',
                  categoryName: _categoryLabel(currentExpense.tx, locale),
                ),
              ),
            )
            .toList(growable: false)
          ..sort(
            (ExpenseTransactionItem a, ExpenseTransactionItem b) =>
                b.date.compareTo(a.date),
          );

    final double projectedMonthlySpend = currentExpenses.length >= 3
        ? averageDaily * DateUtils.getDaysInMonth(now.year, now.month)
        : 0;
    final double spendingHealthScore = _spendingHealthScore(
      totalCurrent: totalCurrent,
      incomeCurrent: incomeCurrent,
      changePct: changePct,
      averageDaily: averageDaily,
      dailyTotals: dailyTotals,
    );

    final List<CategoryDelta> deltas = _categoryDeltas(
      currentExpenses: currentExpenses,
      previousExpenses: previousExpenses,
      locale: locale,
    );

    return ExpenseAnalysisData(
      expenseMetrics: expenseMetrics,
      combinedMetrics: combinedMetrics,
      totalCurrent: totalCurrent,
      totalPrevious: totalPrevious,
      changePct: changePct,
      averageDaily: averageDaily,
      highestDay: highestDay,
      highestDayValue: highestDayValue,
      transactionCount: currentExpenses.length,
      averagePerTransaction: currentExpenses.isEmpty
          ? 0
          : totalCurrent / currentExpenses.length,
      range: range,
      selectedPeriod: selectedPeriod,
      dailyTotals: dailyTotals,
      currentExpenses: currentExpenses,
      categoryGroups: categoriesBySpend,
      merchantGroups: merchantsBySpend,
      sourceGroups: sourcesBySpend,
      sourceCoverage: totalCurrent <= 0
          ? 0
          : sourceCoveredAmount / totalCurrent,
      incomeCurrent: incomeCurrent,
      incomePrevious: incomePrevious,
      largestTransactions: largestTransactions.take(5).toList(growable: false),
      recentTransactions: recentTransactions.take(5).toList(growable: false),
      categoryDeltas: deltas,
      savings: savings,
      investments: investments,
      market: market,
      currencyCode: mainCurrency,
      projectedMonthlySpend: projectedMonthlySpend > 0
          ? projectedMonthlySpend
          : null,
      spendingHealthScore: spendingHealthScore,
    );
  }

  static List<CategoryDelta> _categoryDeltas({
    required List<DatedExpense> currentExpenses,
    required List<DatedExpense> previousExpenses,
    required String locale,
  }) {
    final Map<String, double> current = <String, double>{};
    final Map<String, double> previous = <String, double>{};

    for (final DatedExpense expense in currentExpenses) {
      final String key = _categoryLabel(expense.tx, locale);
      current[key] = (current[key] ?? 0) + expense.amountEgp;
    }
    for (final DatedExpense expense in previousExpenses) {
      final String key = _categoryLabel(expense.tx, locale);
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
    deltas.sort((CategoryDelta a, CategoryDelta b) {
      return b.currentValue.compareTo(a.currentValue);
    });
    return deltas;
  }

  static DateTime? _parseDate(String value) {
    if (value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static DateTime _dayOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String _categoryLabel(Transaction tx, String locale) {
    final String category = tx.category.trim();
    if (category.isNotEmpty) {
      return AppLocalizations.translateCategoryForLanguage(locale, category);
    }
    final String description = tx.description.trim();
    if (description.isNotEmpty) return description;
    return AppLocalizations.translateCategoryForLanguage(locale, 'Other');
  }

  static String _merchantLabel(Transaction tx, String locale) {
    final String description = tx.description.trim();
    if (description.isNotEmpty) {
      final List<String> parts = description.split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        final Set<String> generic = <String>{
          'purchase',
          'payment',
          'card',
          'debit',
          'credit',
          'transfer',
          'cash',
          'txn',
          'transaction',
          'pos',
          'atm',
          'withdrawal',
          'at',
          'from',
          'to',
          'via',
          'on',
          'in',
          'of',
          'for',
          'by',
          'the',
          'and',
        };
        int firstMerchantIndex = 0;
        while (firstMerchantIndex < parts.length) {
          final String cleaned = parts[firstMerchantIndex]
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9&+-]'), '');
          if (cleaned.isNotEmpty && !generic.contains(cleaned)) break;
          firstMerchantIndex++;
        }
        if (firstMerchantIndex < parts.length) {
          final List<String> merchantParts = parts
              .skip(firstMerchantIndex)
              .map((String value) {
                return value.replaceAll(
                  RegExp(r'^[^A-Za-z0-9&+-]+|[^A-Za-z0-9&+-]+$'),
                  '',
                );
              })
              .where((String value) => value.isNotEmpty)
              .toList(growable: false);
          if (merchantParts.isNotEmpty) {
            return merchantParts.map(_titleCase).join(' ');
          }
        }
        return parts.map(_titleCase).join(' ');
      }
    }
    return _categoryLabel(tx, locale);
  }

  static String? _sourceLabel(Transaction tx) {
    final String description = tx.description.trim();
    if (description.isEmpty) return null;
    final List<String> words = description
        .split(RegExp(r'\s+'))
        .where((String value) => value.trim().isNotEmpty)
        .take(4)
        .toList(growable: false);
    if (words.isEmpty) return null;
    final Set<String> generic = <String>{
      'purchase',
      'payment',
      'card',
      'debit',
      'credit',
      'transfer',
      'cash',
      'txn',
      'transaction',
      'pos',
      'atm',
      'withdrawal',
      'at',
      'from',
      'to',
      'via',
      'on',
      'in',
      'of',
      'for',
      'by',
      'the',
      'and',
    };
    int firstMerchantIndex = 0;
    while (firstMerchantIndex < words.length) {
      final String cleaned = words[firstMerchantIndex].toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9&+-]'),
        '',
      );
      if (cleaned.isNotEmpty && !generic.contains(cleaned)) break;
      firstMerchantIndex++;
    }
    if (firstMerchantIndex < words.length) {
      final List<String> merchantParts = words
          .skip(firstMerchantIndex)
          .map((String value) {
            return value.replaceAll(
              RegExp(r'^[^A-Za-z0-9&+-]+|[^A-Za-z0-9&+-]+$'),
              '',
            );
          })
          .where((String value) => value.isNotEmpty)
          .toList(growable: false);
      if (merchantParts.isNotEmpty) {
        return merchantParts.map(_titleCase).join(' ');
      }
    }
    final String cleaned = words.join(' ');
    if (cleaned.length < 2) return null;
    return _titleCase(cleaned);
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
    required this.selectedRangeLabel,
    required this.summarySentence,
    required this.onBack,
    required this.onTogglePrivacy,
  });

  final bool isArabic;
  final bool balancesHidden;
  final String selectedRangeLabel;
  final String summarySentence;
  final VoidCallback onBack;
  final VoidCallback onTogglePrivacy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final TextStyle? titleStyle = Theme.of(context).textTheme.titleLarge
        ?.copyWith(
          color: tokens.colors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          height: 1.0,
          letterSpacing: -0.2,
        );
    final TextStyle? subtitleStyle = Theme.of(context).textTheme.bodySmall
        ?.copyWith(
          color: tokens.colors.textSecondary.withValues(alpha: 0.84),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.1,
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _RoundIconButton(icon: Icons.arrow_back_rounded, onPressed: onBack),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    isArabic ? 'تحليل المصروفات' : 'Expenses Analysis',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: titleStyle,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    isArabic
                        ? 'افهم أنماط الإنفاق لديك'
                        : 'Understand your spending patterns',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: subtitleStyle,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                selectedRangeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: subtitleStyle?.copyWith(
                  color: tokens.colors.textSecondary.withValues(alpha: 0.96),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                summarySentence,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.colors.textPrimary,
                  fontSize: 12.5,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _RoundIconButton(
          icon: balancesHidden
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          onPressed: onTogglePrivacy,
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final Color background = active
        ? tokens.colors.emerald.withValues(alpha: 0.10)
        : tokens.colors.surface;
    return Material(
      color: background,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: active
                  ? tokens.colors.emerald.withValues(alpha: 0.28)
                  : tokens.colors.divider.withValues(alpha: 0.78),
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: active ? tokens.colors.emerald : tokens.colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _PeriodFilterRow extends StatelessWidget {
  const _PeriodFilterRow({
    required this.selectedPeriod,
    required this.isArabic,
    required this.customRangeSelected,
    required this.onCalendarTap,
    required this.onSelected,
  });

  final String selectedPeriod;
  final bool isArabic;
  final bool customRangeSelected;
  final VoidCallback onCalendarTap;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final List<String> periods = <String>['All', '30D', '90D', '6M', 'YTD'];

    return Row(
      children: <Widget>[
        _RoundIconButton(
          icon: Icons.calendar_month_outlined,
          onPressed: onCalendarTap,
          active: customRangeSelected,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: periods
                  .map(
                    (String period) => Padding(
                      padding: const EdgeInsetsDirectional.only(end: 10),
                      child: _PeriodPill(
                        label: _periodLabel(period, isArabic),
                        selected: selectedPeriod == period,
                        onTap: () => onSelected(period),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final Color borderColor = selected
        ? tokens.colors.gold.withValues(alpha: 0.32)
        : tokens.colors.divider.withValues(alpha: 0.7);
    final Color background = selected
        ? tokens.colors.emerald.withValues(alpha: 0.10)
        : tokens.colors.surface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: ShapeDecoration(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: borderColor),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? tokens.colors.emerald
                    : tokens.colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.data,
    required this.trendSeries,
    required this.balancesHidden,
    required this.isArabic,
  });

  final ExpenseAnalysisData data;
  final TrendSeries trendSeries;
  final bool balancesHidden;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color background = dark
        ? Color.lerp(tokens.colors.card, Colors.white, 0.04)!
        : tokens.colors.surface;
    final Color border = tokens.colors.divider.withValues(alpha: 0.72);
    final Color shadowColor = Colors.black.withValues(
      alpha: dark ? 0.18 : 0.06,
    );
    final String healthLabel = data.spendingHealthLabel(isArabic: isArabic);
    final Color healthColor = data.spendingHealthColor(context);
    final List<_SummaryMetric> metrics = <_SummaryMetric>[
      _SummaryMetric(
        icon: Icons.show_chart_rounded,
        label: isArabic ? 'المتوسط اليومي' : 'Average Daily Spending',
        value: balancesHidden
            ? '••••••'
            : _compactMoney(data.averageDaily, data.currencyCode),
      ),
      _SummaryMetric(
        icon: Icons.emoji_events_outlined,
        label: isArabic ? 'أعلى يوم' : 'Highest spending day',
        value: balancesHidden
            ? '••••••'
            : _compactMoney(data.highestDayValue, data.currencyCode),
      ),
      _SummaryMetric(
        icon: Icons.receipt_long_outlined,
        label: isArabic ? 'المعاملات' : 'Transactions',
        value: data.transactionCount.toString(),
      ),
      _SummaryMetric(
        icon: Icons.account_balance_wallet_outlined,
        label: isArabic ? 'المتوسط / معاملة' : 'Avg / Tx',
        value: balancesHidden
            ? '••••••'
            : _compactMoney(data.averagePerTransaction, data.currencyCode),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: shadowColor,
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isArabic ? 'إجمالي المصروفات' : 'Total Expenses',
                      style: TextStyle(
                        color: tokens.colors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _summaryPeriodLabel(data.range, isArabic),
                      style: TextStyle(
                        color: tokens.colors.textSecondary.withValues(
                          alpha: 0.78,
                        ),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _HealthBadge(
                label: healthLabel,
                color: healthColor,
                isArabic: isArabic,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double fontSize = math.max(
                      28,
                      math.min(34, constraints.maxWidth / 7.6),
                    );
                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        balancesHidden
                            ? '••••••'
                            : _money(data.totalCurrent, data.currencyCode),
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: tokens.colors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: fontSize,
                              letterSpacing: -0.8,
                            ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        data.changePct >= 0
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 16,
                        color: data.changePct >= 0
                            ? tokens.colors.danger
                            : tokens.colors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        balancesHidden
                            ? '••••••'
                            : '${data.changePct.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: data.changePct >= 0
                              ? tokens.colors.danger
                              : tokens.colors.success,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isArabic ? 'مقارنة بالفترة السابقة' : 'vs previous period',
                    style: TextStyle(
                      color: tokens.colors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 18),
          Divider(
            height: 1,
            thickness: 1,
            color: tokens.colors.divider.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 18),
          Row(
            children: metrics
                .map(
                  (_SummaryMetric metric) =>
                      Expanded(child: _SummaryMetricCell(metric: metric)),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _SummaryGroupingDropdown extends StatelessWidget {
  const _SummaryGroupingDropdown({
    required this.value,
    required this.availableSummaryGroupings,
    required this.isArabic,
    required this.onChanged,
  });

  final String value;
  final List<String> availableSummaryGroupings;
  final bool isArabic;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final String label = value == 'source'
        ? (isArabic ? 'بالمصدر' : 'By Source')
        : (isArabic ? 'بالفئة' : 'By Category');

    return PopupMenuButton<String>(
      tooltip: '',
      onSelected: onChanged,
      color: tokens.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      itemBuilder: (BuildContext context) {
        final List<PopupMenuEntry<String>> items = <PopupMenuEntry<String>>[];
        if (availableSummaryGroupings.contains('category')) {
          items.add(
            PopupMenuItem<String>(
              value: 'category',
              child: Text(isArabic ? 'فئة' : 'By Category'),
            ),
          );
        }
        if (availableSummaryGroupings.contains('source')) {
          items.add(
            PopupMenuItem<String>(
              value: 'source',
              child: Text(isArabic ? 'مصدر' : 'By Source'),
            ),
          );
        }
        return items;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: tokens.colors.background.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: tokens.colors.divider.withValues(alpha: 0.75),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                color: tokens.colors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: tokens.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetricCell extends StatelessWidget {
  const _SummaryMetricCell({required this.metric});

  final _SummaryMetric metric;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        height: 102,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 28,
              height: 28,
              child: Center(
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: tokens.colors.emerald.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    metric.icon,
                    size: 14,
                    color: tokens.colors.emerald,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 24,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    metric.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.colors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 32,
              child: Center(
                child: Text(
                  metric.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.colors.textSecondary,
                    fontSize: 11.2,
                    height: 1.08,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSnapshotStrip extends StatelessWidget {
  const _PeriodSnapshotStrip({
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
    final bool hasIncome = data.incomeCurrent > 0 || data.incomePrevious > 0;
    if (!hasIncome) return const SizedBox.shrink();

    final List<_PeriodSnapshotChipData> chips = <_PeriodSnapshotChipData>[
      _PeriodSnapshotChipData(
        label: isArabic ? 'المصروفات' : 'Expenses',
        value: balancesHidden
            ? '••••••'
            : '${data.changePct >= 0 ? '↑' : '↓'} ${data.changePct.abs().toStringAsFixed(0)}%',
        color: data.changePct >= 0
            ? tokens.colors.danger
            : tokens.colors.success,
      ),
      _PeriodSnapshotChipData(
        label: isArabic ? 'الدخل' : 'Income',
        value: balancesHidden
            ? '••••••'
            : data.incomePrevious > 0
            ? '${data.incomeChangePct >= 0 ? '↑' : '↓'} ${data.incomeChangePct.abs().toStringAsFixed(0)}%'
            : (isArabic ? 'جديد' : 'New'),
        color: data.incomePrevious > 0
            ? (data.incomeChangePct >= 0
                  ? tokens.colors.success
                  : tokens.colors.danger)
            : tokens.colors.emerald,
      ),
      _PeriodSnapshotChipData(
        label: isArabic ? 'معدل الادخار' : 'Savings Rate',
        value: balancesHidden || data.incomeCurrent <= 0
            ? '••••••'
            : '${math.max(0, ((data.incomeCurrent - data.totalCurrent) / data.incomeCurrent) * 100).toStringAsFixed(0)}%',
        color: tokens.colors.gold,
      ),
      _PeriodSnapshotChipData(
        label: isArabic ? 'صافي التدفق' : 'Net Cash Flow',
        value: balancesHidden || data.incomeCurrent <= 0
            ? '••••••'
            : _compactMoney(
                data.incomeCurrent - data.totalCurrent,
                data.currencyCode,
              ),
        color: data.incomeCurrent - data.totalCurrent >= 0
            ? tokens.colors.emerald
            : tokens.colors.danger,
      ),
    ];

    return Container(
      decoration: _sectionCardDecoration(context),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            isArabic ? 'هذه الفترة' : 'This period',
            style: TextStyle(
              color: tokens.colors.textSecondary.withValues(alpha: 0.82),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double chipWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: chips
                    .map(
                      (_PeriodSnapshotChipData chip) => SizedBox(
                        width: chipWidth,
                        child: _PeriodSnapshotChip(chip: chip),
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

class _PeriodSnapshotChipData {
  const _PeriodSnapshotChipData({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;
}

class _PeriodSnapshotChip extends StatelessWidget {
  const _PeriodSnapshotChip({required this.chip});

  final _PeriodSnapshotChipData chip;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: chip.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: chip.color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            chip.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.colors.textSecondary,
              fontSize: 10.2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            chip.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: chip.color,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: tokens.colors.textPrimary),
          ),
        ),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}

class _HealthBadge extends StatelessWidget {
  const _HealthBadge({
    required this.label,
    required this.color,
    required this.isArabic,
  });

  final String label;
  final Color color;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            isArabic ? 'الصحة:' : 'Health:',
            style: TextStyle(
              color: tokens.colors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              letterSpacing: 0.1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendStatLine extends StatelessWidget {
  const _TrendStatLine({
    required this.label,
    required this.value,
    required this.color,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: TextStyle(
            color: tokens.colors.textSecondary.withValues(alpha: 0.9),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TrendMiniChip extends StatelessWidget {
  const _TrendMiniChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: tokens.colors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: tokens.colors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({
    required this.data,
    required this.balancesHidden,
    required this.mode,
    required this.isArabic,
  });

  final ExpenseAnalysisData data;
  final bool balancesHidden;
  final String mode;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final List<ExpenseGroup> slices = mode == 'source'
        ? data.sourceSlices
        : data.chartSlices;
    final double total = slices.fold<double>(
      0,
      (double sum, ExpenseGroup group) => sum + group.amountEgp,
    );
    final bool empty = total <= 0;

    return Container(
      decoration: _sectionCardDecoration(context),
      padding: const EdgeInsets.all(20),
      child: empty
          ? Text(
              mode == 'source'
                  ? (isArabic
                        ? 'لا توجد بيانات مصادر موثوقة.'
                        : 'No reliable expense source data yet.')
                  : (isArabic
                        ? 'أضف مصروفات لعرض التحليل.'
                        : 'Add expenses to see spending insights.'),
              style: TextStyle(
                color: tokens.colors.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            )
          : LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool narrow = constraints.maxWidth < 540;
                final Widget chart = SizedBox(
                  width: 170,
                  height: 170,
                  child: _DonutChart(
                    slices: slices,
                    total: total,
                    emptyColor: tokens.colors.divider.withValues(alpha: 0.45),
                    centerAmount: balancesHidden
                        ? '••••••'
                        : _shortMoney(total, data.currencyCode),
                  ),
                );
                final Widget legend = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: slices
                      .map(
                        (ExpenseGroup slice) => _LegendRow(
                          label: slice.label,
                          amount: balancesHidden
                              ? '••••••'
                              : _compactMoney(
                                  slice.amountEgp,
                                  data.currencyCode,
                                ),
                          percent: total <= 0
                              ? 0
                              : (slice.amountEgp / total) * 100,
                          color: CategoryVisuals.colorFromValue(
                            slice.visual.colorValue,
                          ),
                        ),
                      )
                      .toList(growable: false),
                );

                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Center(child: chart),
                      const SizedBox(height: 16),
                      legend,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    chart,
                    const SizedBox(width: 18),
                    Expanded(child: legend),
                  ],
                );
              },
            ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.label,
    required this.amount,
    required this.percent,
    required this.color,
  });

  final String label;
  final String amount;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: color.withValues(alpha: 0.24),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.colors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  amount,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.colors.textSecondary,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${percent.toStringAsFixed(0)}%',
            style: TextStyle(
              color: tokens.colors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendSection extends StatelessWidget {
  const _TrendSection({
    required this.data,
    required this.series,
    required this.balancesHidden,
    required this.isArabic,
    required this.locale,
    required this.currencyCode,
  });

  final ExpenseAnalysisData data;
  final TrendSeries series;
  final bool balancesHidden;
  final bool isArabic;
  final String locale;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Container(
      decoration: _sectionCardDecoration(context),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      balancesHidden
                          ? '••••••'
                          : _money(data.averageDaily, data.currencyCode),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: tokens.colors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                            letterSpacing: -0.4,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isArabic
                          ? 'المتوسط اليومي للإنفاق'
                          : 'Average Daily Spending',
                      style: TextStyle(
                        color: tokens.colors.textSecondary.withValues(
                          alpha: 0.82,
                        ),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _TrendStatLine(
                    label: isArabic ? 'أعلى يوم' : 'Highest spending day',
                    value: balancesHidden
                        ? '••••••'
                        : '${_dateLabel(data.highestDay, locale)} • ${_compactMoney(data.highestDayValue, data.currencyCode)}',
                    color: tokens.colors.emerald,
                    alignEnd: true,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 236,
            child: _InteractiveTrendChart(
              series: series,
              color: tokens.colors.emerald,
              balancesHidden: balancesHidden,
              currencyCode: currencyCode,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: _TrendMiniChip(
                  label: isArabic ? 'المتوسط' : 'Average',
                  value: balancesHidden
                      ? '••••••'
                      : _compactMoney(data.averageDaily, data.currencyCode),
                  color: tokens.colors.emerald,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TrendMiniChip(
                  label: isArabic ? 'أعلى يوم' : 'Highest',
                  value: balancesHidden
                      ? '••••••'
                      : _compactMoney(data.highestDayValue, data.currencyCode),
                  color: tokens.colors.gold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TrendMiniChip(
                  label: isArabic ? 'متوقع الشهر' : 'Projected',
                  value: balancesHidden
                      ? '••••••'
                      : data.projectedMonthlySpend == null
                      ? '—'
                      : _compactMoney(
                          data.projectedMonthlySpend!,
                          data.currencyCode,
                        ),
                  color: tokens.colors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightsFeed extends StatelessWidget {
  const _InsightsFeed({
    required this.data,
    required this.balancesHidden,
    required this.isArabic,
    required this.locale,
  });

  final ExpenseAnalysisData data;
  final bool balancesHidden;
  final bool isArabic;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final List<InsightItem> insights = data.smartInsights(
      balancesHidden: balancesHidden,
      locale: locale,
    );

    return Column(
      children: insights
          .map(
            (InsightItem insight) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _InsightRow(insight: insight),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.insight});

  final InsightItem insight;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Color.lerp(tokens.colors.surface, Colors.white, 0.02)!,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: tokens.colors.divider.withValues(alpha: 0.65),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: insight.color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(insight.icon, size: 18, color: insight.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  insight.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.colors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  insight.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.colors.textSecondary,
                    fontSize: 12.5,
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

class _RecentTransactionsCard extends StatelessWidget {
  const _RecentTransactionsCard({
    required this.data,
    required this.balancesHidden,
    required this.isArabic,
    required this.locale,
    required this.currencyCode,
  });

  final ExpenseAnalysisData data;
  final bool balancesHidden;
  final bool isArabic;
  final String locale;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Container(
      decoration: _sectionCardDecoration(context),
      padding: const EdgeInsets.all(22),
      child: data.recentTransactions.isEmpty
          ? Text(
              isArabic
                  ? 'لا توجد معاملات حديثة.'
                  : 'No recent transactions yet.',
              style: TextStyle(
                color: tokens.colors.textSecondary,
                fontSize: 13.5,
              ),
            )
          : Column(
              children: data.recentTransactions
                  .asMap()
                  .entries
                  .map(
                    (MapEntry<int, ExpenseTransactionItem> entry) => Column(
                      children: <Widget>[
                        _TransactionRow(
                          item: entry.value,
                          balancesHidden: balancesHidden,
                          isArabic: isArabic,
                          locale: locale,
                          currencyCode: currencyCode,
                        ),
                        if (entry.key != data.recentTransactions.length - 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: tokens.colors.divider.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.item,
    required this.balancesHidden,
    required this.isArabic,
    required this.locale,
    required this.currencyCode,
  });

  final ExpenseTransactionItem item;
  final bool balancesHidden;
  final bool isArabic;
  final String locale;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final Color accent = CategoryVisuals.colorFromValue(item.visual.colorValue);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CategoryVisuals.iconForKey(item.visual.iconKey),
              size: 17,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${AppLocalizations.translateCategoryForLanguage(locale, item.category)} • ${_dateLabel(item.date, locale)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
            balancesHidden
                ? '••••••'
                : _compactMoney(item.amountEgp, currencyCode),
            style: TextStyle(
              color: tokens.colors.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveTrendChart extends StatefulWidget {
  const _InteractiveTrendChart({
    required this.series,
    required this.color,
    required this.balancesHidden,
    required this.currencyCode,
  });

  final TrendSeries series;
  final Color color;
  final bool balancesHidden;
  final String currencyCode;

  @override
  State<_InteractiveTrendChart> createState() => _InteractiveTrendChartState();
}

class _InteractiveTrendChartState extends State<_InteractiveTrendChart> {
  int? _selectedIndex;

  void _updateSelection(Offset localPosition, Size size) {
    if (widget.series.values.isEmpty || size.width <= 0) return;
    final List<Offset> points = _chartPoints(
      widget.series.values,
      size,
      widget.series.scaleMax,
    );
    int bestIndex = 0;
    double bestDistance = double.infinity;
    for (int i = 0; i < points.length; i++) {
      final double distance = (points[i].dx - localPosition.dx).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    setState(() => _selectedIndex = bestIndex);
  }

  void _clearSelection() {
    if (_selectedIndex == null) return;
    setState(() => _selectedIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, 188);
        final List<Offset> points = _chartPoints(
          widget.series.values,
          size,
          widget.series.scaleMax,
        );
        final int? selectedIndex = _selectedIndex?.clamp(
          0,
          math.max(0, widget.series.values.length - 1),
        );
        final int? currentIndex = widget.series.currentIndex;
        final Offset? selectedPoint = selectedIndex == null || points.isEmpty
            ? null
            : points[selectedIndex];
        final String selectedLabel = selectedIndex == null
            ? ''
            : widget.series.labels[selectedIndex];
        final String selectedValue = selectedIndex == null
            ? ''
            : widget.balancesHidden
            ? '••••••'
            : _money(widget.series.values[selectedIndex], widget.currencyCode);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: MouseRegion(
            onHover: (PointerHoverEvent event) {
              _updateSelection(event.localPosition, size);
            },
            onExit: (_) => _clearSelection(),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (TapDownDetails details) {
                _updateSelection(details.localPosition, size);
              },
              onTapUp: (_) => _clearSelection(),
              onTapCancel: _clearSelection,
              onPanDown: (DragDownDetails details) {
                _updateSelection(details.localPosition, size);
              },
              onPanStart: (DragStartDetails details) {
                _updateSelection(details.localPosition, size);
              },
              onPanUpdate: (DragUpdateDetails details) {
                _updateSelection(details.localPosition, size);
              },
              onPanEnd: (_) => _clearSelection(),
              onPanCancel: _clearSelection,
              onLongPressStart: (LongPressStartDetails details) {
                _updateSelection(details.localPosition, size);
              },
              onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) {
                _updateSelection(details.localPosition, size);
              },
              onLongPressEnd: (_) => _clearSelection(),
              child: SizedBox(
                width: size.width,
                height: size.height + 12,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    CustomPaint(
                      size: size,
                      painter: _TrendChartPainter(
                        points: points,
                        values: widget.series.values,
                        color: widget.color,
                        selectedIndex: selectedIndex,
                        currentIndex: currentIndex,
                        scaleMax: widget.series.scaleMax,
                      ),
                    ),
                    if (selectedPoint != null)
                      Positioned(
                        left: (selectedPoint.dx - 56).clamp(
                          0,
                          size.width - 112,
                        ),
                        top: (selectedPoint.dy - 56).clamp(0, size.height - 56),
                        child: _TrendTooltip(
                          label: selectedLabel,
                          value: selectedValue,
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: widget.series.labels
                            .asMap()
                            .entries
                            .where((MapEntry<int, String> entry) {
                              if (entry.value.trim().isEmpty) return false;
                              final int length = widget.series.labels.length;
                              if (length <= 6) return true;
                              final int step =
                                  widget.series.selectedPeriod == '30D'
                                  ? 5
                                  : math.max(1, (length / 4).ceil());
                              return entry.key % step == 0 ||
                                  entry.key == length - 1;
                            })
                            .map(
                              (MapEntry<int, String> entry) => Text(
                                entry.value,
                                style: TextStyle(
                                  color: tokens.colors.textSecondary,
                                  fontSize: 10.5,
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrendTooltip extends StatelessWidget {
  const _TrendTooltip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tokens.colors.divider.withValues(alpha: 0.75),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: tokens.colors.textSecondary,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: tokens.colors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter({
    required this.points,
    required this.values,
    required this.color,
    required this.selectedIndex,
    required this.currentIndex,
    required this.scaleMax,
  });

  final List<Offset> points;
  final List<double> values;
  final Color color;
  final int? selectedIndex;
  final int? currentIndex;
  final double scaleMax;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.isEmpty) return;

    final Rect rect = Offset.zero & size;
    final Paint grid = Paint()
      ..color = color.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    for (int i = 1; i <= 3; i++) {
      final double y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (points.length == 1) {
      canvas.drawCircle(points.first, 3, Paint()..color = color);
      return;
    }

    final Path linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final Offset current = points[i];
      linePath.lineTo(current.dx, current.dy);
    }

    final Path fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          color.withValues(alpha: 0.08),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(rect);
    canvas.drawPath(fillPath, fillPaint);

    final Paint linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    final Paint pointPaint = Paint()..color = color;
    final Paint hollowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.88);

    if (currentIndex != null && currentIndex! < points.length) {
      final Offset currentPoint = points[currentIndex!];
      canvas.drawCircle(
        currentPoint,
        4.8,
        Paint()..color = color.withValues(alpha: 0.95),
      );
    }

    if (selectedIndex != null && selectedIndex! < points.length) {
      canvas.drawCircle(points[selectedIndex!], 5.5, pointPaint);
      canvas.drawCircle(points[selectedIndex!], 9, hollowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.currentIndex != currentIndex ||
        oldDelegate.scaleMax != scaleMax;
  }
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({
    required this.slices,
    required this.total,
    required this.emptyColor,
    required this.centerAmount,
  });

  final List<ExpenseGroup> slices;
  final double total;
  final Color emptyColor;
  final String centerAmount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        CustomPaint(
          size: const Size.square(176),
          painter: _DonutPainter(
            slices: slices,
            total: total,
            emptyColor: emptyColor,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              centerAmount,
              style: TextStyle(
                color: tokens.colors.textPrimary,
                fontSize: 25,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Total expenses',
              style: TextStyle(
                color: tokens.colors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.total,
    required this.emptyColor,
  });

  final List<ExpenseGroup> slices;
  final double total;
  final Color emptyColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Rect rect = Offset.zero & size;
    final double strokeWidth = 18;
    final Paint base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = emptyColor;
    canvas.drawArc(rect.deflate(strokeWidth / 2), 0, math.pi * 2, false, base);

    if (total <= 0) return;
    double start = -math.pi / 2;
    for (final ExpenseGroup slice in slices) {
      final double sweep = (slice.amountEgp / total) * math.pi * 2;
      if (sweep <= 0) continue;
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = CategoryVisuals.colorFromValue(slice.visual.colorValue);
      canvas.drawArc(rect.deflate(strokeWidth / 2), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.slices != slices ||
        oldDelegate.total != total ||
        oldDelegate.emptyColor != emptyColor;
  }
}

class ExpenseAnalysisData {
  const ExpenseAnalysisData({
    required this.expenseMetrics,
    required this.combinedMetrics,
    required this.totalCurrent,
    required this.totalPrevious,
    required this.changePct,
    required this.averageDaily,
    required this.highestDay,
    required this.highestDayValue,
    required this.transactionCount,
    required this.averagePerTransaction,
    required this.range,
    required this.selectedPeriod,
    required this.dailyTotals,
    required this.currentExpenses,
    required this.categoryGroups,
    required this.merchantGroups,
    required this.sourceGroups,
    required this.sourceCoverage,
    required this.incomeCurrent,
    required this.incomePrevious,
    required this.currencyCode,
    required this.largestTransactions,
    required this.recentTransactions,
    required this.categoryDeltas,
    required this.savings,
    required this.investments,
    required this.market,
    required this.projectedMonthlySpend,
    required this.spendingHealthScore,
  });

  final FinancialMetricsResult<Transaction> expenseMetrics;
  final FinancialMetricsResult<Transaction> combinedMetrics;
  final double totalCurrent;
  final double totalPrevious;
  final double changePct;
  final double averageDaily;
  final DateTime highestDay;
  final double highestDayValue;
  final int transactionCount;
  final double averagePerTransaction;
  final DateTimeRange range;
  final String selectedPeriod;
  final Map<DateTime, double> dailyTotals;
  final List<DatedExpense> currentExpenses;
  final List<ExpenseGroup> categoryGroups;
  final List<ExpenseGroup> merchantGroups;
  final List<ExpenseGroup> sourceGroups;
  final double sourceCoverage;
  final double incomeCurrent;
  final double incomePrevious;
  final String currencyCode;
  final List<ExpenseTransactionItem> largestTransactions;
  final List<ExpenseTransactionItem> recentTransactions;
  final List<CategoryDelta> categoryDeltas;
  final List<Saving> savings;
  final List<InvestmentAsset> investments;
  final MarketData market;
  final double? projectedMonthlySpend;
  final double spendingHealthScore;

  List<ExpenseGroup> get chartSlices {
    return _limitedSlices(categoryGroups);
  }

  ExpenseGroup? get primaryCategorySlice {
    final List<ExpenseGroup> slices = chartSlices;
    return slices.isEmpty ? null : slices.first;
  }

  List<ExpenseGroup> get sourceSlices {
    if (sourceCoverage < 0.6 || sourceGroups.isEmpty) {
      return const <ExpenseGroup>[];
    }
    return _limitedSlices(sourceGroups);
  }

  bool get hasIncomeData => incomeCurrent > 0 || incomePrevious > 0;

  double get incomeChangePct {
    if (incomePrevious <= 0) return 0;
    return ((incomeCurrent - incomePrevious) / incomePrevious) * 100;
  }

  double get savingsRate {
    if (incomeCurrent <= 0) return 0;
    return ((incomeCurrent - totalCurrent) / incomeCurrent) * 100;
  }

  String spendingHealthLabel({required bool isArabic}) {
    if (spendingHealthScore >= 75) {
      return isArabic ? 'ممتاز' : 'Excellent';
    }
    if (spendingHealthScore >= 55) {
      return isArabic ? 'جيد' : 'Good';
    }
    return isArabic ? 'راقب' : 'Watch';
  }

  Color spendingHealthColor(BuildContext context) {
    final tokens = context.premiumTokens;
    if (spendingHealthScore >= 75) {
      return tokens.colors.emerald;
    }
    if (spendingHealthScore >= 55) {
      return tokens.colors.gold;
    }
    return tokens.colors.danger;
  }

  List<ExpenseGroup> _limitedSlices(List<ExpenseGroup> groups) {
    if (groups.isEmpty) return const <ExpenseGroup>[];

    final List<ExpenseGroup> sorted = groups.toList()
      ..sort(
        (ExpenseGroup a, ExpenseGroup b) => b.amountEgp.compareTo(a.amountEgp),
      );
    final List<ExpenseGroup> nonOther = sorted
        .where((ExpenseGroup group) => !_isOtherLabel(group.label))
        .toList(growable: false);
    ExpenseGroup? existingOther;
    for (final ExpenseGroup group in sorted) {
      if (_isOtherLabel(group.label)) {
        existingOther = group;
        break;
      }
    }
    final List<ExpenseGroup> top = nonOther.take(5).toList(growable: false);
    final double otherAmount =
        (existingOther?.amountEgp ?? 0) +
        nonOther
            .skip(5)
            .fold<double>(
              0,
              (double total, ExpenseGroup group) => total + group.amountEgp,
            );
    final List<ExpenseGroup> result = <ExpenseGroup>[...top];
    if (otherAmount > 0) {
      result.add(
        ExpenseGroup(
          label: 'Other',
          amountEgp: otherAmount,
          visual: CategoryVisual(iconKey: 'wallet', colorValue: 0xFF94A3B8),
        ),
      );
    }
    result.sort(
      (ExpenseGroup a, ExpenseGroup b) => b.amountEgp.compareTo(a.amountEgp),
    );
    return result;
  }

  List<String> get availableSummaryGroupings {
    final List<String> values = <String>['category'];
    if (sourceCoverage >= 0.6 && sourceGroups.isNotEmpty) {
      values.add('source');
    }
    return values;
  }

  List<InsightItem> smartInsights({
    required bool balancesHidden,
    required String locale,
  }) {
    final List<InsightItem> insights = <InsightItem>[];
    final tokens = PremiumThemePresets.light.colors;
    final ExpenseGroup? topCategory = primaryCategorySlice;
    final double meaningfulBaseline = math.max(totalCurrent * 0.05, 100);

    if (totalCurrent <= 0) {
      return <InsightItem>[
        InsightItem(
          title: 'No spending to analyze yet',
          subtitle: 'Add expenses to surface insights.',
          icon: Icons.insights_outlined,
          color: tokens.emerald,
        ),
      ];
    }

    if (spendingHealthScore >= 75) {
      insights.add(
        InsightItem(
          title: 'Overall spending is healthy',
          subtitle: 'Your pace is leaving room for saving.',
          icon: Icons.verified_rounded,
          color: tokens.emerald,
        ),
      );
    } else if (spendingHealthScore >= 55) {
      insights.add(
        InsightItem(
          title: 'Overall spending is stable',
          subtitle: 'A few categories are growing faster than the rest.',
          icon: Icons.check_circle_outline_rounded,
          color: tokens.warning,
        ),
      );
    } else {
      insights.add(
        InsightItem(
          title: 'Spending needs attention',
          subtitle:
              'Review the fastest growing categories before the period ends.',
          icon: Icons.warning_amber_rounded,
          color: tokens.danger,
        ),
      );
    }

    if (topCategory != null) {
      final double share = (topCategory.amountEgp / totalCurrent) * 100;
      insights.add(
        InsightItem(
          title:
              '${topCategory.label} drives ${share.toStringAsFixed(0)}% of spend',
          subtitle:
              '${balancesHidden ? '••••••' : _compactMoney(topCategory.amountEgp, currencyCode)} this period',
          icon: CategoryVisuals.iconForKey(topCategory.visual.iconKey),
          color: CategoryVisuals.colorFromValue(topCategory.visual.colorValue),
        ),
      );
    }

    if (changePct.abs() >= 10) {
      insights.add(
        InsightItem(
          title: changePct >= 0
              ? 'Spending increased ${_formatPercentChange(changePct)}'
              : 'Spending decreased ${_formatPercentChange(changePct)}',
          subtitle: 'Compared with the previous period.',
          icon: changePct >= 0
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded,
          color: changePct >= 0 ? tokens.danger : tokens.success,
        ),
      );
    }

    if (largestTransactions.isNotEmpty) {
      final ExpenseTransactionItem topTransaction = largestTransactions.first;
      insights.add(
        InsightItem(
          title:
              'Largest transaction on ${_dateLabel(topTransaction.date, locale)}',
          subtitle:
              '${topTransaction.label} • ${balancesHidden ? '••••••' : _compactMoney(topTransaction.amountEgp, currencyCode)}',
          icon: CategoryVisuals.iconForKey(topTransaction.visual.iconKey),
          color: CategoryVisuals.colorFromValue(
            topTransaction.visual.colorValue,
          ),
        ),
      );
    }

    final List<CategoryDelta> sortedDeltas = categoryDeltas.toList()
      ..sort((CategoryDelta a, CategoryDelta b) {
        return b.pct.abs().compareTo(a.pct.abs());
      });
    final CategoryDelta? biggestIncrease = sortedDeltas
        .where(
          (CategoryDelta delta) => delta.currentValue > delta.previousValue,
        )
        .fold<CategoryDelta?>(null, (
          CategoryDelta? current,
          CategoryDelta delta,
        ) {
          if (current == null || delta.pct > current.pct) return delta;
          return current;
        });
    final CategoryDelta? biggestDecrease = sortedDeltas
        .where(
          (CategoryDelta delta) => delta.currentValue < delta.previousValue,
        )
        .fold<CategoryDelta?>(null, (
          CategoryDelta? current,
          CategoryDelta delta,
        ) {
          if (current == null || delta.pct < current.pct) return delta;
          return current;
        });

    if (biggestIncrease != null) {
      if (biggestIncrease.previousValue < meaningfulBaseline) {
        insights.add(
          InsightItem(
            title: 'New spending detected in ${biggestIncrease.label}',
            subtitle: 'Compared with the previous period.',
            icon: Icons.fiber_new_rounded,
            color: tokens.emerald,
          ),
        );
      } else if (biggestIncrease.pct.abs() >= 20) {
        insights.add(
          InsightItem(
            title: '${biggestIncrease.label} is the fastest growing category',
            subtitle:
                '${_formatPercentChange(biggestIncrease.pct)} compared with the previous period',
            icon: Icons.trending_up_rounded,
            color: tokens.danger,
          ),
        );
      }
    }

    if (biggestDecrease != null && biggestDecrease.pct.abs() >= 15) {
      insights.add(
        InsightItem(
          title: '${biggestDecrease.label} is the most improved category',
          subtitle:
              '${_formatPercentChange(biggestDecrease.pct)} compared with the previous period',
          icon: Icons.trending_down_rounded,
          color: tokens.success,
        ),
      );
    }

    if (projectedMonthlySpend != null && incomeCurrent > 0) {
      final double projectedSurplus = incomeCurrent - projectedMonthlySpend!;
      insights.add(
        InsightItem(
          title: projectedSurplus >= 0
              ? 'Projected monthly surplus remains positive'
              : 'Projected monthly surplus may turn negative',
          subtitle:
              '${balancesHidden ? '••••••' : _compactMoney(projectedMonthlySpend!, currencyCode)} estimated spending',
          icon: projectedSurplus >= 0
              ? Icons.savings_outlined
              : Icons.report_outlined,
          color: projectedSurplus >= 0 ? tokens.emerald : tokens.warning,
        ),
      );
    }

    return insights.take(5).toList(growable: false);
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

class ExpenseTransactionItem {
  const ExpenseTransactionItem({
    required this.label,
    required this.category,
    required this.amountEgp,
    required this.date,
    required this.visual,
  });

  final String label;
  final String category;
  final double amountEgp;
  final DateTime date;
  final CategoryVisual visual;
}

class DatedExpense {
  const DatedExpense({
    required this.tx,
    required this.date,
    required this.amountEgp,
  });

  final Transaction tx;
  final DateTime date;
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

class TrendSeries {
  const TrendSeries({
    required this.values,
    required this.labels,
    required this.selectedPeriod,
    required this.currentIndex,
    required this.highestIndex,
    required this.scaleMax,
  });

  final List<double> values;
  final List<String> labels;
  final String selectedPeriod;
  final int? currentIndex;
  final int highestIndex;
  final double scaleMax;

  String get highestLabel => labels[highestIndex];
  double get highestValue => values[highestIndex];
}

class InsightItem {
  const InsightItem({
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

class _SummaryMetric {
  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

String _periodLabel(String period, bool isArabic) {
  switch (period) {
    case 'All':
      return isArabic ? 'الكل' : 'All';
    case '30D':
      return '30D';
    case '90D':
      return '90D';
    case '6M':
      return '6M';
    case 'YTD':
      return 'YTD';
    default:
      return period;
  }
}

BoxDecoration _sectionCardDecoration(BuildContext context) {
  final tokens = context.premiumTokens;
  final bool dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: dark
        ? Color.lerp(tokens.colors.card, Colors.white, 0.04)!
        : tokens.colors.surface,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: tokens.colors.divider.withValues(alpha: 0.68)),
    boxShadow: <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.16 : 0.05),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

TrendSeries _buildTrendSeries(FinancialMetricsResult<Transaction> metrics) {
  final List<double> values = metrics.chartBuckets
      .map((FinancialMetricsBucket bucket) => bucket.value)
      .toList(growable: false);
  final List<String> labels = metrics.chartBuckets
      .map((FinancialMetricsBucket bucket) => bucket.label)
      .toList(growable: false);
  final int highestIndex = _highestIndex(values);
  final int? currentIndex = metrics.chartBuckets.isEmpty
      ? null
      : metrics.chartBuckets.indexWhere((FinancialMetricsBucket bucket) {
          return bucket.isCurrent;
        });
  return TrendSeries(
    values: values,
    labels: labels.map(_latinDigits).toList(growable: false),
    selectedPeriod: metrics.selectedPeriod,
    currentIndex: currentIndex != null && currentIndex >= 0
        ? currentIndex
        : (metrics.chartBuckets.isEmpty
              ? null
              : metrics.chartBuckets.length - 1),
    highestIndex: highestIndex,
    scaleMax: metrics.chartMax,
  );
}

List<Offset> _chartPoints(List<double> values, Size size, double scaleMax) {
  if (values.isEmpty || size.isEmpty) return <Offset>[];
  final double topPadding = 10;
  final double bottomPadding = 14;
  final double height = math.max(1, size.height - topPadding - bottomPadding);
  final double denom = values.length <= 1 ? 1 : values.length - 1;
  final List<Offset> points = <Offset>[];
  for (int i = 0; i < values.length; i++) {
    final double x = (i / denom) * size.width;
    final double normalized = scaleMax <= 0
        ? 0
        : (values[i].clamp(0, scaleMax) / scaleMax).clamp(0, 1);
    final double y = topPadding + ((1 - normalized) * height);
    points.add(Offset(x, y));
  }
  return points;
}

int _highestIndex(List<double> values) {
  if (values.isEmpty) return 0;
  int bestIndex = 0;
  double bestValue = values.first;
  for (int i = 1; i < values.length; i++) {
    if (values[i] > bestValue) {
      bestValue = values[i];
      bestIndex = i;
    }
  }
  return bestIndex;
}

String _money(double value, [String currencyCode = 'EGP']) {
  return ZakatEngineService.formatCurrency(value, currencyCode);
}

String _shortMoney(double value, [String currencyCode = 'EGP']) {
  return _compactMoney(value, currencyCode);
}

String _compactMoney(double value, [String currencyCode = 'EGP']) {
  final String symbol = ZakatEngineService.getCurrencySymbol(currencyCode);
  final double absValue = value.abs();
  String suffix = '';
  double display = absValue;

  if (absValue >= 1000000000) {
    display = absValue / 1000000000;
    suffix = 'B';
  } else if (absValue >= 1000000) {
    display = absValue / 1000000;
    suffix = 'M';
  } else if (absValue >= 1000) {
    display = absValue / 1000;
    suffix = 'K';
  }

  final String number = suffix.isEmpty
      ? NumberFormat('#,##0.##', 'en_US').format(display)
      : display
            .toStringAsFixed(display >= 100 ? 0 : 1)
            .replaceFirst(RegExp(r'\.0$'), '');
  final String prefix = value < 0 ? '- ' : '';
  return '$prefix$symbol $number$suffix';
}

String _dateLabel(DateTime value, String locale) {
  return _latinDigits(DateFormat('d MMM yyyy', locale).format(value));
}

double _convertToDisplayCurrency(
  double amount,
  String sourceCurrency,
  MarketData market,
  String targetCurrency,
) {
  final double amountEgp = ZakatEngineService.convertToEgp(
    amount,
    sourceCurrency,
    market,
  );
  if (!amountEgp.isFinite) return double.nan;
  final String currency = targetCurrency.trim().isEmpty
      ? 'EGP'
      : targetCurrency;
  final double converted = ZakatEngineService.convertFromEgp(
    amountEgp,
    currency,
    market,
  );
  return converted.isFinite ? converted : amountEgp;
}

String _summaryPeriodLabel(DateTimeRange range, bool isArabic) {
  final DateFormat format = DateFormat('MMMM yyyy', isArabic ? 'ar' : 'en_US');
  if (range.start.year == range.end.year &&
      range.start.month == range.end.month) {
    return _latinDigits(format.format(range.end));
  }
  return '${_latinDigits(DateFormat('d MMM', isArabic ? 'ar' : 'en_US').format(range.start))} - ${_latinDigits(DateFormat('d MMM yyyy', isArabic ? 'ar' : 'en_US').format(range.end))}';
}

String _summarySentence(ExpenseAnalysisData data, bool isArabic) {
  final String health = data.spendingHealthLabel(isArabic: isArabic);
  final String change = data.changePct.abs().toStringAsFixed(0);
  if (isArabic) {
    return data.changePct >= 0
        ? 'زاد الإنفاق $change%، والحالة المالية الآن $health.'
        : 'انخفض الإنفاق $change%، والحالة المالية الآن $health.';
  }
  return data.changePct >= 0
      ? 'Spending increased by $change%, and your spending health is $health.'
      : 'Spending decreased by $change%, and your spending health is $health.';
}

String _formatPercentChange(double changePct) {
  final double abs = changePct.abs();
  if (abs >= 1000) {
    return '${changePct >= 0 ? '+' : '-'}${(abs / 100).toStringAsFixed(1)}x';
  }
  return '${changePct >= 0 ? '+' : '-'}${abs.toStringAsFixed(abs >= 100 ? 0 : 1)}%';
}

double _spendingHealthScore({
  required double totalCurrent,
  required double incomeCurrent,
  required double changePct,
  required double averageDaily,
  required Map<DateTime, double> dailyTotals,
}) {
  if (totalCurrent <= 0) return 100;
  double score = 55;

  if (incomeCurrent > 0) {
    final double savingsRate = ((incomeCurrent - totalCurrent) / incomeCurrent)
        .clamp(-1.0, 1.0);
    score += savingsRate * 35;
  } else {
    score -= 10;
  }

  if (changePct < 0) {
    score += math.min(10, changePct.abs() / 6);
  } else {
    score -= math.min(18, changePct / 4);
  }

  if (dailyTotals.isNotEmpty && averageDaily > 0) {
    final double variance =
        dailyTotals.values.fold<double>(0, (double total, double value) {
          final double delta = value - averageDaily;
          return total + delta * delta;
        }) /
        dailyTotals.length;
    final double stdDev = math.sqrt(variance);
    final double volatility = stdDev / averageDaily;
    if (volatility < 0.5) {
      score += 8;
    } else if (volatility > 1.2) {
      score -= 8;
    }
  }

  return score.clamp(0, 100);
}

String _breakdownTitle(ExpenseAnalysisData data, String mode, bool isArabic) {
  if (mode == 'source' &&
      data.sourceCoverage >= 0.6 &&
      data.sourceGroups.isNotEmpty) {
    return isArabic ? 'مصادر الإنفاق' : 'Top Expense Sources';
  }
  return isArabic ? 'المصروفات حسب الفئة' : 'Expenses by Category';
}

String _latinDigits(String value) {
  const Map<String, String> map = <String, String>{
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
  };
  return value.split('').map((String c) => map[c] ?? c).join();
}

bool _isOtherLabel(String value) {
  return value.trim().toLowerCase() == 'other';
}
