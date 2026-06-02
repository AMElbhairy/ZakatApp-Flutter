import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/financial_plan.dart';
import '../../services/app_state_controller.dart';
import '../entry/add_financial_plan_screen.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final double navSafeBottomPadding = 112 + MediaQuery.paddingOf(context).bottom;
    final List<FinancialPlan> plans =
        context.watch<AppStateController>().state.financialPlans;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: context.l10n.tr('plans'),
            trailing: FilledButton.icon(
              key: const Key('addPlanButton'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AddFinancialPlanScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: Text(context.l10n.tr('add_plan')),
            ),
          ),
          Expanded(
            child: plans.isEmpty
                ? Center(
                    child: EmptyStateCard(
                      cardKey: Key('plansEmptyState'),
                      icon: Icons.auto_graph,
                      title: context.l10n.tr('no_plans_yet'),
                      message: context.l10n.tr('plans_empty_message'),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.only(bottom: navSafeBottomPadding),
                    itemCount: plans.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (_, int index) {
                      final FinancialPlan plan = plans[index];
                      final double projected = _projectedBalance(plan);

                      return PremiumCard(
                        child: ListTile(
                          key: Key('planItem_${plan.id}'),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AddFinancialPlanScreen(initialPlan: plan),
                              ),
                            );
                          },
                          contentPadding: const EdgeInsets.symmetric(vertical: 2),
                          title: Text(plan.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.trf(
                                  'duration_years',
                                  <String, String>{'years': '${plan.durationYears}'},
                                ),
                              ),
                              Text(
                                context.l10n.trf(
                                  'monthly_saving_value',
                                  <String, String>{
                                    'amount': plan.monthlyIncome.toStringAsFixed(2),
                                    'currency': plan.currency,
                                  },
                                ),
                              ),
                              Text(
                                context.l10n.trf(
                                  'projected_balance_value',
                                  <String, String>{
                                    'amount': projected.toStringAsFixed(2),
                                    'currency': plan.currency,
                                  },
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            key: Key('deletePlan_${plan.id}'),
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _confirmDelete(context, plan),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static double _projectedBalance(FinancialPlan plan) {
    final Map<String, dynamic> context = plan.context ?? const <String, dynamic>{};
    final double startingBalance = _asDouble(context['startingBalance']);
    final int months = plan.durationYears * 12;
    final double monthlyNet = plan.monthlyIncome - plan.monthlyExpenses;
    return startingBalance + (monthlyNet * months);
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  Future<void> _confirmDelete(BuildContext context, FinancialPlan plan) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(context.l10n.tr('delete_plan')),
              content: Text(context.l10n.tr('delete_plan_message')),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(context.l10n.tr('cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(context.l10n.tr('delete')),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !context.mounted) return;
    await context.read<AppStateController>().deleteFinancialPlan(plan.id);
  }
}
