import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/zakat_engine.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/investment_asset.dart';
import '../../models/saving.dart';
import '../../services/app_state_controller.dart';
import '../entry/add_investment_screen.dart';
import '../entry/add_saving_screen.dart';

class AssetsScreen extends StatelessWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStateController controller = context.watch<AppStateController>();
    final List<Saving> savings = controller.state.savings;
    final List<InvestmentAsset> investments = controller.state.investments;
    final MarketData market = MarketData.fromJson(controller.state.marketData);

    final List<Saving> cash = savings.where((s) => s.assetType == 'cash').toList();
    final List<Saving> gold = savings.where((s) => s.assetType == 'gold').toList();
    final List<Saving> silver = savings.where((s) => s.assetType == 'silver').toList();

    final List<InvestmentAsset> properties =
        investments.where((a) => a.investmentType == 'property').toList(growable: false);
    final List<InvestmentAsset> companyShares =
        investments.where((a) => a.investmentType == 'company_share').toList(growable: false);

    final double totalCash = cash.fold<double>(0, (sum, s) => sum + s.remainingAmount);
    final double totalGold = gold.fold<double>(0, (sum, s) => sum + s.remainingAmount);
    final double totalSilver = silver.fold<double>(0, (sum, s) => sum + s.remainingAmount);

    final double totalInvestmentEgp = ZakatEngineService.calculateTotalInvestmentsEgp(
      investments: investments,
      marketData: market,
    );
    final double totalInvestmentNetEgp =
        investments.fold<double>(0, (double sum, InvestmentAsset asset) {
      final double share = (asset.ownershipSharePct / 100).clamp(0, 1);
      final double gross =
          ZakatEngineService.convertToEgp(asset.marketValue * share, asset.currency, market);
      final double liability =
          ZakatEngineService.convertToEgp(asset.loanBalance, asset.currency, market);
      return sum + (gross - liability);
    });

    final bool hasAnyAssets = savings.isNotEmpty || investments.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeader(title: 'Assets', bottomSpacing: 14),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionHeader(title: 'Totals', bottomSpacing: 8),
                MetricTile(label: 'Total Cash', value: totalCash.toStringAsFixed(2)),
                const SizedBox(height: 8),
                MetricTile(label: 'Total Gold (g)', value: totalGold.toStringAsFixed(2)),
                const SizedBox(height: 8),
                MetricTile(label: 'Total Silver (g)', value: totalSilver.toStringAsFixed(2)),
                const SizedBox(height: 8),
                MetricTile(
                  label: 'Total Investment Value (EGP)',
                  value: totalInvestmentEgp.toStringAsFixed(2),
                ),
                const SizedBox(height: 8),
                MetricTile(
                  label: 'Total Investment Net (EGP)',
                  value: totalInvestmentNetEgp.toStringAsFixed(2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: !hasAnyAssets
                ? const Center(
                    child: EmptyStateCard(
                      cardKey: Key('assetsEmptyState'),
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No assets added yet',
                      message: 'Add savings and investments to track your wealth.',
                    ),
                  )
                : ListView(
                    children: <Widget>[
                      _savingSection(context, 'Cash', cash),
                      _savingSection(context, 'Gold', gold),
                      _savingSection(context, 'Silver', silver),
                      _investmentSection(context, 'Property', properties),
                      _investmentSection(context, 'Company Shares', companyShares),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _savingSection(BuildContext context, String title, List<Saving> list) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeader(title: title, bottomSpacing: 8),
            if (list.isEmpty)
              Text('No $title entries', style: Theme.of(context).textTheme.bodySmall),
            ...list.map(
              (Saving saving) => ListTile(
                key: Key('savingItem_${saving.id}'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AddSavingScreen(initialSaving: saving),
                    ),
                  );
                },
                contentPadding: const EdgeInsets.symmetric(vertical: 2),
                title: Text(
                  saving.description.isEmpty
                      ? _titleForAssetType(saving.assetType)
                      : saving.description,
                ),
                subtitle: Text('${saving.dateAcquired} • ${saving.unit}'),
                trailing: Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(saving.remainingAmount.toStringAsFixed(2)),
                    IconButton(
                      tooltip: 'Delete saving',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDeleteSaving(context, saving),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _investmentSection(BuildContext context, String title, List<InvestmentAsset> list) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeader(title: title, bottomSpacing: 8),
            if (list.isEmpty)
              Text('No $title entries', style: Theme.of(context).textTheme.bodySmall),
            ...list.map(
              (InvestmentAsset asset) => ListTile(
                key: Key('investmentItem_${asset.id}'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AddInvestmentScreen(initialInvestment: asset),
                    ),
                  );
                },
                contentPadding: const EdgeInsets.symmetric(vertical: 2),
                title: Text(
                  asset.location.isEmpty
                      ? (asset.investmentType == 'company_share'
                          ? 'Company Share'
                          : 'Property')
                      : asset.location,
                ),
                subtitle: Text('${asset.valuationDate} • ${asset.currency}'),
                trailing: Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(asset.marketValue.toStringAsFixed(2)),
                    IconButton(
                      tooltip: 'Delete investment',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDeleteInvestment(context, asset),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _titleForAssetType(String assetType) {
    if (assetType == 'cash') return 'Cash Saving';
    if (assetType == 'gold') return 'Gold Saving';
    return 'Silver Saving';
  }

  Future<void> _confirmDeleteSaving(BuildContext context, Saving saving) async {
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

  Future<void> _confirmDeleteInvestment(BuildContext context, InvestmentAsset asset) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete investment?'),
          content: const Text('This investment entry will be removed permanently.'),
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
      await context.read<AppStateController>().deleteInvestment(asset.id);
    }
  }
}
