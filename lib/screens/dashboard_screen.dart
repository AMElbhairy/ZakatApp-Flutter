import 'package:flutter/material.dart';
import '../core/i18n/app_localizations.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZakatApp'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'السلام عليكم',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),

            Card(
              child: ListTile(
                title: Text(context.l10n.tr('total_wealth')),
                subtitle: const Text('0.00'),
                trailing: const Icon(Icons.account_balance_wallet),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: ListTile(
                title: Text(context.l10n.tr('zakat_summary')),
                subtitle: const Text('0.00'),
                trailing: const Icon(Icons.calculate),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
