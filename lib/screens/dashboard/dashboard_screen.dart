import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/services/zakat_schedule_service.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/investment_asset.dart';
import '../../models/market_snapshot.dart';
import '../../models/saving.dart';
import '../../models/transaction.dart';
import '../../services/app_state_controller.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.onViewAllActivity,
    this.onOpenAddActions,
    this.onOpenZakatSchedule,
  });

  final VoidCallback? onViewAllActivity;
  final VoidCallback? onOpenAddActions;
  final VoidCallback? onOpenZakatSchedule;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color _deepEmerald = Color(0xFF073B3A);
  static const Color _richEmerald = Color(0xFF0F766E);
  bool _animateIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _animateIn = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final state = controller.state;
    final transactions = state.transactions;
    final savings = state.savings;
    final investments = state.investments;

    final market = MarketData.fromJson(state.marketData);
    final MarketSnapshot snapshot = controller.currentMarketSnapshot;
    final Set<String> requiredCurrencies = _requiredCurrencies(
      transactions: transactions,
      savings: savings,
      investments: investments,
    );
    final bool hasFxData = requiredCurrencies.every(
      (String c) => ZakatEngineService.isCurrencyConversionAvailable(c, market),
    );
    final bool hasMetalsData = snapshot.hasRequiredData;
    final bool hasMarketData = hasFxData && hasMetalsData;

    double totalIncomeEgp = 0;
    double totalExpensesEgp = 0;
    NisabTotals savingsTotals = const NisabTotals(
      totalCashEgp: 0,
      totalGold24k: 0,
      totalGoldEgp: 0,
      totalSilverGrams: 0,
      totalSilverEgp: 0,
      totalSavingsWealthEgp: 0,
    );
    double investmentsEgp = 0;
    double totalWealthEgp = 0;
    double investmentLiabilityEgp = 0;
    double netPositionEgp = 0;
    double nisabThreshold = 0;
    bool nisabMet = false;

    if (hasFxData) {
      for (final tx in transactions) {
        final double egpAmount = ZakatEngineService.convertToEgp(tx.amount, tx.currency, market);
        if (tx.type == 'income') {
          totalIncomeEgp += egpAmount;
        } else if (tx.type == 'expense') {
          totalExpensesEgp += egpAmount;
        }
      }
      investmentsEgp = ZakatEngineService.calculateTotalInvestmentsEgp(
        investments: investments,
        marketData: market,
      );
    }

    if (hasMarketData) {
      savingsTotals = ZakatEngineService.computeNisabTotals(savings: savings, marketData: market);
      totalWealthEgp = ZakatEngineService.calculateTotalWealthEgp(
        transactions: transactions,
        savings: savings,
        investments: investments,
        marketData: market,
      );

      investmentLiabilityEgp = investments.fold<double>(
        0,
        (double sum, InvestmentAsset asset) =>
            sum + ZakatEngineService.convertToEgp(asset.loanBalance, asset.currency, market),
      );
      netPositionEgp = totalWealthEgp - investmentLiabilityEgp;

      nisabThreshold = ZakatEngineService.defaultConfig.nisabGoldGrams * market.goldPrice24kEgp;
      nisabMet = ZakatEngineService.checkCashNisab(totalWealthEgp, market);
    }

    final List<Map<String, dynamic>> schedule = hasMarketData
        ? _buildSchedule(
            zakatMethod: state.zakatMethod,
            zakatAnnualDate: state.zakatAnnualDate,
            transactions: transactions,
            savings: savings,
            investments: investments,
            marketData: market,
          )
        : const <Map<String, dynamic>>[];
    final _Dues dues = _computeDues(schedule);
    final String? nextZakatDate = _findNextZakatDate(schedule);

    final _Allocation allocation = _computeAllocation(
      savingsTotals: savingsTotals,
      investments: investments,
      marketData: market,
      totalWealthEgp: totalWealthEgp,
    );

    final List<Transaction> recent = List<Transaction>.from(transactions)
      ..sort((a, b) => _parseDate(b.date).compareTo(_parseDate(a.date)));
    final List<Transaction> recent4 = recent.take(4).toList(growable: false);

    final bool hasAnyData = transactions.isNotEmpty || savings.isNotEmpty || investments.isNotEmpty;

    final tokens = context.premiumTokens;
    final double navSafeBottomPadding = 112 + MediaQuery.paddingOf(context).bottom;
    return Container(
      color: tokens.colors.background,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 20, 16, navSafeBottomPadding),
        children: <Widget>[
          SectionHeader(title: context.l10n.tr('dashboard'), bottomSpacing: 16),
          if (!hasAnyData)
            EmptyStateCard(
              cardKey: const Key('dashboardEmptyCard'),
              icon: Icons.auto_graph,
              title: context.l10n.tr('start_zakat_journey'),
              message: context.l10n.tr('add_first_income_saving_asset'),
              action: AppPrimaryButton(
                key: const Key('dashboardStartAddingButton'),
                onPressed: widget.onOpenAddActions,
                label: context.l10n.tr('add_first_entry'),
                icon: Icons.add,
              ),
            )
          else ...<Widget>[
            _stagger(
              order: 0,
              child: _PremiumHeroCard(
                totalWealthEgp: totalWealthEgp,
                netPositionEgp: netPositionEgp,
                dues: dues,
                nisabMet: nisabMet,
                hasMarketData: hasMarketData,
                hasFxData: hasFxData,
                state: state,
                market: market,
                nextZakatDate: nextZakatDate,
              ),
            ),
            const SizedBox(height: 16),
            _stagger(
              order: 1,
              child: _QuickActionsRow(
                onOpenAddActions: widget.onOpenAddActions,
                onOpenZakatSchedule: widget.onOpenZakatSchedule,
              ),
            ),
            const SizedBox(height: 16),
            _stagger(
              order: 2,
              child: _InsightPanel(
                title: context.l10n.tr('current_nisab_threshold'),
                value: hasFxData && !hasMetalsData
                    ? context.l10n.tr('gold_silver_required')
                    : _formatOrMissing(context, nisabThreshold, hasMarketData, state.mainCurrency, market),
              ),
            ),
            const SizedBox(height: 16),
            _stagger(
              order: 3,
              child: _PremiumSection(
                title: context.l10n.tr('financial_summary'),
                child: Column(
                  children: <Widget>[
                    _MetricRow(
                      label: context.l10n.tr('total_income'),
                      value: _formatOrMissing(context, totalIncomeEgp, hasFxData, state.mainCurrency, market),
                    ),
                    _MetricRow(
                      label: context.l10n.tr('total_expenses'),
                      value: _formatOrMissing(context, totalExpensesEgp, hasFxData, state.mainCurrency, market),
                    ),
                    _MetricRow(
                      label: context.l10n.tr('total_savings_wealth'),
                      value: _formatOrMissing(
                        context,
                        savingsTotals.totalSavingsWealthEgp,
                        hasMarketData,
                        state.mainCurrency,
                        market,
                      ),
                    ),
                    _MetricRow(
                      label: context.l10n.tr('investment_wealth'),
                      value: _formatOrMissing(context, investmentsEgp, hasFxData, state.mainCurrency, market),
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _stagger(
              order: 4,
              child: _PremiumSection(
                key: const Key('dashboardZakatSummaryCard'),
                title: context.l10n.tr('zakat_summary'),
                onTap: widget.onOpenZakatSchedule,
                child: Column(
                  children: <Widget>[
                    _MetricRow(
                      label: context.l10n.tr('nisab_status'),
                      value: hasMarketData
                          ? (nisabMet ? context.l10n.tr('above_nisab') : context.l10n.tr('below_nisab'))
                          : (hasFxData
                              ? context.l10n.tr('gold_silver_required')
                              : context.l10n.tr('market_data_required')),
                      valueColor: nisabMet ? _richEmerald : const Color(0xFF8A6A2A),
                    ),
                    _MetricRow(
                      label: context.l10n.tr('current_nisab_threshold'),
                      value: hasFxData && !hasMetalsData
                          ? context.l10n.tr('gold_silver_required')
                          : _formatOrMissing(context, nisabThreshold, hasMarketData, state.mainCurrency, market),
                    ),
                    _MetricRow(
                      label: context.l10n.tr('zakat_due_this_month'),
                      value: _formatOrMissing(context, dues.thisMonth, hasMarketData, state.mainCurrency, market),
                    ),
                    _MetricRow(
                      label: context.l10n.tr('zakat_due_next_month'),
                      value: _formatOrMissing(context, dues.nextMonth, hasMarketData, state.mainCurrency, market),
                    ),
                    _MetricRow(
                      label: context.l10n.tr('total_upcoming_dues'),
                      value: _formatOrMissing(context, dues.totalUpcoming, hasMarketData, state.mainCurrency, market),
                      valueColor: _deepEmerald,
                      isLast: true,
                    ),
                    const SizedBox(height: 14),
                    _MiniZakatJourney(isMet: nisabMet, hasMarketData: hasMarketData),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _stagger(
              order: 5,
              child: _PremiumSection(
                title: context.l10n.tr('asset_allocation'),
                child: _AllocationRing(allocation: allocation),
              ),
            ),
            const SizedBox(height: 16),
            _stagger(
              order: 6,
              child: _PremiumSection(
                title: context.l10n.tr('recent_activity_title'),
                trailing: TextButton(
                  key: const Key('dashboardViewAllActivityButton'),
                  onPressed: widget.onViewAllActivity,
                  child: Text(context.l10n.tr('view_all')),
                ),
                child: Column(
                  children: <Widget>[
                    if (recent4.isEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          context.l10n.tr('no_recent_transactions'),
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: const Color(0xFF6B7280)),
                        ),
                      )
                    else
                      ...recent4.map((Transaction tx) => _ActivityRow(tx: tx)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stagger({required int order, required Widget child}) {
    final int base = 280 + (order * 80);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: _animateIn ? 1 : 0),
      duration: Duration(milliseconds: base),
      curve: Curves.easeOutCubic,
      builder: (_, double value, Widget? built) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: built,
          ),
        );
      },
      child: child,
    );
  }

  static List<Map<String, dynamic>> _buildSchedule({
    required String zakatMethod,
    required String zakatAnnualDate,
    required List<Transaction> transactions,
    required List<Saving> savings,
    required List<InvestmentAsset> investments,
    required MarketData marketData,
  }) {
    if (zakatMethod == 'annual') {
      return ZakatScheduleService.calculateAnnualZakatSchedule(
        zakatAnnualDate: zakatAnnualDate,
        transactions: transactions.map((e) => e.toJson()).toList(growable: false),
        savings: savings.map((e) => e.toJson()).toList(growable: false),
        investments: investments.map((e) => e.toJson()).toList(growable: false),
        marketData: marketData,
      );
    }

    final List<Map<String, dynamic>> incomeSchedule = ZakatScheduleService.calculateMonthlyZakatSchedule(
      transactions: transactions.map((e) => e.toJson()).toList(growable: false),
      marketData: marketData,
    );
    final List<Map<String, dynamic>> savingsSchedule = ZakatScheduleService.calculateSavingsZakatSchedule(
      savings: savings.map((e) => e.toJson()).toList(growable: false),
      marketData: marketData,
    );

    return <Map<String, dynamic>>[...incomeSchedule, ...savingsSchedule];
  }

  static _Dues _computeDues(List<Map<String, dynamic>> schedule) {
    final DateTime now = DateTime.now();
    final String thisMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final DateTime nextMonthDate = DateTime(now.year, now.month + 1, 1);
    final String nextMonthKey = '${nextMonthDate.year}-${nextMonthDate.month.toString().padLeft(2, '0')}';

    double thisMonth = 0;
    double nextMonth = 0;
    double upcoming = 0;

    for (final item in schedule) {
      final String monthKey = (item['monthKey'] ?? '').toString();
      final double value = ((item['totalZakat'] ?? 0) as num).toDouble();
      if (monthKey == thisMonthKey) thisMonth += value;
      if (monthKey == nextMonthKey) nextMonth += value;

      DateTime? paymentDate;
      try {
        paymentDate = DateTime.parse((item['paymentDate'] ?? '').toString());
      } catch (_) {
        paymentDate = null;
      }
      if (paymentDate != null &&
          !DateTime(paymentDate.year, paymentDate.month, 1)
              .isBefore(DateTime(now.year, now.month, 1))) {
        upcoming += value;
      }
    }

    return _Dues(thisMonth: thisMonth, nextMonth: nextMonth, totalUpcoming: upcoming);
  }

  static _Allocation _computeAllocation({
    required NisabTotals savingsTotals,
    required List<InvestmentAsset> investments,
    required MarketData marketData,
    required double totalWealthEgp,
  }) {
    if (totalWealthEgp <= 0 || totalWealthEgp.isNaN || totalWealthEgp.isInfinite) {
      return const _Allocation(cashPct: 0, metalsPct: 0, propertyPct: 0, companyPct: 0);
    }

    final double cash = savingsTotals.totalCashEgp;
    final double metals = savingsTotals.totalGoldEgp + savingsTotals.totalSilverEgp;

    double property = 0;
    double company = 0;
    for (final asset in investments) {
      final double value = ZakatEngineService.calculateInvestmentEstimatedValueEgp(
        asset: asset,
        marketData: marketData,
      );
      if (ZakatEngineService.isCompanyInvestmentType(asset.investmentType)) {
        company += value;
      } else {
        property += value;
      }
    }

    return _Allocation(
      cashPct: (cash / totalWealthEgp) * 100,
      metalsPct: (metals / totalWealthEgp) * 100,
      propertyPct: (property / totalWealthEgp) * 100,
      companyPct: (company / totalWealthEgp) * 100,
    );
  }

  static Set<String> _requiredCurrencies({
    required List<Transaction> transactions,
    required List<Saving> savings,
    required List<InvestmentAsset> investments,
  }) {
    final Set<String> out = <String>{};
    for (final Transaction tx in transactions) {
      out.add(tx.currency);
    }
    for (final Saving s in savings) {
      if ((s.assetType).toLowerCase() == 'cash') {
        out.add(s.unit);
      }
    }
    for (final InvestmentAsset asset in investments) {
      out.add(asset.currency);
    }
    out.removeWhere((String c) => c.trim().isEmpty || c == 'EGP');
    return out;
  }

  static String _formatDisplay(double value, String currencyCode) {
    final NumberFormat formatter = NumberFormat('#,##0.00', 'en_US');
    if (currencyCode == 'EGP') {
      return 'E£ ${formatter.format(value)}';
    }
    return '$currencyCode ${formatter.format(value)}';
  }

  static String _formatOrMissing(
    BuildContext context,
    double valueEgp,
    bool hasMarketData,
    String mainCurrency,
    MarketData marketData,
  ) {
    if (!hasMarketData) return context.l10n.tr('market_data_required');
    final String displayCurrency = mainCurrency.trim().isEmpty ? 'EGP' : mainCurrency.trim();
    final double displayValue = ZakatEngineService.convertFromEgp(valueEgp, displayCurrency, marketData);
    if (displayValue.isNaN) return context.l10n.tr('market_data_required');
    return _formatDisplay(displayValue, displayCurrency);
  }

  static String _formatPct(double value) {
    return '${value.toStringAsFixed(1)}%';
  }

  static String? _findNextZakatDate(List<Map<String, dynamic>> schedule) {
    final DateTime today = DateTime.now();
    DateTime? best;
    for (final Map<String, dynamic> item in schedule) {
      final String raw = (item['paymentDate'] ?? '').toString().trim();
      if (raw.isEmpty) continue;
      final DateTime? parsed = DateTime.tryParse(raw);
      if (parsed == null) continue;
      if (parsed.isBefore(DateTime(today.year, today.month, today.day))) continue;
      if (best == null || parsed.isBefore(best)) {
        best = parsed;
      }
    }
    if (best == null) return null;
    return DateFormat('yyyy-MM-dd').format(best);
  }

  static DateTime _parseDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }
}

class _PremiumHeroCard extends StatelessWidget {
  const _PremiumHeroCard({
    required this.totalWealthEgp,
    required this.netPositionEgp,
    required this.dues,
    required this.nisabMet,
    required this.hasMarketData,
    required this.hasFxData,
    required this.state,
    required this.market,
    required this.nextZakatDate,
  });

  final double totalWealthEgp;
  final double netPositionEgp;
  final _Dues dues;
  final bool nisabMet;
  final bool hasMarketData;
  final bool hasFxData;
  final dynamic state;
  final MarketData market;
  final String? nextZakatDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF073B3A), Color(0xFF0F766E)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.tr('total_wealth'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          _AnimatedAmountText(
            valueEgp: totalWealthEgp,
            hasMarketData: hasMarketData,
            mainCurrency: state.mainCurrency,
            marketData: market,
          ),
          const SizedBox(height: 14),
          Text(
            hasMarketData
                ? (nisabMet ? context.l10n.tr('above_nisab') : context.l10n.tr('below_nisab'))
                : (hasFxData ? context.l10n.tr('gold_silver_required') : context.l10n.tr('market_data_required')),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFFC8A75B),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          _HeroMetricLine(
            label: context.l10n.tr('net_position'),
            value: _DashboardScreenState._formatOrMissing(
              context,
              netPositionEgp,
              hasMarketData,
              state.mainCurrency,
              market,
            ),
          ),
          const SizedBox(height: 8),
          _HeroMetricLine(
            label: context.l10n.tr('total_upcoming_dues'),
            value: _DashboardScreenState._formatOrMissing(
              context,
              dues.totalUpcoming,
              hasMarketData,
              state.mainCurrency,
              market,
            ),
          ),
          if (nextZakatDate != null) ...<Widget>[
            const SizedBox(height: 8),
            _HeroMetricLine(label: context.l10n.tr('next_zakat_date'), value: nextZakatDate!),
          ],
        ],
      ),
    );
  }
}

class _HeroMetricLine extends StatelessWidget {
  const _HeroMetricLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _AnimatedAmountText extends StatelessWidget {
  const _AnimatedAmountText({
    required this.valueEgp,
    required this.hasMarketData,
    required this.mainCurrency,
    required this.marketData,
  });

  final double valueEgp;
  final bool hasMarketData;
  final String mainCurrency;
  final MarketData marketData;

  @override
  Widget build(BuildContext context) {
    if (!hasMarketData) {
      return Text(
        context.l10n.tr('market_data_required'),
        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
      );
    }
    final String currency = mainCurrency.trim().isEmpty ? 'EGP' : mainCurrency.trim();
    final double displayValue = ZakatEngineService.convertFromEgp(valueEgp, currency, marketData);
    if (displayValue.isNaN) {
      return Text(
        context.l10n.tr('market_data_required'),
        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: displayValue),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, double value, Widget? child) {
        return Text(
          _DashboardScreenState._formatDisplay(value, currency),
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
        );
      },
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.onOpenAddActions,
    required this.onOpenZakatSchedule,
  });

  final VoidCallback? onOpenAddActions;
  final VoidCallback? onOpenZakatSchedule;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(title: context.l10n.tr('quick_actions'), bottomSpacing: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: _ActionTile(
                icon: Icons.south_west_rounded,
                label: context.l10n.tr('expense'),
                onTap: onOpenAddActions,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: Icons.north_east_rounded,
                label: context.l10n.tr('income'),
                onTap: onOpenAddActions,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: Icons.account_balance_wallet_rounded,
                label: context.l10n.tr('assets'),
                onTap: onOpenAddActions,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: Icons.mosque_rounded,
                label: context.l10n.tr('zakat_summary'),
                onTap: onOpenZakatSchedule,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF0F1720) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: dark ? const Color(0xFF1F2A37) : const Color(0xFFDCE4DF)),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, color: const Color(0xFF0F766E), size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumSection extends StatelessWidget {
  const _PremiumSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.onTap,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Widget body = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0F1720) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dark ? const Color(0xFF1F2A37) : const Color(0xFFDCE4DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: dark ? Colors.white : const Color(0xFF111827),
                      ),
                ),
              ),
              if (trailing case final Widget t) t,
              if (onTap != null && trailing == null)
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF0F766E)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );

    if (onTap == null) return body;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: body,
    );
  }
}

