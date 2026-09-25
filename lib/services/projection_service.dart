import 'dart:math' as math;

import '../core/services/zakat_engine.dart';
import '../core/services/zakat_schedule_service.dart';
import '../models/financial_plan.dart';
import '../models/investment_asset.dart';
import '../models/saving.dart';
import '../models/transaction.dart';

class ProjectionPoint {
  const ProjectionPoint({
    required this.monthNumber,
    required this.date,
    required this.balance,
    required this.income,
    required this.expenses,
    required this.installmentsOutflow,
    required this.zakatOutflow,
  });

  final int monthNumber;
  final DateTime date;
  final double balance;
  final double income;
  final double expenses;
  final double installmentsOutflow;
  final double zakatOutflow;
}

class ProjectionService {
  ProjectionService._();

  static List<ProjectionPoint> calculateProjection({
    required FinancialPlan plan,
    required List<Transaction> transactions,
    required List<Saving> savings,
    required List<InvestmentAsset> investments,
    required MarketData marketData,
    String zakatMethod = 'hawl',
    String zakatAnnualDate = '',
    double? startingBalanceOverride,
    DateTime? now,
    String? lastRollover,
    String? zakatNisabBasis,
  }) {
    final List<ProjectionPoint> points = <ProjectionPoint>[];
    final DateTime startDateTime =
        DateTime.tryParse(plan.startDate) ?? DateTime.now();
    final DateTime effectiveNow = now ?? DateTime.now();
    final double initialBalance =
        startingBalanceOverride ?? plan.startingBalance;
    final int totalMonths = plan.durationYears * 12;

    double currentBalance = initialBalance;

    // Pre-parse installment data for faster lookup.
    final List<_UnpaidInstallment> unpaidInstallments = <_UnpaidInstallment>[];
    if (plan.includeInstallments) {
      for (final InvestmentAsset asset in investments) {
        for (final Map<String, dynamic> item in asset.installmentPlan) {
          final bool isPaid = item['isPaid'] == true;
          if (!isPaid) {
            final double amount = _asDouble(item['amount']);
            final String dateStr = InvestmentAsset.installmentDueDate(item);
            final DateTime? date = DateTime.tryParse(dateStr);
            if (amount > 0 && date != null) {
              unpaidInstallments.add(
                _UnpaidInstallment(
                  dueDate: date,
                  amount: amount,
                  currency: (item['currency']?.toString().isNotEmpty == true)
                      ? item['currency'].toString().trim().toUpperCase()
                      : asset.currency,
                ),
              );
            }
          }
        }
      }
    }
    final List<double> installmentsOutflows = List<double>.filled(
      totalMonths + 1,
      0.0,
    );

    for (int month = 1; month <= totalMonths; month++) {
      final DateTime monthDate = DateTime(
        startDateTime.year,
        startDateTime.month + month - 1,
        startDateTime.day,
      );

      double installmentsOutflow = 0.0;
      if (plan.includeInstallments) {
        final List<_UnpaidInstallment> currentMonthInsts = unpaidInstallments
            .where(
              (_UnpaidInstallment inst) =>
                  inst.dueDate.year == monthDate.year &&
                  inst.dueDate.month == monthDate.month,
            )
            .toList(growable: false);

        for (final _UnpaidInstallment inst in currentMonthInsts) {
          final double amountInProjectionCurrency = convertToCurrency(
            amount: inst.amount,
            from: inst.currency,
            to: plan.projectionCurrency,
            marketData: marketData,
          );
          installmentsOutflow += amountInProjectionCurrency;
        }
      }
      installmentsOutflows[month] = installmentsOutflow;
    }

    final List<Map<String, dynamic>> mergedZakatSchedule = plan.includeZakat
        ? ZakatScheduleService.calculateMergedZakatSchedule(
            zakatMethod: zakatMethod,
            zakatAnnualDate: zakatAnnualDate,
            transactions: transactions
                .map((Transaction tx) => tx.toJson())
                .toList(growable: false),
            savings: savings
                .map((Saving s) => s.toJson())
                .toList(growable: false),
            investments: investments
                .map((InvestmentAsset inv) => inv.toJson())
                .toList(growable: false),
            marketData: marketData,
            now: effectiveNow,
            lastRollover: lastRollover,
            zakatNisabBasis: zakatNisabBasis,
          )
        : <Map<String, dynamic>>[];
    final List<double> scheduledZakatByMonth = List<double>.filled(
      totalMonths + 1,
      0.0,
    );
    for (final Map<String, dynamic> item in mergedZakatSchedule) {
      final DateTime? paymentDate = DateTime.tryParse(
        (item['paymentDate'] ?? '').toString(),
      );
      if (paymentDate == null) continue;
      final int monthsDiff =
          (paymentDate.year - startDateTime.year) * 12 +
          (paymentDate.month - startDateTime.month);
      final int monthIndex = monthsDiff + 1;
      if (monthIndex < 1 || monthIndex > totalMonths) continue;
      scheduledZakatByMonth[monthIndex] += convertToCurrency(
        amount: _asDouble(item['totalZakat']),
        from: 'EGP',
        to: plan.projectionCurrency,
        marketData: marketData,
      );
    }

    for (int month = 1; month <= totalMonths; month++) {
      final DateTime monthDate = DateTime(
        startDateTime.year,
        startDateTime.month + month - 1,
        startDateTime.day,
      );

      final double installmentsOutflow = installmentsOutflows[month];
      final double balanceBeforeZakat =
          currentBalance +
          plan.monthlyIncome -
          plan.monthlyExpenses -
          installmentsOutflow;

      double zakatOutflow = scheduledZakatByMonth[month];

      if (zakatOutflow > balanceBeforeZakat) {
        zakatOutflow = math.max(0.0, balanceBeforeZakat);
      }

      currentBalance = balanceBeforeZakat - zakatOutflow;
      if (currentBalance < 0) {
        currentBalance = 0;
      }

      points.add(
        ProjectionPoint(
          monthNumber: month,
          date: monthDate,
          balance: currentBalance,
          income: plan.monthlyIncome,
          expenses: plan.monthlyExpenses,
          installmentsOutflow: installmentsOutflow,
          zakatOutflow: math.max(0.0, zakatOutflow),
        ),
      );
    }

    return points;
  }

