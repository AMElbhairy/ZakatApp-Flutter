import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/zakat_schedule_service.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/theme/app_radii.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/app_state.dart';
import '../../models/investment_asset.dart';
import '../../models/market_snapshot.dart';
import '../../models/saving.dart';
import '../../models/transaction.dart';
import '../../services/app_state_controller.dart';
import '../../services/auth_controller.dart';
import 'obligations_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.onViewAllActivity,
    this.onOpenAddActions,
    this.onOpenZakatSchedule,
    this.onOpenAddTransaction,
    this.onOpenAddAsset,
    this.onViewAssets,
  });

  final VoidCallback? onViewAllActivity;
  final VoidCallback? onOpenAddActions;
  final VoidCallback? onOpenZakatSchedule;
  final ValueChanged<String>? onOpenAddTransaction;
  final VoidCallback? onOpenAddAsset;
  final VoidCallback? onViewAssets;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _animateIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _animateIn = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final authController = context.watch<AuthController>();
    final user = authController.currentUser;
    final String? firstName = _extractFirstName(user?.name);
    final state = controller.state;
    final transactions = state.transactions;
    final savings = state.savings;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
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

    NisabTotals savingsTotals = const NisabTotals(
      totalCashEgp: 0,
      totalGold24k: 0,
      totalGoldEgp: 0,
      totalSilverGrams: 0,
      totalSilverEgp: 0,
      totalSavingsWealthEgp: 0,
    );
    double totalWealthEgp = 0;
    double totalLiabilitiesEgp = 0;
    double netPositionEgp = 0;
    double nisabThreshold = 0;
    bool nisabMet = false;

    if (hasMarketData) {
      savingsTotals = ZakatEngineService.computeNisabTotals(
        savings: savings,
        marketData: market,
      );
      totalWealthEgp = ZakatEngineService.calculateTotalWealthEgp(
        transactions: transactions,
        savings: savings,
        investments: investments,
        marketData: market,
        lastRollover: state.lastRollover,
      );

      totalLiabilitiesEgp = ZakatEngineService.calculateTotalLiabilitiesEgp(
        transactions: transactions,
        savings: savings,
        investments: investments,
        marketData: market,
        lastRollover: state.lastRollover,
      );
      netPositionEgp = totalWealthEgp - totalLiabilitiesEgp;

      nisabThreshold = ZakatEngineService.cashNisabThresholdEgp(
        market,
        zakatNisabBasis: state.zakatNisabBasis,
      );
      nisabMet = ZakatEngineService.checkCashNisab(
        totalWealthEgp,
        market,
        zakatNisabBasis: state.zakatNisabBasis,
      );
    }

    final List<Map<String, dynamic>> schedule = hasMarketData
        ? _buildSchedule(
            zakatMethod: state.zakatMethod,
            zakatAnnualDate: state.zakatAnnualDate,
            transactions: transactions,
            savings: savings,
            investments: investments,
            marketData: market,
            lastRollover: state.lastRollover,
            zakatNisabBasis: state.zakatNisabBasis,
          )
        : const <Map<String, dynamic>>[];
    final _Dues dues = _computeDues(
      schedule: schedule,
      zakatPaidMonths: state.zakatPaidMonths,
      investments: investments,
      marketData: market,
    );
    final String? nextZakatDate = _findNextZakatDate(schedule);

    final double cashWealthEgp = hasFxData
        ? ZakatEngineService.calculateTotalCashWealthEgp(
            transactions: transactions,
            savings: savings,
            marketData: market,
            lastRollover: state.lastRollover,
          )
        : 0.0;

    final _Allocation allocation = _computeAllocation(
      savingsTotals: savingsTotals,
      investments: investments,
      marketData: market,
      totalWealthEgp: totalWealthEgp,
      cashWealthEgp: cashWealthEgp,
    );
    final bool balancesHidden = _isBalanceHidden(state);
    final _HeroGrowthData? heroGrowth = _computeHeroGrowth(
      transactions: transactions,
      savings: savings,
      investments: investments,
      marketData: market,
      marketHistory: state.marketHistory,
      totalWealthEgp: totalWealthEgp,
      hasMarketData: hasMarketData,
      lastRollover: state.lastRollover,
    );

    final List<_DashboardActivityEntry> recent =
        <_DashboardActivityEntry>[
          ...transactions.map(_DashboardActivityEntry.transaction),
          ...savings
              .where(
                (Saving saving) =>
                    ZakatEngineService.normaliseAssetType(saving.assetType) ==
                    'cash',
              )
              .map(_DashboardActivityEntry.cashSaving),
        ]..sort((_DashboardActivityEntry a, _DashboardActivityEntry b) {
          final int byDate = _parseDate(b.date).compareTo(_parseDate(a.date));
          if (byDate != 0) return byDate;
          return b.createdAt.compareTo(a.createdAt);
        });
    final List<_DashboardActivityEntry> recent4 = recent
        .take(4)
        .toList(growable: false);

    final bool hasAnyData =
        transactions.isNotEmpty || savings.isNotEmpty || investments.isNotEmpty;

    final tokens = context.premiumTokens;
    final double navSafeBottomPadding =
        112 + MediaQuery.paddingOf(context).bottom;
    return Container(
      color: tokens.colors.background,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 20, 16, navSafeBottomPadding),
        children: <Widget>[
          _DashboardHeader(
            title: context.l10n.tr('dashboard'),
            firstName: firstName,
            balancesHidden: balancesHidden,
            onTogglePrivacy: () => controller.togglePrivacyMode(),
            hasNotifications:
                false, // You can update this based on actual state if available
            onTapNotifications: () {}, // No-op for now
          ),
          const SizedBox(height: 18),
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
                balancesHidden: balancesHidden,
                heroGrowth: heroGrowth,
              ),
            ),
            const SizedBox(height: 16),
            _stagger(
              order: 1,
              child: _QuickActionsRow(
                onOpenAddTransaction: widget.onOpenAddTransaction,
                onOpenAddAsset: widget.onOpenAddAsset,
                onOpenZakatSchedule: widget.onOpenZakatSchedule,
              ),
            ),
            const SizedBox(height: 16),
            _stagger(
              order: 2,
              child: _PremiumSection(
                title: context.l10n.tr('asset_allocation'),
                trailing: TextButton(
                  key: const Key('dashboardViewAssetAllocationDetailsButton'),
                  onPressed: widget.onViewAssets,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: const Color(0xFF0F766E),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        context.l10n.tr('view_details'),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 11),
                    ],
                  ),
                ),
                child: _AllocationRing(
                  allocation: allocation,
                  hasMarketData: hasMarketData,
                  mainCurrency: state.mainCurrency,
                  market: market,
                  balancesHidden: balancesHidden,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _stagger(
              order: 3,
              child: _NisabStatusCard(
                nisabThreshold: nisabThreshold,
                nisabMet: nisabMet,
                hasMarketData: hasMarketData,
                hasFxData: hasFxData,
                hasMetalsData: hasMetalsData,
                mainCurrency: state.mainCurrency,
                market: market,
                zakatAnnualDate: state.zakatAnnualDate,
                transactions: transactions,
                savings: savings,
              ),
            ),
            const SizedBox(height: 16),
            _stagger(
              order: 4,
              child: _PremiumSection(
                key: const Key('dashboardUpcomingObligationsCard'),
                title: context.l10n.tr('upcoming_obligations'),
                padding: const EdgeInsets.only(top: 10, bottom: 10, left: 16, right: 16),
                spacing: 9,
                child: Row(
                  children: <Widget>[
                    _ObligationColumn(
                      title: context.l10n.tr('this_month'),
                      value: balancesHidden
                          ? '••••••'
                          : _formatOrMissing(
                              context,
                              dues.thisMonth,
                              hasMarketData,
                              state.mainCurrency,
                              market,
                              compact: true,
                            ),
                      icon: Icons.calendar_today_outlined,
                      iconColor: const Color(0xFF10B981),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ObligationsListScreen(
                              filterMode: 'this_month',
                            ),
                          ),
                        );
                      },
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: const Color(0xFFC5A059).withValues(alpha: 0.35),
                    ),
                    _ObligationColumn(
                      title: context.l10n.tr('next_month'),
                      value: balancesHidden
                          ? '••••••'
                          : _formatOrMissing(
                              context,
                              dues.nextMonth,
                              hasMarketData,
                              state.mainCurrency,
                              market,
                              compact: true,
                            ),
                      icon: Icons.calendar_month_outlined,
                      iconColor: const Color(0xFFD97706),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ObligationsListScreen(
                              filterMode: 'next_month',
                            ),
                          ),
                        );
                      },
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: const Color(0xFFC5A059).withValues(alpha: 0.35),
                    ),
                    _ObligationColumn(
                      title: context.l10n.tr('total'),
                      value: balancesHidden
                          ? '••••••'
                          : _formatOrMissing(
                              context,
                              dues.totalUpcoming,
                              hasMarketData,
                              state.mainCurrency,
                              market,
                              compact: true,
                            ),
                      icon: Icons.date_range_outlined,
                      iconColor: const Color(0xFF8B5CF6),
                      isTotal: true,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ObligationsListScreen(
                              filterMode: 'total',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _stagger(
              order: 5,
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
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: const Color(0xFF6B7280)),
                        ),
                      )
                    else
                      ...recent4.asMap().entries.map(
                        (MapEntry<int, _DashboardActivityEntry> item) {
                          final int index = item.key;
                          final _DashboardActivityEntry entry = item.value;
                          final bool isLast = index == recent4.length - 1;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              _ActivityRow(
                                entry: entry,
                                balancesHidden: balancesHidden,
                              ),
                              if (!isLast)
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: dark
                                      ? tokens.colors.divider
                                      : const Color(0xFFE8E8E8),
                                ),
                            ],
                          );
                        },
                      ),
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
    return _KeepAliveWrapper(
      child: TweenAnimationBuilder<double>(
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
      ),
    );
  }

  static List<Map<String, dynamic>> _buildSchedule({
    required String zakatMethod,
    required String zakatAnnualDate,
    required List<Transaction> transactions,
    required List<Saving> savings,
    required List<InvestmentAsset> investments,
    required MarketData marketData,
    String? lastRollover,
    String? zakatNisabBasis,
  }) {
    if (zakatMethod == 'annual') {
      return ZakatScheduleService.calculateAnnualZakatSchedule(
        zakatAnnualDate: zakatAnnualDate,
        transactions: transactions
            .map((e) => e.toJson())
            .toList(growable: false),
        savings: savings.map((e) => e.toJson()).toList(growable: false),
        investments: investments.map((e) => e.toJson()).toList(growable: false),
        marketData: marketData,
        lastRollover: lastRollover,
        zakatNisabBasis: zakatNisabBasis,
      );
    }

    final List<Map<String, dynamic>> transactionJson = transactions
        .map((e) => e.toJson())
        .toList(growable: false);
    final List<Map<String, dynamic>> savingsJson = savings
        .map((e) => e.toJson())
        .toList(growable: false);

    final List<Map<String, dynamic>> incomeSchedule =
        ZakatScheduleService.calculateMonthlyZakatSchedule(
          transactions: transactionJson,
          savings: savingsJson,
          marketData: marketData,
          lastRollover: lastRollover,
          zakatNisabBasis: zakatNisabBasis,
        );
    final List<Map<String, dynamic>> savingsSchedule =
        ZakatScheduleService.calculateSavingsZakatSchedule(
          savings: savingsJson,
          transactions: transactionJson,
          marketData: marketData,
          lastRollover: lastRollover,
          zakatNisabBasis: zakatNisabBasis,
        );

    return <Map<String, dynamic>>[...incomeSchedule, ...savingsSchedule];
  }

  static _Dues _computeDues({
    required List<Map<String, dynamic>> schedule,
    required List<String> zakatPaidMonths,
    required List<InvestmentAsset> investments,
    required MarketData marketData,
  }) {
    final DateTime now = DateTime.now();
    final String thisMonthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final DateTime nextMonthDate = DateTime(now.year, now.month + 1, 1);
    final String nextMonthKey =
        '${nextMonthDate.year}-${nextMonthDate.month.toString().padLeft(2, '0')}';

    double thisMonth = 0;
    double nextMonth = 0;

    // 1. Zakat dues from the schedule (excluding paid months)
    for (final item in schedule) {
      final String monthKey = (item['monthKey'] ?? '').toString();
      final String paymentDateRaw = (item['paymentDate'] ?? '').toString();
      final DateTime? paymentDate = DateTime.tryParse(paymentDateRaw);
      final String scheduleMonthKey = paymentDate == null
          ? monthKey.length >= 7
                ? monthKey.substring(0, 7)
                : monthKey
          : '${paymentDate.year}-${paymentDate.month.toString().padLeft(2, '0')}';
      final double value = ((item['totalZakat'] ?? 0) as num).toDouble();
      if (scheduleMonthKey == thisMonthKey) {
        if (!zakatPaidMonths.contains(monthKey)) {
          thisMonth += value;
        }
      } else if (scheduleMonthKey == nextMonthKey) {
        if (!zakatPaidMonths.contains(monthKey)) {
          nextMonth += value;
        }
      }
    }

    // 2. Unpaid installments
    for (final asset in investments) {
      for (final installment in asset.installmentPlan) {
        final bool isPaid = installment['isPaid'] == true;
        if (isPaid) continue;

        final String rawDate = InvestmentAsset.installmentDueDate(installment);
        final DateTime? parsedDate = DateTime.tryParse(rawDate);
        if (parsedDate == null) continue;

        final String installmentMonthKey =
            '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}';

        final double amount =
            (installment['amount'] as num?)?.toDouble() ?? 0.0;
        final String currency = (installment['currency'] ?? asset.currency)
            .toString();
        final double amountEgp = ZakatEngineService.convertToEgp(
          amount,
          currency,
          marketData,
        );

        if (installmentMonthKey == thisMonthKey) {
          thisMonth += amountEgp;
        } else if (installmentMonthKey == nextMonthKey) {
          nextMonth += amountEgp;
        }
      }
    }

    return _Dues(
      thisMonth: thisMonth,
      nextMonth: nextMonth,
      totalUpcoming: thisMonth + nextMonth,
    );
  }

  static _Allocation _computeAllocation({
    required NisabTotals savingsTotals,
    required List<InvestmentAsset> investments,
    required MarketData marketData,
    required double totalWealthEgp,
    required double cashWealthEgp,
  }) {
    if (totalWealthEgp <= 0 ||
        totalWealthEgp.isNaN ||
        totalWealthEgp.isInfinite) {
      return const _Allocation(
        cashPct: 0,
        metalsPct: 0,
        propertyPct: 0,
        companyPct: 0,
        cashVal: 0,
        metalsVal: 0,
        propertyVal: 0,
        companyVal: 0,
        totalVal: 0,
      );
    }

    final double cash = cashWealthEgp;
    final double metals =
        savingsTotals.totalGoldEgp + savingsTotals.totalSilverEgp;

    double property = 0;
    double company = 0;
    for (final asset in investments) {
      final double value =
          ZakatEngineService.calculateInvestmentEstimatedValueEgp(
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
      cashVal: cash,
      metalsVal: metals,
      propertyVal: property,
      companyVal: company,
      totalVal: totalWealthEgp,
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

  static bool _isArabic(BuildContext context) {
    return Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
  }

  static String _formatDisplay(
    BuildContext context,
    double value,
    String currencyCode,
  ) {
    return ZakatEngineService.formatCurrency(
      value,
      currencyCode,
      isArabic: _isArabic(context),
    );
  }

  static String _formatCompactDisplay(
    BuildContext context,
    double value,
    String currencyCode,
  ) {
    return ZakatEngineService.formatCurrency(
      value,
      currencyCode,
      isArabic: _isArabic(context),
      compact: true,
    );
  }

  static String _formatOrMissing(
    BuildContext context,
    double valueEgp,
    bool hasMarketData,
    String mainCurrency,
    MarketData marketData, {
    bool compact = false,
  }) {
    if (!hasMarketData) return context.l10n.tr('market_data_required');
    final String displayCurrency = mainCurrency.trim().isEmpty
        ? 'EGP'
        : mainCurrency.trim();
    final double displayValue = ZakatEngineService.convertFromEgp(
      valueEgp,
      displayCurrency,
      marketData,
    );
    if (displayValue.isNaN) return context.l10n.tr('market_data_required');
    return compact
        ? _formatCompactDisplay(context, displayValue, displayCurrency)
        : _formatDisplay(context, displayValue, displayCurrency);
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
      if (parsed.isBefore(DateTime(today.year, today.month, today.day))) {
        continue;
      }
      if (best == null || parsed.isBefore(best)) {
        best = parsed;
      }
    }
    if (best == null) return null;
    return DateFormat('dd MMM yyyy', 'en_US').format(best);
  }

  static DateTime _parseDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  static bool _isBalanceHidden(AppStateModel state) {
    final Map<String, dynamic> json = state.toJson();
    final Map<String, dynamic> aiSettings = Map<String, dynamic>.from(
      state.aiSettings ?? const <String, dynamic>{},
    );
    const List<String> keys = <String>[
      'hideBalances',
      'balancesHidden',
      'balanceHidden',
      'isBalanceHidden',
      'privacyMode',
    ];
    for (final String key in keys) {
      final dynamic value = json[key];
      final dynamic aiValue = aiSettings[key];
      if (_truthy(value) || _truthy(aiValue)) {
        return true;
      }
    }
    return false;
  }

  static bool _truthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final String raw = (value ?? '').toString().trim().toLowerCase();
    return raw == 'true' || raw == '1';
  }

  static String? _extractFirstName(String? name) {
    final String trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return null;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  static _HeroGrowthData? _computeHeroGrowth({
    required List<Transaction> transactions,
    required List<Saving> savings,
    required List<InvestmentAsset> investments,
    required MarketData marketData,
    required List<Map<String, dynamic>> marketHistory,
    required double totalWealthEgp,
    required bool hasMarketData,
    String? lastRollover,
  }) {
    final DateTime now = DateTime.now();
    if (!hasMarketData || totalWealthEgp < 0 || !totalWealthEgp.isFinite) {
      return null;
    }

    final DateTime startOfYear = DateTime(now.year, 1, 1);
    final double startOfYearWealth =
        ZakatEngineService.calculateTotalWealthEgpAt(
          asOf: startOfYear,
          transactions: transactions,
          savings: savings,
          investments: investments,
          marketData: marketData,
          lastRollover: lastRollover,
        );
    if (startOfYearWealth <= 0 || !startOfYearWealth.isFinite) return null;

    final double changePct =
        ((totalWealthEgp - startOfYearWealth) / startOfYearWealth) * 100;
    if (!changePct.isFinite) return null;

    final List<_WealthHistoryPoint> realHistory = <_WealthHistoryPoint>[];
    for (final Map<String, dynamic> item in marketHistory) {
      final dynamic rawWealth =
          item['totalWealthEgp'] ??
          item['wealthEgp'] ??
          item['total_wealth_egp'];
      final double? wealth = _asDouble(rawWealth);
      if (wealth == null || wealth <= 0) continue;

      final String rawDate =
          (item['recordedAt'] ??
                  item['timestamp'] ??
                  item['updatedAt'] ??
                  item['date'] ??
                  item['LAST_UPDATED'] ??
                  '')
              .toString();
      final DateTime? recordedAt = DateTime.tryParse(rawDate);
      if (recordedAt == null) continue;
      if (recordedAt.isBefore(startOfYear)) continue;

      realHistory.add(_WealthHistoryPoint(recordedAt.toLocal(), wealth));
    }

    final List<double> sparklinePoints = realHistory.length >= 2
        ? (realHistory..sort((a, b) => a.at.compareTo(b.at)))
              .map((point) => point.value)
              .toList(growable: false)
        : _buildMonthlyWealthPoints(
            startOfYear: startOfYear,
            now: now,
            transactions: transactions,
            savings: savings,
            investments: investments,
            marketData: marketData,
            lastRollover: lastRollover,
          );

    return _HeroGrowthData(changePct: changePct, points: sparklinePoints);
  }

  static List<double> _buildMonthlyWealthPoints({
    required DateTime startOfYear,
    required DateTime now,
    required List<Transaction> transactions,
    required List<Saving> savings,
    required List<InvestmentAsset> investments,
    required MarketData marketData,
    String? lastRollover,
  }) {
    final List<double> points = <double>[];
    DateTime cursor = DateTime(startOfYear.year, startOfYear.month, 1);
    while (!cursor.isAfter(now)) {
      final DateTime monthEnd = DateTime(cursor.year, cursor.month + 1, 0);
      final DateTime asOf = monthEnd.isAfter(now) ? now : monthEnd;
      final double value = ZakatEngineService.calculateTotalWealthEgpAt(
        asOf: asOf,
        transactions: transactions,
        savings: savings,
        investments: investments,
        marketData: marketData,
        lastRollover: lastRollover,
      );
      if (value.isFinite && value > 0) {
        points.add(value);
      }
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return points.length >= 2 ? points : const <double>[];
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString());
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.title,
    this.firstName,
    required this.balancesHidden,
    required this.onTogglePrivacy,
    required this.hasNotifications,
    required this.onTapNotifications,
  });

  final String title;
  final String? firstName;
  final bool balancesHidden;
  final VoidCallback onTogglePrivacy;
  final bool hasNotifications;
  final VoidCallback onTapNotifications;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final textTheme = Theme.of(context).textTheme;
    final String languageCode = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase();

    final String greetingBase = languageCode == 'ar'
        ? 'السلام عليكم'
        : 'Assalamu alaikum';
    final String greetingText =
        firstName != null && firstName!.trim().isNotEmpty
        ? (languageCode == 'ar'
              ? '$greetingBase، $firstName'
              : '$greetingBase, $firstName')
        : greetingBase;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: textTheme.headlineMedium?.copyWith(
                  color: tokens.colors.textPrimary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  _RubElHizbIcon(color: tokens.colors.gold, size: 14),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      greetingText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge?.copyWith(
                        color: tokens.colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
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
    required this.balancesHidden,
    required this.heroGrowth,
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
  final bool balancesHidden;
  final _HeroGrowthData? heroGrowth;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;
    final Alignment gradientBegin = isRtl
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final Alignment gradientEnd = isRtl
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final String nisabLabel = hasMarketData
        ? (nisabMet
              ? context.l10n.tr('above_nisab')
              : context.l10n.tr('below_nisab'))
        : (hasFxData
              ? context.l10n.tr('gold_silver_required')
              : context.l10n.tr('market_data_required'));
    final String hiddenValue = '••••••';
    final bool showGrowth = heroGrowth != null && !balancesHidden;

    final List<_HeroSupportItem> supportItems = <_HeroSupportItem>[
      _HeroSupportItem(
        label: context.l10n.tr('net_position').toUpperCase(),
        icon: Icons.verified_user_outlined,
        value: balancesHidden
            ? hiddenValue
            : _DashboardScreenState._formatOrMissing(
                context,
                netPositionEgp,
                hasMarketData,
                state.mainCurrency,
                market,
              ),
      ),
      _HeroSupportItem(
        label: context.l10n.tr('upcoming_dues').toUpperCase(),
        icon: Icons.calendar_today_outlined,
        value: balancesHidden
            ? hiddenValue
            : _DashboardScreenState._formatOrMissing(
                context,
                dues.totalUpcoming,
                hasMarketData,
                state.mainCurrency,
                market,
              ),
      ),
    ];

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color borderColor = isDark
        ? const Color(0xFFFFC928).withValues(alpha: 0.45)
        : const Color(0xFFC5A059).withValues(alpha: 0.65);

    return PremiumCard(
      key: const Key('dashboardHeroCard'),
      hero: true,
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 380;
          final bool tablet = constraints.maxWidth >= 700;
          final double heroHeight = tablet ? 284 : (compact ? 249 : 264);
          final double artworkWidth =
              constraints.maxWidth * (tablet ? 0.44 : 0.51);

          return SizedBox(
            height: heroHeight,
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
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        PositionedDirectional(
                          top: 0,
                          start: 0,
                          end: 0,
                          bottom: 0,
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
                        PositionedDirectional(
                          top: 8,
                          end: 0,
                          bottom: 8,
                          width: artworkWidth,
                          child: IgnorePointer(
                            child: _HeroArtwork(width: artworkWidth),
                          ),
                        ),
                        PositionedDirectional(
                          start: 22,
                          top: 19,
                          end: artworkWidth + 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    context.l10n
                                        .tr('total_wealth')
                                        .toUpperCase(),
                                    style: textTheme.titleSmall?.copyWith(
                                      color: const Color(0xFFFFC928),
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              FractionallySizedBox(
                                widthFactor: compact ? 1.0 : 0.96,
                                alignment: AlignmentDirectional.centerStart,
                                child: _AnimatedAmountText(
                                  valueEgp: totalWealthEgp,
                                  hasMarketData: hasMarketData,
                                  mainCurrency: state.mainCurrency,
                                  marketData: market,
                                  hidden: balancesHidden,
                                ),
                              ),
                              if (showGrowth) ...<Widget>[
                                const SizedBox(height: 8),
                                _HeroGrowthRow(growth: heroGrowth!),
                              ],
                              const SizedBox(height: 11),
                              _HeroStatusPanel(
                                label: nisabLabel,
                                subtitle: hasMarketData
                                    ? (nisabMet
                                          ? context.l10n.tr('zakat_applicable')
                                          : context.l10n.tr('no_zakat_due'))
                                    : null,
                              ),
                              if (nextZakatDate != null && !balancesHidden) ...[
                                const SizedBox(height: 8),
                                _HeroNextZakatBadge(date: nextZakatDate!),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _HeroMetricsBar(items: supportItems),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroSupportItem {
  const _HeroSupportItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _HeroGrowthData {
  const _HeroGrowthData({required this.changePct, required this.points});

  final double changePct;
  final List<double> points;
}

class _WealthHistoryPoint {
  const _WealthHistoryPoint(this.at, this.value);

  final DateTime at;
  final double value;
}

class _HeroArtwork extends StatelessWidget {
  const _HeroArtwork({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Opacity(
        opacity: 0.94,
        child: Image.asset(
          'assets/images/hero_mosque_watermark.png',
          fit: BoxFit.contain,
          alignment: AlignmentDirectional.centerEnd,
        ),
      ),
    );
  }
}

class _AnimatedAmountText extends StatelessWidget {
  const _AnimatedAmountText({
    required this.valueEgp,
    required this.hasMarketData,
    required this.mainCurrency,
    required this.marketData,
    required this.hidden,
  });

  final double valueEgp;
  final bool hasMarketData;
  final String mainCurrency;
  final MarketData marketData;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    if (!hasMarketData) {
      return Text(
        context.l10n.tr('market_data_required'),
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: Colors.white),
      );
    }
    final String currency = mainCurrency.trim().isEmpty
        ? 'EGP'
        : mainCurrency.trim();
    final double displayValue = ZakatEngineService.convertFromEgp(
      valueEgp,
      currency,
      marketData,
    );
    if (displayValue.isNaN) {
      return Text(
        context.l10n.tr('market_data_required'),
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: Colors.white),
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        hidden
            ? '••••••'
            : _DashboardScreenState._formatCompactDisplay(
                context,
                displayValue,
                currency,
              ),
        maxLines: 1,
        style: Theme.of(context).textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: hidden ? 0 : -0.5,
        ),
      ),
    );
  }
}

class _HeroSupportMetric extends StatelessWidget {
  const _HeroSupportMetric({required this.item});

  final _HeroSupportItem item;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = item.icon == Icons.calendar_today_outlined
        ? const Color(0xFFFFC928)
        : const Color(0xFF21D99B);
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: 16.0,
        end: 2.0,
        top: 8.0,
        bottom: 8.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(item.icon, size: 20, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w700,
                      fontSize: 9.0,
                      letterSpacing: 0,
                      height: 1.05,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    item.value,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
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

class _HeroGrowthRow extends StatelessWidget {
  const _HeroGrowthRow({required this.growth});

  final _HeroGrowthData growth;

  @override
  Widget build(BuildContext context) {
    final bool isPositive = growth.changePct >= 0;
    final tokens = context.premiumTokens;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isPositive
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: 14,
            color: isPositive ? const Color(0xFF21D99B) : tokens.colors.danger,
          ),
          const SizedBox(width: 6),
          Text.rich(
            TextSpan(
              children: <TextSpan>[
                TextSpan(
                  text:
                      '${_DashboardScreenState._formatPct(growth.changePct.abs())} ',
                  style: TextStyle(
                    color: isPositive
                        ? const Color(0xFF21D99B)
                        : tokens.colors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: context.l10n.tr('this_year'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (growth.points.length >= 2) ...<Widget>[
            const SizedBox(width: 10),
            SizedBox(
              width: 55,
              height: 14,
              child: _HeroSparkline(points: growth.points),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroSparkline extends StatelessWidget {
  const _HeroSparkline({required this.points});

  final List<double> points;

  @override
  Widget build(BuildContext context) {
    final double min = points.reduce((a, b) => a < b ? a : b);
    final double max = points.reduce((a, b) => a > b ? a : b);
    final double spread = (max - min).abs();
    final List<Offset> offsets = <Offset>[];

    for (int i = 0; i < points.length; i++) {
      final double x = points.length == 1 ? 0 : i / (points.length - 1);
      final double normalizedY = spread == 0
          ? 0.5
          : ((points[i] - min) / spread);
      offsets.add(Offset(x, 1 - normalizedY));
    }

    return CustomPaint(
      painter: _HeroSparklinePainter(
        points: offsets,
        color: const Color(0xFF21D99B),
      ),
    );
  }
}

class _HeroSparklinePainter extends CustomPainter {
  const _HeroSparklinePainter({required this.points, required this.color});

  final List<Offset> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final Path path = Path();

    for (int i = 0; i < points.length; i++) {
      final Offset point = Offset(
        points[i].dx * size.width,
        points[i].dy * size.height,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeroSparklinePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}

class _RubElHizbIcon extends StatelessWidget {
  const _RubElHizbIcon({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Transform.rotate(
            angle: 0,
            child: Container(
              width: size * 0.76,
              height: size * 0.76,
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 1.1),
              ),
            ),
          ),
          Transform.rotate(
            angle: 3.14159 / 4,
            child: Container(
              width: size * 0.76,
              height: size * 0.76,
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 1.1),
              ),
            ),
          ),
          Container(
            width: size * 0.44,
            height: size * 0.44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.1),
            ),
          ),
          Container(
            width: size * 0.16,
            height: size * 0.16,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ],
      ),
    );
  }
}

class _HeroStatusPanel extends StatelessWidget {
  const _HeroStatusPanel({required this.label, this.subtitle});

  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: SizedBox(
        width: 145,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFC5A059).withValues(alpha: 0.35),
              width: 1.0,
            ),
            color: const Color(0xFF032F2A).withValues(alpha: 0.44),
          ),
          child: Row(
            children: <Widget>[
              const _RubElHizbIcon(color: Color(0xFFFFC928), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFFFFC928),
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: const Color(0xFFFFC928),
                              fontWeight: FontWeight.w600,
                              fontSize: 9.5,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroNextZakatBadge extends StatelessWidget {
  const _HeroNextZakatBadge({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.nightlight_round,
              color: Color(0xFF21D99B),
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              '${context.l10n.tr('next_zakat').toUpperCase()}: ',
              style: textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.54),
                fontWeight: FontWeight.w700,
                fontSize: 8.5,
                letterSpacing: 0.2,
              ),
            ),
            Text(
              date,
              style: textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 10.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetricsBar extends StatelessWidget {
  const _HeroMetricsBar({required this.items});

  final List<_HeroSupportItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            height: 1.0,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: List<Widget>.generate(items.length * 2 - 1, (int index) {
              if (index.isOdd) {
                return Container(
                  width: 1,
                  height: 42,
                  color: Colors.white.withValues(alpha: 0.1),
                );
              }

              final _HeroSupportItem item = items[index ~/ 2];
              return Expanded(child: _HeroSupportMetric(item: item));
            }),
          ),
        ),
      ],
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    this.onOpenAddTransaction,
    this.onOpenAddAsset,
    this.onOpenZakatSchedule,
  });

  final ValueChanged<String>? onOpenAddTransaction;
  final VoidCallback? onOpenAddAsset;
  final VoidCallback? onOpenZakatSchedule;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              context.l10n.tr('quick_actions'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 5),
            const Text(
              '✦',
              style: TextStyle(color: Color(0xFFD4AF37), fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: _ActionTile(
                icon: Icons.south_west_rounded,
                label: context.l10n.tr('expense'),
                iconColor: const Color(0xFF14B8A6),
                onTap: () => onOpenAddTransaction?.call('expense'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: Icons.north_east_rounded,
                label: context.l10n.tr('income'),
                iconColor: const Color(0xFF14B8A6),
                onTap: () => onOpenAddTransaction?.call('income'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: Icons.account_balance_wallet_rounded,
                label: context.l10n.tr('assets'),
                iconColor: const Color(0xFF14B8A6),
                onTap: onOpenAddAsset,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: Icons.mosque_rounded,
                label: context.l10n.tr('zakat'),
                iconColor: const Color(0xFFC5A059),
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
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final tokens = context.premiumTokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: BoxDecoration(
            color: dark ? tokens.colors.card : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: dark ? tokens.colors.divider : const Color(0xFFDCE4DF),
              width: 1.0,
            ),
            boxShadow: dark
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: dark ? Colors.white : const Color(0xFF0C2E26),
                ),
              ),
            ],
          ),
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
    this.padding,
    this.spacing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final tokens = context.premiumTokens;
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? tokens.colors.card : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dark ? tokens.colors.divider : const Color(0xFFDCE4DF),
        ),
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
            ],
          ),
          SizedBox(height: spacing ?? 12),
          child,
        ],
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  const _ShieldPainter({required this.fillColor, required this.borderColor});

  final Color fillColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final double w = size.width;
    final double h = size.height;

    final Path path = Path();
    path.moveTo(w * 0.15, 0);
    path.lineTo(w * 0.85, 0);
    path.quadraticBezierTo(w, 0, w, h * 0.15);
    path.lineTo(w, h * 0.45);
    path.quadraticBezierTo(w, h * 0.75, w * 0.5, h);
    path.quadraticBezierTo(0, h * 0.75, 0, h * 0.45);
    path.lineTo(0, h * 0.15);
    path.quadraticBezierTo(0, 0, w * 0.15, 0);
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ShieldPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor;
  }
}

class _NisabStatusCard extends StatelessWidget {
  const _NisabStatusCard({
    required this.nisabThreshold,
    required this.nisabMet,
    required this.hasMarketData,
    required this.hasFxData,
    required this.hasMetalsData,
    required this.mainCurrency,
    required this.market,
    required this.zakatAnnualDate,
    required this.transactions,
    required this.savings,
  });

  final double nisabThreshold;
  final bool nisabMet;
  final bool hasMarketData;
  final bool hasFxData;
  final bool hasMetalsData;
  final String mainCurrency;
  final MarketData market;
  final String zakatAnnualDate;
  final List<Transaction> transactions;
  final List<Saving> savings;

  static String _getHijriMonthName(int month, bool isArabic) {
    if (isArabic) {
      switch (month) {
        case 1:
          return 'محرم';
        case 2:
          return 'صفر';
        case 3:
          return 'ربيع الأول';
        case 4:
          return 'ربيع الآخر';
        case 5:
          return 'جمادى الأولى';
        case 6:
          return 'جمادى الآخرة';
        case 7:
          return 'رجب';
        case 8:
          return 'شعبان';
        case 9:
          return 'رمضان';
        case 10:
          return 'شوال';
        case 11:
          return 'ذو القعدة';
        case 12:
          return 'ذو الحجة';
        default:
          return '';
      }
    } else {
      switch (month) {
        case 1:
          return 'Muharram';
        case 2:
          return 'Safar';
        case 3:
          return 'Rabi\' al-Awwal';
        case 4:
          return 'Rabi\' al-Thani';
        case 5:
          return 'Jumada al-Awwal';
        case 6:
          return 'Jumada al-Thani';
        case 7:
          return 'Rajab';
        case 8:
          return 'Sha\'ban';
        case 9:
          return 'Ramadan';
        case 10:
          return 'Shawwal';
        case 11:
          return 'Dhu al-Qadah';
        case 12:
          return 'Dhu al-Hijjah';
        default:
          return '';
      }
    }
  }

  static String _formatNumber(int val, bool isArabic) {
    if (!isArabic) return val.toString();
    const Map<String, String> digits = {
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
    return val.toString().split('').map((char) => digits[char] ?? char).join();
  }

  static double _calculateWealthAt(
    String dateStr,
    List<Transaction> transactions,
    List<Saving> savings,
    MarketData marketData,
  ) {
    final Map<String, double> cashAmounts = {};
    for (final tx in transactions) {
      if (tx.date.compareTo(dateStr) <= 0) {
        final String cur = tx.currency;
        double val = 0;
        if (tx.type == 'income') {
          if (tx.rolledOver && tx.rolledAmount != null) {
            val = tx.amount - tx.rolledAmount!;
          } else {
            val = tx.amount;
          }
        } else if (tx.type == 'expense') {
          val = -tx.amount;
        }
        cashAmounts[cur] = (cashAmounts[cur] ?? 0) + val;
      }
    }

    for (final s in savings) {
      if (s.dateAcquired.compareTo(dateStr) <= 0 &&
          ZakatEngineService.normaliseAssetType(s.assetType) == 'cash') {
        final String cur = s.unit;
        cashAmounts[cur] = (cashAmounts[cur] ?? 0) + s.amount;
      }
    }

    double totalCashEgp = 0;
    cashAmounts.forEach((currency, amount) {
      if (amount > 0) {
        totalCashEgp += ZakatEngineService.convertToEgp(
          amount,
          currency,
          marketData,
        );
      }
    });

    double totalGold24k = 0;
    double totalSilverGrams = 0;
    for (final s in savings) {
      if (s.dateAcquired.compareTo(dateStr) <= 0) {
        final String type = ZakatEngineService.normaliseAssetType(s.assetType);
        if (type == 'gold') {
          totalGold24k += ZakatEngineService.convertToGold24k(s.amount, s.unit);
        } else if (type == 'silver') {
          totalSilverGrams += ZakatEngineService.convertToSilverGrams(s.amount);
        }
      }
    }

    final double goldEgp = totalGold24k * marketData.goldPrice24kEgp;
    final double silverEgp = totalSilverGrams * marketData.silverPriceEgp;

    return totalCashEgp + goldEgp + silverEgp;
  }

  static DateTime? _calculateCrossingDate(
    List<Transaction> transactions,
    List<Saving> savings,
    double nisabThreshold,
    MarketData market,
  ) {
    final Set<String> dateSet = {};
    for (final tx in transactions) {
      dateSet.add(tx.date);
    }
    for (final s in savings) {
      dateSet.add(s.dateAcquired);
    }
    final List<String> sortedDates = dateSet.toList()..sort();

    DateTime? crossingDate;
    for (int i = sortedDates.length - 1; i >= 0; i--) {
      final String d = sortedDates[i];
      final double wealth = _calculateWealthAt(
        d,
        transactions,
        savings,
        market,
      );
      if (wealth >= nisabThreshold) {
        crossingDate = DateTime.tryParse(d);
      } else {
        break;
      }
    }
    return crossingDate;
  }

  HijriDate _getAnniversaryHijriDateObject() {
    final DateTime today = DateTime.now();
    final HijriDate todayH = ZakatEngineService.gregorianToHijri(today);

    int hm = todayH.month;
    int hd = todayH.day;
    int hy = todayH.year;

    if (zakatAnnualDate.isNotEmpty && zakatAnnualDate.contains('-')) {
      final List<String> parts = zakatAnnualDate.split('-');
      final int? parsedMonth = int.tryParse(parts[0]);
      final int? parsedDay = int.tryParse(parts[1]);

      if (parsedMonth != null &&
          parsedDay != null &&
          parsedMonth >= 1 &&
          parsedMonth <= 12 &&
          parsedDay >= 1 &&
          parsedDay <= ZakatEngineService.hijriMonthLength(parsedMonth)) {
        hm = parsedMonth;
        hd = parsedDay;
        final bool hasPassed =
            todayH.month > hm || (todayH.month == hm && todayH.day >= hd);
        hy = hasPassed ? todayH.year : todayH.year - 1;
      }
    }
    return HijriDate(year: hy, month: hm, day: hd);
  }

  String _getAnniversaryHijriDate(bool isArabic) {
    final DateTime? crossing = _calculateCrossingDate(
      transactions,
      savings,
      nisabThreshold,
      market,
    );
    final HijriDate targetH = crossing != null
        ? ZakatEngineService.gregorianToHijri(crossing)
        : _getAnniversaryHijriDateObject();

    final String dayStr = _formatNumber(targetH.day, isArabic);
    final String monthStr = _getHijriMonthName(targetH.month, isArabic);
    final String yearStr = _formatNumber(targetH.year, isArabic);

    return '$dayStr $monthStr $yearStr';
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final tokens = context.premiumTokens;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    final Color bgColor = dark ? tokens.colors.card : const Color(0xFFFFFBF1);
    final Color borderColor = dark
        ? tokens.colors.divider
        : const Color(0xFFE8DFC3);
    final Color textColor = dark ? Colors.white : const Color(0xFF111827);
    final Color labelColor = dark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF4B5563);

    final Color statusColor = nisabMet
        ? (dark ? const Color(0xFF10B981) : const Color(0xFF0F766E))
        : (dark ? const Color(0xFFE0A53A) : const Color(0xFFB7791F));

    final Alignment gradientBegin = isRtl
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final Alignment gradientEnd = isRtl
        ? Alignment.centerRight
        : Alignment.centerLeft;

    final String thresholdValue = hasFxData && !hasMetalsData
        ? context.l10n.tr('gold_silver_required')
        : _DashboardScreenState._formatOrMissing(
            context,
            nisabThreshold,
            hasMarketData,
            mainCurrency,
            market,
          );

    final String statusLabel = hasMarketData
        ? (nisabMet
              ? context.l10n.tr('above_nisab')
              : context.l10n.tr('below_nisab'))
        : (hasFxData
              ? context.l10n.tr('gold_silver_required')
              : context.l10n.tr('market_data_required'));

    final String subtitleText = nisabMet
        ? '${context.l10n.tr('protected_since')} ${_getAnniversaryHijriDate(isRtl)}'
        : context.l10n.tr('no_zakat_due');

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          PositionedDirectional(
            top: 0,
            end: 0,
            bottom: 0,
            width: 110,
            child: IgnorePointer(
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: gradientBegin,
                    end: gradientEnd,
                    colors: <Color>[
                      Colors.white.withValues(alpha: dark ? 0.30 : 0.40),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const <double>[0.0, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: Image.asset(
                  'assets/images/hero_pattern_watermark.png',
                  fit: BoxFit.cover,
                  alignment: AlignmentDirectional.centerEnd,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: <Widget>[
                CustomPaint(
                  size: const Size(34, 40),
                  painter: const _ShieldPainter(
                    fillColor: Color(0xFF032F2A),
                    borderColor: Color(0xFFC5A059),
                  ),
                  child: const SizedBox(
                    width: 34,
                    height: 40,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: _RubElHizbIcon(
                          color: Color(0xFFFFC928),
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        context.l10n
                            .tr('current_nisab_threshold')
                            .toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          thresholdValue,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1.0,
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: dark
                      ? const Color(0xFF181E24)
                      : const Color(0xFFE6E3D9),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        context.l10n.tr('status').toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          subtitleText,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: dark
                                ? const Color(0xFF9CA3BF)
                                : const Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    ],
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

class _AllocationRing extends StatelessWidget {
  const _AllocationRing({
    required this.allocation,
    required this.hasMarketData,
    required this.mainCurrency,
    required this.market,
    required this.balancesHidden,
  });

  final _Allocation allocation;
  final bool hasMarketData;
  final String mainCurrency;
  final MarketData market;
  final bool balancesHidden;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final String currency = mainCurrency.trim().isEmpty
        ? 'EGP'
        : mainCurrency.trim();
    final double displayTotalVal = ZakatEngineService.convertFromEgp(
      allocation.totalVal,
      currency,
      market,
    );
    final String formattedTotal = balancesHidden
        ? '••••••'
        : _DashboardScreenState._formatCompactDisplay(
            context,
            displayTotalVal,
            currency,
          );

    final List<Map<String, dynamic>> items = <Map<String, dynamic>>[
      <String, dynamic>{
        'label': context.l10n.tr('cash_pct'),
        'value': allocation.cashVal,
        'pct': allocation.cashPct,
        'icon': Icons.account_balance_wallet_rounded,
        'iconColor': const Color(0xFF14B8A6),
        'bg': dark ? const Color(0xFF0C2E26) : const Color(0xFFE2F0EC),
      },
      <String, dynamic>{
        'label': context.l10n.tr('metals_pct'),
        'value': allocation.metalsVal,
        'pct': allocation.metalsPct,
        'icon': Icons.layers_rounded,
        'iconColor': const Color(0xFFC8A75B),
        'bg': dark ? const Color(0xFF382D16) : const Color(0xFFF9F0DB),
      },
      <String, dynamic>{
        'label': context.l10n.tr('property_pct'),
        'value': allocation.propertyVal,
        'pct': allocation.propertyPct,
        'icon': Icons.home_rounded,
        'iconColor': const Color(0xFF456E85),
        'bg': dark ? const Color(0xFF1B313F) : const Color(0xFFE1EFF6),
      },
      <String, dynamic>{
        'label': context.l10n.tr('company_pct'),
        'value': allocation.companyVal,
        'pct': allocation.companyPct,
        'icon': Icons.business_rounded,
        'iconColor': const Color(0xFF6B5A95),
        'bg': dark ? const Color(0xFF281C3F) : const Color(0xFFF0EBF9),
      },
    ];

    final List<_AllocSeg> segs = items.map((item) {
      return _AllocSeg(
        _safePct(item['pct'] as double),
        item['iconColor'] as Color,
        item['label'] as String,
      );
    }).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // Ring chart on the left
        SizedBox(
          height: 140,
          width: 140,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, double value, Widget? child) {
                    return CustomPaint(
                      painter: _RingPainter(
                        segs: segs,
                        progress: value,
                        isDark: dark,
                      ),
                      child: child,
                    );
                  },
                  child: const SizedBox.expand(),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                      child: Text(
                        formattedTotal,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: dark ? Colors.white : const Color(0xFF0F2E28),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.tr('total_assets'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: dark
                          ? const Color(0xFFA3B8B5)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 74,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: Container(
                            height: 1.0,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  const Color(
                                    0xFFD4AF37,
                                  ).withValues(alpha: 0.0),
                                  const Color(
                                    0xFFD4AF37,
                                  ).withValues(alpha: 0.6),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6.0),
                          child: Text(
                            '✦',
                            style: TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 10,
                              height: 1.0,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1.0,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  const Color(
                                    0xFFD4AF37,
                                  ).withValues(alpha: 0.6),
                                  const Color(
                                    0xFFD4AF37,
                                  ).withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Legend on the right
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: items
                .map((Map<String, dynamic> item) {
                  final double valueEgp = item['value'] as double;
                  final double pct = item['pct'] as double;
                  final String formattedValue = balancesHidden
                      ? '••••••'
                      : _DashboardScreenState._formatOrMissing(
                          context,
                          valueEgp,
                          hasMarketData,
                          mainCurrency,
                          market,
                        );

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: item['bg'] as Color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            item['icon'] as IconData,
                            color: item['iconColor'] as Color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                item['label'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: dark
                                      ? Colors.white
                                      : const Color(0xFF0F2E28),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formattedValue,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: dark
                                      ? const Color(0xFFA3B8B5)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _DashboardScreenState._formatPct(pct),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: item['iconColor'] as Color,
                          ),
                        ),
                      ],
                    ),
                  );
                })
                .toList(growable: false),
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
  _RingPainter({
    required this.segs,
    required this.progress,
    required this.isDark,
  });

  final List<_AllocSeg> segs;
  final double progress;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final double stroke = 18;
    final Rect rect = Offset.zero & size;
    final Paint bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = isDark ? const Color(0xFF052A22) : const Color(0xFFEBE8E0);
    canvas.drawArc(rect.deflate(stroke / 2), 0, 6.28318, false, bg);

    final double R = size.width / 2 - stroke / 2;
    final Offset C = Offset(size.width / 2, size.height / 2);

    double start = -1.5708;
    for (final _AllocSeg seg in segs) {
      final double sweep = (seg.value / 100) * 6.28318 * progress;
      if (sweep <= 0) continue;

      final double startAngle = start;
      final double endAngle = start + sweep;

      final Offset pStart = Offset(
        C.dx + R * math.cos(startAngle),
        C.dy + R * math.sin(startAngle),
      );
      final Offset pEnd = Offset(
        C.dx + R * math.cos(endAngle),
        C.dy + R * math.sin(endAngle),
      );

      final Paint strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = seg.color;

      final Paint fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = seg.color;

      // 1. Save canvas and clip out the start circle (concave cap)
      canvas.save();
      final Path clipPath = Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      final Path startCircle = Path()
        ..addOval(Rect.fromCircle(center: pStart, radius: stroke / 2));
      final Path finalClip = Path.combine(
        PathOperation.difference,
        clipPath,
        startCircle,
      );
      canvas.clipPath(finalClip);

      // 2. Draw the flat-ended arc
      canvas.drawArc(
        rect.deflate(stroke / 2),
        startAngle,
        sweep,
        false,
        strokePaint,
      );
      canvas.restore();

      // 3. Draw the convex cap at the end of the arc
      canvas.drawCircle(pEnd, stroke / 2, fillPaint);

      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.segs != segs ||
        oldDelegate.isDark != isDark;
  }
}

class _AllocSeg {
  const _AllocSeg(this.value, this.color, this.label);

  final double value;
  final Color color;
  final String label;
}

class _DashboardActivityEntry {
  const _DashboardActivityEntry._({this.transaction, this.saving});

  factory _DashboardActivityEntry.transaction(Transaction transaction) {
    return _DashboardActivityEntry._(transaction: transaction);
  }

  factory _DashboardActivityEntry.cashSaving(Saving saving) {
    return _DashboardActivityEntry._(saving: saving);
  }

  final Transaction? transaction;
  final Saving? saving;

  bool get isSaving => saving != null;
  bool get isExpense => transaction?.type == 'expense';
  String get id => isSaving ? 'saving_${saving!.id}' : 'tx_${transaction!.id}';
  String get date => saving?.dateAcquired ?? transaction!.date;
  String get createdAt => saving?.createdAt ?? transaction!.createdAt;
  String get currency => saving?.unit ?? transaction!.currency;
  double get amount => saving?.amount ?? transaction!.amount;

  String title(BuildContext context) {
    if (isSaving) return context.l10n.tr('cash_in');
    return transaction!.category;
  }
}

class _ActivityRow extends StatefulWidget {
  const _ActivityRow({required this.entry, required this.balancesHidden});

  final _DashboardActivityEntry entry;
  final bool balancesHidden;

  @override
  State<_ActivityRow> createState() => _ActivityRowState();
}

class _ActivityRowState extends State<_ActivityRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isExpense = widget.entry.isExpense;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color valueColor = isExpense
        ? (dark ? const Color(0xFFF87171) : const Color(0xFFB91C1C))
        : (dark ? const Color(0xFF34D399) : const Color(0xFF047857));

    final Color iconBg = isExpense
        ? (dark ? const Color(0xFF7F1D1D).withValues(alpha: 0.2) : const Color(0xFFFFF1F2))
        : (dark ? const Color(0xFF064E3B).withValues(alpha: 0.2) : const Color(0xFFF0FDF4));

    final Color iconColor = isExpense
        ? const Color(0xFFDC2626)
        : const Color(0xFF16A34A);

    final Color pressedOverlay = dark
        ? const Color(0xFF10B981).withValues(alpha: 0.08)
        : const Color(0xFF10B981).withValues(alpha: 0.04);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) {
          _controller.forward();
          setState(() {
            _isPressed = true;
          });
        },
        onTapUp: (_) {
          _controller.reverse();
          setState(() {
            _isPressed = false;
          });
        },
        onTapCancel: () {
          _controller.reverse();
          setState(() {
            _isPressed = false;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          key: Key('dashboardRecent_${widget.entry.id}'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: _isPressed ? pressedOverlay : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isExpense ? Icons.south_west_rounded : Icons.north_east_rounded,
                  color: iconColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      widget.entry.title(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: dark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.entry.date,
                      style: TextStyle(
                        fontSize: 11.0,
                        color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    widget.balancesHidden
                        ? '••••••'
                        : ZakatEngineService.formatCurrency(
                            isExpense ? -widget.entry.amount : widget.entry.amount,
                            widget.entry.currency,
                            isArabic: _DashboardScreenState._isArabic(context),
                            showSign: true,
                          ),
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w800,
                      color: valueColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: iconColor.withValues(alpha: 0.8),
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dues {
  const _Dues({
    required this.thisMonth,
    required this.nextMonth,
    required this.totalUpcoming,
  });

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
    required this.cashVal,
    required this.metalsVal,
    required this.propertyVal,
    required this.companyVal,
    required this.totalVal,
  });

  final double cashPct;
  final double metalsPct;
  final double propertyPct;
  final double companyPct;
  final double cashVal;
  final double metalsVal;
  final double propertyVal;
  final double companyVal;
  final double totalVal;
}

class _ObligationColumn extends StatefulWidget {
  const _ObligationColumn({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.isTotal = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final bool isTotal;

  @override
  State<_ObligationColumn> createState() => _ObligationColumnState();
}

class _ObligationColumnState extends State<_ObligationColumn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color pressedOverlay = dark
        ? const Color(0xFF10B981).withValues(alpha: 0.08)
        : const Color(0xFF10B981).withValues(alpha: 0.04);

    return Expanded(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTapDown: (_) {
            _controller.forward();
            setState(() {
              _isPressed = true;
            });
          },
          onTapUp: (_) {
            _controller.reverse();
            setState(() {
              _isPressed = false;
            });
            widget.onTap();
          },
          onTapCancel: () {
            _controller.reverse();
            setState(() {
              _isPressed = false;
            });
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: _isPressed ? pressedOverlay : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      widget.icon,
                      size: 14,
                      color: widget.iconColor.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: dark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: widget.isTotal ? 16.0 : 15.0,
                            fontWeight: widget.isTotal ? FontWeight.w900 : FontWeight.w800,
                            color: dark ? const Color(0xFF10B981) : const Color(0xFF0F766E),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: widget.iconColor.withValues(alpha: 0.8),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  const _KeepAliveWrapper({required this.child});
  final Widget child;

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
