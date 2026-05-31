import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state_controller.dart';

class AssetsScreen extends StatelessWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final int savingsCount =
        context.select<AppStateController, int>((c) => c.state.savings.length);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Assets', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.account_balance_wallet_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Savings entries: $savingsCount',
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
