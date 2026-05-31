import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state_controller.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String mainCurrency =
        context.select<AppStateController, String>((c) => c.state.mainCurrency);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Account', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.person_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Primary currency: $mainCurrency',
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
