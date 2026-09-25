import '../core/services/zakat_engine.dart';
import '../models/financial_plan.dart';
import '../models/investment_asset.dart';
import '../models/saving.dart';
import '../models/transaction.dart';
import 'projection_service.dart';

class MonthlyCashFlowPoint {
  const MonthlyCashFlowPoint({
    required this.month,
    required this.plannedCashIn,
    required this.plannedCashOut,
    required this.plannedBalance,
    this.actualCashIn,
    this.actualCashOut,
    this.actualBalance,
    required this.isCurrentMonth,
  });

  final DateTime month;
  final double plannedCashIn;
  final double plannedCashOut;
  final double plannedBalance;

  final double? actualCashIn;
  final double? actualCashOut;
  final double? actualBalance;

  final bool isCurrentMonth;

  double get plannedNet => plannedCashIn - plannedCashOut;

  double? get actualNet {
    final double? cashIn = actualCashIn;
    final double? cashOut = actualCashOut;
    if (cashIn == null || cashOut == null) {
      return null;
    }
    return cashIn - cashOut;
  }

  double? get netVariance {
    final double? actNet = actualNet;
    if (actNet == null) {
      return null;
    }
    return actNet - plannedNet;
  }
}

class CashFlowChartDataBuilder {
  const CashFlowChartDataBuilder();

  List<MonthlyCashFlowPoint> build({
    required FinancialPlan plan,
    required Iterable<Transaction> transactions,
    required List<Saving> savings,
    required List<InvestmentAsset> investments,
    required MarketData marketData,
    required String zakatMethod,
    required String zakatAnnualDate,
    String? lastRollover,
    String? zakatNisabBasis,
    double? startingBalanceOverride,
    required DateTime now,
  }) {
    final DateTime planStart = DateTime.tryParse(plan.startDate) ?? now;
    final DateTime planStartMonth = DateTime(planStart.year, planStart.month);
    final int totalMonths = plan.durationYears * 12;
    final double startingBalance =
        startingBalanceOverride ?? ProjectionService.cashFlowStartingBalance(plan);

    // Call projection service to calculate accurate planned timeline
    final List<ProjectionPoint> projection = ProjectionService.calculateProjection(
      plan: plan,
      transactions: transactions.toList(growable: false),
      savings: savings,
      investments: investments,
      marketData: marketData,
      zakatMethod: zakatMethod,
      zakatAnnualDate: zakatAnnualDate,
      startingBalanceOverride: startingBalance,
      now: now,
      lastRollover: lastRollover,
      zakatNisabBasis: zakatNisabBasis,
    );

    final List<MonthlyCashFlowPoint> points = <MonthlyCashFlowPoint>[];

    double cumulativePlannedCashIn = 0.0;
    double cumulativePlannedCashOut = 0.0;
    double cumulativeActualCashIn = 0.0;
    double cumulativeActualCashOut = 0.0;

    final DateTime planEnd = DateTime(
      planStart.year + plan.durationYears,
      planStart.month,
      planStart.day,
    );

    // Filter relevant actual transactions:
    // 1. Inclusions/exclusions (no transfers, no currency exchange)
    // 2. Exact start/end date range
    final List<Transaction> validTransactions = transactions.where((Transaction tx) {
      final DateTime? txDate = DateTime.tryParse(tx.date);
      if (txDate == null) return false;

      if (txDate.isBefore(planStart) || txDate.isAfter(planEnd)) {
        return false;
      }

      final String categoryLower = tx.category.trim().toLowerCase();
      if (tx.type == 'transfer' ||
          tx.isTransferActivity ||
          categoryLower == 'currency exchange' ||
          categoryLower == 'exchange') {
        return false;
      }

      return true;
    }).toList();

    double lastActualBalance = startingBalance;
    double currentMonthPlannedBalance = startingBalance;

    final DateTime currentMonthStart = DateTime(now.year, now.month);

    for (int i = 0; i < totalMonths; i++) {
      final DateTime monthDate = DateTime(planStartMonth.year, planStartMonth.month + i);

      // Get matching planned projection data point
      double plannedIncome = 0.0;
      double plannedExpenses = 0.0;
      double plannedBalance = startingBalance;

      if (i < projection.length) {
        final ProjectionPoint pt = projection[i];
        plannedIncome = pt.income;
        plannedExpenses = pt.expenses + pt.installmentsOutflow + pt.zakatOutflow;
        plannedBalance = pt.balance;
      }

      cumulativePlannedCashIn += plannedIncome;
      cumulativePlannedCashOut += plannedExpenses;

      final bool isFuture = monthDate.isAfter(currentMonthStart);
      final bool isCurrent = monthDate.year == currentMonthStart.year && monthDate.month == currentMonthStart.month;

      double? actualCashIn;
      double? actualCashOut;
      double? actualBalance;

      if (!isFuture) {
        double incomeSum = 0.0;
        double expenseSum = 0.0;

        for (final Transaction tx in validTransactions) {
          final DateTime txDate = DateTime.parse(tx.date);
          if (txDate.year == monthDate.year && txDate.month == monthDate.month) {
            double convertedAmount = tx.amount;
            if (tx.currency.trim().toUpperCase() != plan.projectionCurrency.trim().toUpperCase()) {
              convertedAmount = ProjectionService.convertToCurrency(
                amount: tx.amount,
                from: tx.currency,
                to: plan.projectionCurrency,
                marketData: marketData,
              );
            }

            if (tx.type == 'income') {
              incomeSum += convertedAmount;
            } else {
              expenseSum += convertedAmount;
            }
          }
        }

        cumulativeActualCashIn += incomeSum;
        cumulativeActualCashOut += expenseSum;

        actualCashIn = cumulativeActualCashIn;
        actualCashOut = cumulativeActualCashOut;
        actualBalance = startingBalance + (cumulativeActualCashIn - cumulativeActualCashOut);
        
        lastActualBalance = actualBalance;
        currentMonthPlannedBalance = plannedBalance;
      } else {
        // Future month: project actual balance based on planned growth from the current month
        actualBalance = lastActualBalance + (plannedBalance - currentMonthPlannedBalance);
      }

      points.add(
        MonthlyCashFlowPoint(
          month: monthDate,
          plannedCashIn: cumulativePlannedCashIn,
          plannedCashOut: cumulativePlannedCashOut,
          plannedBalance: plannedBalance,
          actualCashIn: actualCashIn,
          actualCashOut: actualCashOut,
          actualBalance: actualBalance,
          isCurrentMonth: isCurrent,
        ),
      );
    }

    return points;
  }
}
