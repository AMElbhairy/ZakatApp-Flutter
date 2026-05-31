import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/zakat_engine.dart';
import '../../core/services/zakat_schedule_service.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/investment_asset.dart';
import '../../models/market_snapshot.dart';
import '../../models/saving.dart';
import '../../models/transaction.dart';
import '../../services/app_state_controller.dart';

class DashboardScreen extends StatelessWidget {
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
    final bool hasFxData =
        requiredCurrencies.every(
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
        final double egpAmount =
            ZakatEngineService.convertToEgp(tx.amount, tx.currency, market);
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
      savingsTotals = ZakatEngineService.computeNisabTotals(
        savings: savings,
        marketData: market,
      );
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

      nisabThreshold =
          ZakatEngineService.defaultConfig.nisabGoldGrams * market.goldPrice24kEgp;
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

    final _Allocation allocation = _computeAllocation(
      savingsTotals: savingsTotals,
      investments: investments,
      marketData: market,
      totalWealthEgp: totalWealthEgp,
    );

    final List<Transaction> recent = List<Transaction>.from(transactions)
      ..sort((a, b) => _parseDate(b.date).compareTo(_parseDate(a.date)));
    final List<Transaction> recent4 = recent.take(4).toList(growable: false);

    final bool hasAnyData =
        transactions.isNotEmpty || savings.isNotEmpty || investments.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        SectionHeader(title: 'Dashboard', bottomSpacing: 14),
        if (!hasAnyData)
          EmptyStateCard(
            cardKey: const Key('dashboardEmptyCard'),
            icon: Icons.auto_graph,
            title: 'Start your Zakat journey',
            message: 'Add your first income, saving, or asset.',
            action: AppPrimaryButton(
              key: const Key('dashboardStartAddingButton'),
              onPressed: onOpenAddActions,
              label: 'Add First Entry',
              icon: Icons.add,
            ),
          )
        else ...<Widget>[
          PremiumCard(
            hero: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Total Wealth', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  _formatOrMissing(totalWealthEgp, hasMarketData),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                MetricTile(
                  label: 'Net Position',
                  value: _formatOrMissing(netPositionEgp, hasMarketData),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeader(title: 'Financial Summary', bottomSpacing: 10),
                MetricTile(
                  label: 'Total Income',
                  value: _formatOrMissing(totalIncomeEgp, hasFxData),
                ),
                const SizedBox(height: 10),
                MetricTile(
                  label: 'Total Expenses',
                  value: _formatOrMissing(totalExpensesEgp, hasFxData),
                ),
                const SizedBox(height: 10),
                MetricTile(
                  label: 'Total Savings Wealth',
                  value: _formatOrMissing(savingsTotals.totalSavingsWealthEgp, hasMarketData),
                ),
                const SizedBox(height: 10),
                MetricTile(
                  label: 'Investment Wealth',
                  value: _formatOrMissing(investmentsEgp, hasFxData),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PremiumCard(
            key: const Key('dashboardZakatSummaryCard'),
            onTap: onOpenZakatSchedule,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeader(
                  title: 'Zakat Summary',
                  bottomSpacing: 10,
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                MetricTile(
                  label: 'Nisab Status',
                  value: hasMarketData
                      ? (nisabMet ? 'Met' : 'Not Met')
                      : (hasFxData ? 'Gold/silver price required' : 'Market data required'),
                  bold: nisabMet,
                ),
                const SizedBox(height: 10),
                MetricTile(
                  label: 'Current Nisab Threshold',
                  value: hasFxData && !hasMetalsData
                      ? 'Gold/silver price required'
                      : _formatOrMissing(nisabThreshold, hasMarketData),
                ),
                const SizedBox(height: 10),
                MetricTile(
                  label: 'Zakat Due This Month',
                  value: _formatOrMissing(dues.thisMonth, hasMarketData),
                ),
                const SizedBox(height: 10),
                MetricTile(
                  label: 'Zakat Due Next Month',
                  value: _formatOrMissing(dues.nextMonth, hasMarketData),
                ),
                const SizedBox(height: 10),
                MetricTile(
                  label: 'Total Upcoming Dues',
                  value: _formatOrMissing(dues.totalUpcoming, hasMarketData),
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeader(title: 'Asset Allocation', bottomSpacing: 10),
                MetricTile(label: 'Cash %', value: _formatPct(allocation.cashPct)),
                const SizedBox(height: 10),
                MetricTile(label: 'Metals %', value: _formatPct(allocation.metalsPct)),
                const SizedBox(height: 10),
                MetricTile(label: 'Property %', value: _formatPct(allocation.propertyPct)),
                const SizedBox(height: 10),
                MetricTile(label: 'Company %', value: _formatPct(allocation.companyPct)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeader(
                  title: 'Recent Activity',
                  trailing: TextButton(
                    key: const Key('dashboardViewAllActivityButton'),
                    onPressed: onViewAllActivity,
                    child: const Text('View All'),
                  ),
                ),
                if (recent4.isEmpty)
                  const Text('No recent transactions')
                else
                  ...recent4.map(
                    (Transaction tx) => ListTile(
                      key: Key('dashboardRecentTx_${tx.id}'),
                      contentPadding: const EdgeInsets.symmetric(vertical: 2),
                      dense: true,
                      title: Text(tx.category),
                      subtitle: Text(tx.date),
                      trailing: Text(
                        '${tx.type == 'expense' ? '-' : '+'}${tx.amount.toStringAsFixed(2)} ${tx.currency}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
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

    final List<Map<String, dynamic>> incomeSchedule =
        ZakatScheduleService.calculateMonthlyZakatSchedule(
      transactions: transactions.map((e) => e.toJson()).toList(growable: false),
      marketData: marketData,
    );
    final List<Map<String, dynamic>> savingsSchedule =
        ZakatScheduleService.calculateSavingsZakatSchedule(
      savings: savings.map((e) => e.toJson()).toList(growable: false),
      marketData: marketData,
    );

    return <Map<String, dynamic>>[...incomeSchedule, ...savingsSchedule];
  }

  static _Dues _computeDues(List<Map<String, dynamic>> schedule) {
    final DateTime now = DateTime.now();
    final String thisMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final DateTime nextMonthDate = DateTime(now.year, now.month + 1, 1);
    final String nextMonthKey =
        '${nextMonthDate.year}-${nextMonthDate.month.toString().padLeft(2, '0')}';

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

    return _Dues(
      thisMonth: thisMonth,
      nextMonth: nextMonth,
      totalUpcoming: upcoming,
    );
  }

  static _Allocation _computeAllocation({
    required NisabTotals savingsTotals,
    required List<InvestmentAsset> investments,
    required MarketData marketData,
    required double totalWealthEgp,
  }) {
    if (totalWealthEgp <= 0) {
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
      if (asset.investmentType == 'company_share') {
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

  static String _formatEgp(double value) {
    final NumberFormat formatter = NumberFormat('#,##0.00', 'en_US');
    return 'E£ ${formatter.format(value)}';
  }

  static String _formatOrMissing(double value, bool hasMarketData) {
    if (!hasMarketData) return 'Market data required';
    return _formatEgp(value);
  }

  static String _formatPct(double value) {
    return '${value.toStringAsFixed(1)}%';
  }

  static DateTime _parseDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
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
  });

  final double cashPct;
  final double metalsPct;
  final double propertyPct;
  final double companyPct;
}
