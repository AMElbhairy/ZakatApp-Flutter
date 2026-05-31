import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state_controller.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final int plansCount =
        context.select<AppStateController, int>((c) => c.state.financialPlans.length);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Plans', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.auto_graph),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Financial plans: $plansCount',
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
