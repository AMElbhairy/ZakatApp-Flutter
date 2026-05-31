import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state_controller.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final int transactionsCount =
        context.select<AppStateController, int>((c) => c.state.transactions.length);

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
              child: Row(
                children: <Widget>[
                  const Icon(Icons.pie_chart_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Transactions tracked: $transactionsCount',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
