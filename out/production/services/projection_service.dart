import 'dart:math' as math;
import '../core/services/zakat_engine.dart';
import '../models/financial_plan.dart';
import '../models/investment_asset.dart';

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
    required List<InvestmentAsset> investments,
    required MarketData marketData,
    String zakatMethod = 'hawl',
    String zakatAnnualDate = '',
  }) {
    final List<ProjectionPoint> points = <ProjectionPoint>[];
    final DateTime startDateTime =
        DateTime.tryParse(plan.startDate) ?? DateTime.now();

    double currentBalance = plan.startingBalance;
    final int totalMonths = plan.durationYears * 12;

    // Calculate the zakatable portion of starting balance (cash + gold + silver only)
    double zakatableStartingBalance = plan.startingBalance;
    if (plan.startingAssetBreakdown.isNotEmpty) {
      final double cashVal = plan.startingAssetBreakdown['cash'] ?? 0.0;
      final double goldVal = plan.startingAssetBreakdown['gold'] ?? 0.0;
      final double silverVal = plan.startingAssetBreakdown['silver'] ?? 0.0;
      zakatableStartingBalance = cashVal + goldVal + silverVal;
    }

    // Pre-parse installment data for faster lookup
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
                  currency: asset.currency,
                ),
              );
            }
          }
        }
      }
    }

    // Determine Nisab threshold
    double nisabThresholdEgp = plan.startingNisabSnapshot;
    if (nisabThresholdEgp <= 0) {
      nisabThresholdEgp = ZakatEngineService.cashNisabThresholdEgp(marketData);
    }
    final double nisabThreshold = convertToCurrency(
      amount: nisabThresholdEgp,
      from: 'EGP',
      to: plan.projectionCurrency,
      marketData: marketData,
    );

    // Calculate monthly surpluses and find when Nisab is crossed
    final List<double> monthlySurpluses = List<double>.filled(
      totalMonths + 1,
      0.0,
    );
    final List<double> installmentsOutflows = List<double>.filled(
      totalMonths + 1,
      0.0,
    );
    double cumulativeNoZakat = plan.startingBalance;
    int? nisabCrossedMonth; // 1-based month index; 0 if crossed at start

    if (cumulativeNoZakat >= nisabThreshold) {
      nisabCrossedMonth = 0;
    }

    for (int month = 1; month <= totalMonths; month++) {
      final DateTime monthDate = DateTime(
        startDateTime.year,
        startDateTime.month + month,
        startDateTime.day,
      );

      double installmentsOutflow = 0;
      if (plan.includeInstallments) {
        final List<_UnpaidInstallment> currentMonthInsts = unpaidInstallments
            .where(
              (_UnpaidInstallment inst) =>
                  inst.dueDate.year == monthDate.year &&
                  inst.dueDate.month == monthDate.month,
            )
            .toList();

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

      final double surplus =
          plan.monthlyIncome - plan.monthlyExpenses - installmentsOutflow;
      monthlySurpluses[month] = surplus;

      cumulativeNoZakat += surplus;
      if (nisabCrossedMonth == null && cumulativeNoZakat >= nisabThreshold) {
        nisabCrossedMonth = month;
      }
    }

    // Calculate Zakat outflow schedule for each month
    final List<double> projectedZakatByMonth = List<double>.filled(
      totalMonths + 1,
      0.0,
    );
    // Use a boolean set to track annual Hijri due months (instead of -1.0 flags in numeric array)
    final Set<int> annualDueMonths = <int>{};

    if (plan.includeZakat) {
      if (zakatMethod == 'annual') {
        // Identify months that match the Hijri Annual date in the projection
        if (zakatAnnualDate.isNotEmpty && zakatAnnualDate.contains('-')) {
          final List<String> parts = zakatAnnualDate.split('-');
          final int? hm = int.tryParse(parts[0]);
          final int? hd = int.tryParse(parts[1]);
          if (hm != null && hd != null && hm >= 1 && hm <= 12 && hd >= 1) {
            final DateTime today = DateTime.now();
            final HijriDate todayH = ZakatEngineService.gregorianToHijri(today);
            final int yearsToCheck = (totalMonths / 12).ceil() + 2;

            for (
              int yearOffset = -1;
              yearOffset <= yearsToCheck;
              yearOffset++
            ) {
              final int hy = todayH.year + yearOffset;
              if (hy < 1) continue;
              final int maxDays = ZakatEngineService.hijriMonthLength(hm);
              final DateTime dueGreg = ZakatEngineService.hijriToGregorian(
                hy,
                hm,
                hd < maxDays ? hd : maxDays,
              );

              final int monthsDiff =
                  (dueGreg.year - startDateTime.year) * 12 +
                  (dueGreg.month - startDateTime.month) +
                  1;
              if (monthsDiff >= 1 && monthsDiff <= totalMonths) {
                annualDueMonths.add(monthsDiff);
              }
            }
          }
        }
      } else {
        // Hawl method: lot-based tracking
        if (nisabCrossedMonth != null) {
          // Use the pre-calculated zakatable starting balance
          double bundleAmount = zakatableStartingBalance;

          for (int m = 1; m <= nisabCrossedMonth; m++) {
            if (monthlySurpluses[m] > 0) {
              bundleAmount += monthlySurpluses[m];
            }
          }
          if (bundleAmount > 0) {
            final int startDueMonth = nisabCrossedMonth == 0
                ? 12
                : nisabCrossedMonth + 12;
            for (int due = startDueMonth; due <= totalMonths; due += 12) {
              projectedZakatByMonth[due] += bundleAmount * 0.025;
            }
          }

          // 2. Subsequent monthly surplus lots
          for (int m = nisabCrossedMonth + 1; m <= totalMonths; m++) {
            final double surplus = monthlySurpluses[m];
            if (surplus > 0) {
              for (int due = m + 12; due <= totalMonths; due += 12) {
                projectedZakatByMonth[due] += surplus * 0.025;
              }
            }
          }
        }
      }
    }

    // Run the actual projection loop and subtract Zakat
    for (int month = 1; month <= totalMonths; month++) {
      final DateTime monthDate = DateTime(
        startDateTime.year,
        startDateTime.month + month,
        startDateTime.day,
      );

      final double installmentsOutflow = installmentsOutflows[month];
      final double balanceBeforeZakat =
          currentBalance +
          plan.monthlyIncome -
          plan.monthlyExpenses -
          installmentsOutflow;

      double zakatOutflow = 0.0;
      if (plan.includeZakat) {
        if (zakatMethod == 'annual') {
          final bool isDueMonth =
              annualDueMonths.contains(month) ||
              (zakatAnnualDate.isEmpty && month % 12 == 0);
          if (isDueMonth) {
            // Calculate zakatable balance: start with zakatable starting assets,
            // then add cumulative positive monthly surpluses up to this month
            double zakatableBalance = zakatableStartingBalance;
            for (int m = 1; m <= month; m++) {
              if (monthlySurpluses[m] > 0) {
                zakatableBalance += monthlySurpluses[m];
              }
              // Subtract any prior Zakat paid
              zakatableBalance -= projectedZakatByMonth[m];
            }
            zakatableBalance = math.max(0.0, zakatableBalance);
            if (zakatableBalance >= nisabThreshold) {
              zakatOutflow = zakatableBalance * 0.025;
              projectedZakatByMonth[month] = zakatOutflow;
            }
          }
        } else {
          zakatOutflow = math.max(0.0, projectedZakatByMonth[month]);
          if (zakatOutflow > balanceBeforeZakat) {
            zakatOutflow = math.max(0.0, balanceBeforeZakat);
          }
        }
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

  static double convertToCurrency({
    required double amount,
    required String from,
    required String to,
    required MarketData marketData,
  }) {
    if (from.trim().toUpperCase() == to.trim().toUpperCase()) {
      return amount;
    }
    // Convert from source currency to EGP, then from EGP to target currency
    final double amountInEgp = ZakatEngineService.convertToEgp(
      amount,
      from,
      marketData,
    );
    if (to.trim().toUpperCase() == 'EGP') {
      return amountInEgp;
    }

    // Resolve rate from EGP to target currency
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

    return amountInEgp; // fallback to EGP if rate is not resolved
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
