import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state_controller.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final int recurringCount = context
        .select<AppStateController, int>((c) => c.state.recurringTransactions.length);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Activity', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.history),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Recurring items: $recurringCount',
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
