import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/zakat_engine.dart';
import '../../core/services/zakat_schedule_service.dart';
import '../../models/investment_asset.dart';
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

    double totalIncomeEgp = 0;
    double totalExpensesEgp = 0;

    for (final tx in transactions) {
      final double egpAmount =
          ZakatEngineService.convertToEgp(tx.amount, tx.currency, market);
      if (tx.type == 'income') {
        totalIncomeEgp += egpAmount;
      } else if (tx.type == 'expense') {
        totalExpensesEgp += egpAmount;
      }
    }

    final NisabTotals savingsTotals = ZakatEngineService.computeNisabTotals(
      savings: savings,
      marketData: market,
    );
    final double investmentsEgp = ZakatEngineService.calculateTotalInvestmentsEgp(
      investments: investments,
      marketData: market,
    );
    final double totalWealthEgp = ZakatEngineService.calculateTotalWealthEgp(
      transactions: transactions,
      savings: savings,
      investments: investments,
      marketData: market,
    );

    final double investmentLiabilityEgp = investments.fold<double>(
      0,
      (double sum, InvestmentAsset asset) =>
          sum + ZakatEngineService.convertToEgp(asset.loanBalance, asset.currency, market),
    );
    final double netPositionEgp = totalWealthEgp - investmentLiabilityEgp;

    final double nisabThreshold =
        ZakatEngineService.defaultConfig.nisabGoldGrams * market.goldPrice24kEgp;
    final bool nisabMet = ZakatEngineService.checkCashNisab(totalWealthEgp, market);

    final List<Map<String, dynamic>> schedule = _buildSchedule(
      zakatMethod: state.zakatMethod,
      zakatAnnualDate: state.zakatAnnualDate,
      transactions: transactions,
      savings: savings,
      investments: investments,
      marketData: market,
    );
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
        Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        if (!hasAnyData)
          Card(
            key: const Key('dashboardEmptyCard'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Start your Zakat journey',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('Add your first income, saving, or asset.'),
                  const SizedBox(height: 14),
                  FilledButton(
                    key: const Key('dashboardStartAddingButton'),
                    onPressed: onOpenAddActions,
                    child: const Text('Add First Entry'),
                  ),
                ],
              ),
            ),
          )
        else ...<Widget>[
          _sectionCard(
            context,
            title: 'Financial Summary',
            children: <Widget>[
              _metricRow('Total Wealth', _formatEgp(totalWealthEgp), bold: true),
              const SizedBox(height: 10),
              _metricRow('Net Position', _formatEgp(netPositionEgp)),
              const SizedBox(height: 10),
              _metricRow('Total Income', _formatEgp(totalIncomeEgp)),
              const SizedBox(height: 10),
              _metricRow('Total Expenses', _formatEgp(totalExpensesEgp)),
              const SizedBox(height: 10),
              _metricRow(
                'Total Savings Wealth',
                _formatEgp(savingsTotals.totalSavingsWealthEgp),
              ),
              const SizedBox(height: 10),
              _metricRow('Investment Wealth', _formatEgp(investmentsEgp)),
            ],
          ),
          const SizedBox(height: 12),
          _sectionCard(
            context,
            title: 'Zakat Summary',
            key: const Key('dashboardZakatSummaryCard'),
            onTap: onOpenZakatSchedule,
            children: <Widget>[
              _metricRow('Nisab Status', nisabMet ? 'Met' : 'Not Met',
                  bold: nisabMet),
              const SizedBox(height: 10),
              _metricRow('Current Nisab Threshold', _formatEgp(nisabThreshold)),
              const SizedBox(height: 10),
              _metricRow('Zakat Due This Month', _formatEgp(dues.thisMonth)),
              const SizedBox(height: 10),
              _metricRow('Zakat Due Next Month', _formatEgp(dues.nextMonth)),
              const SizedBox(height: 10),
              _metricRow('Total Upcoming Dues', _formatEgp(dues.totalUpcoming),
                  bold: true),
            ],
          ),
          const SizedBox(height: 12),
          _sectionCard(
            context,
            title: 'Asset Allocation',
            children: <Widget>[
              _metricRow('Cash %', _formatPct(allocation.cashPct)),
              const SizedBox(height: 10),
              _metricRow('Metals %', _formatPct(allocation.metalsPct)),
              const SizedBox(height: 10),
              _metricRow('Property %', _formatPct(allocation.propertyPct)),
              const SizedBox(height: 10),
              _metricRow('Company %', _formatPct(allocation.companyPct)),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text('Recent Activity',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      TextButton(
                        key: const Key('dashboardViewAllActivityButton'),
                        onPressed: onViewAllActivity,
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  if (recent4.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('No recent transactions'),
                    )
                  else
                    ...recent4.map((Transaction tx) => ListTile(
                          key: Key('dashboardRecentTx_${tx.id}'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(tx.category),
                          subtitle: Text(tx.date),
                          trailing: Text(
                            '${tx.type == 'expense' ? '-' : '+'}${tx.amount.toStringAsFixed(2)} ${tx.currency}',
                          ),
                        )),
                ],
              ),
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

  static Card _sectionCard(
    BuildContext context, {
    Key? key,
    required String title,
    required List<Widget> children,
    VoidCallback? onTap,
  }) {
    return Card(
      key: key,
      child: Padding(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _metricRow(String label, String value, {bool bold = false}) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        Text(
          value,
          style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500),
        ),
      ],
    );
  }

  static String _formatEgp(double value) {
    final NumberFormat formatter = NumberFormat('#,##0.00', 'en_US');
    return 'E£ ${formatter.format(value)}';
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
