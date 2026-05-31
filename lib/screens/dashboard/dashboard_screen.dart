import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/zakat_engine.dart';
import '../../services/app_state_controller.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final transactions = controller.state.transactions;

    final market = MarketData.fromJson(controller.state.marketData);

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

    final double netEgp = totalIncomeEgp - totalExpensesEgp;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _metricRow('Total Transactions', '${transactions.length}'),
                  const SizedBox(height: 10),
                  _metricRow('Total Income', _formatEgp(totalIncomeEgp)),
                  const SizedBox(height: 10),
                  _metricRow('Total Expenses', _formatEgp(totalExpensesEgp)),
                  const Divider(height: 24),
                  _metricRow('Net Balance', _formatEgp(netEgp), bold: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value, {bool bold = false}) {
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
}
