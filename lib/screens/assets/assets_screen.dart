import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/saving.dart';
import '../../services/app_state_controller.dart';
import '../entry/add_saving_screen.dart';

class AssetsScreen extends StatelessWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Saving> savings = context
        .select<AppStateController, List<Saving>>((c) => c.state.savings);

    final List<Saving> cash = savings.where((s) => s.assetType == 'cash').toList();
    final List<Saving> gold = savings.where((s) => s.assetType == 'gold').toList();
    final List<Saving> silver =
        savings.where((s) => s.assetType == 'silver').toList();

    final double totalCash =
        cash.fold<double>(0, (sum, s) => sum + s.remainingAmount);
    final double totalGold =
        gold.fold<double>(0, (sum, s) => sum + s.remainingAmount);
    final double totalSilver =
        silver.fold<double>(0, (sum, s) => sum + s.remainingAmount);

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _totalRow('Total Cash', totalCash.toStringAsFixed(2)),
                  const SizedBox(height: 8),
                  _totalRow('Total Gold (g)', totalGold.toStringAsFixed(2)),
                  const SizedBox(height: 8),
                  _totalRow('Total Silver (g)', totalSilver.toStringAsFixed(2)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: savings.isEmpty
                ? const Center(
                    child: Text(
                      'No savings added yet',
                      key: Key('assetsEmptyState'),
                    ),
                  )
                : ListView(
                    children: <Widget>[
                      _section(context, 'Cash', cash),
                      _section(context, 'Gold', gold),
                      _section(context, 'Silver', silver),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Saving> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (list.isEmpty)
          Text('No $title entries', style: Theme.of(context).textTheme.bodySmall),
        ...list.map((Saving saving) => Card(
              child: ListTile(
                key: Key('savingItem_${saving.id}'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AddSavingScreen(initialSaving: saving),
                    ),
                  );
                },
                title: Text(
                  saving.description.isEmpty
                      ? _titleForAssetType(saving.assetType)
                      : saving.description,
                ),
                subtitle: Text('${saving.dateAcquired} • ${saving.unit}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(saving.remainingAmount.toStringAsFixed(2)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDelete(context, saving),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  static Widget _totalRow(String label, String value) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  static String _titleForAssetType(String assetType) {
    if (assetType == 'cash') return 'Cash Saving';
    if (assetType == 'gold') return 'Gold Saving';
    return 'Silver Saving';
  }

  Future<void> _confirmDelete(BuildContext context, Saving saving) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete saving?'),
          content: const Text('This saving entry will be removed permanently.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      await context.read<AppStateController>().deleteSaving(saving.id);
    }
  }
}
