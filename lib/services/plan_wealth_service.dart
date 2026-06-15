import 'dart:math' as math;
import '../core/services/zakat_engine.dart';
import '../models/investment_asset.dart';
import '../models/transaction.dart';
import '../models/saving.dart';
import 'projection_service.dart';

class PlanWealthService {
  PlanWealthService._();

  static double calculateActualPlanWealth({
    required List<Transaction> transactions,
    required List<Saving> savings,
    required List<InvestmentAsset> investments,
    required MarketData marketData,
    required String projectionCurrency,
    String? lastRollover,
  }) {
    final double netWorthEgp = ZakatEngineService.calculateNetWorthEgp(
      transactions: transactions,
      savings: savings,
      investments: investments,
      marketData: marketData,
      lastRollover: lastRollover,
    );

    return ProjectionService.convertToCurrency(
      amount: netWorthEgp,
      from: 'EGP',
      to: projectionCurrency,
      marketData: marketData,
    );
  }

  static double calculateExpectedPlanWealth({
    required List<ProjectionPoint> projection,
    required int currentMonthIndex,
    required double startingBalance,
  }) {
    if (projection.isEmpty) return startingBalance;
    if (currentMonthIndex <= 0) return startingBalance;
    if (currentMonthIndex > projection.length) return projection.last.balance;
    return projection[currentMonthIndex - 1].balance;
  }

  static double calculateVariance(double actual, double expected) {
    return actual - expected;
  }

  static Map<String, Map<String, double>> calculateAssetDrift({
    required Map<String, double> startingAssetBreakdown,
    required List<Transaction> transactions,
    required List<Saving> savings,
    required List<InvestmentAsset> investments,
    required MarketData marketData,
    required String projectionCurrency,
    String? lastRollover,
  }) {
    final NisabTotals totals = ZakatEngineService.computeNisabTotals(
      savings: savings,
      marketData: marketData,
    );

    final double cashEgp = ZakatEngineService.calculateTotalCashWealthEgp(
      transactions: transactions,
      savings: savings,
      marketData: marketData,
      lastRollover: lastRollover,
    );
    final double goldEgp = totals.totalGold24k * marketData.goldPrice24kEgp;
    final double silverEgp =
        totals.totalSilverGrams * marketData.silverPriceEgp;

    final Map<String, double> currentBreakdown = <String, double>{};
    currentBreakdown['cash'] = ProjectionService.convertToCurrency(
      amount: cashEgp,
      from: 'EGP',
      to: projectionCurrency,
      marketData: marketData,
    );
    currentBreakdown['gold'] = ProjectionService.convertToCurrency(
      amount: goldEgp,
      from: 'EGP',
      to: projectionCurrency,
      marketData: marketData,
    );
    currentBreakdown['silver'] = ProjectionService.convertToCurrency(
      amount: silverEgp,
      from: 'EGP',
      to: projectionCurrency,
      marketData: marketData,
    );

    for (final InvestmentAsset asset in investments) {
      final String type = ZakatEngineService.normaliseInvestmentType(
        asset.investmentType,
      );
      final double assetValueEgp =
          ZakatEngineService.calculateInvestmentEstimatedValueEgp(
            asset: asset,
            marketData: marketData,
          );
      final double assetValueInProj = ProjectionService.convertToCurrency(
        amount: assetValueEgp,
        from: 'EGP',
        to: projectionCurrency,
        marketData: marketData,
      );
      currentBreakdown[type] =
          (currentBreakdown[type] ?? 0.0) + assetValueInProj;
    }

    final double totalLiabilitiesEgp =
        ZakatEngineService.calculateTotalLiabilitiesEgp(
          transactions: transactions,
          savings: savings,
          investments: investments,
          marketData: marketData,
          lastRollover: lastRollover,
        );
    final double currentLiabilityInProj = ProjectionService.convertToCurrency(
      amount: totalLiabilitiesEgp,
      from: 'EGP',
      to: projectionCurrency,
      marketData: marketData,
    );
    currentBreakdown['liability'] = currentLiabilityInProj;

    final Map<String, Map<String, double>> drift =
        <String, Map<String, double>>{};
    final Set<String> allKeys = <String>{
      ...startingAssetBreakdown.keys,
      ...currentBreakdown.keys,
    };

    for (final String key in allKeys) {
      final double started = startingAssetBreakdown[key] ?? 0.0;
      final double current = currentBreakdown[key] ?? 0.0;
      final double variance = current - started;
      drift[key] = <String, double>{
        'started': started,
        'current': current,
        'variance': variance,
      };
    }

    return drift;
  }

  static double calculateActualAverageSurplus({
    required double currentNetWorth,
    required double startingNetWorth,
    required DateTime startDate,
    DateTime? asOf,
  }) {
    final DateTime now = asOf ?? DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime start = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final int elapsedDays = today.difference(start).inDays;
    if (elapsedDays < 30) return 0.0;
    return (currentNetWorth - startingNetWorth) / (elapsedDays / 30.0);
  }

  static double calculateForecastEndBalance({
    required double planEndGoal,
    required double currentFinancialVariance,
    required double averageMonthlySurplus,
    required double requiredMonthlySurplus,
    required int remainingMonths,
  }) {
    final double monthlyPaceGap =
        averageMonthlySurplus - requiredMonthlySurplus;
    return math.max(
      0.0,
      planEndGoal +
          currentFinancialVariance +
          (monthlyPaceGap * math.max(0, remainingMonths)),
    );
  }
}
