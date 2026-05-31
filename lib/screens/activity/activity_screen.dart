import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../services/app_state_controller.dart';
import '../entry/add_transaction_screen.dart';

enum _ActivityFilter { all, income, expense }

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  _ActivityFilter _filter = _ActivityFilter.all;

  @override
  Widget build(BuildContext context) {
    final List<Transaction> transactions =
        context.watch<AppStateController>().state.transactions;

    final List<Transaction> sorted = List<Transaction>.from(transactions)
      ..sort((Transaction a, Transaction b) {
        final DateTime ad = _parseDate(a.date);
        final DateTime bd = _parseDate(b.date);
        final int byDate = bd.compareTo(ad);
        if (byDate != 0) return byDate;
        return b.createdAt.compareTo(a.createdAt);
      });

    final List<Transaction> filtered = sorted.where((Transaction tx) {
      switch (_filter) {
        case _ActivityFilter.income:
          return tx.type == 'income';
        case _ActivityFilter.expense:
          return tx.type == 'expense';
        case _ActivityFilter.all:
          return true;
      }
    }).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Activity', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          SegmentedButton<_ActivityFilter>(
            segments: const <ButtonSegment<_ActivityFilter>>[
              ButtonSegment<_ActivityFilter>(
                value: _ActivityFilter.all,
                label: Text('All'),
              ),
              ButtonSegment<_ActivityFilter>(
                value: _ActivityFilter.income,
                label: Text('Income'),
              ),
              ButtonSegment<_ActivityFilter>(
                value: _ActivityFilter.expense,
                label: Text('Expense'),
              ),
            ],
            selected: <_ActivityFilter>{_filter},
            onSelectionChanged: (Set<_ActivityFilter> selected) {
              setState(() {
                _filter = selected.first;
              });
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No transactions yet',
                      key: Key('activityEmptyState'),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final Transaction tx = filtered[index];
                      final bool isIncome = tx.type == 'income';

                      return Card(
                        child: ListTile(
                          key: Key('transactionTile_${tx.id}'),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    AddTransactionScreen(initialTransaction: tx),
                              ),
                            );
                          },
                          title: Row(
                            children: <Widget>[
                              _TypeBadge(type: tx.type),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  tx.category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text('${tx.date} • ${tx.currency}'),
                                if (tx.description.trim().isNotEmpty)
                                  Text(
                                    tx.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                '${isIncome ? '+' : '-'}${tx.amount.toStringAsFixed(2)} ${tx.currency}',
                                style: TextStyle(
                                  color: isIncome
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              IconButton(
                                key: Key('deleteTransaction_${tx.id}'),
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _confirmDelete(context, tx),
                              ),
                            ],
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

  Future<void> _confirmDelete(BuildContext context, Transaction tx) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete transaction?'),
              content: const Text('This action cannot be undone.'),
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
    await context.read<AppStateController>().deleteTransaction(tx.id);
  }

  static DateTime _parseDate(String raw) {
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final bool isIncome = type == 'income';
    final Color bg = isIncome ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
    final Color fg = isIncome ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isIncome ? 'Income' : 'Expense',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
