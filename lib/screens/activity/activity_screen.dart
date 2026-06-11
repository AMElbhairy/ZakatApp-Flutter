import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/services/zakat_schedule_service.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../models/saving.dart';
import '../../models/transaction.dart';
import '../../services/app_state_controller.dart';
import '../entry/add_saving_screen.dart';
import '../entry/add_transaction_screen.dart';

enum _ActivityFilter { all, income, expense, transfer }

enum _ActivitySection { transactions, schedule }

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  ActivityScreenState createState() => ActivityScreenState();
}

class ActivityScreenState extends State<ActivityScreen> {
  _ActivityFilter _filter = _ActivityFilter.all;
  _ActivitySection _section = _ActivitySection.transactions;
  final TextEditingController _searchController = TextEditingController();

  // Filter States for Transactions
  String _selectedDateFilter = 'All Time';
  DateTimeRange? _customDateRange;
  String _selectedCategory = 'All';

  // Filter States for Zakat Schedule (Default "not paid only" filter to true)
  bool _showUnpaidOnly = true;
  String _zakatDateFilter = 'All Time';
  DateTimeRange? _zakatCustomDateRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void showSchedule() {
    if (!mounted) return;
    setState(() => _section = _ActivitySection.schedule);
  }

  void showTransactions() {
    if (!mounted) return;
    setState(() => _section = _ActivitySection.transactions);
  }

