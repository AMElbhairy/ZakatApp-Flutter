import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../core/services/zakat_engine.dart';
import '../../models/financial_plan.dart';
import '../../models/investment_asset.dart';
import '../../models/saving.dart';
import '../../models/transaction.dart';
import '../../services/app_state_controller.dart';
import '../../services/plan_wealth_service.dart';
import '../../services/projection_service.dart';
import '../entry/add_financial_plan_screen.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../account/notifications_screen.dart';
import '../../models/pending_transaction.dart';

const Color _emerald = Color(0xFF0B3D32);
const Color _emeraldLight = Color(0xFF176B55);
const Color _gold = Color(0xFFD4AF37);
const Color _ink = Color(0xFF17231F);
const Color _muted = Color(0xFF6D7974);
const Color _dangerLight = Color(0xFFB54747);
const Color _dangerDark = Color(
  0xFFFF8A80,
); // Lighter pastel coral red for dark mode contrast

Color _dangerColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? _dangerDark
      : _dangerLight;
}

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final AppStateController controller = context.watch<AppStateController>();
    final List<FinancialPlan> plans = controller.state.financialPlans;

    if (plans.isEmpty) {
      return const AddFinancialPlanScreen();
    }

    final FinancialPlan plan = plans.first;
    final List<Transaction> transactions = controller.state.transactions;
    final List<Saving> savings = controller.state.savings;
    final List<InvestmentAsset> investments = controller.state.investments;
    final MarketData marketData = MarketData.fromJson(
      controller.state.marketData,
    );

    final String targetCurrency =
        controller.state.mainCurrency.isNotEmpty == true
        ? controller.state.mainCurrency
        : plan.projectionCurrency;

    final List<ProjectionPoint> projection =
        ProjectionService.calculateProjection(
          plan: plan,
          investments: investments,
          marketData: marketData,
          zakatMethod: controller.state.zakatMethod,
          zakatAnnualDate: controller.state.zakatAnnualDate,
        );

    double convertValue(double value) {
      if (plan.projectionCurrency == targetCurrency) return value;
      final double egpVal = ZakatEngineService.convertToEgp(
        value,
        plan.projectionCurrency,
        marketData,
      );
      return ZakatEngineService.convertFromEgp(
        egpVal,
        targetCurrency,
        marketData,
      );
    }

    List<ProjectionPoint> displayedProjection = projection;
    if (plan.projectionCurrency != targetCurrency) {
      displayedProjection = projection
          .map(
            (p) => ProjectionPoint(
              monthNumber: p.monthNumber,
              date: p.date,
              balance: convertValue(p.balance),
              income: convertValue(p.income),
              expenses: convertValue(p.expenses),
              installmentsOutflow: convertValue(p.installmentsOutflow),
              zakatOutflow: convertValue(p.zakatOutflow),
            ),
          )
          .toList();
    }

    final double actualWealthNative =
        PlanWealthService.calculateActualPlanWealth(
          transactions: transactions,
          savings: savings,
          investments: investments,
          marketData: marketData,
          projectionCurrency: plan.projectionCurrency,
          lastRollover: controller.state.lastRollover,
        );

    final DateTime startDate =
        DateTime.tryParse(plan.startDate) ?? DateTime.now();
    final DateTime now = DateTime.now();
    final int totalMonths = plan.durationYears * 12;
    int currentMonthIndex =
        (now.year - startDate.year) * 12 + (now.month - startDate.month);
    currentMonthIndex = currentMonthIndex.clamp(0, totalMonths);
    final DateTime targetDate = DateTime(
      startDate.year + plan.durationYears,
      startDate.month,
      startDate.day,
    );

    final double expectedWealthNative =
        PlanWealthService.calculateExpectedPlanWealth(
          projection: projection,
          currentMonthIndex: currentMonthIndex,
          startingBalance: plan.startingBalance,
        );
    final double requiredSurplusNative =
        plan.monthlyIncome - plan.monthlyExpenses;
    final double currentSurplusNative =
        PlanWealthService.calculateActualAverageSurplus(
          currentNetWorth: actualWealthNative,
          startingNetWorth: plan.startingNetWorth,
          startDate: startDate,
        );

    final double actualWealth = convertValue(actualWealthNative);
    final double expectedWealth = convertValue(expectedWealthNative);
    final double requiredSurplus = convertValue(requiredSurplusNative);
    final double currentSurplus = convertValue(currentSurplusNative);
    final double surplusGap = currentSurplus - requiredSurplus;
    final double variance = actualWealth - expectedWealth;

    final double planEndGoal = convertValue(
      projection.isEmpty ? plan.startingBalance : projection.last.balance,
    );
    final int remainingMonths = math.max(0, totalMonths - currentMonthIndex);
    final double projectedEndBalance =
        PlanWealthService.calculateForecastEndBalance(
          planEndGoal: planEndGoal,
          currentFinancialVariance: variance,
          averageMonthlySurplus: currentSurplus,
          requiredMonthlySurplus: requiredSurplus,
          remainingMonths: remainingMonths,
        );
    final double projectedGrowth =
        projectedEndBalance - convertValue(plan.startingBalance);
    final double forecastGap = projectedEndBalance - planEndGoal;
    final double monthlyAdjustmentNeeded = remainingMonths <= 0
        ? 0.0
        : math.max(0.0, -forecastGap / remainingMonths);

    String healthCode;
    if (planEndGoal <= 0) {
      healthCode = 'on_track';
    } else {
      final double forecastRatio = projectedEndBalance / planEndGoal;
      if (forecastRatio >= 1.05) {
        healthCode = 'ahead';
      } else if (forecastRatio >= 0.95) {
        healthCode = 'on_track';
      } else {
        healthCode = 'behind';
      }
    }

    int confidence;
    if (planEndGoal <= 0) {
      confidence = 100;
    } else {
      confidence = ((projectedEndBalance / planEndGoal) * 100)
          .clamp(0, 100)
          .round();
    }

    final double progressRatio = requiredSurplus <= 0
        ? (currentSurplus >= 0 ? 1.0 : 0.0)
        : currentSurplus / requiredSurplus;

    final Map<String, Map<String, double>> assetDrift =
        PlanWealthService.calculateAssetDrift(
          startingAssetBreakdown: plan.startingAssetBreakdown,
          transactions: transactions,
          savings: savings,
          investments: investments,
          marketData: marketData,
          projectionCurrency: plan.projectionCurrency,
          lastRollover: controller.state.lastRollover,
        );
    final List<String> allocationKeys = assetDrift.keys
        .where((String key) => key != 'liability')
        .toList(growable: false);
    final double assets = allocationKeys.fold<double>(
      0,
      (double total, String key) => total + (assetDrift[key]?['current'] ?? 0),
    );
    final double liabilities = assetDrift['liability']?['current'] ?? 0;

    final List<_Milestone> milestones = _buildMilestones(
      projection: displayedProjection,
      actualWealth: actualWealth,
      projectedEndBalance: planEndGoal,
      targetDate: targetDate,
    );

    double projectedLifetimeZakat = 0.0;
    final List<double> yearlyZakatProjections = [];
    double currentYearZakatSum = 0.0;
    for (int idx = 0; idx < displayedProjection.length; idx++) {
      final ProjectionPoint point = displayedProjection[idx];
      projectedLifetimeZakat += point.zakatOutflow;
      currentYearZakatSum += point.zakatOutflow;
      if ((idx + 1) % 12 == 0) {
        yearlyZakatProjections.add(currentYearZakatSum);
        currentYearZakatSum = 0.0;
      }
    }
    if (yearlyZakatProjections.length < plan.durationYears &&
        currentYearZakatSum > 0.0) {
      yearlyZakatProjections.add(currentYearZakatSum);
    }

    final String currencyCode = targetCurrency;
    final String healthLabel = _healthLabel(healthCode, isArabic);
    final Color healthColor = healthCode == 'behind'
        ? _dangerColor(context)
        : healthCode == 'ahead'
        ? _emeraldLight
        : _gold;
    bool balancesHidden = false;
    final Map<String, dynamic> aiSettings = Map<String, dynamic>.from(
      controller.state.aiSettings ?? const <String, dynamic>{},
    );
    const List<String> privacyKeys = <String>[
      'hideBalances',
      'balancesHidden',
      'balanceHidden',
      'isBalanceHidden',
      'privacyMode',
    ];
    for (final String key in privacyKeys) {
      if (aiSettings[key] == true) {
        balancesHidden = true;
        break;
      }
    }

    final tokens = context.premiumTokens;
    final Color editActionColor = dark ? tokens.colors.gold : _gold;

    return Scaffold(
      backgroundColor: tokens.colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            112 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            children: <Widget>[
              _PlansHeader(
                title: isArabic ? 'التخطيط المالي' : 'Financial Planning',
                planName: plan.name,
                balancesHidden: balancesHidden,
                onTogglePrivacy: () => controller.togglePrivacyMode(),
                hasNotifications: controller.state.pendingTransactions.any(
                  (t) => t.status == CaptureStatus.pendingReview,
                ),
                onTapNotifications: () {
                  Navigator.of(context).push(NotificationsScreen.route());
                },
                isArabic: isArabic,
              ),
              const SizedBox(height: 16),
              _JourneyHero(
                currencyCode: currencyCode,
                projectedEndBalance: projectedEndBalance,
                planEndGoal: planEndGoal,
                currentNetWorth: actualWealth,
                startingNetWorth: convertValue(plan.startingBalance),
                projectedGrowth: projectedGrowth,
                startDate: startDate,
                today: now,
                targetDate: targetDate,
                totalMonths: totalMonths,
                currentMonthIndex: currentMonthIndex,
                healthLabel: healthLabel,
                healthCode: healthCode,
                balancesHidden: balancesHidden,
                isArabic: isArabic,
              ),
              const SizedBox(height: 14),
              _MonthlyGoalCard(
                currencyCode: currencyCode,
                required: requiredSurplus,
                current: currentSurplus,
                gap: surplusGap,
                progressRatio: progressRatio,
                healthCode: healthCode,
                balancesHidden: balancesHidden,
                isArabic: isArabic,
              ),
              const SizedBox(height: 14),
              _ConfidenceCard(
                confidence: confidence,
                healthCode: healthCode,
                healthLabel: healthLabel,
                healthColor: healthColor,
                actualWealth: actualWealth,
                expectedWealth: expectedWealth,
                variance: variance,
                sinceStartGrowth: actualWealth - plan.startingBalance,
                currencyCode: currencyCode,
                balancesHidden: balancesHidden,
                isArabic: isArabic,
              ),
              const SizedBox(height: 14),
              _BreakdownCard(
                assets: assets,
                liabilities: liabilities,
                startingLiabilities: plan.startingLiabilities,
                netWorth: actualWealth,
                allocationKeys: allocationKeys,
                assetDrift: assetDrift,
                currencyCode: currencyCode,
                balancesHidden: balancesHidden,
                isArabic: isArabic,
              ),
              const SizedBox(height: 14),
              _ZakatLifetimeCard(
                lifetimeZakat: projectedLifetimeZakat,
                yearlyProjections: yearlyZakatProjections,
                currencyCode: currencyCode,
                balancesHidden: balancesHidden,
                isArabic: isArabic,
              ),
              const SizedBox(height: 14),
              _MilestonesCard(
                milestones: milestones,
                currencyCode: currencyCode,
                balancesHidden: balancesHidden,
                isArabic: isArabic,
              ),
              const SizedBox(height: 14),
              _ProjectionCard(
                projection: displayedProjection,
                startingBalance: convertValue(plan.startingBalance),
                actualWealth: actualWealth,
                projectedEndBalance: planEndGoal,
                currentMonthIndex: currentMonthIndex,
                totalMonths: totalMonths,
                currencyCode: currencyCode,
                balancesHidden: balancesHidden,
                isArabic: isArabic,
              ),
              const SizedBox(height: 14),
              _InsightCard(
                healthCode: healthCode,
                requiredSurplus: requiredSurplus,
                monthlyAdjustmentNeeded: monthlyAdjustmentNeeded,
                forecastGap: forecastGap,
                currencyCode: currencyCode,
                balancesHidden: balancesHidden,
                isArabic: isArabic,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('editPlanButton'),
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: editActionColor,
                      ),
                      label: Text(
                        isArabic ? 'تعديل الخطة' : 'Edit Plan',
                        style: TextStyle(
                          color: editActionColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: editActionColor, width: 1.5),
                        backgroundColor: dark
                            ? editActionColor.withValues(alpha: 0.1)
                            : null,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                AddFinancialPlanScreen(initialPlan: plan),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: _dangerColor(context),
                      ),
                      label: Text(
                        isArabic ? 'حذف الخطة' : 'Delete Plan',
                        style: TextStyle(
                          color: _dangerColor(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _dangerColor(context),
                          width: 1.5,
                        ),
                        backgroundColor: dark
                            ? _dangerColor(context).withValues(alpha: 0.1)
                            : null,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _confirmDelete(context, plan),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, FinancialPlan plan) async {
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(
              isArabic ? 'حذف الخطة المالية؟' : 'Delete Financial Plan?',
            ),
            content: Text(
              isArabic
                  ? 'سيؤدي هذا إلى إزالة كافة التوقعات بشكل دائم.'
                  : 'This will permanently remove all projections.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(isArabic ? 'حذف' : 'Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !context.mounted) return;
    await context.read<AppStateController>().deleteFinancialPlan(plan.id);
  }
}

class _JourneyHero extends StatelessWidget {
  const _JourneyHero({
    required this.currencyCode,
    required this.projectedEndBalance,
    required this.planEndGoal,
    required this.currentNetWorth,
    required this.startingNetWorth,
    required this.projectedGrowth,
    required this.startDate,
    required this.today,
    required this.targetDate,
    required this.totalMonths,
    required this.currentMonthIndex,
    required this.healthLabel,
    required this.healthCode,
    required this.balancesHidden,
    required this.isArabic,
  });

  final String currencyCode;
  final double projectedEndBalance;
  final double planEndGoal;
  final double currentNetWorth;
  final double startingNetWorth;
  final double projectedGrowth;
  final DateTime startDate;
  final DateTime today;
  final DateTime targetDate;
  final int totalMonths;
  final int currentMonthIndex;
  final String healthLabel;
  final String healthCode;
  final bool balancesHidden;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final double journeyProgress = totalMonths <= 0
        ? 0
        : (currentMonthIndex / totalMonths).clamp(0, 1);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color borderColor = isDark
        ? const Color(0xFFFFC928).withValues(alpha: 0.45)
        : const Color(0xFFC5A059).withValues(alpha: 0.65);
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;
    final Alignment gradientBegin = isRtl
        ? Alignment.topLeft
        : Alignment.topRight;
    final Alignment gradientEnd = isRtl
        ? Alignment.bottomRight
        : Alignment.bottomLeft;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 1.5),
        gradient: const LinearGradient(
          colors: <Color>[_emerald, Color(0xFF092B25)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _emerald.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
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
                      Colors.white.withValues(alpha: isDark ? 0.12 : 0.18),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const <double>[0.0, 0.8],
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
            end: 5,
            top: 3,
            width: 240,
            height: 240,
            child: Opacity(
              opacity: 0.15,
              child: Transform.scale(
                scale: 1.5,
                child: Transform.flip(
                  flipX: isRtl,
                  child: Image.asset(
                    'assets/images/Financial_Plan_Hero_Watermark.png',
                    fit: BoxFit.contain,
                  ),
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
                        isArabic ? 'رحلة صافي الثروة' : 'NET WORTH JOURNEY',
                        style: const TextStyle(
                          color: _gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    _StatusPill(
                      label: healthLabel.toUpperCase(),
                      color: healthCode == 'behind'
                          ? const Color(0xFFFFB4AB)
                          : healthCode == 'ahead'
                          ? const Color(0xFF66DFB4)
                          : const Color(0xFFFFE08A),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    balancesHidden
                        ? '••••••'
                        : _compactMoney(projectedEndBalance, currencyCode),
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isArabic
                      ? 'صافي الثروة المتوقع عند تاريخ الهدف'
                      : 'Projected net worth at goal date',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    const Icon(Icons.auto_awesome, color: _gold, size: 17),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _heroMessage(healthCode, isArabic),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _HeroStat(
                        label: isArabic
                            ? 'صافي الثروة الحالي'
                            : 'Current Net Worth',
                        value: balancesHidden
                            ? '••••••'
                            : _compactMoney(currentNetWorth, currencyCode),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HeroStat(
                        label: isArabic ? 'إجمالي النمو' : 'Total Growth',
                        value: balancesHidden
                            ? '••••••'
                            : _signedCompactMoney(
                                projectedGrowth,
                                currencyCode,
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HeroStat(
                        label: isArabic
                            ? 'الأشهر المتبقية'
                            : 'Months Remaining',
                        value:
                            '${math.max(0, totalMonths - currentMonthIndex)}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _JourneyLine(progress: journeyProgress),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _JourneyPoint(
                        label: isArabic ? 'البداية' : 'Start',
                        date: _date(startDate),
                        value: balancesHidden
                            ? '••••••'
                            : _fullMoney(startingNetWorth, currencyCode),
                        alignment: CrossAxisAlignment.start,
                      ),
                    ),
                    Expanded(
                      child: _JourneyPoint(
                        label: isArabic ? 'اليوم' : 'Today',
                        date: _date(today),
                        value: balancesHidden
                            ? '••••••'
                            : _fullMoney(currentNetWorth, currencyCode),
                        alignment: CrossAxisAlignment.center,
                      ),
                    ),
                    Expanded(
                      child: _JourneyPoint(
                        label: isArabic ? 'الهدف' : 'Target',
                        date: _date(targetDate),
                        value: balancesHidden
                            ? '••••••'
                            : _fullMoney(planEndGoal, currencyCode),
                        alignment: CrossAxisAlignment.end,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyGoalCard extends StatelessWidget {
  const _MonthlyGoalCard({
    required this.currencyCode,
    required this.required,
    required this.current,
    required this.gap,
    required this.progressRatio,
    required this.healthCode,
    required this.balancesHidden,
    required this.isArabic,
  });

  final String currencyCode;
  final double required;
  final double current;
  final double gap;
  final double progressRatio;
  final String healthCode;
  final bool balancesHidden;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final bool ahead = current >= required;
    final double displayRatio = progressRatio.clamp(0, 1);
    final int percentage = (progressRatio * 100).clamp(0, 999).round();
    return _DashboardCard(
      title: isArabic ? 'سرعة الادخار الحالية' : 'Current Saving Pace',
      icon: Icons.savings_outlined,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricBlock(
                  label: isArabic ? 'المطلوب' : 'Required',
                  value: balancesHidden
                      ? '••••••'
                      : _compactMoney(required, currencyCode),
                ),
              ),
              Expanded(
                child: _MetricBlock(
                  label: isArabic
                      ? 'متوسط الفائض الفعلي'
                      : 'Actual Average Surplus',
                  value: balancesHidden
                      ? '••••••'
                      : _compactMoney(current, currencyCode),
                ),
              ),
              Expanded(
                child: _MetricBlock(
                  label: ahead
                      ? (isArabic ? 'متقدم بمقدار' : 'Ahead by')
                      : (isArabic ? 'متأخر بمقدار' : 'Behind by'),
                  value: balancesHidden
                      ? '••••••'
                      : _compactMoney(gap.abs(), currencyCode),
                  valueColor: ahead ? _emeraldLight : _dangerColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: displayRatio,
                    backgroundColor: _emerald.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ahead ? _emeraldLight : _gold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$percentage%',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : _emerald,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              ahead
                  ? (isArabic
                        ? 'عمل رائع! أنت تدخر أكثر من المطلوب.'
                        : 'Great job! You are saving more than needed.')
                  : (isArabic
                        ? (balancesHidden
                              ? 'تحتاج المزيد للبقاء على المسار.'
                              : 'تحتاج ${_compactMoney(gap.abs(), currencyCode)} إضافية شهرياً للبقاء على المسار.')
                        : (balancesHidden
                              ? 'You need more per month to stay on track.'
                              : 'You need ${_compactMoney(gap.abs(), currencyCode)} more per month to stay on track.')),
              style: TextStyle(
                color: ahead ? _emeraldLight : _dangerColor(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceCard extends StatelessWidget {
  const _ConfidenceCard({
    required this.confidence,
    required this.healthCode,
    required this.healthLabel,
    required this.healthColor,
    required this.actualWealth,
    required this.expectedWealth,
    required this.variance,
    required this.sinceStartGrowth,
    required this.currencyCode,
    required this.balancesHidden,
    required this.isArabic,
  });

  final int confidence;
  final String healthCode;
  final String healthLabel;
  final Color healthColor;
  final double actualWealth;
  final double expectedWealth;
  final double variance;
  final double sinceStartGrowth;
  final String currencyCode;
  final bool balancesHidden;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final Color confidenceColor = confidence >= 75
        ? _emeraldLight
        : confidence >= 50
        ? _gold
        : _dangerColor(context);

    String explanation;
    if (confidence >= 75) {
      explanation = isArabic
          ? 'يعتمد هذا التوقع على انحرافك المالي الحالي ومتوسط نمو صافي الثروة منذ بداية الخطة.'
          : 'This forecast applies your current financial variance and average net worth growth since the plan started.';
    } else if (confidence >= 50) {
      explanation = isArabic
          ? 'انحرافك المالي الحالي ومتوسط نمو صافي الثروة منذ بداية الخطة يضعانك قريباً من الهدف، لكن توجد فجوة.'
          : 'Your current financial variance and average net worth growth since the plan started put you near the target, but a gap remains.';
    } else {
      explanation = isArabic
          ? 'التوقع المبني على انحرافك المالي الحالي ومتوسط نمو صافي الثروة منذ بداية الخطة أقل من هدف الخطة.'
          : 'The forecast from your current financial variance and average net worth growth since the plan started is below the plan target.';
    }

    return _DashboardCard(
      title: isArabic ? 'نظرة مستقبلية للخطة' : 'Plan Outlook',
      icon: Icons.verified_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: confidenceColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: confidenceColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '$confidence%',
                      style: TextStyle(
                        color: confidenceColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      confidence >= 75
                          ? (isArabic ? 'خطة قوية' : 'Strong Plan')
                          : confidence >= 50
                          ? (isArabic ? 'خطة معتدلة' : 'Moderate Plan')
                          : (isArabic ? 'خطة ضعيفة' : 'Weak Plan'),
                      style: TextStyle(
                        color: confidenceColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _StatusPill(label: healthLabel, color: healthColor),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            explanation,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.87)
                  : _ink,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'الانحراف المالي' : 'Financial Variance',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white60
                      : _muted,
                  fontSize: 11,
                ),
              ),
              Text(
                balancesHidden
                    ? '••••••'
                    : _signedFullMoney(variance, currencyCode),
                style: TextStyle(
                  color: variance >= 0 ? _emeraldLight : _dangerColor(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatefulWidget {
  const _BreakdownCard({
    required this.assets,
    required this.liabilities,
    required this.startingLiabilities,
    required this.netWorth,
    required this.allocationKeys,
    required this.assetDrift,
    required this.currencyCode,
    required this.balancesHidden,
    required this.isArabic,
  });

  final double assets;
  final double liabilities;
  final double startingLiabilities;
  final double netWorth;
  final List<String> allocationKeys;
  final Map<String, Map<String, double>> assetDrift;
  final String currencyCode;
  final bool balancesHidden;
  final bool isArabic;

  @override
  State<_BreakdownCard> createState() => _BreakdownCardState();
}

class _BreakdownCardState extends State<_BreakdownCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final bool isArabic = widget.isArabic;
    final double assets = widget.assets;
    final double liabilities = widget.liabilities;
    final double startingLiabilities = widget.startingLiabilities;
    final double netWorth = widget.netWorth;
    final List<String> allocationKeys = widget.allocationKeys;
    final Map<String, Map<String, double>> assetDrift = widget.assetDrift;
    final String currencyCode = widget.currencyCode;
    final bool balancesHidden = widget.balancesHidden;

    final List<String> displayedKeys = _expanded
        ? allocationKeys
        : allocationKeys.take(4).toList();

    return _DashboardCard(
      title: isArabic ? 'تفصيل صافي الثروة' : 'Net Worth Breakdown',
      icon: Icons.donut_small_outlined,
      trailing: allocationKeys.length > 4
          ? TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded
                    ? (isArabic ? 'عرض أقل' : 'Show Less')
                    : (isArabic ? 'عرض الكل' : 'Show All'),
                style: const TextStyle(fontSize: 12),
              ),
            )
          : null,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricBlock(
                  label: isArabic ? 'الأصول' : 'Assets',
                  value: balancesHidden
                      ? '••••••'
                      : _compactMoney(assets, currencyCode),
                ),
              ),
              Expanded(
                child: _MetricBlock(
                  label: isArabic ? 'الالتزامات' : 'Liabilities',
                  value: balancesHidden
                      ? '••••••'
                      : _compactMoney(liabilities, currencyCode),
                  valueColor: _dangerColor(context),
                ),
              ),
              Expanded(
                child: _MetricBlock(
                  label: isArabic ? 'صافي الثروة' : 'Net Worth',
                  value: balancesHidden
                      ? '••••••'
                      : _compactMoney(netWorth, currencyCode),
                  valueColor: _emeraldLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...displayedKeys.asMap().entries.map((MapEntry<int, String> entry) {
            final String key = entry.value;
            final double value = assetDrift[key]?['current'] ?? 0;
            final double startedValue = assetDrift[key]?['started'] ?? 0;
            final double percentage = assets <= 0 ? 0 : (value / assets) * 100;
            final double startedAssets = allocationKeys.fold<double>(
              0,
              (double total, String allocationKey) =>
                  total + (assetDrift[allocationKey]?['started'] ?? 0),
            );
            final double startedPercentage = startedAssets <= 0
                ? 0
                : (startedValue / startedAssets) * 100;
            final Color color = _allocationColor(entry.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          _allocationLabel(key, isArabic),
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.87)
                                : _ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        balancesHidden
                            ? '••••••'
                            : _compactMoney(value, currencyCode),
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.87)
                              : _ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${percentage.toStringAsFixed(1)}%',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white60
                                : _muted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: (percentage / 100).clamp(0, 1),
                      minHeight: 5,
                      backgroundColor: color.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      '${isArabic ? "البداية" : "Started"} ${startedPercentage.toStringAsFixed(1)}%  •  '
                      '${isArabic ? "التغير" : "Change"} ${(percentage - startedPercentage) >= 0 ? "+" : ""}${(percentage - startedPercentage).toStringAsFixed(1)} pts',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white38
                            : _muted,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 18),
          _DetailRow(
            label: isArabic ? 'إجمالي الأصول' : 'Total Assets',
            value: balancesHidden ? '••••••' : _fullMoney(assets, currencyCode),
          ),
          _DetailRow(
            label: isArabic ? 'الالتزامات عند البداية' : 'Started Liability',
            value: balancesHidden
                ? '••••••'
                : _fullMoney(startingLiabilities, currencyCode),
          ),
          _DetailRow(
            label: isArabic ? 'الالتزامات المتبقية' : 'Remaining Liability',
            value: balancesHidden
                ? '••••••'
                : _fullMoney(liabilities, currencyCode),
            valueColor: _dangerColor(context),
          ),
          _DetailRow(
            label: isArabic ? 'تغير الالتزامات' : 'Liability Change',
            value: balancesHidden
                ? '••••••'
                : _signedFullMoney(
                    liabilities - startingLiabilities,
                    currencyCode,
                  ),
            valueColor: liabilities <= startingLiabilities
                ? _emeraldLight
                : _dangerColor(context),
          ),
          _DetailRow(
            label: isArabic ? 'صافي الثروة الحالي' : 'Current Net Worth',
            value: balancesHidden
                ? '••••••'
                : _fullMoney(netWorth, currencyCode),
            valueColor: _emeraldLight,
          ),
        ],
      ),
    );
  }
}

class _ZakatLifetimeCard extends StatefulWidget {
  const _ZakatLifetimeCard({
    required this.lifetimeZakat,
    required this.yearlyProjections,
    required this.currencyCode,
    required this.balancesHidden,
    required this.isArabic,
  });

  final double lifetimeZakat;
  final List<double> yearlyProjections;
  final String currencyCode;
  final bool balancesHidden;
  final bool isArabic;

  @override
  State<_ZakatLifetimeCard> createState() => _ZakatLifetimeCardState();
}

class _ZakatLifetimeCardState extends State<_ZakatLifetimeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      title: widget.isArabic ? 'توقعات الزكاة' : 'Zakat Forecast',
      icon: Icons.mosque_outlined,
      trailing: widget.yearlyProjections.isEmpty
          ? null
          : IconButton(
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: _emerald,
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _DetailRow(
            label: widget.isArabic
                ? 'إجمالي الزكاة المتوقعة (مدى الحياة)'
                : 'Projected Lifetime Zakat',
            value: widget.balancesHidden
                ? '••••••'
                : _fullMoney(widget.lifetimeZakat, widget.currencyCode),
            valueColor: _gold,
          ),
          if (_expanded && widget.yearlyProjections.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...List.generate(widget.yearlyProjections.length, (index) {
              final val = widget.yearlyProjections[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.isArabic
                          ? 'السنة ${index + 1}'
                          : 'Year ${index + 1}',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white60
                            : _muted,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      widget.balancesHidden
                          ? '••••••'
                          : _fullMoney(val, widget.currencyCode),
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.87)
                            : _ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _MilestonesCard extends StatelessWidget {
  const _MilestonesCard({
    required this.milestones,
    required this.currencyCode,
    required this.balancesHidden,
    required this.isArabic,
  });

  final List<_Milestone> milestones;
  final String currencyCode;
  final bool balancesHidden;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      title: isArabic ? 'المحطات' : 'Milestones',
      icon: Icons.flag_outlined,
      child: Column(
        children: milestones
            .asMap()
            .entries
            .map((entry) {
              final int index = entry.key;
              final _Milestone milestone = entry.value;
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      width: 22,
                      child: Column(
                        children: <Widget>[
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: milestone.reached ? _emeraldLight : _gold,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          if (index < milestones.length - 1)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: _emerald.withValues(alpha: 0.12),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              milestone.title,
                              style: TextStyle(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.87)
                                    : _ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              milestone.date != null
                                  ? '${isArabic ? "متوقع" : "Estimated"} ${DateFormat('MMM yyyy').format(milestone.date!)}'
                                  : (balancesHidden
                                        ? '${isArabic ? "متبقية" : "to go"}'
                                        : '${_compactMoney(milestone.remaining, currencyCode)} ${isArabic ? "متبقية" : "to go"}'),
                              style: TextStyle(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white38
                                    : _muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  const _ProjectionCard({
    required this.projection,
    required this.startingBalance,
    required this.actualWealth,
    required this.projectedEndBalance,
    required this.currentMonthIndex,
    required this.totalMonths,
    required this.currencyCode,
    required this.balancesHidden,
    required this.isArabic,
  });

  final List<ProjectionPoint> projection;
  final double startingBalance;
  final double actualWealth;
  final double projectedEndBalance;
  final int currentMonthIndex;
  final int totalMonths;
  final String currencyCode;
  final bool balancesHidden;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final int years = (totalMonths / 12).round();
    final String titleStr = isArabic
        ? 'توقعات $years سنوات'
        : '$years Year Projection';
    return _DashboardCard(
      title: titleStr,
      icon: Icons.show_chart,
      trailing: TextButton(
        onPressed: () => _showFullChart(context),
        child: Text(isArabic ? 'عرض المخطط' : 'View Full Chart'),
      ),
      child: Column(
        children: <Widget>[
          _InteractiveProjectionChart(
            points: projection,
            startingBalance: startingBalance,
            actualWealth: actualWealth,
            currentMonthIndex: currentMonthIndex,
            totalMonths: totalMonths,
            currencyCode: currencyCode,
            balancesHidden: balancesHidden,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: <Widget>[
              _Legend(
                color: _gold,
                label: isArabic ? 'صافي الثروة المتوقع' : 'Projected Net Worth',
              ),
              _Legend(color: _emerald, label: isArabic ? 'الهدف' : 'Goal'),
              _Legend(
                color: _emeraldLight,
                label: isArabic ? 'اليوم' : 'Today',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailRow(
            label: isArabic ? 'هدف نهاية الخطة' : 'Plan End Goal',
            value: _fullMoney(projectedEndBalance, currencyCode),
          ),
        ],
      ),
    );
  }

  void _showFullChart(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                isArabic ? 'مخطط التوقعات الكامل' : 'Full Projection Chart',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              _InteractiveProjectionChart(
                points: projection,
                startingBalance: startingBalance,
                actualWealth: actualWealth,
                currentMonthIndex: currentMonthIndex,
                totalMonths: totalMonths,
                currencyCode: currencyCode,
                balancesHidden: balancesHidden,
                height: 300.0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.healthCode,
    required this.requiredSurplus,
    required this.monthlyAdjustmentNeeded,
    required this.forecastGap,
    required this.currencyCode,
    required this.balancesHidden,
    required this.isArabic,
  });

  final String healthCode;
  final double requiredSurplus;
  final double monthlyAdjustmentNeeded;
  final double forecastGap;
  final String currencyCode;
  final bool balancesHidden;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    String message;
    if (healthCode == 'ahead') {
      message = isArabic
          ? (balancesHidden
                ? 'حافظ على متوسط فائضك الحالي للبقاء متقدماً على هدف الخطة.'
                : 'حافظ على متوسط فائضك الحالي. من المتوقع أن تتجاوز هدفك بمقدار ${_compactMoney(forecastGap.abs(), currencyCode)}.')
          : (balancesHidden
                ? 'Maintain your current average surplus to stay ahead of the plan target.'
                : 'Maintain your current average surplus. You are forecast to exceed the target by ${_compactMoney(forecastGap.abs(), currencyCode)}.');
    } else if (healthCode == 'behind') {
      message = isArabic
          ? (balancesHidden
                ? 'زد متوسط فائضك الشهري لإغلاق فجوة التوقع.'
                : 'زد متوسط فائضك الشهري بمقدار ${_compactMoney(monthlyAdjustmentNeeded, currencyCode)} لإغلاق الفجوة المتوقعة.')
          : (balancesHidden
                ? 'Increase your average monthly surplus to close the forecast gap.'
                : 'Increase your average monthly surplus by ${_compactMoney(monthlyAdjustmentNeeded, currencyCode)} to close the forecast gap.');
    } else {
      message = isArabic
          ? (balancesHidden
                ? 'أنت على المسار الصحيح. حافظ على فائض شهري مناسب.'
                : 'أنت على المسار الصحيح. حافظ على فائض شهري قريب من ${_compactMoney(requiredSurplus, currencyCode)}.')
          : (balancesHidden
                ? 'You are on track. Keep up your monthly surplus.'
                : 'You are on track. Keep your monthly surplus near ${_compactMoney(requiredSurplus, currencyCode)}.');
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).cardColor
            : const Color(0xFFE5F1E9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _emerald.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lightbulb_outline, color: _gold),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isArabic ? 'رؤية' : 'Insight',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF66DFB4)
                        : _emerald,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.87)
                        : _ink,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
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

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final tokens = context.premiumTokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: tokens.colors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tokens.colors.divider),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? _emerald.withValues(alpha: 0.2)
                      : _emerald.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: isDark ? const Color(0xFF66DFB4) : _emerald,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : _ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    this.valueColor = _ink,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color effectiveValueColor = valueColor == _ink && isDark
        ? Colors.white.withValues(alpha: 0.87)
        : valueColor;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            maxLines: 2,
            style: TextStyle(
              color: isDark ? Colors.white60 : _muted,
              fontSize: 10,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: TextStyle(
                color: effectiveValueColor,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyPoint extends StatelessWidget {
  const _JourneyPoint({
    required this.label,
    required this.date,
    required this.value,
    required this.alignment,
  });

  final String label;
  final String date;
  final String value;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: _gold,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          date,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 8,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment == CrossAxisAlignment.start
              ? AlignmentDirectional.centerStart
              : alignment == CrossAxisAlignment.end
              ? AlignmentDirectional.centerEnd
              : Alignment.center,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _JourneyLine extends StatelessWidget {
  const _JourneyLine({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double todayX = constraints.maxWidth * progress;
          return Stack(
            alignment: AlignmentDirectional.centerStart,
            children: <Widget>[
              Container(height: 2, color: Colors.white.withValues(alpha: 0.2)),
              Container(height: 2, width: todayX, color: _gold),
              const PositionedDirectional(
                start: 0,
                child: _JourneyDot(color: Colors.white),
              ),
              PositionedDirectional(
                start: math.max(0, todayX - 7),
                child: const _JourneyDot(color: _gold, large: true),
              ),
              const PositionedDirectional(
                end: 0,
                child: _JourneyDot(color: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _JourneyDot extends StatelessWidget {
  const _JourneyDot({required this.color, this.large = false});

  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final double size = large ? 14 : 10;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: _emerald, width: 2),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor = _ink,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color effectiveValueColor = valueColor == _ink && isDark
        ? Colors.white.withValues(alpha: 0.87)
        : valueColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white60 : _muted,
                fontSize: 11,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: effectiveValueColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white60
                : _muted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _InteractiveProjectionChart extends StatefulWidget {
  const _InteractiveProjectionChart({
    required this.points,
    required this.startingBalance,
    required this.actualWealth,
    required this.currentMonthIndex,
    required this.totalMonths,
    required this.currencyCode,
    required this.balancesHidden,
    this.height = 190.0,
  });

  final List<ProjectionPoint> points;
  final double startingBalance;
  final double actualWealth;
  final int currentMonthIndex;
  final int totalMonths;
  final String currencyCode;
  final bool balancesHidden;
  final double height;

  @override
  State<_InteractiveProjectionChart> createState() =>
      _InteractiveProjectionChartState();
}

class _InteractiveProjectionChartState
    extends State<_InteractiveProjectionChart> {
  int? _selectedIndex;

  void _handleTouch(double localX, double boxWidth) {
    if (boxWidth <= 0 || widget.points.isEmpty) return;
    final double ratio = localX / boxWidth;
    final int index = (ratio * widget.totalMonths).round() - 1;
    final int clamped = index.clamp(-1, widget.points.length - 1);
    if (_selectedIndex != clamped) {
      setState(() {
        _selectedIndex = clamped;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;

        ProjectionPoint? selectedPoint;
        if (_selectedIndex != null) {
          if (_selectedIndex == -1) {
            selectedPoint = ProjectionPoint(
              monthNumber: 0,
              date: widget.points.isNotEmpty
                  ? widget.points[0].date.subtract(const Duration(days: 30))
                  : DateTime.now(),
              balance: widget.startingBalance,
              income: 0,
              expenses: 0,
              installmentsOutflow: 0,
              zakatOutflow: 0,
            );
          } else if (_selectedIndex! < widget.points.length) {
            selectedPoint = widget.points[_selectedIndex!];
          }
        }
        final bool isToday =
            _selectedIndex != null &&
            _selectedIndex! + 1 == widget.currentMonthIndex;
        final bool showStaticToday =
            _selectedIndex == null &&
            widget.currentMonthIndex >= 0 &&
            widget.currentMonthIndex <= widget.points.length;
        ProjectionPoint? todayPoint;
        if (showStaticToday) {
          if (widget.currentMonthIndex == 0) {
            todayPoint = ProjectionPoint(
              monthNumber: 0,
              date: widget.points.isNotEmpty
                  ? widget.points[0].date.subtract(const Duration(days: 30))
                  : DateTime.now(),
              balance: widget.startingBalance,
              income: 0,
              expenses: 0,
              installmentsOutflow: 0,
              zakatOutflow: 0,
            );
          } else {
            todayPoint = widget.points[widget.currentMonthIndex - 1];
          }
        }

        return GestureDetector(
          onPanStart: (DragStartDetails details) =>
              _handleTouch(details.localPosition.dx, width),
          onPanUpdate: (DragUpdateDetails details) =>
              _handleTouch(details.localPosition.dx, width),
          onPanEnd: (_) {
            setState(() {
              _selectedIndex = null;
            });
          },
          onTapDown: (TapDownDetails details) =>
              _handleTouch(details.localPosition.dx, width),
          onTapUp: (_) {
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                setState(() {
                  _selectedIndex = null;
                });
              }
            });
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              CustomPaint(
                size: Size(width, widget.height),
                painter: _ProjectionChartPainter(
                  points: widget.points,
                  startingBalance: widget.startingBalance,
                  actualWealth: widget.actualWealth,
                  currentMonthIndex: widget.currentMonthIndex,
                  totalMonths: widget.totalMonths,
                  highlightIndex: _selectedIndex,
                ),
              ),
              if (showStaticToday && todayPoint != null) ...<Widget>[
                Positioned(
                  left: math.max(
                    8.0,
                    math.min(
                      width - 138.0,
                      (width * widget.currentMonthIndex / widget.totalMonths) -
                          69.0,
                    ),
                  ),
                  top: 8.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1E1E1E).withValues(alpha: 0.95)
                          : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _emeraldLight.withValues(alpha: 0.35),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          isArabic ? 'اليوم' : 'Today',
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: _emeraldLight,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              '${isArabic ? "المخطط" : "Plan"}: ',
                              style: TextStyle(
                                fontSize: 8,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white54
                                    : _muted,
                              ),
                            ),
                            Text(
                              widget.balancesHidden
                                  ? '••••••'
                                  : _compactMoney(
                                      todayPoint.balance,
                                      widget.currencyCode,
                                    ),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _gold,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              '${isArabic ? "الفعلي" : "Act"}: ',
                              style: TextStyle(
                                fontSize: 8,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white54
                                    : _muted,
                              ),
                            ),
                            Text(
                              widget.balancesHidden
                                  ? '••••••'
                                  : _compactMoney(
                                      widget.actualWealth,
                                      widget.currencyCode,
                                    ),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _emeraldLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (selectedPoint != null) ...<Widget>[
                // Vertical selection line
                Positioned(
                  left: width * (_selectedIndex! + 1) / widget.totalMonths,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 1.5,
                    color: _gold.withValues(alpha: 0.5),
                  ),
                ),
                // Floating tooltip bubble
                Positioned(
                  left: math.max(
                    8.0,
                    math.min(
                      width - (isToday ? 168.0 : 158.0),
                      (width * (_selectedIndex! + 1) / widget.totalMonths) -
                          (isToday ? 84.0 : 75.0),
                    ),
                  ),
                  top: 8.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _gold.withValues(alpha: 0.3)),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          DateFormat(
                            'MMM yyyy',
                            isArabic ? 'ar' : 'en',
                          ).format(selectedPoint.date),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (isToday) ...<Widget>[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                '${isArabic ? "المخطط" : "Planned"}: ',
                                style: TextStyle(
                                  fontSize: 10,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white54
                                      : _muted,
                                ),
                              ),
                              Text(
                                widget.balancesHidden
                                    ? '••••••'
                                    : _compactMoney(
                                        selectedPoint.balance,
                                        widget.currencyCode,
                                      ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _gold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                '${isArabic ? "الفعلي" : "Actual"}: ',
                                style: TextStyle(
                                  fontSize: 10,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white54
                                      : _muted,
                                ),
                              ),
                              Text(
                                widget.balancesHidden
                                    ? '••••••'
                                    : _compactMoney(
                                        widget.actualWealth,
                                        widget.currencyCode,
                                      ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _emeraldLight,
                                ),
                              ),
                            ],
                          ),
                        ] else ...<Widget>[
                          Text(
                            widget.balancesHidden
                                ? '••••••'
                                : _compactMoney(
                                    selectedPoint.balance,
                                    widget.currencyCode,
                                  ),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _gold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ProjectionChartPainter extends CustomPainter {
  const _ProjectionChartPainter({
    required this.points,
    required this.startingBalance,
    required this.actualWealth,
    required this.currentMonthIndex,
    required this.totalMonths,
    this.highlightIndex,
  });

  final List<ProjectionPoint> points;
  final double startingBalance;
  final double actualWealth;
  final int currentMonthIndex;
  final int totalMonths;
  final int? highlightIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (totalMonths <= 0) return;
    final double maxValue = math.max(
      1,
      math.max(
        actualWealth,
        points.fold<double>(
          startingBalance,
          (double value, ProjectionPoint point) =>
              math.max(value, point.balance),
        ),
      ),
    );
    final Paint grid = Paint()
      ..color = _emerald.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final double y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final Paint fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          _gold.withValues(alpha: 0.18),
          _gold.withValues(alpha: 0),
        ],
      ).createShader(Offset.zero & size);
    final Path path = Path();
    final double startY = size.height * (1 - startingBalance / maxValue);
    path.moveTo(0, startY);
    for (int i = 0; i < points.length; i++) {
      path.lineTo(
        size.width * (i + 1) / totalMonths,
        size.height * (1 - points[i].balance / maxValue),
      );
    }
    final Path fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = _gold
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    final double todayX = size.width * currentMonthIndex / totalMonths;
    final double todayY = size.height * (1 - actualWealth / maxValue);
    canvas.drawLine(
      Offset(todayX, 0),
      Offset(todayX, size.height),
      Paint()
        ..color = _emeraldLight.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      Offset(todayX, todayY),
      7,
      Paint()..color = _emeraldLight.withValues(alpha: 0.2),
    );
    canvas.drawCircle(
      Offset(todayX, todayY),
      4,
      Paint()..color = _emeraldLight,
    );
    canvas.drawCircle(
      Offset(
        size.width,
        size.height * (1 - points.lastOrNullBalance / maxValue),
      ),
      5,
      Paint()..color = _emerald,
    );

    // Draw highlight dot if selected
    if (highlightIndex != null) {
      final double x;
      final double y;
      if (highlightIndex == -1) {
        x = 0;
        y = size.height * (1 - startingBalance / maxValue);
      } else {
        x = size.width * (highlightIndex! + 1) / totalMonths;
        y = size.height * (1 - points[highlightIndex!].balance / maxValue);
      }
      canvas.drawCircle(Offset(x, y), 6, Paint()..color = _gold);
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _ProjectionChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.startingBalance != startingBalance ||
        oldDelegate.actualWealth != actualWealth ||
        oldDelegate.currentMonthIndex != currentMonthIndex ||
        oldDelegate.totalMonths != totalMonths;
  }
}

extension on List<ProjectionPoint> {
  double get lastOrNullBalance => isEmpty ? 0 : last.balance;
}

class _Milestone {
  const _Milestone({
    required this.title,
    required this.remaining,
    required this.reached,
    this.date,
  });

  final String title;
  final double remaining;
  final bool reached;
  final DateTime? date;
}

List<_Milestone> _buildMilestones({
  required List<ProjectionPoint> projection,
  required double actualWealth,
  required double projectedEndBalance,
  required DateTime targetDate,
}) {
  final double journey = projectedEndBalance - actualWealth;
  final List<double> goals = <double>[];

  if (journey > 1000.0) {
    final double rawStep = journey / 4.0;
    double roundBase;
    if (rawStep >= 1000000.0) {
      roundBase = 500000.0;
    } else if (rawStep >= 100000.0) {
      roundBase = 50000.0;
    } else if (rawStep >= 10000.0) {
      roundBase = 5000.0;
    } else {
      roundBase = 1000.0;
    }

    for (int i = 1; i <= 3; i++) {
      final double rawGoal = actualWealth + (rawStep * i);
      final double roundedGoal =
          (rawGoal / roundBase).roundToDouble() * roundBase;
      goals.add(roundedGoal);
    }
  } else {
    final double scaleTarget = math.max(projectedEndBalance, actualWealth);
    if (scaleTarget >= 15000000.0) {
      goals.addAll(<double>[3000000.0, 5000000.0, 10000000.0]);
    } else if (scaleTarget >= 3000000.0) {
      goals.addAll(<double>[500000.0, 1000000.0, 2000000.0]);
    } else if (scaleTarget >= 500000.0) {
      goals.addAll(<double>[100000.0, 250000.0, 500000.0]);
    } else {
      goals.addAll(<double>[
        (scaleTarget * 0.25).roundToDouble(),
        (scaleTarget * 0.50).roundToDouble(),
        (scaleTarget * 0.75).roundToDouble(),
      ]);
    }
  }

  // Ensure unique sorted list of intermediate goals
  final List<double> uniqueGoals = goals.toSet().toList()..sort();

  final List<_Milestone> result = <_Milestone>[];
  int lastMatchedIndex = -1;

  for (final double goal in uniqueGoals) {
    if (goal <= 0) continue;
    ProjectionPoint? match;
    for (int i = lastMatchedIndex + 1; i < projection.length; i++) {
      final ProjectionPoint point = projection[i];
      if (point.balance >= goal) {
        match = point;
        lastMatchedIndex = i;
        break;
      }
    }

    result.add(
      _Milestone(
        title: 'Net Worth ${_shortNumber(goal)}',
        remaining: math.max(0, goal - actualWealth),
        reached: actualWealth >= goal,
        date: actualWealth >= goal ? DateTime.now() : match?.date,
      ),
    );
  }

  result.add(
    _Milestone(
      title: 'Target Achieved',
      remaining: math.max(0, projectedEndBalance - actualWealth),
      reached: actualWealth >= projectedEndBalance,
      date: targetDate,
    ),
  );
  return result;
}

String _healthLabel(String code, bool isArabic) {
  if (code == 'ahead') return isArabic ? 'متقدم على الخطة' : 'Ahead';
  if (code == 'behind') return isArabic ? 'يحتاج اهتماماً' : 'Needs Attention';
  return isArabic ? 'على المسار' : 'On Track';
}

String _heroMessage(String code, bool isArabic) {
  if (code == 'ahead') {
    return isArabic
        ? 'أداء ممتاز. حافظ على هذا الزخم.'
        : 'You are doing great. Keep the momentum going.';
  }
  if (code == 'behind') {
    return isArabic
        ? 'يمكن لتعديل بسيط في الفائض إعادتك إلى المسار.'
        : 'A small surplus adjustment can get you back on track.';
  }
  return isArabic
      ? 'أنت تسير بخطى ثابتة نحو هدفك.'
      : 'You are moving steadily toward your goal.';
}

String _allocationLabel(String key, bool isArabic) {
  if (key == 'cash') return isArabic ? 'النقد' : 'Cash';
  if (key == 'gold') return isArabic ? 'الذهب' : 'Gold';
  if (key == 'silver') return isArabic ? 'الفضة' : 'Silver';
  if (key == 'company_investment') {
    return isArabic ? 'استثمارات الشركات' : 'Company Investments';
  }
  if (key == 'real_estate') return isArabic ? 'العقارات' : 'Real Estate';
  return key.replaceAll('_', ' ');
}

Color _allocationColor(int index) {
  const List<Color> colors = <Color>[
    _emeraldLight,
    _gold,
    Color(0xFF9CA8A3),
    Color(0xFF3C7D96),
    Color(0xFF8E6A4B),
    Color(0xFF7868A6),
  ];
  return colors[index % colors.length];
}

String _compactMoney(double value, String currency, {bool? isArabic}) {
  final bool ar = isArabic ?? Intl.getCurrentLocale().startsWith('ar');
  return ZakatEngineService.formatCurrency(
    value,
    currency,
    isArabic: ar,
    compact: true,
  );
}

String _signedCompactMoney(double value, String currency, {bool? isArabic}) {
  final bool ar = isArabic ?? Intl.getCurrentLocale().startsWith('ar');
  return ZakatEngineService.formatCurrency(
    value,
    currency,
    isArabic: ar,
    compact: true,
    showSign: true,
  );
}

String _fullMoney(double value, String currency, {bool? isArabic}) {
  final bool ar = isArabic ?? Intl.getCurrentLocale().startsWith('ar');
  return ZakatEngineService.formatCurrency(
    value,
    currency,
    isArabic: ar,
    compact: false,
  );
}

String _signedFullMoney(double value, String currency, {bool? isArabic}) {
  final bool ar = isArabic ?? Intl.getCurrentLocale().startsWith('ar');
  return ZakatEngineService.formatCurrency(
    value,
    currency,
    isArabic: ar,
    compact: false,
    showSign: true,
  );
}

String _shortNumber(double value) {
  final double absolute = value.abs();
  if (absolute >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(absolute >= 10000000000 ? 1 : 2)}B';
  }
  if (absolute >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(absolute >= 10000000 ? 1 : 2)}M';
  }
  if (absolute >= 1000) {
    return '${(value / 1000).toStringAsFixed(absolute >= 100000 ? 0 : 1)}K';
  }
  return NumberFormat('#,##0.##').format(value);
}

String _date(DateTime value) => DateFormat('dd MMM yyyy').format(value);

class _PlansHeader extends StatelessWidget {
  const _PlansHeader({
    required this.title,
    required this.planName,
    required this.balancesHidden,
    required this.onTogglePrivacy,
    required this.hasNotifications,
    required this.onTapNotifications,
    required this.isArabic,
  });

  final String title;
  final String planName;
  final bool balancesHidden;
  final VoidCallback onTogglePrivacy;
  final bool hasNotifications;
  final VoidCallback onTapNotifications;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = dark ? Colors.white : const Color(0xFF17231F);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isArabic ? 'الخطة: $planName' : 'Plan: $planName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6D7974),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
              iconColor: textColor,
              onPressed: onTogglePrivacy,
            ),
            const SizedBox(width: 10),
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                _HeaderCircleButton(
                  icon: Icons.notifications_none_rounded,
                  iconColor: textColor,
                  onPressed: onTapNotifications,
                ),
                if (hasNotifications)
                  PositionedDirectional(
                    end: 7,
                    top: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD4AF37),
                        shape: BoxShape.circle,
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
          icon: Icon(icon, size: 24, color: iconColor),
        ),
      ),
    );
  }
}