class _InsightPanel extends StatelessWidget {
  const _InsightPanel({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1A222E) : const Color(0xFFFFFBF1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? const Color(0xFF2B3441) : const Color(0xFFE8DFC3)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.workspace_premium_rounded, color: Color(0xFFC8A75B), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: dark ? const Color(0xFF273241) : const Color(0xFFE7E7E7), width: 1)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: dark ? const Color(0xFFA8B0BD) : const Color(0xFF4B5563),
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: valueColor ?? (dark ? Colors.white : const Color(0xFF111827)),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniZakatJourney extends StatelessWidget {
  const _MiniZakatJourney({required this.isMet, required this.hasMarketData});

  final bool isMet;
  final bool hasMarketData;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final String text = hasMarketData
        ? (isMet ? context.l10n.tr('above_nisab') : context.l10n.tr('below_nisab'))
        : context.l10n.tr('market_data_required');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: dark ? const Color(0xFF18242B) : const Color(0xFFF4F7F6),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isMet ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
            size: 18,
            color: const Color(0xFF0F766E),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _AllocationRing extends StatelessWidget {
  const _AllocationRing({required this.allocation});

  final _Allocation allocation;

  @override
  Widget build(BuildContext context) {
    final List<_AllocSeg> segs = <_AllocSeg>[
      _AllocSeg(_safePct(allocation.cashPct), const Color(0xFF0F766E), context.l10n.tr('cash_pct')),
      _AllocSeg(_safePct(allocation.metalsPct), const Color(0xFFC8A75B), context.l10n.tr('metals_pct')),
      _AllocSeg(_safePct(allocation.propertyPct), const Color(0xFF456E85), context.l10n.tr('property_pct')),
      _AllocSeg(_safePct(allocation.companyPct), const Color(0xFF6B5A95), context.l10n.tr('company_pct')),
    ];

    return Column(
      children: <Widget>[
        SizedBox(
          height: 150,
          width: 150,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, double value, Widget? child) {
              return CustomPaint(
                painter: _RingPainter(segs: segs, progress: value),
                child: child,
              );
            },
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 12),
        ...segs.map(
          (_AllocSeg seg) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: seg.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(seg.label)),
                Text(_DashboardScreenState._formatPct(seg.value), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static double _safePct(double value) {
    if (value.isNaN || value.isInfinite || value < 0) return 0;
    return value;
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.segs, required this.progress});

  final List<_AllocSeg> segs;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final double stroke = 16;
    final Rect rect = Offset.zero & size;
    final Paint bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFF344153);
    canvas.drawArc(rect.deflate(stroke / 2), 0, 6.28318, false, bg);

    double start = -1.5708;
    for (final _AllocSeg seg in segs) {
      final double sweep = (seg.value / 100) * 6.28318 * progress;
      if (sweep <= 0) continue;
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..color = seg.color;
      canvas.drawArc(rect.deflate(stroke / 2), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.segs != segs;
  }
}

class _AllocSeg {
  const _AllocSeg(this.value, this.color, this.label);

  final double value;
  final Color color;
  final String label;
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.tx});

  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    final bool isExpense = tx.type == 'expense';
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: Key('dashboardRecentTx_${tx.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF111925) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dark ? const Color(0xFF253243) : const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isExpense ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isExpense ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: isExpense ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  tx.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(tx.date, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            '${isExpense ? '-' : '+'}${tx.amount.toStringAsFixed(2)} ${tx.currency}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isExpense ? const Color(0xFFB91C1C) : const Color(0xFF047857),
                ),
          ),
        ],
      ),
    );
  }
}

class _Dues {
  const _Dues({required this.thisMonth, required this.nextMonth, required this.totalUpcoming});

  final double thisMonth;
  final double nextMonth;
  final double totalUpcoming;
}

class _Allocation {
  const _Allocation({
    required this.cashPct,
    required this.metalsPct,
    required this.propertyPct,
    required this.companyPct,
  });

  final double cashPct;
  final double metalsPct;
  final double propertyPct;
  final double companyPct;
}