  Future<void> _selectCustomRange(
    BuildContext context, {
    required bool isZakat,
  }) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange:
          (isZakat ? _zakatCustomDateRange : _customDateRange) ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );
    if (picked != null) {
      setState(() {
        if (isZakat) {
          _zakatCustomDateRange = picked;
          _zakatDateFilter = 'Custom';
        } else {
          _customDateRange = picked;
          _selectedDateFilter = 'Custom';
        }
      });
    }
  }

  void _showCategoryPicker(
    BuildContext context,
    List<String> sortedCategories,
  ) {
    final tokens = context.premiumTokens;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: tokens.colors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Top Bar Drag Handle & Title
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.colors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                child: Text(
                  context.l10n.tr('select_payment_category'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: tokens.colors.textPrimary,
                  ),
                ),
              ),
              const Divider(),
              // Categories List
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sortedCategories.length,
                  itemBuilder: (BuildContext context, int index) {
                    final String category = sortedCategories[index];
                    final bool isSelected = _selectedCategory == category;
                    String label = category;
                    if (category == 'All') {
                      label = context.l10n.tr('all_categories');
                    }

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 2,
                      ),
                      title: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? tokens.colors.gold
                              : tokens.colors.textPrimary,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              color: tokens.colors.gold,
                              size: 20,
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double navSafeBottomPadding =
        112 + MediaQuery.paddingOf(context).bottom;
    final controller = context.watch<AppStateController>();
    final state = controller.state;
    final List<Transaction> transactions = state.transactions;

    final tokens = context.premiumTokens;
    final bool balancesHidden =
        state.aiSettings?['privacyMode'] == true ||
        state.aiSettings?['hideBalances'] == true ||
        state.aiSettings?['balancesHidden'] == true;

    final Map<String, List<Transaction>> exchangePairs =
        <String, List<Transaction>>{};
    for (final Transaction transaction in transactions.where(
      (Transaction transaction) =>
          transaction.category == 'Currency Exchange' &&
          (transaction.exchangePairId ?? '').isNotEmpty,
    )) {
      exchangePairs
          .putIfAbsent(transaction.exchangePairId!, () => <Transaction>[])
          .add(transaction);
    }
    final Map<String, List<Saving>> exchangeSavings = <String, List<Saving>>{};
    for (final Saving saving in state.savings.where(
      (Saving saving) => (saving.transferActivityId ?? '').isNotEmpty,
    )) {
      exchangeSavings
          .putIfAbsent(saving.transferActivityId!, () => <Saving>[])
          .add(saving);
    }
    final Set<String> exchangeActivityIds = <String>{
      ...exchangePairs.keys,
      ...exchangeSavings.keys,
    };
    final Set<String> fundedMetalIds = state.savings
        .where((Saving saving) => saving.fundingAllocations.isNotEmpty)
        .map((Saving saving) => saving.id)
        .toSet();
    final List<_ActivityEntry> sorted =
        <_ActivityEntry>[
          ...transactions
              .where(
                (Transaction transaction) =>
                    !transaction.isTransferActivity ||
                    ((transaction.exchangePairId ?? '').isEmpty &&
                        !fundedMetalIds.contains(transaction.exchangePairId)),
              )
              .map(_ActivityEntry.transaction),
          ...exchangeActivityIds.map(
            (String id) => _ActivityEntry.currencyExchange(
              exchangePairs[id] ?? const <Transaction>[],
              exchangeSavings[id] ?? const <Saving>[],
            ),
          ),
          ...state.savings
              .where(
                (Saving saving) =>
                    (saving.exchangeSourceSavingId ?? '').isNotEmpty &&
                    (saving.transferActivityId ?? '').isEmpty,
              )
              .map(_ActivityEntry.legacySavingExchange),
          ...state.savings
              .where((Saving saving) => saving.fundingAllocations.isNotEmpty)
              .map(_ActivityEntry.metalTransfer),
          ...state.savings
              .where(
                (Saving saving) =>
                    saving.assetType == 'cash' &&
                    (saving.exchangeSourceSavingId ?? '').isEmpty &&
                    (saving.exchangeSourceIncomeId ?? '').isEmpty,
              )
              .map(_ActivityEntry.cashSaving),
        ]..sort((_ActivityEntry a, _ActivityEntry b) {
          final DateTime ad = _parseDate(a.date);
          final DateTime bd = _parseDate(b.date);
          final int byDate = bd.compareTo(ad);
          if (byDate != 0) return byDate;
          return b.createdAt.compareTo(a.createdAt);
        });

    // 1. First, apply type and date filters
    final List<_ActivityEntry> filteredByTypeAndDate = sorted
        .where((_ActivityEntry entry) {
          switch (_filter) {
            case _ActivityFilter.income:
              return entry.isIncome;
            case _ActivityFilter.expense:
              return entry.isExpense;
            case _ActivityFilter.transfer:
              return entry.isTransfer;
            case _ActivityFilter.all:
              return true;
          }
        })
        .where((_ActivityEntry entry) {
          if (_selectedDateFilter == 'All Time') return true;
          final DateTime date = _parseDate(entry.date);
          final DateTime now = DateTime.now();
          if (_selectedDateFilter == '30D') {
            return date.isAfter(now.subtract(const Duration(days: 30))) ||
                date.isAtSameMomentAs(now.subtract(const Duration(days: 30)));
          } else if (_selectedDateFilter == '90D') {
            return date.isAfter(now.subtract(const Duration(days: 90))) ||
                date.isAtSameMomentAs(now.subtract(const Duration(days: 90)));
          } else if (_selectedDateFilter == 'YTD') {
            return date.year == now.year;
          } else if (_selectedDateFilter == 'Custom' &&
              _customDateRange != null) {
            return (date.isAfter(_customDateRange!.start) ||
                    date.isAtSameMomentAs(_customDateRange!.start)) &&
                (date.isBefore(_customDateRange!.end) ||
                    date.isAtSameMomentAs(_customDateRange!.end));
          }
          return true;
        })
        .toList(growable: false);

    // 2. Extract unique categories from the list that met the active type & date filters
    final Set<String> availableCategories = {
      ...filteredByTypeAndDate.map(
        (entry) => entry.isCashSaving
            ? context.l10n.tr('cash_in')
            : entry.transaction!.category,
      ),
    };
    final List<String> sortedCategories = [
      'All',
      ...availableCategories.toList()..sort(),
    ];

    // Reset category to 'All' if the currently selected one is no longer available under the current active list
    if (!sortedCategories.contains(_selectedCategory)) {
      _selectedCategory = 'All';
    }

    // 3. Finally, filter by the selected category and transaction note.
    final String searchQuery = _searchController.text.trim().toLowerCase();
    final List<_ActivityEntry> filtered = filteredByTypeAndDate
        .where((_ActivityEntry entry) {
          if (_selectedCategory == 'All') return true;
          final String catName = entry.isCashSaving
              ? context.l10n.tr('cash_in')
              : entry.transaction!.category;
          return catName == _selectedCategory;
        })
        .where((_ActivityEntry entry) {
          if (searchQuery.isEmpty) return true;
          return entry.transaction?.description.toLowerCase().contains(
                searchQuery,
              ) ??
              false;
        })
        .toList(growable: false);

    final MarketData market = MarketData.fromJson(state.marketData);
    final List<Map<String, dynamic>> schedule = _buildSchedule(
      zakatMethod: state.zakatMethod,
      zakatAnnualDate: state.zakatAnnualDate,
      transactions: state.transactions,
      savings: state.savings.map((e) => e.toJson()).toList(growable: false),
      investments: state.investments
          .map((e) => e.toJson())
          .toList(growable: false),
      marketData: market,
      lastRollover: state.lastRollover,
      zakatNisabBasis: state.zakatNisabBasis,
    );
    final Set<String> paidMonths = state.zakatPaidMonths.toSet();

    return Container(
      color: tokens.colors.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _ActivityHeader(
              title: context.l10n.tr('activity'),
              balancesHidden: balancesHidden,
              onTogglePrivacy: () => controller.togglePrivacyMode(),
              hasNotifications: false,
              onTapNotifications: () {},
            ),
            const SizedBox(height: 18),
            SegmentedButton<_ActivitySection>(
              key: const Key('activitySectionSegment'),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: tokens.colors.gold.withValues(
                  alpha: 0.15,
                ),
                selectedForegroundColor: tokens.colors.textPrimary,
                side: BorderSide(
                  color: tokens.colors.gold.withValues(alpha: 0.3),
                ),
              ),
              segments: <ButtonSegment<_ActivitySection>>[
                ButtonSegment<_ActivitySection>(
                  value: _ActivitySection.transactions,
                  label: Text(
                    context.l10n.tr('transactions'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                ButtonSegment<_ActivitySection>(
                  value: _ActivitySection.schedule,
                  label: Text(
                    context.l10n.tr('zakat_schedule'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              selected: <_ActivitySection>{_section},
              onSelectionChanged: (Set<_ActivitySection> selected) {
                setState(() => _section = selected.first);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _section == _ActivitySection.transactions
                  ? _buildTransactionsView(
                      context,
                      filtered,
                      sortedCategories,
                      balancesHidden,
                    )
                  : _buildScheduleView(
                      context,
                      schedule,
                      paidMonths: paidMonths,
                      balancesHidden: balancesHidden,
                      navSafeBottomPadding: navSafeBottomPadding,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsView(
    BuildContext context,
    List<_ActivityEntry> filtered,
    List<String> sortedCategories,
    bool balancesHidden,
  ) {
    final double navSafeBottomPadding =
        112 + MediaQuery.paddingOf(context).bottom;
    final tokens = context.premiumTokens;

    String catFilterLabel = _selectedCategory == 'All'
        ? context.l10n.tr('all_categories')
        : _selectedCategory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SegmentedButton<_ActivityFilter>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: tokens.colors.gold.withValues(alpha: 0.1),
            selectedForegroundColor: tokens.colors.textPrimary,
            side: BorderSide(color: tokens.colors.gold.withValues(alpha: 0.15)),
            textStyle: const TextStyle(fontSize: 12),
          ),
          segments: <ButtonSegment<_ActivityFilter>>[
            ButtonSegment<_ActivityFilter>(
              value: _ActivityFilter.all,
              label: Text(context.l10n.tr('all'), maxLines: 1, softWrap: false),
            ),
            ButtonSegment<_ActivityFilter>(
              value: _ActivityFilter.income,
              label: Text(
                context.l10n.tr('income'),
                maxLines: 1,
                softWrap: false,
              ),
            ),
            ButtonSegment<_ActivityFilter>(
              value: _ActivityFilter.expense,
              label: Text(
                context.l10n.tr('expense'),
                maxLines: 1,
                softWrap: false,
              ),
            ),
            ButtonSegment<_ActivityFilter>(
              value: _ActivityFilter.transfer,
              label: Text(
                context.l10n.tr('transfer'),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ],
          selected: <_ActivityFilter>{_filter},
          onSelectionChanged: (Set<_ActivityFilter> selected) {
            setState(() {
              _filter = selected.first;
              _selectedCategory = 'All';
            });
          },
        ),
        const SizedBox(height: 12),

        // Date Filter Row
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 18,
                      color: tokens.colors.textPrimary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    ...<String>['All Time', '30D', '90D', 'YTD', 'Custom'].map((
                      filter,
                    ) {
                      final bool isSelected = _selectedDateFilter == filter;
                      String label = filter;
                      if (filter == 'All Time') {
                        label = context.l10n.tr('all');
                      }
                      if (filter == 'Custom' &&
                          _customDateRange != null &&
                          _selectedDateFilter == 'Custom') {
                        final String startStr =
                            '${_customDateRange!.start.day}/${_customDateRange!.start.month}';
                        final String endStr =
                            '${_customDateRange!.end.day}/${_customDateRange!.end.month}';
                        label = '$startStr-$endStr';
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          labelPadding: EdgeInsets.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          visualDensity: const VisualDensity(
                            horizontal: -2,
                            vertical: -3,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            if (filter == 'Custom') {
                              _selectCustomRange(context, isZakat: false);
                            } else {
                              setState(() {
                                _selectedDateFilter = filter;
                              });
                            }
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),

        // Category and note search filters
        Row(
          children: <Widget>[
            Icon(
              Icons.filter_list_rounded,
              size: 18,
              color: tokens.colors.textPrimary.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              avatar: Icon(
                Icons.filter_list_rounded,
                size: 14,
                color: _selectedCategory != 'All'
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : tokens.colors.textPrimary.withValues(alpha: 0.6),
              ),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: _selectedCategory != 'All'
                    ? FontWeight.bold
                    : FontWeight.w500,
              ),
              label: Text(catFilterLabel),
              selected: _selectedCategory != 'All',
              onSelected: (bool selected) =>
                  _showCategoryPicker(context, sortedCategories),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 34,
                child: TextField(
                  key: const Key('activitySearchField'),
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: context.l10n.tr('search_notes'),
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: tokens.colors.textSecondary,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 17,
                      color: tokens.colors.textPrimary.withValues(alpha: 0.6),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 34),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            key: const Key('clearActivitySearch'),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: tokens.colors.textSecondary,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          ),
                    suffixIconConstraints: const BoxConstraints(minWidth: 32),
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: tokens.colors.gold.withValues(alpha: 0.15),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: tokens.colors.gold.withValues(alpha: 0.15),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: tokens.colors.gold.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: EmptyStateCard(
                    cardKey: const Key('activityEmptyState'),
                    icon: Icons.receipt_long_outlined,
                    title: context.l10n.tr('no_transactions_yet'),
                    message: context.l10n.tr('activity_empty_message'),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.only(bottom: navSafeBottomPadding),
                  itemCount: filtered.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final _ActivityEntry entry = filtered[index];

                    return PremiumCard(
                      child: ListTile(
                        key: Key('activityTile_${entry.key}'),
                        onTap: () {
                          if (entry.isTransfer) {
                            return;
                          } else if (entry.transaction != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AddTransactionScreen(
                                  initialTransaction: entry.transaction,
                                ),
                              ),
                            );
                          } else if (entry.saving != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AddSavingScreen(
                                  initialSaving: entry.saving,
                                ),
                              ),
                            );
                          }
                        },
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 2,
                          horizontal: 4,
                        ),
                        title: Row(
                          children: <Widget>[
                            _TypeBadge(type: entry.type),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.title(context),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${entry.date} • '
                                '${ZakatEngineService.getCurrencySymbol(entry.currency, isArabic: Localizations.localeOf(context).languageCode.toLowerCase() == 'ar')}',
                                style: TextStyle(
                                  color: tokens.colors.textSecondary,
                                ),
                              ),
                              if (entry.description.trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    entry.description,
                                    style: TextStyle(
                                      color: tokens.colors.textSecondary
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              balancesHidden
                                  ? '••••••'
                                  : ZakatEngineService.formatCurrency(
                                      entry.signedAmount,
                                      entry.currency,
                                      isArabic:
                                          Localizations.localeOf(
                                            context,
                                          ).languageCode.toLowerCase() ==
                                          'ar',
                                      showSign: !entry.isTransfer,
                                    ),
                              style: TextStyle(
                                color: entry.isTransfer
                                    ? const Color(0xFFB8860B)
                                    : (entry.isIncome
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFC62828)),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            IconButton(
                              key: Key('deleteActivityEntry_${entry.key}'),
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: tokens.colors.textSecondary,
                              onPressed: () =>
                                  _confirmDeleteActivityEntry(context, entry),
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

  Widget _buildScheduleView(
    BuildContext context,
    List<Map<String, dynamic>> schedule, {
    required Set<String> paidMonths,
    required bool balancesHidden,
    required double navSafeBottomPadding,
  }) {
    final tokens = context.premiumTokens;

    if (schedule.isEmpty) {
      return Center(
        child: EmptyStateCard(
          cardKey: const Key('zakatScheduleEmptyState'),
          icon: Icons.event_note,
          title: context.l10n.tr('zakat_schedule'),
          message: context.l10n.tr('schedule_empty_message'),
        ),
      );
    }

    final List<Map<String, dynamic>> sorted =
        List<Map<String, dynamic>>.from(schedule)..sort(
          (a, b) => (a['monthKey'] ?? '').toString().compareTo(
            (b['monthKey'] ?? '').toString(),
          ),
        );

    final DateTime now = DateTime.now();

    // Filter by unpaid status & date range
    final List<Map<String, dynamic>> filtered = sorted.where((row) {
      if (_showUnpaidOnly) {
        final String monthKey = (row['monthKey'] ?? '').toString();
        if (paidMonths.contains(monthKey)) return false;
      }

      if (_zakatDateFilter != 'All Time') {
        final DateTime date = _parseDate((row['paymentDate'] ?? '').toString());
        if (_zakatDateFilter == '30D') {
          return date.isAfter(now.subtract(const Duration(days: 30))) ||
              date.isAtSameMomentAs(now.subtract(const Duration(days: 30)));
        } else if (_zakatDateFilter == '90D') {
          return date.isAfter(now.subtract(const Duration(days: 90))) ||
              date.isAtSameMomentAs(now.subtract(const Duration(days: 90)));
        } else if (_zakatDateFilter == 'YTD') {
          return date.year == now.year;
        } else if (_zakatDateFilter == 'Custom' &&
            _zakatCustomDateRange != null) {
          return (date.isAfter(_zakatCustomDateRange!.start) ||
                  date.isAtSameMomentAs(_zakatCustomDateRange!.start)) &&
              (date.isBefore(_zakatCustomDateRange!.end) ||
                  date.isAtSameMomentAs(_zakatCustomDateRange!.end));
        }
      }

      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Date Filter Row
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 18,
                      color: tokens.colors.textPrimary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),

                    // Date Range chips for Zakat Schedule
                    ...<String>['All Time', '30D', '90D', 'YTD', 'Custom'].map((
                      filter,
                    ) {
                      final bool isSelected = _zakatDateFilter == filter;
                      String label = filter;
                      if (filter == 'All Time') {
                        label = context.l10n.tr('all');
                      }
                      if (filter == 'Custom' &&
                          _zakatCustomDateRange != null &&
                          _zakatDateFilter == 'Custom') {
                        final String startStr =
                            '${_zakatCustomDateRange!.start.day}/${_zakatCustomDateRange!.start.month}';
                        final String endStr =
                            '${_zakatCustomDateRange!.end.day}/${_zakatCustomDateRange!.end.month}';
                        label = '$startStr-$endStr';
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          labelPadding: EdgeInsets.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          visualDensity: const VisualDensity(
                            horizontal: -2,
                            vertical: -3,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            if (filter == 'Custom') {
                              _selectCustomRange(context, isZakat: true);
                            } else {
                              setState(() {
                                _zakatDateFilter = filter;
                              });
                            }
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),

        // Unpaid Toggle Row (Separate Row underneath, matching Transactions Categories layout)
        Row(
          children: <Widget>[
            Icon(
              Icons.filter_list_rounded,
              size: 18,
              color: tokens.colors.textPrimary.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: _showUnpaidOnly ? FontWeight.w700 : FontWeight.w500,
              ),
              label: Text(context.l10n.tr('not_paid')),
              selected: _showUnpaidOnly,
              onSelected: (bool selected) {
                setState(() {
                  _showUnpaidOnly = selected;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: EmptyStateCard(
                    cardKey: const Key('zakatScheduleFilteredEmptyState'),
                    icon: Icons.event_note_outlined,
                    title: context.l10n.tr('zakat_schedule'),
                    message: context.l10n.tr('schedule_empty_message'),
                  ),
                )
              : ListView.separated(
                  key: const Key('zakatScheduleList'),
                  padding: EdgeInsets.only(bottom: navSafeBottomPadding),
                  itemCount: filtered.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (_, int index) {
                    final Map<String, dynamic> row = filtered[index];
                    final bool isPast = row['isPast'] == true;
                    final bool isCurrent = row['isCurrentMonth'] == true;
                    final List<dynamic> entries =
                        (row['entries'] as List<dynamic>? ?? const []);
                    final String status = isCurrent
                        ? context.l10n.tr('due_now')
                        : (isPast
                              ? context.l10n.tr('past')
                              : context.l10n.tr('upcoming'));
                    final String monthKey = (row['monthKey'] ?? '').toString();
                    final String paymentDate = (row['paymentDate'] ?? '')
                        .toString();
                    final String hijriDate = (row['hijriDate'] ?? '')
                        .toString();
                    final String titleText = hijriDate.isEmpty
                        ? '$monthKey • $paymentDate'
                        : '$paymentDate • $hijriDate AH';
                    final double totalZakat = ((row['totalZakat'] ?? 0) as num)
                        .toDouble();
                    final bool isPaid = paidMonths.contains(monthKey);

                    return PremiumCard(
                      child: Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          key: Key('scheduleRow_$monthKey'),
                          tilePadding: EdgeInsets.zero,
                          title: Text(
                            titleText,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${context.l10n.tr('entries')}: ${entries.length}',
                            style: TextStyle(
                              color: tokens.colors.textSecondary,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                balancesHidden
                                    ? '••••••'
                                    : _formatEgp(context, totalZakat),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? tokens.colors.gold.withValues(
                                          alpha: 0.15,
                                        )
                                      : (isPast
                                            ? tokens.colors.textSecondary
                                                  .withValues(alpha: 0.1)
                                            : tokens.colors.gold.withValues(
                                                alpha: 0.05,
                                              )),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrent
                                        ? tokens.colors.textPrimary
                                        : tokens.colors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Row(
                                    children: [
                                      Icon(
                                        isPaid
                                            ? Icons.check_circle_rounded
                                            : Icons
                                                  .radio_button_unchecked_rounded,
                                        color: isPaid
                                            ? const Color(0xFF2E7D32)
                                            : tokens.colors.textSecondary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isPaid
                                            ? context.l10n.tr('paid')
                                            : context.l10n.tr('not_paid'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isPaid
                                              ? const Color(0xFF2E7D32)
                                              : tokens.colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton(
                                    key: Key('toggleZakatPaid_$monthKey'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: tokens.colors.gold,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                    ),
                                    onPressed: () => context
                                        .read<AppStateController>()
                                        .toggleZakatPaid(
                                          monthKey: monthKey,
                                          zakatAmountMainCurrency: totalZakat,
                                          paymentDate: paymentDate,
                                        ),
                                    child: Text(
                                      isPaid
                                          ? context.l10n.tr('undo_paid')
                                          : context.l10n.tr('mark_zakat_paid'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            ...entries.map((dynamic raw) {
                              final Map<String, dynamic> entry =
                                  Map<String, dynamic>.from(raw as Map);
                              final String type = (entry['type'] ?? 'entry')
                                  .toString();
                              final double amount =
                                  ((entry['zakatAmount'] ?? 0) as num)
                                      .toDouble();
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                title: Text(
                                  type.toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  (entry['dueDateRaw'] ?? '').toString(),
                                  style: TextStyle(
                                    color: tokens.colors.textSecondary,
                                  ),
                                ),
                                trailing: Text(
                                  balancesHidden
                                      ? '••••••'
                                      : _formatEgp(context, amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }),
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

  static List<Map<String, dynamic>> _buildSchedule({
    required String zakatMethod,
    required String zakatAnnualDate,
    required List<Transaction> transactions,
    required List<Map<String, dynamic>> savings,
    required List<Map<String, dynamic>> investments,
    required MarketData marketData,
    String? lastRollover,
    String? zakatNisabBasis,
  }) {
    if (zakatMethod == 'annual') {
      return ZakatScheduleService.calculateAnnualZakatSchedule(
        zakatAnnualDate: zakatAnnualDate,
        transactions: transactions
            .map((e) => e.toJson())
            .toList(growable: false),
        savings: savings,
        investments: investments,
        marketData: marketData,
        lastRollover: lastRollover,
        zakatNisabBasis: zakatNisabBasis,
      );
    }

    final List<Map<String, dynamic>> transactionJson = transactions
        .map((e) => e.toJson())
        .toList(growable: false);
    final List<Map<String, dynamic>> monthly =
        ZakatScheduleService.calculateMonthlyZakatSchedule(
          transactions: transactionJson,
          savings: savings,
          marketData: marketData,
          lastRollover: lastRollover,
          zakatNisabBasis: zakatNisabBasis,
        );
    final List<Map<String, dynamic>> savingsSchedule =
        ZakatScheduleService.calculateSavingsZakatSchedule(
          savings: savings,
          transactions: transactionJson,
          marketData: marketData,
          lastRollover: lastRollover,
          zakatNisabBasis: zakatNisabBasis,
        );
    return <Map<String, dynamic>>[...monthly, ...savingsSchedule];
  }

  Future<void> _confirmDelete(BuildContext context, Transaction tx) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(context.l10n.tr('delete_transaction')),
              content: Text(context.l10n.tr('delete_transaction_message')),
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
    await context.read<AppStateController>().deleteTransaction(tx.id);
  }

  Future<void> _confirmDeleteSaving(BuildContext context, Saving saving) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(context.l10n.tr('delete_saving')),
              content: Text(context.l10n.tr('delete_saving_message')),
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
    await context.read<AppStateController>().deleteSaving(saving.id);
  }

  Future<void> _confirmDeleteActivityEntry(
    BuildContext context,
    _ActivityEntry entry,
  ) async {
    final Transaction? tx = entry.transaction;
    if (tx != null) {
      await _confirmDelete(context, tx);
      return;
    }

    final Saving? saving = entry.saving;
    if (saving != null) {
      await _confirmDeleteSaving(context, saving);
    }
  }

  static DateTime _parseDate(String raw) {
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  static String _formatEgp(BuildContext context, double value) {
    return _formatDisplay(context, value, 'EGP');
  }

  static String _formatDisplay(
    BuildContext context,
    double value,
    String currencyCode,
  ) {
    return ZakatEngineService.formatCurrency(
      value,
      currencyCode,
      isArabic:
          Localizations.localeOf(context).languageCode.toLowerCase() == 'ar',
    );
  }
}

class _ActivityEntry {
  const _ActivityEntry._({
    this.transaction,
    this.saving,
    this.transferTitle,
    this.transferDescription,
    this.transferKey,
    this.transferDate,
    this.transferCreatedAt,
    this.transferCurrency,
    this.transferAmount,
  });

  factory _ActivityEntry.transaction(Transaction transaction) {
    return _ActivityEntry._(transaction: transaction);
  }

  factory _ActivityEntry.cashSaving(Saving saving) {
    return _ActivityEntry._(saving: saving);
  }

  factory _ActivityEntry.currencyExchange(
    List<Transaction> pair,
    List<Saving> targetSavings,
  ) {
    final Transaction? sourceTransaction = pair
        .where((Transaction transaction) => transaction.type == 'expense')
        .firstOrNull;
    final Transaction? targetTransaction = pair
        .where((Transaction transaction) => transaction.type == 'income')
        .firstOrNull;
    final Saving? targetSaving = targetSavings.firstOrNull;
    final Transaction source =
        sourceTransaction ??
        pair.firstOrNull ??
        Transaction(
          id: targetSaving!.id,
          type: 'expense',
          date: targetSaving.dateAcquired,
          amount: 0,
          currency: '',
          category: 'Currency Exchange',
          description: '',
          createdAt: targetSaving.createdAt,
          rolledOver: false,
        );
    final RegExp savingExchangePattern = RegExp(
      r'Savings exchange:\s*([0-9.]+)\s+([A-Z]+)\s+→',
    );
    final double savingSourceAmount = targetSavings.fold<double>(
      0,
      (double total, Saving saving) =>
          total +
          (double.tryParse(
                savingExchangePattern
                        .firstMatch(saving.description)
                        ?.group(1) ??
                    '',
              ) ??
              0),
    );
    final String savingSourceCurrency =
        savingExchangePattern
            .firstMatch(targetSaving?.description ?? '')
            ?.group(2) ??
        '';
    final String sourceCurrency = sourceTransaction?.currency.isNotEmpty == true
        ? sourceTransaction!.currency
        : savingSourceCurrency;
    final String targetCurrency = targetTransaction?.currency.isNotEmpty == true
        ? targetTransaction!.currency
        : (targetSaving?.unit ?? '');
    final double sourceAmount =
        pair
            .where((Transaction transaction) => transaction.type == 'expense')
            .fold<double>(0, (double total, Transaction transaction) {
              return total + transaction.amount;
            }) +
        savingSourceAmount;
    final double targetAmount =
        pair
            .where((Transaction transaction) => transaction.type == 'income')
            .fold<double>(0, (double total, Transaction transaction) {
              return total + transaction.amount;
            }) +
        targetSavings.fold<double>(
          0,
          (double total, Saving saving) => total + saving.amount,
        );
    return _ActivityEntry._(
      transaction: source,
      transferTitle: 'Currency Exchange',
      transferDescription:
          '${sourceAmount.toStringAsFixed(2)} $sourceCurrency → ${targetAmount.toStringAsFixed(2)} $targetCurrency',
      transferKey: 'exchange_${source.exchangePairId ?? source.id}',
      transferDate: source.date,
      transferCreatedAt: source.createdAt,
      transferCurrency: sourceCurrency,
      transferAmount: sourceAmount,
    );
  }

  factory _ActivityEntry.legacySavingExchange(Saving saving) {
    final RegExp pattern = RegExp(
      r'Savings exchange:\s*([0-9.]+)\s+([A-Z]+)\s+→',
    );
    final Match? match = pattern.firstMatch(saving.description);
    final double sourceAmount = double.tryParse(match?.group(1) ?? '') ?? 0;
    final String sourceCurrency = match?.group(2) ?? saving.unit;
    return _ActivityEntry._(
      saving: saving,
      transferTitle: 'Currency Exchange',
      transferDescription:
          '${sourceAmount.toStringAsFixed(2)} $sourceCurrency → ${saving.amount.toStringAsFixed(2)} ${saving.unit}',
      transferKey: 'legacy_exchange_${saving.id}',
      transferDate: saving.dateAcquired,
      transferCreatedAt: saving.createdAt,
      transferCurrency: sourceCurrency,
      transferAmount: sourceAmount,
    );
  }

  factory _ActivityEntry.metalTransfer(Saving saving) {
    final String metal = saving.assetType == 'gold' ? 'Gold' : 'Silver';
    return _ActivityEntry._(
      saving: saving,
      transferTitle: '$metal Purchase',
      transferDescription:
          '${saving.purchaseAmount.toStringAsFixed(2)} ${saving.purchaseCurrency} Cash → ${saving.amount.toStringAsFixed(2)}g $metal',
      transferKey: 'metal_${saving.id}',
      transferDate: saving.dateAcquired,
      transferCreatedAt: saving.createdAt,
      transferCurrency: saving.purchaseCurrency,
      transferAmount: saving.purchaseAmount,
    );
  }

  final Transaction? transaction;
  final Saving? saving;
  final String? transferTitle;
  final String? transferDescription;
  final String? transferKey;
  final String? transferDate;
  final String? transferCreatedAt;
  final String? transferCurrency;
  final double? transferAmount;

  bool get isCashSaving => saving != null;
  bool get isTransfer =>
      transferTitle != null || transaction?.isTransferActivity == true;
  bool get isIncome =>
      !isTransfer && (isCashSaving || transaction?.type == 'income');
  bool get isExpense => !isTransfer && transaction?.type == 'expense';
  String get type {
    if (isTransfer) return 'transfer';
    if (isCashSaving) return 'savings';
    return isIncome ? 'income' : 'expense';
  }

  String get key =>
      transferKey ??
      (isCashSaving ? 'saving_${saving!.id}' : 'tx_${transaction!.id}');
  String get date {
    if (transferDate != null) return transferDate!;
    final Saving? cashSaving = saving;
    if (cashSaving != null) {
      if ((cashSaving.exchangeSourceSavingId ?? '').isNotEmpty &&
          cashSaving.createdAt.isNotEmpty) {
        return cashSaving.createdAt;
      }
      return cashSaving.dateAcquired;
    }
    return transaction!.date;
  }

  String get createdAt =>
      transferCreatedAt ?? saving?.createdAt ?? transaction!.createdAt;
  String get currency =>
      transferCurrency ?? saving?.unit ?? transaction!.currency;
  double get amount => transferAmount ?? saving?.amount ?? transaction!.amount;
  double get signedAmount => isExpense ? -amount : amount;
  String get description =>
      transferDescription ?? saving?.description ?? transaction!.description;

  String title(BuildContext context) {
    if (transferTitle != null) return transferTitle!;
    if (isCashSaving) return context.l10n.tr('cash_in');
    return transaction!.category;
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final bool isIncome = type == 'income';
    final bool isSavings = type == 'savings';
    final bool isTransfer = type == 'transfer';
    final Color bg = isTransfer
        ? const Color(0xFFFFF4CC)
        : isSavings
        ? const Color(0xFFEAF3FF)
        : (isIncome ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE));
    final Color fg = isTransfer
        ? const Color(0xFF8A6500)
        : isSavings
        ? const Color(0xFF174A7C)
        : (isIncome ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C));
    final String label = isTransfer
        ? context.l10n.tr('transfer')
        : isSavings
        ? context.l10n.tr('savings')
        : (isIncome ? context.l10n.tr('income') : context.l10n.tr('expense'));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader({
    required this.title,
    required this.balancesHidden,
    required this.onTogglePrivacy,
    required this.hasNotifications,
    required this.onTapNotifications,
  });

  final String title;
  final bool balancesHidden;
  final VoidCallback onTogglePrivacy;
  final bool hasNotifications;
  final VoidCallback onTapNotifications;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: textTheme.headlineMedium?.copyWith(
              color: tokens.colors.textPrimary,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _HeaderCircleButton(
              icon: balancesHidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              iconColor: tokens.colors.textPrimary,
              onPressed: onTogglePrivacy,
            ),
            const SizedBox(width: 10),
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                _HeaderCircleButton(
                  icon: Icons.notifications_none_rounded,
                  iconColor: tokens.colors.textPrimary,
                  onPressed: onTapNotifications,
                ),
                if (hasNotifications)
                  PositionedDirectional(
                    end: 7,
                    top: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: tokens.colors.gold,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: tokens.colors.background,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({
    required this.icon,
    required this.iconColor,
    required this.onPressed,
  });

  final IconData icon;
  final Color iconColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark
          ? Colors.white.withValues(alpha: 0.03)
          : Colors.white.withValues(alpha: 0.74),
      shape: const CircleBorder(),
      elevation: dark ? 0 : 5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: SizedBox(
        width: 52,
        height: 52,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: iconColor, size: 24),
          splashRadius: 24,
        ),
      ),
    );
  }
}
