import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../core/services/zakat_engine.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../models/financial_plan.dart';
import '../../models/transaction.dart';
import '../../models/saving.dart';
import '../../services/app_state_controller.dart';
import '../../services/cash_flow_chart_data_builder.dart';
import '../../services/projection_service.dart';
import '../../services/orientation_controller.dart';

const Color _cashFlowPlannedGold = Color(0xFFD6AC2B);
const Color _cashFlowEmerald = Color(0xFF087A5A);
const Color _cashFlowExpenseRedOrange = Color(0xFFD9433F);
const Color _cashFlowNegativeRed = Color(0xFFD92D20);
const Color _cashFlowNeutral = Color(0xFF171A18);
const Color _cashFlowBackground = Color(0xFFFBFAF6);
const Color _cashFlowSecondaryText = Color(0xFF7C8783);
const Color _cashFlowAxisText = Color(0xFF8CA5A1);
const Color _cashFlowGrid = Color(0xFFE9E6DE);
const Color _cashFlowDivider = Color(0xFFDED9CD);
const Color _cashFlowTooltipBorder = Color(0xFFDDD8CC);

enum CashFlowViewType {
  netFlow,
  cashIn,
  cashOut,
  balance,
  plannedStructure,
}

class CashFlowChartScreen extends StatefulWidget {
  const CashFlowChartScreen({
    super.key,
    required this.planId,
    this.orientationController = const SystemOrientationController(),
  });

  final String planId;
  final OrientationController orientationController;

  static Route<void> route({
    required String planId,
    OrientationController orientationController = const SystemOrientationController(),
  }) {
    return CupertinoPageRoute<void>(
      builder: (BuildContext context) => CashFlowChartScreen(
        planId: planId,
        orientationController: orientationController,
      ),
    );
  }

  @override
  State<CashFlowChartScreen> createState() => _CashFlowChartScreenState();
}

class _CashFlowChartScreenState extends State<CashFlowChartScreen> {
  CashFlowViewType _selectedView = CashFlowViewType.netFlow;
  bool _isCumulative = true;
  int? _hoveredIndex;
  Offset? _tapPosition;

  @override
  void initState() {
    super.initState();
    widget.orientationController.enterLandscape();
  }

  @override
  void dispose() {
    widget.orientationController.restorePortrait();
    super.dispose();
  }

  void _handleTap(TapUpDetails details, BoxConstraints constraints, List<MonthlyCashFlowPoint> points, bool isArabic) {
    final double leftMargin = 12.0;
    final double rightMargin = 20.0;
    final double chartWidth = constraints.maxWidth - leftMargin - rightMargin;

    final double xLocal = details.localPosition.dx;
    if (xLocal < leftMargin || xLocal > constraints.maxWidth - rightMargin) {
      return;
    }

    final double fraction = (xLocal - leftMargin) / chartWidth;
    int index = (fraction * (points.length - 1)).round();
    index = math.max(0, math.min(points.length - 1, index));

    setState(() {
      if (_hoveredIndex == index) {
        _hoveredIndex = null;
        _tapPosition = null;
      } else {
        _hoveredIndex = index;
        _tapPosition = details.localPosition;
      }
    });
  }