  static double cashFlowStartingBalance(FinancialPlan plan) {
    if (plan.startingAssetBreakdown.isEmpty) {
      return plan.startingBalance;
    }
    final double cashVal = plan.startingAssetBreakdown['cash'] ?? 0.0;
    final double goldVal = plan.startingAssetBreakdown['gold'] ?? 0.0;
    final double silverVal = plan.startingAssetBreakdown['silver'] ?? 0.0;
    return cashVal + goldVal + silverVal;
  }

  static double convertToCurrency({
    required double amount,
    required String from,
    required String to,
    required MarketData marketData,
  }) {
    if (from.trim().toUpperCase() == to.trim().toUpperCase()) {
      return amount;
    }

    final double amountInEgp = ZakatEngineService.convertToEgp(
      amount,
      from,
      marketData,
    );
    if (to.trim().toUpperCase() == 'EGP') {
      return amountInEgp;
    }

    final double? rateToEgp = marketData.ratesToEgp[to.trim().toUpperCase()];
    if (rateToEgp != null && rateToEgp > 0) {
      return amountInEgp / rateToEgp;
    }
    if (to.trim().toUpperCase() == 'USD' && marketData.usdToEgp > 0) {
      return amountInEgp / marketData.usdToEgp;
    }
    if (to.trim().toUpperCase() == 'SAR' && marketData.sarToEgp > 0) {
      return amountInEgp / marketData.sarToEgp;
    }

    return amountInEgp;
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _UnpaidInstallment {
  const _UnpaidInstallment({
    required this.dueDate,
    required this.amount,
    required this.currency,
  });

  final DateTime dueDate;
  final double amount;
  final String currency;
}
