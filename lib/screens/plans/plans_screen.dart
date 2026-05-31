import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/financial_plan.dart';
import '../../services/app_state_controller.dart';
import '../entry/add_financial_plan_screen.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<FinancialPlan> plans =
        context.watch<AppStateController>().state.financialPlans;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('Plans', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              FilledButton.icon(
                key: const Key('addPlanButton'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AddFinancialPlanScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Plan'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: plans.isEmpty
                ? const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No financial plans yet',
                          key: Key('plansEmptyState'),
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: plans.length,
                    separatorBuilder:
                        (BuildContext context, int index) =>
                            const SizedBox(height: 10),
                    itemBuilder: (_, int index) {
                      final FinancialPlan plan = plans[index];
                      final double projected = _projectedBalance(plan);

                      return Card(
                        child: ListTile(
                          key: Key('planItem_${plan.id}'),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    AddFinancialPlanScreen(initialPlan: plan),
                              ),
                            );
                          },
                          title: Text(plan.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const SizedBox(height: 4),
                              Text('Duration: ${plan.durationYears} years'),
                              Text(
                                'Monthly saving: ${plan.monthlyIncome.toStringAsFixed(2)} ${plan.currency}',
                              ),
                              Text(
                                'Projected balance: ${projected.toStringAsFixed(2)} ${plan.currency}',
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
              title: const Text('Delete plan?'),
              content: const Text('This plan will be removed permanently.'),
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
        ) ??
        false;

    if (!confirmed || !context.mounted) return;
    await context.read<AppStateController>().deleteFinancialPlan(plan.id);
  }
}