  Widget _buildTypeToggle(bool isArabic, dynamic tokens) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.colors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() {
              _isCumulative = true;
              _hoveredIndex = null;
              _tapPosition = null;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _isCumulative ? _cashFlowEmerald : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isArabic ? 'تراكمي' : 'Cumulative',
                style: TextStyle(
                  color: _isCumulative ? Colors.white : tokens.colors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _isCumulative = false;
              _hoveredIndex = null;
              _tapPosition = null;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: !_isCumulative ? _cashFlowEmerald : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isArabic ? 'شهري' : 'Interval',
                style: TextStyle(
                  color: !_isCumulative ? Colors.white : tokens.colors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final tokens = theme.extension<PremiumThemeTokens>() ?? PremiumThemePresets.dark;

    final AppStateController controller = context.watch<AppStateController>();
    final List<FinancialPlan> plans = controller.state.financialPlans;

    final FinancialPlan? plan = plans.cast<FinancialPlan?>().firstWhere(
          (p) => p?.id == widget.planId,
          orElse: () => null,
        );

    if (plan == null) {
      return Scaffold(
        backgroundColor: _cashFlowBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isArabic ? 'لم يتم العثور على الخطة المالية' : 'Financial plan not found',
                style: TextStyle(color: tokens.colors.danger, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isArabic ? 'رجوع' : 'Back'),
              ),
            ],
          ),
        ),
      );
    }

    final List<Transaction> transactions = controller.state.transactions;
    final List<Saving> savings = controller.state.savings;
    final DateTime now = DateTime.now();
    final double cashFlowStartingBalance =
        ProjectionService.cashFlowStartingBalance(plan);

    final List<MonthlyCashFlowPoint> points = const CashFlowChartDataBuilder().build(
      plan: plan,
      transactions: transactions,
      savings: savings,
      investments: controller.state.investments,
      marketData: MarketData.fromJson(controller.state.marketData),
      zakatMethod: controller.state.zakatMethod,
      zakatAnnualDate: controller.state.zakatAnnualDate,
      startingBalanceOverride: cashFlowStartingBalance,
      now: now,
    );

    if (points.isEmpty) {
      return Scaffold(
        backgroundColor: _cashFlowBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isArabic ? 'لا توجد بيانات مخطط كافية' : 'Insufficient chart data available',
                style: TextStyle(color: tokens.colors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isArabic ? 'رجوع' : 'Back'),
              ),
            ],
          ),
        ),
      );
    }

    final MonthlyCashFlowPoint currentMonthPoint = points.firstWhere(
      (p) => p.isCurrentMonth,
      orElse: () => points.last,
    );

    final int currentIdx = points.indexOf(currentMonthPoint);

    double intervalPlannedValue(int index, CashFlowViewType viewType) {
      if (points.isEmpty) return 0.0;
      if (index <= 0) {
        switch (viewType) {
          case CashFlowViewType.netFlow:
            return points[0].plannedNet;
          case CashFlowViewType.cashIn:
            return points[0].plannedCashIn;
          case CashFlowViewType.cashOut:
            return points[0].plannedCashOut;
          case CashFlowViewType.balance:
            return points[0].plannedBalance;
          case CashFlowViewType.plannedStructure:
            return points[0].plannedNet;
        }
      }
      final MonthlyCashFlowPoint current = points[index];
      final MonthlyCashFlowPoint previous = points[index - 1];
      switch (viewType) {
        case CashFlowViewType.netFlow:
          return current.plannedNet - previous.plannedNet;
        case CashFlowViewType.cashIn:
          return current.plannedCashIn - previous.plannedCashIn;
        case CashFlowViewType.cashOut:
          return current.plannedCashOut - previous.plannedCashOut;
        case CashFlowViewType.balance:
          return current.plannedBalance;
        case CashFlowViewType.plannedStructure:
          return current.plannedNet - previous.plannedNet;
      }
    }

    double? intervalActualValue(int index, CashFlowViewType viewType) {
      if (points.isEmpty) return null;
      if (index <= 0) {
        switch (viewType) {
          case CashFlowViewType.netFlow:
            return points[0].actualNet;
          case CashFlowViewType.cashIn:
            return points[0].actualCashIn;
          case CashFlowViewType.cashOut:
            return points[0].actualCashOut;
          case CashFlowViewType.balance:
            return points[0].actualBalance;
          case CashFlowViewType.plannedStructure:
            return points[0].plannedNet;
        }
      }
      final MonthlyCashFlowPoint current = points[index];
      final MonthlyCashFlowPoint previous = points[index - 1];
      switch (viewType) {
        case CashFlowViewType.netFlow:
          if (current.actualNet == null || previous.actualNet == null) return current.actualNet;
          return current.actualNet! - previous.actualNet!;
        case CashFlowViewType.cashIn:
          if (current.actualCashIn == null || previous.actualCashIn == null) return current.actualCashIn;
          return current.actualCashIn! - previous.actualCashIn!;
        case CashFlowViewType.cashOut:
          if (current.actualCashOut == null || previous.actualCashOut == null) return current.actualCashOut;
          return current.actualCashOut! - previous.actualCashOut!;
        case CashFlowViewType.balance:
          return current.actualBalance;
        case CashFlowViewType.plannedStructure:
          return current.plannedNet - previous.plannedNet;
      }
    }

    // Summary Header Calculations: show either interval stats or cumulative stats based on toggle state
    double plannedValTotal = 0.0;
    double? actualValTotal = 0.0;

    if (_isCumulative) {
      // Cumulative Stats
      switch (_selectedView) {
        case CashFlowViewType.netFlow:
          plannedValTotal = currentMonthPoint.plannedNet;
          actualValTotal = currentMonthPoint.actualNet;
          break;
        case CashFlowViewType.cashIn:
          plannedValTotal = currentMonthPoint.plannedCashIn;
          actualValTotal = currentMonthPoint.actualCashIn;
          break;
        case CashFlowViewType.cashOut:
          plannedValTotal = currentMonthPoint.plannedCashOut;
          actualValTotal = currentMonthPoint.actualCashOut;
          break;
        case CashFlowViewType.balance:
          plannedValTotal = currentMonthPoint.plannedBalance;
          actualValTotal = currentMonthPoint.actualBalance;
          break;
        case CashFlowViewType.plannedStructure:
          break;
      }
    } else {
      // Interval Stats (Current Month only)
      switch (_selectedView) {
        case CashFlowViewType.netFlow:
          plannedValTotal = intervalPlannedValue(currentIdx, CashFlowViewType.netFlow);
          actualValTotal = intervalActualValue(currentIdx, CashFlowViewType.netFlow);
          break;
        case CashFlowViewType.cashIn:
          plannedValTotal = intervalPlannedValue(currentIdx, CashFlowViewType.cashIn);
          actualValTotal = intervalActualValue(currentIdx, CashFlowViewType.cashIn);
          break;
        case CashFlowViewType.cashOut:
          plannedValTotal = intervalPlannedValue(currentIdx, CashFlowViewType.cashOut);
          actualValTotal = intervalActualValue(currentIdx, CashFlowViewType.cashOut);
          break;
        case CashFlowViewType.balance:
          plannedValTotal = currentMonthPoint.plannedBalance;
          actualValTotal = currentMonthPoint.actualBalance;
          break;
        case CashFlowViewType.plannedStructure:
          break;
      }
    }

    double plannedIncomeHeader = 0.0;
    double plannedExpenseHeader = 0.0;
    double plannedNetHeader = 0.0;

    if (_isCumulative) {
      plannedIncomeHeader = currentMonthPoint.plannedCashIn;
      plannedExpenseHeader = currentMonthPoint.plannedCashOut;
      plannedNetHeader = currentMonthPoint.plannedNet;
    } else {
      plannedIncomeHeader = intervalPlannedValue(currentIdx, CashFlowViewType.cashIn);
      plannedExpenseHeader = intervalPlannedValue(currentIdx, CashFlowViewType.cashOut);
      plannedNetHeader = intervalPlannedValue(currentIdx, CashFlowViewType.netFlow);
    }

    final double variance = (actualValTotal ?? 0.0) - plannedValTotal;
    final bool cashOutVarianceIsBadWhenPositive =
        _selectedView == CashFlowViewType.cashOut;
    final Color varianceColor = cashOutVarianceIsBadWhenPositive
        ? (variance >= 0 ? tokens.colors.danger : tokens.colors.success)
        : (variance >= 0 ? tokens.colors.success : tokens.colors.danger);
    final double forecastedEndBalance = points.last.actualBalance ?? points.last.plannedBalance;
    final Color balanceNeutralColor = _cashFlowNeutral;

    final String planYearLabel = isArabic
        ? 'الخطة المالية · ${plan.name}'
        : 'Financial Plan · ${plan.name}';

    String formatMoney(double value) {
      final formatter = NumberFormat.currency(
        symbol: '',
        decimalDigits: 0,
      );
      final String formatted = formatter.format(value.abs());
      return value < 0
          ? '-$formatted ${plan.projectionCurrency}'
          : '$formatted ${plan.projectionCurrency}';
    }

    final bool isPlannedStructure = _selectedView == CashFlowViewType.plannedStructure;

    // Y Axis Range calculations for sticky and chart painters
    final List<double> plannedValues = [];
    final List<double?> actualValues = [];
    final List<double> plannedCashInValues = [];
    final List<double> plannedCashOutValues = [];
    final List<double> plannedNetValues = [];

    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      if (_isCumulative) {
        switch (_selectedView) {
          case CashFlowViewType.netFlow:
            plannedValues.add(pt.plannedNet);
            actualValues.add(pt.actualNet);
            break;
          case CashFlowViewType.cashIn:
            plannedValues.add(pt.plannedCashIn);
            actualValues.add(pt.actualCashIn);
            break;
          case CashFlowViewType.cashOut:
            plannedValues.add(pt.plannedCashOut);
            actualValues.add(pt.actualCashOut);
            break;
          case CashFlowViewType.balance:
            plannedValues.add(pt.plannedBalance);
            actualValues.add(pt.actualBalance);
            break;
          case CashFlowViewType.plannedStructure:
            plannedCashInValues.add(pt.plannedCashIn);
            plannedCashOutValues.add(pt.plannedCashOut);
            plannedNetValues.add(pt.plannedNet);
            break;
        }
      } else {
        if (i == 0) {
          switch (_selectedView) {
            case CashFlowViewType.netFlow:
              plannedValues.add(intervalPlannedValue(i, CashFlowViewType.netFlow));
              actualValues.add(intervalActualValue(i, CashFlowViewType.netFlow));
              break;
            case CashFlowViewType.cashIn:
              plannedValues.add(intervalPlannedValue(i, CashFlowViewType.cashIn));
              actualValues.add(intervalActualValue(i, CashFlowViewType.cashIn));
              break;
            case CashFlowViewType.cashOut:
              plannedValues.add(intervalPlannedValue(i, CashFlowViewType.cashOut));
              actualValues.add(intervalActualValue(i, CashFlowViewType.cashOut));
              break;
            case CashFlowViewType.balance:
              plannedValues.add(pt.plannedBalance);
              actualValues.add(pt.actualBalance);
              break;
            case CashFlowViewType.plannedStructure:
              plannedCashInValues.add(intervalPlannedValue(i, CashFlowViewType.cashIn));
              plannedCashOutValues.add(intervalPlannedValue(i, CashFlowViewType.cashOut));
              plannedNetValues.add(intervalPlannedValue(i, CashFlowViewType.netFlow));
              break;
          }
        } else {
          final prev = points[i - 1];
          switch (_selectedView) {
            case CashFlowViewType.netFlow:
              plannedValues.add(pt.plannedNet - prev.plannedNet);
              final double? actCurr = pt.actualNet;
              final double? actPrev = prev.actualNet;
              actualValues.add((actCurr != null && actPrev != null) ? (actCurr - actPrev) : actCurr);
              break;
            case CashFlowViewType.cashIn:
              plannedValues.add(pt.plannedCashIn - prev.plannedCashIn);
              final double? actCurr = pt.actualCashIn;
              final double? actPrev = prev.actualCashIn;
              actualValues.add((actCurr != null && actPrev != null) ? (actCurr - actPrev) : actCurr);
              break;
            case CashFlowViewType.cashOut:
              plannedValues.add(pt.plannedCashOut - prev.plannedCashOut);
              final double? actCurr = pt.actualCashOut;
              final double? actPrev = prev.actualCashOut;
              actualValues.add((actCurr != null && actPrev != null) ? (actCurr - actPrev) : actCurr);
              break;
            case CashFlowViewType.balance:
              plannedValues.add(pt.plannedBalance);
              actualValues.add(pt.actualBalance);
              break;
            case CashFlowViewType.plannedStructure:
              plannedCashInValues.add(pt.plannedCashIn - prev.plannedCashIn);
              plannedCashOutValues.add(pt.plannedCashOut - prev.plannedCashOut);
              plannedNetValues.add(pt.plannedNet - prev.plannedNet);
              break;
          }
        }
      }
    }

    double safeMin = double.infinity;
    double safeMax = -double.infinity;

    if (_selectedView == CashFlowViewType.plannedStructure) {
      for (final val in plannedCashInValues) {
        safeMin = math.min(safeMin, val);
        safeMax = math.max(safeMax, val);
      }
      for (final val in plannedCashOutValues) {
        safeMin = math.min(safeMin, val);
        safeMax = math.max(safeMax, val);
      }
      for (final val in plannedNetValues) {
        safeMin = math.min(safeMin, val);
        safeMax = math.max(safeMax, val);
      }
    } else {
      for (final val in plannedValues) {
        safeMin = math.min(safeMin, val);
        safeMax = math.max(safeMax, val);
      }
      for (final val in actualValues) {
        if (val != null) {
          safeMin = math.min(safeMin, val);
          safeMax = math.max(safeMax, val);
        }
      }
    }

    if (safeMin == safeMax) {
      safeMin -= 1000.0;
      safeMax += 1000.0;
    }

    if (!_isCumulative) {
      safeMin = math.min(safeMin, 0.0);
      safeMax = math.max(safeMax, 0.0);
    }

      return Scaffold(
        backgroundColor: _cashFlowBackground,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // 1. Navigation / Header row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios, color: tokens.colors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isArabic ? 'التدفق النقدي' : 'Cash Flow',
                    style: TextStyle(
                      color: tokens.colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$planYearLabel [${plan.projectionCurrency}]',
                    style: TextStyle(
                      color: tokens.colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 0.5),

            // 2. Summary stats values row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryStatTile(
                      label: isPlannedStructure
                          ? (_isCumulative
                              ? (isArabic ? 'الدخل المخطط (التراكمي)' : 'Planned Income (Cum)')
                              : (isArabic ? 'الدخل المخطط (الحالي)' : 'Planned Income (Current)'))
                          : (_isCumulative
                              ? (isArabic ? 'المخطط (التراكمي)' : 'Planned (Cum)')
                              : (isArabic ? 'المخطط (الحالي)' : 'Planned (Current)')),
                      value: formatMoney(isPlannedStructure ? plannedIncomeHeader : plannedValTotal),
                      color: _cashFlowPlannedGold,
                    ),
                    const SizedBox(width: 20),
                    _SummaryStatTile(
                      label: isPlannedStructure
                          ? (_isCumulative
                              ? (isArabic ? 'المصروفات المخططة (التراكمي)' : 'Planned Expenses (Cum)')
                              : (isArabic ? 'المصروفات المخططة (الحالي)' : 'Planned Expenses (Current)'))
                          : (currentMonthPoint.isCurrentMonth
                              ? (isArabic ? 'الفعلي (حتى تاريخه)' : 'Actual (Month to Date)')
                              : (_isCumulative
                                  ? (isArabic ? 'الفعلي (التراكمي)' : 'Actual (Cum)')
                                  : (isArabic ? 'الفعلي (الحالي)' : 'Actual (Current)'))),
                      value: isPlannedStructure
                          ? formatMoney(plannedExpenseHeader)
                          : (actualValTotal != null ? formatMoney(actualValTotal) : (isArabic ? 'غير متوفر' : 'N/A')),
                      color: isPlannedStructure ? _cashFlowExpenseRedOrange : _cashFlowEmerald,
                    ),
                    const SizedBox(width: 20),
                    _SummaryStatTile(
                      label: isPlannedStructure
                          ? (_isCumulative
                              ? (isArabic ? 'الصافي المخطط (التراكمي)' : 'Planned Net (Cum)')
                              : (isArabic ? 'الصافي المخطط (الحالي)' : 'Planned Net (Current)'))
                          : (isArabic ? 'الانحراف' : 'Variance'),
                      value: isPlannedStructure
                          ? formatMoney(plannedNetHeader)
                          : (actualValTotal != null ? formatMoney(variance) : (isArabic ? 'غير متوفر' : 'N/A')),
                      color: isPlannedStructure
                          ? _cashFlowEmerald
                          : varianceColor,
                    ),
                    const SizedBox(width: 20),
                    _SummaryStatTile(
                      label: isArabic ? 'رصيد نهاية الخطة المتوقع' : 'Projected End Balance',
                      value: formatMoney(points.last.plannedBalance),
                      color: balanceNeutralColor,
                    ),
                    const SizedBox(width: 20),
                    _SummaryStatTile(
                      label: isArabic ? 'رصيد نهاية الخطة المتوقعة' : 'Forecasted End Balance',
                      value: formatMoney(forecastedEndBalance),
                      color: balanceNeutralColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),

            // 3. Tab Selectors & Cumulative Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _SelectorButton(
                            label: isArabic ? 'صافي التدفق' : 'Net Flow',
                            isSelected: _selectedView == CashFlowViewType.netFlow,
                            onTap: () => setState(() {
                              _selectedView = CashFlowViewType.netFlow;
                              _hoveredIndex = null;
                              _tapPosition = null;
                            }),
                            tokens: tokens,
                          ),
                          const SizedBox(width: 8),
                          _SelectorButton(
                            label: isArabic ? 'التدفقات الداخلة' : 'Cash In',
                            isSelected: _selectedView == CashFlowViewType.cashIn,
                            onTap: () => setState(() {
                              _selectedView = CashFlowViewType.cashIn;
                              _hoveredIndex = null;
                              _tapPosition = null;
                            }),
                            tokens: tokens,
                          ),
                          const SizedBox(width: 8),
                          _SelectorButton(
                            label: isArabic ? 'التدفقات الخارجة' : 'Cash Out',
                            isSelected: _selectedView == CashFlowViewType.cashOut,
                            onTap: () => setState(() {
                              _selectedView = CashFlowViewType.cashOut;
                              _hoveredIndex = null;
                              _tapPosition = null;
                            }),
                            tokens: tokens,
                          ),
                          const SizedBox(width: 8),
                          _SelectorButton(
                            label: isArabic ? 'الرصيد' : 'Balance',
                            isSelected: _selectedView == CashFlowViewType.balance,
                            onTap: () => setState(() {
                              _selectedView = CashFlowViewType.balance;
                              _hoveredIndex = null;
                              _tapPosition = null;
                            }),
                            tokens: tokens,
                          ),
                          const SizedBox(width: 8),
                          _SelectorButton(
                            label: isArabic ? 'الخطة المقدرة' : 'Planned Flow',
                            isSelected: _selectedView == CashFlowViewType.plannedStructure,
                            onTap: () => setState(() {
                              _selectedView = CashFlowViewType.plannedStructure;
                              _hoveredIndex = null;
                              _tapPosition = null;
                            }),
                            tokens: tokens,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  _buildTypeToggle(isArabic, tokens),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 4. Interactive Chart Area (Sticky Y-axis on the left, horizontally scrollable lines/columns on the right)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sticky Y Axis Painter Container
                  SizedBox(
                    width: 50,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 20.0),
                      child: CustomPaint(
                        painter: _StickyYAxisPainter(
                          safeMin: safeMin,
                          safeMax: safeMax,
                          tokens: tokens,
                          selectedLocale: Localizations.localeOf(context).toString(),
                        ),
                      ),
                    ),
                  ),
                  // Scrollable Chart Container
                  Expanded(
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final double baseWidth = constraints.maxWidth;
                        final double chartWidth = points.length > 24
                            ? (baseWidth * (points.length / 24.0))
                            : baseWidth;

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: chartWidth,
                            height: constraints.maxHeight,
                            child: GestureDetector(
                              onTapUp: (details) => _handleTap(
                                details,
                                BoxConstraints.tightFor(width: chartWidth, height: constraints.maxHeight),
                                points,
                                isArabic,
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(4, 8, 16, 20),
                                      child: CustomPaint(
                                        painter: _CashFlowChartPainter(
                                          points: points,
                                          viewType: _selectedView,
                                          isCumulative: _isCumulative,
                                          safeMin: safeMin,
                                          safeMax: safeMax,
                                          tokens: tokens,
                                          selectedLocale: Localizations.localeOf(context).toString(),
                                          isArabic: isArabic,
                                          hoveredIndex: _hoveredIndex,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Tooltip layer
                                  if (_hoveredIndex != null && _tapPosition != null && _hoveredIndex! < points.length) ...[
                                    Builder(
                                      builder: (context) {
                                        final int idx = _hoveredIndex!;
                                        final pt = points[idx];
                                        double planned = 0.0;
                                        double? actual;

                                        // Compute values representing the chart's current state (cumulative or interval)
                                        if (_isCumulative) {
                                          switch (_selectedView) {
                                            case CashFlowViewType.netFlow:
                                              planned = pt.plannedNet;
                                              actual = pt.actualNet;
                                              break;
                                            case CashFlowViewType.cashIn:
                                              planned = pt.plannedCashIn;
                                              actual = pt.actualCashIn;
                                              break;
                                            case CashFlowViewType.cashOut:
                                              planned = pt.plannedCashOut;
                                              actual = pt.actualCashOut;
                                              break;
                                            case CashFlowViewType.balance:
                                              planned = pt.plannedBalance;
                                              actual = pt.actualBalance;
                                              break;
                                            case CashFlowViewType.plannedStructure:
                                              break;
                                          }
                                        } else {
                                          switch (_selectedView) {
                                            case CashFlowViewType.netFlow:
                                              planned = intervalPlannedValue(idx, CashFlowViewType.netFlow);
                                              actual = intervalActualValue(idx, CashFlowViewType.netFlow);
                                              break;
                                            case CashFlowViewType.cashIn:
                                              planned = intervalPlannedValue(idx, CashFlowViewType.cashIn);
                                              actual = intervalActualValue(idx, CashFlowViewType.cashIn);
                                              break;
                                            case CashFlowViewType.cashOut:
                                              planned = intervalPlannedValue(idx, CashFlowViewType.cashOut);
                                              actual = intervalActualValue(idx, CashFlowViewType.cashOut);
                                              break;
                                            case CashFlowViewType.balance:
                                              planned = pt.plannedBalance;
                                              actual = pt.actualBalance;
                                              break;
                                            case CashFlowViewType.plannedStructure:
                                              break;
                                          }
                                        }

                                        final String monthStr = DateFormat.MMMM(
                                          Localizations.localeOf(context).toString(),
                                        ).format(pt.month);

                                        final String planLabel = _isCumulative
                                            ? (isArabic ? 'المخطط (التراكمي)' : 'Planned (Cum)')
                                            : (isArabic ? 'المخطط' : 'Planned');

                                        final bool isForecastBalancePoint =
                                            _selectedView == CashFlowViewType.balance &&
                                            idx > currentIdx &&
                                            !pt.isCurrentMonth;
                                        final String actualLabel = isForecastBalancePoint
                                            ? (isArabic ? 'التوقع' : 'Forecast')
                                            : (pt.isCurrentMonth
                                                ? (isArabic ? 'الفعلي (حتى تاريخه)' : 'Actual (MTD)')
                                                : (_isCumulative
                                                    ? (isArabic ? 'الفعلي (التراكمي)' : 'Actual (Cum)')
                                                    : (isArabic ? 'الفعلي' : 'Actual')));

                                        final double varianceVal = (actual ?? 0.0) - planned;
                                        final String varianceSign = varianceVal >= 0 ? '+' : '';

                                        String percentStr = '';
                                        if (planned != 0.0 && actual != null) {
                                          final double pct = (varianceVal / planned.abs()) * 100;
                                          percentStr = ' ($varianceSign${pct.toStringAsFixed(1)}%)';
                                        }

                                        return Positioned(
                                          left: math.max(16.0, math.min(chartWidth - 200.0, _tapPosition!.dx - 100.0)),
                                          top: math.max(8.0, _tapPosition!.dy - 110.0),
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            width: 180,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.95),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: _cashFlowTooltipBorder),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.25),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  monthStr,
                                                  style: TextStyle(
                                                    color: tokens.colors.textPrimary,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                if (_selectedView == CashFlowViewType.plannedStructure) ...[
                                                  Text(
                                                    '${_isCumulative ? (isArabic ? 'دخل مخطط (تراكمي)' : 'Planned Income (Cum)') : (isArabic ? 'الدخل المخطط' : 'Planned Income')}: ${formatMoney(_isCumulative ? pt.plannedCashIn : (idx == 0 ? pt.plannedCashIn : pt.plannedCashIn - points[idx - 1].plannedCashIn))}',
                                                    style: TextStyle(color: _cashFlowPlannedGold, fontSize: 11),
                                                  ),
                                                  Text(
                                                    '${_isCumulative ? (isArabic ? 'مصروف مخطط (تراكمي)' : 'Planned Expenses (Cum)') : (isArabic ? 'المصروفات المخططة' : 'Planned Expenses')}: ${formatMoney(_isCumulative ? pt.plannedCashOut : (idx == 0 ? pt.plannedCashOut : pt.plannedCashOut - points[idx - 1].plannedCashOut))}',
                                                    style: TextStyle(color: _cashFlowExpenseRedOrange, fontSize: 11),
                                                  ),
                                                  Text(
                                                    '${_isCumulative ? (isArabic ? 'صافي مخطط (تراكمي)' : 'Planned Net (Cum)') : (isArabic ? 'الصافي المخطط' : 'Planned Net')}: ${formatMoney(_isCumulative ? pt.plannedNet : (idx == 0 ? pt.plannedNet : pt.plannedNet - points[idx - 1].plannedNet))}',
                                                    style: TextStyle(color: _cashFlowEmerald, fontSize: 11),
                                                  ),
                                                ] else ...[
                                                  Text(
                                                    '$planLabel: ${formatMoney(planned)}',
                                                    style: TextStyle(color: _cashFlowPlannedGold, fontSize: 11),
                                                  ),
                                                  Text(
                                                    '$actualLabel: ${actual != null ? formatMoney(actual) : (isArabic ? 'غير متوفر' : 'N/A')}',
                                                    style: TextStyle(color: _cashFlowEmerald, fontSize: 11),
                                                  ),
                                                  if (actual != null)
                                                    Text(
                                                      '${isArabic ? 'الانحراف' : 'Variance'}: $varianceSign${formatMoney(varianceVal)}$percentStr',
                                                      style: TextStyle(
                                                        color: _selectedView == CashFlowViewType.cashOut
                                                            ? (varianceVal >= 0 ? _cashFlowNegativeRed : _cashFlowEmerald)
                                                            : (varianceVal >= 0 ? _cashFlowEmerald : _cashFlowNegativeRed),
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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

class _StickyYAxisPainter extends CustomPainter {
  const _StickyYAxisPainter({
    required this.safeMin,
    required this.safeMax,
    required this.tokens,
    required this.selectedLocale,
  });

  final double safeMin;
  final double safeMax;
  final dynamic tokens;
  final String selectedLocale;

  @override
  void paint(Canvas canvas, Size size) {
    final double topMargin = 20.0;
    final double bottomMargin = 20.0;
    final double chartHeight = size.height - topMargin - bottomMargin;
    final double yRange = safeMax - safeMin;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= 4; i++) {
      final double fraction = i / 4;
      final double yVal = safeMin + (fraction * yRange);
      final double fractionY = (yVal - safeMin) / yRange;
      final double yPos = size.height - bottomMargin - (fractionY * chartHeight);

      final NumberFormat numberFormatter = NumberFormat.compact(locale: selectedLocale);
      textPainter.text = TextSpan(
        text: numberFormatter.format(yVal),
        style: const TextStyle(color: _cashFlowAxisText, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(size.width - textPainter.width - 8, yPos - (textPainter.height / 2)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StickyYAxisPainter oldDelegate) {
    return oldDelegate.safeMin != safeMin ||
        oldDelegate.safeMax != safeMax ||
        oldDelegate.selectedLocale != selectedLocale;
  }
}

class _SummaryStatTile extends StatelessWidget {
  const _SummaryStatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: _cashFlowSecondaryText, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

class _SelectorButton extends StatelessWidget {
  const _SelectorButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.tokens,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final dynamic tokens;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _cashFlowEmerald : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _cashFlowEmerald : _cashFlowDivider,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : _cashFlowNeutral,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _CashFlowChartPainter extends CustomPainter {
  const _CashFlowChartPainter({
    required this.points,
    required this.viewType,
    required this.isCumulative,
    required this.safeMin,
    required this.safeMax,
    required this.tokens,
    required this.selectedLocale,
    required this.isArabic,
    this.hoveredIndex,
  });

  final List<MonthlyCashFlowPoint> points;
  final CashFlowViewType viewType;
  final bool isCumulative;
  final double safeMin;
  final double safeMax;
  final dynamic tokens;
  final String selectedLocale;
  final bool isArabic;
  final int? hoveredIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final double leftMargin = 12.0;
    final double rightMargin = 20.0;
    final double topMargin = 20.0;
    final double bottomMargin = 20.0;

    final double chartWidth = size.width - leftMargin - rightMargin;
    final double chartHeight = size.height - topMargin - bottomMargin;

    if (points.isEmpty) return;

    final List<double> plannedValues = [];
    final List<double?> actualValues = [];

    final List<double> plannedCashInValues = [];
    final List<double> plannedCashOutValues = [];
    final List<double> plannedNetValues = [];

    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      if (isCumulative) {
        switch (viewType) {
          case CashFlowViewType.netFlow:
            plannedValues.add(pt.plannedNet);
            actualValues.add(pt.actualNet);
            break;
          case CashFlowViewType.cashIn:
            plannedValues.add(pt.plannedCashIn);
            actualValues.add(pt.actualCashIn);
            break;
          case CashFlowViewType.cashOut:
            plannedValues.add(pt.plannedCashOut);
            actualValues.add(pt.actualCashOut);
            break;
          case CashFlowViewType.balance:
            plannedValues.add(pt.plannedBalance);
            actualValues.add(pt.actualBalance);
            break;
          case CashFlowViewType.plannedStructure:
            plannedCashInValues.add(pt.plannedCashIn);
            plannedCashOutValues.add(pt.plannedCashOut);
            plannedNetValues.add(pt.plannedNet);
            break;
        }
      } else {
        if (i == 0) {
          switch (viewType) {
            case CashFlowViewType.netFlow:
              plannedValues.add(pt.plannedNet);
              actualValues.add(pt.actualNet);
              break;
            case CashFlowViewType.cashIn:
              plannedValues.add(pt.plannedCashIn);
              actualValues.add(pt.actualCashIn);
              break;
            case CashFlowViewType.cashOut:
              plannedValues.add(pt.plannedCashOut);
              actualValues.add(pt.actualCashOut);
              break;
            case CashFlowViewType.balance:
              plannedValues.add(pt.plannedBalance);
              actualValues.add(pt.actualBalance);
              break;
            case CashFlowViewType.plannedStructure:
              plannedCashInValues.add(pt.plannedCashIn);
              plannedCashOutValues.add(pt.plannedCashOut);
              plannedNetValues.add(pt.plannedNet);
              break;
          }
        } else {
          final prev = points[i - 1];
          switch (viewType) {
            case CashFlowViewType.netFlow:
              plannedValues.add(pt.plannedNet - prev.plannedNet);
              final double? actCurr = pt.actualNet;
              final double? actPrev = prev.actualNet;
              actualValues.add((actCurr != null && actPrev != null) ? (actCurr - actPrev) : actCurr);
              break;
            case CashFlowViewType.cashIn:
              plannedValues.add(pt.plannedCashIn - prev.plannedCashIn);
              final double? actCurr = pt.actualCashIn;
              final double? actPrev = prev.actualCashIn;
              actualValues.add((actCurr != null && actPrev != null) ? (actCurr - actPrev) : actCurr);
              break;
            case CashFlowViewType.cashOut:
              plannedValues.add(pt.plannedCashOut - prev.plannedCashOut);
              final double? actCurr = pt.actualCashOut;
              final double? actPrev = prev.actualCashOut;
              actualValues.add((actCurr != null && actPrev != null) ? (actCurr - actPrev) : actCurr);
              break;
            case CashFlowViewType.balance:
              plannedValues.add(pt.plannedBalance);
              actualValues.add(pt.actualBalance);
              break;
            case CashFlowViewType.plannedStructure:
              plannedCashInValues.add(pt.plannedCashIn - prev.plannedCashIn);
              plannedCashOutValues.add(pt.plannedCashOut - prev.plannedCashOut);
              plannedNetValues.add(pt.plannedNet - prev.plannedNet);
              break;
          }
        }
      }
    }

    final double yRange = safeMax - safeMin;

    double getX(int index) {
      final double fraction = index / (points.length - 1);
      if (isArabic) {
        return size.width - rightMargin - (fraction * chartWidth);
      } else {
        return leftMargin + (fraction * chartWidth);
      }
    }

    double getY(double value) {
      final double fraction = (value - safeMin) / yRange;
      return size.height - bottomMargin - (fraction * chartHeight);
    }

    // 1. Draw grid lines
    final gridLinePaint = Paint()
      ..color = _cashFlowGrid.withValues(alpha: 0.9)
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 4; i++) {
      final double fraction = i / 4;
      final double yVal = safeMin + (fraction * yRange);
      final double yPos = getY(yVal);

      canvas.drawLine(
        Offset(leftMargin, yPos),
        Offset(size.width - rightMargin, yPos),
        gridLinePaint,
      );
    }

    // 2. Draw Zero Baseline
    if (safeMin < 0.0 && safeMax > 0.0) {
      final zeroPaint = Paint()
        ..color = _cashFlowAxisText.withValues(alpha: 0.8)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(leftMargin, getY(0.0)),
        Offset(size.width - rightMargin, getY(0.0)),
        zeroPaint,
      );
    }

    // 3. Draw month labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < points.length; i++) {
      final DateTime month = points[i].month;
      final String monthStr = DateFormat.MMM(selectedLocale).format(month);
      final double xPos = getX(i);

      textPainter.text = TextSpan(
        text: monthStr,
        style: TextStyle(
          color: hoveredIndex == i ? _cashFlowPlannedGold : _cashFlowSecondaryText,
          fontWeight: hoveredIndex == i ? FontWeight.bold : FontWeight.normal,
          fontSize: 9,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(xPos - (textPainter.width / 2), size.height - bottomMargin + 4),
      );

        if (hoveredIndex == i) {
        final hoverColPaint = Paint()
          ..color = _cashFlowPlannedGold.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill;
        canvas.drawRect(
          Rect.fromLTRB(xPos - 12, topMargin, xPos + 12, size.height - bottomMargin),
          hoverColPaint,
        );
      }
    }

    if (!isCumulative) {
      // Draw Column Chart (Interval view)
        final double spacing = points.length > 1 ? (getX(1) - getX(0)).abs() : chartWidth;
      final double barWidth = spacing * 0.32;

      if (viewType == CashFlowViewType.plannedStructure) {
        final double subBarWidth = spacing * 0.22;
        final plannedInBarPaint = Paint()..color = _cashFlowPlannedGold..style = PaintingStyle.fill;
        final plannedOutBarPaint = Paint()..color = _cashFlowExpenseRedOrange..style = PaintingStyle.fill;
        final plannedNetBarPaint = Paint()..color = _cashFlowEmerald..style = PaintingStyle.fill;

        for (int i = 0; i < points.length; i++) {
          final double x = getX(i);
          final double yZero = getY(0.0);

          final double yIn = getY(plannedCashInValues[i]);
          canvas.drawRect(
            Rect.fromLTRB(x - subBarWidth * 1.5, math.min(yZero, yIn), x - subBarWidth * 0.5, math.max(yZero, yIn)),
            plannedInBarPaint,
          );

          final double yOut = getY(plannedCashOutValues[i]);
          canvas.drawRect(
            Rect.fromLTRB(x - subBarWidth * 0.5, math.min(yZero, yOut), x + subBarWidth * 0.5, math.max(yZero, yOut)),
            plannedOutBarPaint,
          );

          final double yNet = getY(plannedNetValues[i]);
          canvas.drawRect(
            Rect.fromLTRB(x + subBarWidth * 0.5, math.min(yZero, yNet), x + subBarWidth * 1.5, math.max(yZero, yNet)),
            plannedNetBarPaint,
          );
        }
      } else {
        final plannedBarPaint = Paint()..color = _cashFlowPlannedGold.withValues(alpha: 0.75)..style = PaintingStyle.fill;
        final actualBarPaint = Paint()..color = _cashFlowEmerald..style = PaintingStyle.fill;

        for (int i = 0; i < points.length; i++) {
          final double x = getX(i);
          final double yZero = getY(0.0);

          final double yPlan = getY(plannedValues[i]);
          canvas.drawRect(
            Rect.fromLTRB(x - barWidth, math.min(yZero, yPlan), x - 1, math.max(yZero, yPlan)),
            plannedBarPaint,
          );

          final double? actVal = actualValues[i];
          if (actVal != null) {
            final double yAct = getY(actVal);
            canvas.drawRect(
              Rect.fromLTRB(x + 1, math.min(yZero, yAct), x + barWidth, math.max(yZero, yAct)),
              actualBarPaint,
            );
          }
        }
      }
    } else {
      // Draw Line Chart (Cumulative view)
      if (viewType == CashFlowViewType.plannedStructure) {
        // Draw planned structure series with dashed strokes so it reads as a forecasted trend.
        final cashInPaint = Paint()
          ..color = _cashFlowPlannedGold.withValues(alpha: 0.9)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        final Path cashInPath = Path();
        for (int i = 0; i < plannedCashInValues.length; i++) {
          final double x = getX(i);
          final double y = getY(plannedCashInValues[i]);
          if (i == 0) {
            cashInPath.moveTo(x, y);
          } else {
            cashInPath.lineTo(x, y);
          }
        }
        _drawDashedPath(canvas, cashInPath, cashInPaint, dashWidth: 6.0, dashSpace: 4.0);

        // Draw Cash-Out
        final cashOutPaint = Paint()
          ..color = _cashFlowExpenseRedOrange.withValues(alpha: 0.9)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        final Path cashOutPath = Path();
        for (int i = 0; i < plannedCashOutValues.length; i++) {
          final double x = getX(i);
          final double y = getY(plannedCashOutValues[i]);
          if (i == 0) {
            cashOutPath.moveTo(x, y);
          } else {
            cashOutPath.lineTo(x, y);
          }
        }
        _drawDashedPath(canvas, cashOutPath, cashOutPaint, dashWidth: 6.0, dashSpace: 4.0);

        // Draw Net Flow
        final netFlowPaint = Paint()
          ..color = _cashFlowEmerald.withValues(alpha: 0.9)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        final Path netFlowPath = Path();
        for (int i = 0; i < plannedNetValues.length; i++) {
          final double x = getX(i);
          final double y = getY(plannedNetValues[i]);
          if (i == 0) {
            netFlowPath.moveTo(x, y);
          } else {
            netFlowPath.lineTo(x, y);
          }
        }
        _drawDashedPath(canvas, netFlowPath, netFlowPaint, dashWidth: 6.0, dashSpace: 4.0);

        final dotPaint = Paint()..style = PaintingStyle.fill;
        for (int i = 0; i < points.length; i++) {
          final double x = getX(i);
          dotPaint.color = i == hoveredIndex ? _cashFlowPlannedGold : _cashFlowPlannedGold.withValues(alpha: 0.95);
          canvas.drawCircle(Offset(x, getY(plannedCashInValues[i])), i == hoveredIndex ? 5.5 : 3.5, dotPaint);

          dotPaint.color = i == hoveredIndex ? _cashFlowExpenseRedOrange : _cashFlowExpenseRedOrange.withValues(alpha: 0.95);
          canvas.drawCircle(Offset(x, getY(plannedCashOutValues[i])), i == hoveredIndex ? 5.5 : 3.5, dotPaint);

          dotPaint.color = i == hoveredIndex ? _cashFlowEmerald : _cashFlowEmerald.withValues(alpha: 0.95);
          canvas.drawCircle(Offset(x, getY(plannedNetValues[i])), i == hoveredIndex ? 5.5 : 3.5, dotPaint);
        }
      } else {
        final plannedPaint = Paint()
          ..color = _cashFlowPlannedGold.withValues(alpha: 0.65)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        final Path plannedPath = Path();
        for (int i = 0; i < plannedValues.length; i++) {
          final double x = getX(i);
          final double y = getY(plannedValues[i]);
          if (i == 0) {
            plannedPath.moveTo(x, y);
          } else {
            plannedPath.lineTo(x, y);
          }
        }

        _drawDashedPath(canvas, plannedPath, plannedPaint, dashWidth: 6.0, dashSpace: 4.0);

        final actualPaint = Paint()
          ..color = _cashFlowEmerald
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        final int currentIdx = points.indexWhere((p) => p.isCurrentMonth);
        final int effectiveCurrentIdx = currentIdx != -1 ? currentIdx : points.length - 1;

        if (viewType == CashFlowViewType.balance) {
          // Draw solid actual balance line up to currentIdx
          final Path solidActualPath = Path();
          bool hasSolidMoved = false;
          for (int i = 0; i <= effectiveCurrentIdx; i++) {
            final double? val = actualValues[i];
            if (val == null) continue;
            final double x = getX(i);
            final double y = getY(val);
            if (!hasSolidMoved) {
              solidActualPath.moveTo(x, y);
              hasSolidMoved = true;
            } else {
              solidActualPath.lineTo(x, y);
            }
          }
          if (hasSolidMoved) {
            canvas.drawPath(solidActualPath, actualPaint);
          }

          // Draw dashed forecast balance line from currentIdx to end
          final Path dashedActualPath = Path();
          bool hasDashedMoved = false;
          for (int i = effectiveCurrentIdx; i < actualValues.length; i++) {
            final double? val = actualValues[i];
            if (val == null) continue;
            final double x = getX(i);
            final double y = getY(val);
            if (!hasDashedMoved) {
              dashedActualPath.moveTo(x, y);
              hasDashedMoved = true;
            } else {
              dashedActualPath.lineTo(x, y);
            }
          }
          if (hasDashedMoved) {
            final forecastPaint = Paint()
              ..color = _cashFlowEmerald.withValues(alpha: 0.7)
              ..strokeWidth = 2.0
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round;
            _drawDashedPath(canvas, dashedActualPath, forecastPaint, dashWidth: 6.0, dashSpace: 4.0);
          }
        } else {
          // Standard actual line (breaks at nulls)
          final Path actualPath = Path();
          bool hasMoved = false;

          for (int i = 0; i < actualValues.length; i++) {
            final double? val = actualValues[i];
            if (val == null) {
              break;
            }
            final double x = getX(i);
            final double y = getY(val);
            if (!hasMoved) {
              actualPath.moveTo(x, y);
              hasMoved = true;
            } else {
              actualPath.lineTo(x, y);
            }
          }

          if (hasMoved) {
            canvas.drawPath(actualPath, actualPaint);
          }
        }

        final dotPaint = Paint()..style = PaintingStyle.fill;
        for (int i = 0; i < points.length; i++) {
          final double x = getX(i);

          dotPaint.color = _cashFlowPlannedGold;
          canvas.drawCircle(Offset(x, getY(plannedValues[i])), i == hoveredIndex ? 5.0 : 3.0, dotPaint);

          final double? actVal = actualValues[i];
          if (actVal != null) {
            dotPaint.color = _cashFlowEmerald;
            canvas.drawCircle(Offset(x, getY(actVal)), i == hoveredIndex ? 6.0 : 4.0, dotPaint);
          }
        }
      }
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, {required double dashWidth, required double dashSpace}) {
    final Path dest = Path();
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double len = math.min(dashWidth, metric.length - distance);
        dest.addPath(metric.extractPath(distance, distance + len), Offset.zero);
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dest, paint);
  }

  @override
  bool shouldRepaint(covariant _CashFlowChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.viewType != viewType ||
        oldDelegate.isCumulative != isCumulative ||
        oldDelegate.safeMin != safeMin ||
        oldDelegate.safeMax != safeMax ||
        oldDelegate.hoveredIndex != hoveredIndex;
  }
}
