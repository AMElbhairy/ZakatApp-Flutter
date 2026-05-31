import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/zakat_engine.dart';
import '../../core/services/zakat_schedule_service.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/transaction.dart';
import '../../services/app_state_controller.dart';
import '../entry/add_transaction_screen.dart';

enum _ActivityFilter { all, income, expense }
enum _ActivitySection { transactions, schedule }

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  ActivityScreenState createState() => ActivityScreenState();
}

class ActivityScreenState extends State<ActivityScreen> {
  _ActivityFilter _filter = _ActivityFilter.all;
  _ActivitySection _section = _ActivitySection.transactions;

  void showSchedule() {
    if (!mounted) return;
    setState(() => _section = _ActivitySection.schedule);
  }

  void showTransactions() {
    if (!mounted) return;
    setState(() => _section = _ActivitySection.transactions);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final state = controller.state;
    final List<Transaction> transactions = state.transactions;

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

    final MarketData market = MarketData.fromJson(state.marketData);
    final List<Map<String, dynamic>> schedule = _buildSchedule(
      zakatMethod: state.zakatMethod,
      zakatAnnualDate: state.zakatAnnualDate,
      transactions: state.transactions,
      savings: state.savings.map((e) => e.toJson()).toList(growable: false),
      investments: state.investments.map((e) => e.toJson()).toList(growable: false),
      marketData: market,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeader(title: 'Activity'),
          SegmentedButton<_ActivitySection>(
            key: const Key('activitySectionSegment'),
            segments: const <ButtonSegment<_ActivitySection>>[
              ButtonSegment<_ActivitySection>(
                value: _ActivitySection.transactions,
                label: Text('Transactions'),
              ),
              ButtonSegment<_ActivitySection>(
                value: _ActivitySection.schedule,
                label: Text('Zakat Schedule'),
              ),
            ],
            selected: <_ActivitySection>{_section},
            onSelectionChanged: (Set<_ActivitySection> selected) {
              setState(() => _section = selected.first);
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _section == _ActivitySection.transactions
                ? _buildTransactionsView(context, filtered)
                : _buildScheduleView(schedule),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsView(BuildContext context, List<Transaction> filtered) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
                  child: EmptyStateCard(
                    cardKey: Key('activityEmptyState'),
                    icon: Icons.receipt_long_outlined,
                    title: 'No transactions yet',
                    message: 'Add income or expenses to see activity history.',
                  ),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final Transaction tx = filtered[index];
                    final bool isIncome = tx.type == 'income';

                    return PremiumCard(
                      child: ListTile(
                        key: Key('transactionTile_${tx.id}'),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AddTransactionScreen(initialTransaction: tx),
                            ),
                          );
                        },
                        contentPadding: const EdgeInsets.symmetric(vertical: 2),
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
                        trailing: Wrap(
                          spacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
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
    );
  }

  Widget _buildScheduleView(List<Map<String, dynamic>> schedule) {
    if (schedule.isEmpty) {
      return const Center(
        child: EmptyStateCard(
          cardKey: Key('zakatScheduleEmptyState'),
          icon: Icons.event_note,
          title: 'No Zakat Due Yet',
          message: 'Dues appear after your assets and income reach hawl and nisab.',
        ),
      );
    }

    final List<Map<String, dynamic>> sorted = List<Map<String, dynamic>>.from(schedule)
      ..sort((a, b) => (a['monthKey'] ?? '')
          .toString()
          .compareTo((b['monthKey'] ?? '').toString()));

    return ListView.separated(
      key: const Key('zakatScheduleList'),
      itemCount: sorted.length,
      separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 10),
      itemBuilder: (_, int index) {
        final Map<String, dynamic> row = sorted[index];
        final bool isPast = row['isPast'] == true;
        final bool isCurrent = row['isCurrentMonth'] == true;
        final List<dynamic> entries = (row['entries'] as List<dynamic>? ?? const []);
        final String status = isCurrent ? 'Due Now' : (isPast ? 'Past' : 'Upcoming');
        final String monthKey = (row['monthKey'] ?? '').toString();
        final String paymentDate = (row['paymentDate'] ?? '').toString();
        final double totalZakat = ((row['totalZakat'] ?? 0) as num).toDouble();

        return PremiumCard(
          child: ExpansionTile(
            key: Key('scheduleRow_$monthKey'),
            tilePadding: EdgeInsets.zero,
            title: Text('$monthKey • $paymentDate'),
            subtitle: Text('Entries: ${entries.length}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(_formatEgp(totalZakat), style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(status, style: const TextStyle(fontSize: 12)),
              ],
            ),
            children: entries.map((dynamic raw) {
              final Map<String, dynamic> entry = Map<String, dynamic>.from(raw as Map);
              final String type = (entry['type'] ?? 'entry').toString();
              final double amount = ((entry['zakatAmount'] ?? 0) as num).toDouble();
              return ListTile(
                dense: true,
                title: Text(type),
                subtitle: Text((entry['dueDateRaw'] ?? '').toString()),
                trailing: Text(_formatEgp(amount)),
              );
            }).toList(growable: false),
          ),
        );
      },
    );
  }

  static List<Map<String, dynamic>> _buildSchedule({
    required String zakatMethod,
    required String zakatAnnualDate,
    required List<Transaction> transactions,
    required List<Map<String, dynamic>> savings,
    required List<Map<String, dynamic>> investments,
    required MarketData marketData,
  }) {
    if (zakatMethod == 'annual') {
      return ZakatScheduleService.calculateAnnualZakatSchedule(
        zakatAnnualDate: zakatAnnualDate,
        transactions: transactions.map((e) => e.toJson()).toList(growable: false),
        savings: savings,
        investments: investments,
        marketData: marketData,
      );
    }

    final List<Map<String, dynamic>> monthly = ZakatScheduleService.calculateMonthlyZakatSchedule(
      transactions: transactions.map((e) => e.toJson()).toList(growable: false),
      marketData: marketData,
    );
    final List<Map<String, dynamic>> savingsSchedule =
        ZakatScheduleService.calculateSavingsZakatSchedule(
      savings: savings,
      marketData: marketData,
    );
    return <Map<String, dynamic>>[...monthly, ...savingsSchedule];
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

  static String _formatEgp(double value) {
    return 'E£ ${value.toStringAsFixed(2)}';
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
