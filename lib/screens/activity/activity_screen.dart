// ignore_for_file: avoid_print
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

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
import '../../core/widgets/currency_exchange_dialog.dart';
import '../../core/widgets/sell_metal_dialog.dart';
import '../account/notifications_screen.dart';
import '../../models/pending_transaction.dart';

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
      (Saving saving) =>
          (saving.transferActivityId ?? '').isNotEmpty &&
          saving.internalTransferType == 'savings_currency_exchange',
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
                    transaction.category == 'Gold Sale' ||
                    transaction.category == 'Silver Sale' ||
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
              .where(
                (Saving saving) =>
                    saving.fundingAllocations.isNotEmpty ||
                    ZakatEngineService.normaliseAssetType(saving.assetType) ==
                        'gold' ||
                    ZakatEngineService.normaliseAssetType(saving.assetType) ==
                        'silver',
              )
              .map(_ActivityEntry.metalTransfer),
          ...state.savings
              .where(
                (Saving saving) =>
                    saving.assetType == 'cash' &&
                    (saving.exchangeSourceSavingId ?? '').isEmpty &&
                    (saving.exchangeSourceIncomeId ?? '').isEmpty &&
                    (saving.transferActivityId ?? '').isEmpty,
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
          return entry.description.toLowerCase().contains(searchQuery);
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
              hasNotifications: state.pendingTransactions.any(
                (t) => t.status == CaptureStatus.pendingReview,
              ),
              onTapNotifications: () {
                Navigator.of(context).push(NotificationsScreen.route());
              },
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
    final controller = context.read<AppStateController>();
    final state = controller.state;
    final String mainCurrency = state.mainCurrency;
    final MarketData market = MarketData.fromJson(state.marketData);
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

    String catFilterLabel = _selectedCategory == 'All'
        ? context.l10n.tr('all_categories')
        : _selectedCategory;

    // Filtered by type and date only for Summary Strip calculations
    final List<Transaction> transactions = state.transactions;
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
      (Saving saving) =>
          (saving.transferActivityId ?? '').isNotEmpty &&
          saving.internalTransferType == 'savings_currency_exchange',
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

    final List<_ActivityEntry> sortedForSummary = <_ActivityEntry>[
      ...transactions
          .where(
            (Transaction transaction) =>
                !transaction.isTransferActivity ||
                transaction.category == 'Gold Sale' ||
                transaction.category == 'Silver Sale' ||
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
          .where(
            (Saving saving) =>
                saving.fundingAllocations.isNotEmpty ||
                ZakatEngineService.normaliseAssetType(saving.assetType) ==
                    'gold' ||
                ZakatEngineService.normaliseAssetType(saving.assetType) ==
                    'silver',
          )
          .map(_ActivityEntry.metalTransfer),
      ...state.savings
          .where(
            (Saving saving) =>
                saving.assetType == 'cash' &&
                (saving.exchangeSourceSavingId ?? '').isEmpty &&
                (saving.exchangeSourceIncomeId ?? '').isEmpty &&
                (saving.transferActivityId ?? '').isEmpty,
          )
          .map(_ActivityEntry.cashSaving),
    ];

    final List<_ActivityEntry> filteredByTypeAndDate = sortedForSummary
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

    double totalIncome = 0.0;
    double totalExpenses = 0.0;
    double totalTransfers = 0.0;

    for (final entry in filteredByTypeAndDate) {
      final double amtEgp = ZakatEngineService.convertToEgp(
        entry.amount,
        entry.currency,
        market,
      );
      final double amtMain = ZakatEngineService.convertFromEgp(
        amtEgp,
        mainCurrency,
        market,
      );
      if (entry.isTransfer) {
        totalTransfers += amtMain;
      } else if (entry.isIncome) {
        totalIncome += amtMain;
      } else if (entry.isExpense) {
        totalExpenses += amtMain;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Compact pill chips for: All, Income, Expense, Transfer
        Row(
          children: _ActivityFilter.values.map((filterVal) {
            final bool isSelected = _filter == filterVal;
            String label = '';
            switch (filterVal) {
              case _ActivityFilter.all:
                label = context.l10n.tr('all');
                break;
              case _ActivityFilter.income:
                label = context.l10n.tr('income');
                break;
              case _ActivityFilter.expense:
                label = context.l10n.tr('expense');
                break;
              case _ActivityFilter.transfer:
                label = context.l10n.tr('transfer');
                break;
            }
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _filter = filterVal;
                      _selectedCategory = 'All';
                    });
                  },
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? tokens.colors.gold
                          : (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF1E2725)
                                : const Color(0xFFF0F4F3)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : tokens.colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),

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
                      size: 16,
                      color: tokens.colors.textPrimary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
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
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ChoiceChip(
                          labelPadding: EdgeInsets.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          visualDensity: const VisualDensity(
                            horizontal: -3,
                            vertical: -3,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          labelStyle: TextStyle(
                            fontSize: 11,
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

        // Merged Category + Search Row
        Row(
          children: <Widget>[
            GestureDetector(
              onTap: () => _showCategoryPicker(context, sortedCategories),
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: _selectedCategory != 'All'
                      ? tokens.colors.gold.withValues(alpha: 0.15)
                      : (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1E2725)
                            : const Color(0xFFF0F4F3)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedCategory != 'All'
                        ? tokens.colors.gold.withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.filter_list_rounded,
                      size: 13,
                      color: _selectedCategory != 'All'
                          ? tokens.colors.gold
                          : tokens.colors.textPrimary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      catFilterLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: _selectedCategory != 'All'
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: _selectedCategory != 'All'
                            ? tokens.colors.gold
                            : tokens.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 13,
                      color: _selectedCategory != 'All'
                          ? tokens.colors.gold
                          : tokens.colors.textPrimary.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: SizedBox(
                height: 28,
                child: TextField(
                  key: const Key('activitySearchField'),
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 11),
                  decoration: InputDecoration(
                    hintText: context.l10n.tr('search_notes'),
                    hintStyle: TextStyle(
                      fontSize: 10,
                      color: tokens.colors.textSecondary,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 13,
                      color: tokens.colors.textPrimary.withValues(alpha: 0.6),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 26),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            key: const Key('clearActivitySearch'),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.close_rounded,
                              size: 13,
                              color: tokens.colors.textSecondary,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          ),
                    suffixIconConstraints: const BoxConstraints(minWidth: 26),
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: tokens.colors.gold.withValues(alpha: 0.15),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: tokens.colors.gold.withValues(alpha: 0.15),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: tokens.colors.gold.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Summary Strip Card
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              if (_filter == _ActivityFilter.all ||
                  _filter == _ActivityFilter.income)
                Expanded(
                  child: _buildSummaryItem(
                    context,
                    title: _filter == _ActivityFilter.all
                        ? context.l10n.tr('income')
                        : (isArabic ? 'إجمالي الدخل' : 'Income Total'),
                    amount: totalIncome,
                    color: const Color(0xFF2E7D32),
                    mainCurrency: mainCurrency,
                    isArabic: isArabic,
                  ),
                ),
              if (_filter == _ActivityFilter.all)
                Container(
                  height: 20,
                  width: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                ),
              if (_filter == _ActivityFilter.all ||
                  _filter == _ActivityFilter.expense)
                Expanded(
                  child: _buildSummaryItem(
                    context,
                    title: _filter == _ActivityFilter.all
                        ? context.l10n.tr('expense')
                        : (isArabic ? 'إجمالي المصروفات' : 'Expense Total'),
                    amount: totalExpenses,
                    color: const Color(0xFFC62828),
                    mainCurrency: mainCurrency,
                    isArabic: isArabic,
                  ),
                ),
              if (_filter == _ActivityFilter.all)
                Container(
                  height: 20,
                  width: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                ),
              if (_filter == _ActivityFilter.all ||
                  _filter == _ActivityFilter.transfer)
                Expanded(
                  child: _buildSummaryItem(
                    context,
                    title: _filter == _ActivityFilter.all
                        ? context.l10n.tr('transfer')
                        : (isArabic ? 'إجمالي التحويلات' : 'Transfer Total'),
                    amount: totalTransfers,
                    color: tokens.colors.gold,
                    mainCurrency: mainCurrency,
                    isArabic: isArabic,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),

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

                    return Slidable(
                      key: Key('dismiss_${entry.key}'),
                      endActionPane: ActionPane(
                        motion: const ScrollMotion(),
                        extentRatio: 0.28,
                        children: [
                          CustomSlidableAction(
                            key: Key('delete_action_${entry.key}'),
                            onPressed: (BuildContext context) async {
                              final AppStateController controller = context
                                  .read<AppStateController>();
                              final bool isTx = entry.transaction != null;
                              final String titleKey = isTx
                                  ? 'delete_transaction'
                                  : 'delete_saving';
                              final String messageKey = isTx
                                  ? 'delete_transaction_message'
                                  : 'delete_saving_message';
                              final bool? confirmed = await showDialog<bool>(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text(context.l10n.tr(titleKey)),
                                    content: Text(context.l10n.tr(messageKey)),
                                    actions: <Widget>[
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: Text(context.l10n.tr('cancel')),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFC62828,
                                          ),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: Text(context.l10n.tr('delete')),
                                      ),
                                    ],
                                  );
                                },
                              );
                              if (confirmed == true) {
                                final bool isCurrencyExchange =
                                    (entry.transferTitle ?? '').toLowerCase() ==
                                    'currency exchange';
                                if (kDebugMode) {
                                  print(
                                    '[Activity][Delete] title=${entry.transferTitle ?? entry.transaction?.category ?? entry.saving?.description ?? entry.key} '
                                    'isExchange=$isCurrencyExchange '
                                    'activityId=${entry.exchangeActivityId} '
                                    'txId=${entry.transaction?.id} '
                                    'txPair=${entry.transaction?.exchangePairId} '
                                    'savingId=${entry.saving?.id} '
                                    'savingActivity=${entry.saving?.transferActivityId} '
                                    'key=${entry.key}',
                                  );
                                }
                                if (isCurrencyExchange &&
                                    entry.exchangeActivityId != null) {
                                  await controller.deleteCurrencyExchangeActivity(
                                    entry.exchangeActivityId!,
                                  );
                                } else if (entry.transaction != null) {
                                  await controller.deleteTransaction(
                                    entry.transaction!.id,
                                  );
                                } else if (entry.saving != null) {
                                  await controller.deleteSaving(
                                    entry.saving!.id,
                                  );
                                }
                              }
                            },
                            backgroundColor: const Color(0xFFC62828),
                            foregroundColor: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.l10n.tr('delete'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      child: PremiumCard(
                        child: ListTile(
                          key: Key('activityTile_${entry.key}'),
                          onTap: () {
                            final AppStateController controller = context
                                .read<AppStateController>();
                            if (entry.isTransfer) {
                              final String titleStr =
                                  (entry.transferTitle ?? entry.title(context))
                                      .toLowerCase();
                              if (titleStr.contains('gold sale') ||
                                  titleStr.contains('silver sale')) {
                                if (entry.transaction != null) {
                                  openSellMetalDialog(
                                    context,
                                    editTransaction: entry.transaction,
                                  );
                                }
                              } else if (titleStr.contains('gold') ||
                                  titleStr.contains('silver')) {
                                Saving? targetSaving;
                                if (entry.saving != null) {
                                  targetSaving = entry.saving;
                                } else if (entry.transaction != null) {
                                  final String? pairId =
                                      entry.transaction!.exchangePairId;
                                  if (pairId != null && pairId.isNotEmpty) {
                                    targetSaving = controller.state.savings
                                        .where((Saving s) => s.id == pairId)
                                        .firstOrNull;
                                  }
                                  if (targetSaving == null) {
                                    final String targetType =
                                        titleStr.contains('gold')
                                        ? 'gold'
                                        : 'silver';
                                    targetSaving = controller.state.savings
                                        .where(
                                          (Saving s) =>
                                              s.assetType == targetType,
                                        )
                                        .firstOrNull;
                                  }
                                }
                                if (targetSaving != null) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => AddSavingScreen(
                                        initialSaving: targetSaving,
                                      ),
                                    ),
                                  );
                                }
                              } else if (titleStr.contains('exchange')) {
                                final dynamic item =
                                    entry.saving ?? entry.transaction;
                                if (kDebugMode) {
                                  print(
                                    '[Activity][Edit] title=$titleStr '
                                    'using=${item.runtimeType} '
                                    'activityId=${entry.exchangeActivityId} '
                                    'txId=${entry.transaction?.id} '
                                    'txPair=${entry.transaction?.exchangePairId} '
                                    'savingId=${entry.saving?.id} '
                                    'savingActivity=${entry.saving?.transferActivityId}',
                                  );
                                }
                                if (item != null) {
                                  openEditCurrencyExchangeDialog(
                                    context,
                                    item,
                                    activityId: entry.exchangeActivityId,
                                  );
                                }
                              } else {
                                if (entry.transaction != null) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => AddTransactionScreen(
                                        initialTransaction: entry.transaction,
                                      ),
                                    ),
                                  );
                                }
                              }
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
                            horizontal: 6,
                          ),
                          leading: _buildActivityIcon(context, entry),
                          title: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  entry.isTransfer
                                      ? (entry.transferTitle ??
                                            entry.title(context))
                                      : entry.title(context),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              entry.isTransfer
                                  ? _getTransferSubtitle(
                                      context,
                                      entry,
                                      mainCurrency,
                                      market,
                                      isArabic,
                                    )
                                  : '${entry.date} • ${entry.description.isNotEmpty ? entry.description : entry.title(context)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.colors.textSecondary,
                                fontSize: 12,
                              ),
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
                                        isArabic: isArabic,
                                        showSign: !entry.isTransfer,
                                      ),
                                style: TextStyle(
                                  color: entry.isTransfer
                                      ? tokens.colors.textPrimary
                                      : (entry.isIncome
                                            ? const Color(0xFF2E7D32)
                                            : tokens.colors.danger),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: tokens.colors.textSecondary.withValues(
                                  alpha: 0.5,
                                ),
                                size: 20,
                              ),
                            ],
                          ),
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

    final Map<String, Map<String, dynamic>> merged =
        <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> item in [...monthly, ...savingsSchedule]) {
      final String monthKey = item['monthKey']?.toString() ?? '';
      if (monthKey.isEmpty) continue;
      if (!merged.containsKey(monthKey)) {
        merged[monthKey] = <String, dynamic>{
          'monthKey': monthKey,
          'paymentDate': item['paymentDate'],
          'totalZakat': (item['totalZakat'] as num).toDouble(),
          'isPast': item['isPast'],
          'isCurrentMonth': item['isCurrentMonth'],
          'entries': List<Map<String, dynamic>>.from(
            item['entries'] as Iterable,
          ),
        };
      } else {
        final Map<String, dynamic> existing = merged[monthKey]!;
        existing['totalZakat'] =
            (existing['totalZakat'] as num).toDouble() +
            (item['totalZakat'] as num).toDouble();
        (existing['entries'] as List<Map<String, dynamic>>).addAll(
          List<Map<String, dynamic>>.from(item['entries'] as Iterable),
        );
      }
    }

    final List<Map<String, dynamic>> sorted = merged.values.toList()
      ..sort(
        (a, b) => a['monthKey'].toString().compareTo(b['monthKey'].toString()),
      );
    return sorted;
  }

  String _getTransferSubtitle(
    BuildContext context,
    _ActivityEntry entry,
    String mainCurrency,
    MarketData market,
    bool isArabic,
  ) {
    if (entry.transferTitle == 'Currency Exchange') {
      final RegExp reg = RegExp(
        r'([A-Z$£€¥a-z]+)\s+([0-9.,]+)\s+→\s+([A-Z$£€¥a-z]+)\s+([0-9.,]+)',
      );
      final Match? match = reg.firstMatch(entry.description);
      if (match != null) {
        final String srcCurr = match.group(1)!;
        final double srcAmt =
            double.tryParse(match.group(2)!.replaceAll(',', '')) ?? 0;
        final String tgtCurr = match.group(3)!;
        final double tgtAmt =
            double.tryParse(match.group(4)!.replaceAll(',', '')) ?? 0;

        final String srcFormatted = ZakatEngineService.formatCurrency(
          srcAmt,
          srcCurr,
          isArabic: isArabic,
        );
        final String tgtFormatted = ZakatEngineService.formatCurrency(
          tgtAmt,
          tgtCurr,
          isArabic: isArabic,
        );
        return '$srcFormatted → $tgtFormatted';
      }
      return entry.description;
    }

    final String titleLower = (entry.transferTitle ?? entry.title(context))
        .toLowerCase();
    if (titleLower.contains('gold purchase')) {
      final Saving? s = entry.saving;
      if (s != null) {
        final String formattedCost = ZakatEngineService.formatCurrency(
          s.purchaseAmount,
          s.purchaseCurrency,
          isArabic: isArabic,
        );
        return '${s.amount.toStringAsFixed(s.amount.truncateToDouble() == s.amount ? 0 : 2)}g Gold • $formattedCost';
      }
    }
    if (titleLower.contains('gold sale')) {
      final Transaction? tx = entry.transaction;
      if (tx != null) {
        double weight = 0.0;
        final RegExp regex = RegExp(r'([0-9.]+)\s*g');
        final Match? match = regex.firstMatch(tx.description);
        if (match != null) {
          weight = double.tryParse(match.group(1) ?? '') ?? 0.0;
        }
        final String formattedCost = ZakatEngineService.formatCurrency(
          tx.amount,
          tx.currency,
          isArabic: isArabic,
        );
        return '${weight.toStringAsFixed(weight.truncateToDouble() == weight ? 0 : 2)}g Gold • $formattedCost';
      }
    }
    if (titleLower.contains('silver purchase')) {
      final Saving? s = entry.saving;
      if (s != null) {
        final String formattedCost = ZakatEngineService.formatCurrency(
          s.purchaseAmount,
          s.purchaseCurrency,
          isArabic: isArabic,
        );
        return '${s.amount.toStringAsFixed(s.amount.truncateToDouble() == s.amount ? 0 : 2)}g Silver • $formattedCost';
      }
    }
    if (titleLower.contains('silver sale')) {
      final Transaction? tx = entry.transaction;
      if (tx != null) {
        double weight = 0.0;
        final RegExp regex = RegExp(r'([0-9.]+)\s*g');
        final Match? match = regex.firstMatch(tx.description);
        if (match != null) {
          weight = double.tryParse(match.group(1) ?? '') ?? 0.0;
        }
        final String formattedCost = ZakatEngineService.formatCurrency(
          tx.amount,
          tx.currency,
          isArabic: isArabic,
        );
        return '${weight.toStringAsFixed(weight.truncateToDouble() == weight ? 0 : 2)}g Silver • $formattedCost';
      }
    }
    return entry.description;
  }

  Widget _buildActivityIcon(BuildContext context, _ActivityEntry entry) {
    final String titleLower = (entry.transferTitle ?? entry.title(context))
        .toLowerCase();

    IconData iconData = Icons.swap_horiz_rounded;
    Color iconColor = const Color(0xFFD4AF37);
    Color bg = const Color(0xFFD4AF37).withValues(alpha: 0.12);

    if (entry.isTransfer) {
      if (titleLower.contains('gold')) {
        iconData = Icons.circle_rounded;
        iconColor = const Color(0xFFD4AF37);
        bg = const Color(0xFFD4AF37).withValues(alpha: 0.12);
      } else if (titleLower.contains('silver')) {
        iconData = Icons.circle_outlined;
        iconColor = const Color(0xFF94A3B8);
        bg = const Color(0xFF94A3B8).withValues(alpha: 0.12);
      } else if (titleLower.contains('exchange')) {
        iconData = Icons.swap_horiz_rounded;
        iconColor = const Color(0xFFD4AF37);
        bg = const Color(0xFFD4AF37).withValues(alpha: 0.12);
      } else {
        iconData = Icons.swap_horiz_rounded;
        iconColor = const Color(0xFFD4AF37);
        bg = const Color(0xFFD4AF37).withValues(alpha: 0.12);
      }
    } else if (entry.isIncome) {
      iconData = Icons.north_east_rounded;
      iconColor = const Color(0xFF2E7D32);
      bg = const Color(0xFF2E7D32).withValues(alpha: 0.12);
    } else if (entry.isExpense) {
      iconData = Icons.south_east_rounded;
      iconColor = const Color(0xFFC62828);
      bg = const Color(0xFFC62828).withValues(alpha: 0.12);
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Center(child: Icon(iconData, color: iconColor, size: 20)),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context, {
    required String title,
    required double amount,
    required Color color,
    required String mainCurrency,
    required bool isArabic,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).hintColor,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            ZakatEngineService.formatCurrency(
              amount,
              mainCurrency,
              isArabic: isArabic,
            ),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
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
    this.exchangeActivityId,
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
          '$sourceCurrency ${sourceAmount.toStringAsFixed(2)} → $targetCurrency ${targetAmount.toStringAsFixed(2)}',
      transferKey: 'exchange_${source.exchangePairId ?? source.id}',
      exchangeActivityId:
          source.exchangePairId?.trim().isNotEmpty == true
          ? source.exchangePairId!.trim()
          : (targetSaving?.transferActivityId?.trim().isNotEmpty == true
                ? targetSaving!.transferActivityId!.trim()
                : null),
      transferDate: (sourceTransaction?.createdAt.isNotEmpty == true
              ? sourceTransaction!.createdAt
              : (targetSaving?.createdAt ?? source.createdAt))
          .split('T')
          .first,
      transferCreatedAt: sourceTransaction?.createdAt.isNotEmpty == true
          ? sourceTransaction!.createdAt
          : (targetSaving?.createdAt ?? source.createdAt),
      transferCurrency: sourceCurrency,
      transferAmount: sourceAmount,
    ).._logExchangeBuild(
      sourceCurrency: sourceCurrency,
      targetCurrency: targetCurrency,
      sourceAmount: sourceAmount,
      targetAmount: targetAmount,
      sourceCreatedAt: sourceTransaction?.createdAt.isNotEmpty == true
          ? sourceTransaction!.createdAt
          : (targetSaving?.createdAt ?? source.createdAt),
      sourceId: source.id,
      pairId: source.exchangePairId,
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
          '$sourceCurrency ${sourceAmount.toStringAsFixed(2)} → ${saving.unit} ${saving.amount.toStringAsFixed(2)}',
      transferKey: 'legacy_exchange_${saving.id}',
      exchangeActivityId:
          saving.transferActivityId?.trim().isNotEmpty == true
          ? saving.transferActivityId!.trim()
          : null,
      transferDate: saving.dateAcquired.trim().isNotEmpty
          ? saving.dateAcquired
          : saving.createdAt.split('T').first,
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
          '${saving.amount.toStringAsFixed(2)}g $metal • ${saving.purchaseCurrency} ${saving.purchaseAmount.toStringAsFixed(2)}',
      transferKey: 'metal_${saving.id}',
      exchangeActivityId:
          saving.transferActivityId?.trim().isNotEmpty == true
          ? saving.transferActivityId!.trim()
          : null,
      transferDate: saving.dateAcquired.trim().isNotEmpty
          ? saving.dateAcquired
          : saving.createdAt.split('T').first,
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
  final String? exchangeActivityId;
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

  void _logExchangeBuild({
    required String sourceCurrency,
    required String targetCurrency,
    required double sourceAmount,
    required double targetAmount,
    required String sourceCreatedAt,
    required String sourceId,
    required String? pairId,
  }) {
    if (!kDebugMode) return;
    print(
      '[Activity][BuildExchange] key=$key '
      'date=$date '
      'createdAt=$createdAt '
      'sourceId=$sourceId '
      'pairId=$pairId '
      'source=$sourceCurrency $sourceAmount '
      'target=$targetCurrency $targetAmount '
      'sourceCreatedAt=$sourceCreatedAt',
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
