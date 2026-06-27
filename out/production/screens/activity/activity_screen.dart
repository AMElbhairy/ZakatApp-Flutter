// ignore_for_file: avoid_print
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/services/zakat_schedule_service.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/theme/app_radii.dart';
import '../../core/utils/category_visuals.dart';
import '../../models/saving.dart';
import '../../models/transaction.dart';
import '../../models/app_state.dart';
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
    final AppCategories categories = context
        .read<AppStateController>()
        .state
        .categories;

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
                    final CategoryVisual visual = category == 'All'
                        ? CategoryVisuals.neutralFallback
                        : CategoryVisuals.resolveCategoryVisual(
                            categories: categories,
                            type: categories.income.contains(category)
                                ? 'income'
                                : 'expense',
                            categoryName: category,
                          );
                    final Color accent = CategoryVisuals.colorFromValue(
                      visual.colorValue,
                    );
                    final IconData iconData = CategoryVisuals.iconForKey(
                      visual.iconKey,
                    );

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 2,
                      ),
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(iconData, size: 16, color: accent),
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
        40 + MediaQuery.paddingOf(context).bottom;
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
        40 + MediaQuery.paddingOf(context).bottom;
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

    return ListView(
      padding: EdgeInsets.fromLTRB(0, 0, 0, navSafeBottomPadding),
      children: <Widget>[
        KeyedSubtree(
          key: const Key('activityTypeChips'),
          child: _buildTypeChipRow(context),
        ),
        const SizedBox(height: 10),
        KeyedSubtree(
          key: const Key('activityDateChips'),
          child: _buildDateFilterRow(context),
        ),
        const SizedBox(height: 10),
        KeyedSubtree(
          key: const Key('activityCategorySearchRow'),
          child: _buildCategorySearchRow(
            context,
            sortedCategories,
            catFilterLabel,
          ),
        ),
        const SizedBox(height: 10),
        KeyedSubtree(
          key: const Key('activitySummaryCard'),
          child: _buildActivitySummaryCard(
            context,
            activeFilter: _filter,
            totalIncome: totalIncome,
            totalExpenses: totalExpenses,
            totalTransfers: totalTransfers,
            mainCurrency: mainCurrency,
            isArabic: isArabic,
          ),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          EmptyStateCard(
            cardKey: const Key('activityEmptyState'),
            icon: Icons.receipt_long_outlined,
            title: context.l10n.tr('no_transactions_yet'),
            message: context.l10n.tr('activity_empty_message'),
          )
        else
          ...<Widget>[
            for (final _ActivityEntry entry in filtered) ...<Widget>[
              Slidable(
                key: Key('dismiss_${entry.key}'),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  extentRatio: 0.28,
                  children: [
                    CustomSlidableAction(
                      key: Key('delete_action_${entry.key}'),
                      onPressed: (BuildContext context) async {
                        final AppStateController controller =
                            context.read<AppStateController>();
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
                                    backgroundColor: const Color(0xFFC62828),
                                    foregroundColor: AppColors.white,
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
                            await controller.deleteSaving(entry.saving!.id);
                          }
                        }
                      },
                      backgroundColor: AppColors.redStrong,
                      foregroundColor: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.white,
                            size: 22,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.tr('delete'),
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                child: _buildTransactionCard(
                  context,
                  entry: entry,
                  balancesHidden: balancesHidden,
                  mainCurrency: mainCurrency,
                  market: market,
                  isArabic: isArabic,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
      ],
    );
  }

  Widget _buildTypeChipRow(BuildContext context) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color unselectedColor = dark
        ? AppColors.surfaceInk
        : AppColors.surfacePale;
    return Row(
      children: _ActivityFilter.values.map((filterVal) {
        final bool isSelected = _filter == filterVal;
        final String label = switch (filterVal) {
          _ActivityFilter.all => context.l10n.tr('all'),
          _ActivityFilter.income => context.l10n.tr('income'),
          _ActivityFilter.expense => context.l10n.tr('expense'),
          _ActivityFilter.transfer => context.l10n.tr('transfer'),
        };
        final Color selectedColor = filterVal == _ActivityFilter.all
            ? tokens.colors.hero
            : tokens.colors.gold;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              onTap: () {
                setState(() {
                  _filter = filterVal;
                  _selectedCategory = 'All';
                });
              },
              borderRadius: BorderRadius.circular(18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? selectedColor : unselectedColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? AppColors.white
                        : tokens.colors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateFilterRow(BuildContext context) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                _buildFilterIconButton(
                  context,
                  icon: Icons.calendar_month_outlined,
                  active: _selectedDateFilter == 'Custom',
                  onTap: () => _selectCustomRange(context, isZakat: false),
                ),
                const SizedBox(width: 8),
                ...<String>['All Time', '30D', '90D', 'YTD'].map((filter) {
                  final bool isSelected = _selectedDateFilter == filter;
                  final String label = filter == 'All Time'
                      ? context.l10n.tr('all')
                      : filter;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      selected: isSelected,
                      showCheckmark: false,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (isSelected)
                            const Icon(Icons.check_rounded, size: 14),
                          if (isSelected) const SizedBox(width: 4),
                          Text(label),
                        ],
                      ),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isSelected
                            ? tokens.colors.hero
                            : tokens.colors.textPrimary,
                      ),
                      backgroundColor: dark
                          ? const Color(0xFF172422)
                          : const Color(0xFFF4F2EA),
                      selectedColor: const Color(0xFFF2E5BF),
                      side: BorderSide(
                        color: isSelected
                            ? tokens.colors.gold.withValues(alpha: 0.35)
                            : tokens.colors.divider,
                      ),
                      onSelected: (_) => setState(() {
                        _selectedDateFilter = filter;
                      }),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategorySearchRow(
    BuildContext context,
    List<String> sortedCategories,
    String catFilterLabel,
  ) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = dark ? const Color(0xFF172422) : const Color(0xFFF4F2EA);
    return Row(
      children: <Widget>[
        GestureDetector(
          onTap: () => _showCategoryPicker(context, sortedCategories),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _selectedCategory != 'All'
                  ? tokens.colors.gold.withValues(alpha: 0.14)
                  : bg,
              borderRadius: AppRadii.pill,
              border: Border.all(
                color: _selectedCategory != 'All'
                    ? tokens.colors.gold.withValues(alpha: 0.28)
                    : tokens.colors.divider,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.filter_list_rounded,
                  size: 14,
                  color: _selectedCategory != 'All'
                      ? tokens.colors.gold
                      : tokens.colors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  catFilterLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: _selectedCategory != 'All'
                        ? FontWeight.w700
                        : FontWeight.w600,
                    color: _selectedCategory != 'All'
                        ? tokens.colors.hero
                        : tokens.colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: _selectedCategory != 'All'
                      ? tokens.colors.gold
                      : tokens.colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextField(
              key: const Key('activitySearchField'),
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: context.l10n.tr('search_notes'),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: tokens.colors.textSecondary,
                ),
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
                filled: true,
                fillColor: bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                border: OutlineInputBorder(
                  borderRadius: AppRadii.pill,
                  borderSide: BorderSide(color: tokens.colors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadii.pill,
                  borderSide: BorderSide(color: tokens.colors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadii.pill,
                  borderSide: BorderSide(
                    color: tokens.colors.gold.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivitySummaryCard(
    BuildContext context, {
    required _ActivityFilter activeFilter,
    required double totalIncome,
    required double totalExpenses,
    required double totalTransfers,
    required String mainCurrency,
    required bool isArabic,
  }) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color expenseColor = dark
        ? const Color(0xFFFF7A7A)
        : tokens.colors.danger;
    final bool showAll = activeFilter == _ActivityFilter.all;
    final String activeLabel = switch (activeFilter) {
      _ActivityFilter.all => context.l10n.tr('all'),
      _ActivityFilter.income => context.l10n.tr('income'),
      _ActivityFilter.expense => context.l10n.tr('expense'),
      _ActivityFilter.transfer => context.l10n.tr('transfer'),
    };
    final double activeAmount = switch (activeFilter) {
      _ActivityFilter.all => totalIncome + totalExpenses + totalTransfers,
      _ActivityFilter.income => totalIncome,
      _ActivityFilter.expense => totalExpenses,
      _ActivityFilter.transfer => totalTransfers,
    };
    final Color activeColor = switch (activeFilter) {
      _ActivityFilter.all => tokens.colors.gold,
      _ActivityFilter.income => tokens.colors.success,
      _ActivityFilter.expense => expenseColor,
      _ActivityFilter.transfer => tokens.colors.gold,
    };
    return PremiumCard(
      child: showAll
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _buildSummaryColumn(
                    context,
                    label: context.l10n.tr('income'),
                    amount: totalIncome,
                    color: tokens.colors.success,
                    mainCurrency: mainCurrency,
                    isArabic: isArabic,
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: VerticalDivider(
                    color: tokens.colors.divider,
                    width: 18,
                  ),
                ),
                Expanded(
                  child: _buildSummaryColumn(
                    context,
                    label: context.l10n.tr('expense'),
                    amount: totalExpenses,
                    color: expenseColor,
                    mainCurrency: mainCurrency,
                    isArabic: isArabic,
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: VerticalDivider(
                    color: tokens.colors.divider,
                    width: 18,
                  ),
                ),
                Expanded(
                  child: _buildSummaryColumn(
                    context,
                    label: context.l10n.tr('transfer'),
                    amount: totalTransfers,
                    color: tokens.colors.gold,
                    mainCurrency: mainCurrency,
                    isArabic: isArabic,
                  ),
                ),
              ],
            )
          : _buildSummaryColumn(
              context,
              label: activeLabel,
              amount: activeAmount,
              color: activeColor,
              mainCurrency: mainCurrency,
              isArabic: isArabic,
              compact: false,
            ),
    );
  }

  Widget _buildSummaryColumn(
    BuildContext context, {
    required String label,
    required double amount,
    required Color color,
    required String mainCurrency,
    required bool isArabic,
    bool compact = true,
  }) {
    final tokens = context.premiumTokens;
    final String formatted = ZakatEngineService.formatCurrency(
      amount,
      mainCurrency,
      isArabic: isArabic,
    );
    final double valueFontSize = _summaryValueFontSize(
      formatted,
      compact: compact,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: tokens.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatted,
              style: TextStyle(
                fontSize: valueFontSize,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _summaryValueFontSize(String formatted, {required bool compact}) {
    final int length = formatted.replaceAll(RegExp(r'\s+'), '').length;
    final double base = compact ? 16 : 22;
    if (length <= 8) return base + 2;
    if (length <= 11) return base;
    if (length <= 14) return base - 2;
    return base - 4;
  }

  Widget _buildTransactionCard(
    BuildContext context, {
    required _ActivityEntry entry,
    required bool balancesHidden,
    required String mainCurrency,
    required MarketData market,
    required bool isArabic,
  }) {
    final controller = context.read<AppStateController>();
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color expenseColor = dark
        ? const Color(0xFFFF7A7A)
        : tokens.colors.danger;
    final AppStateModel state = controller.state;
    final CategoryVisual visual = _resolveEntryVisual(state, entry);
    final CategoryVisual fallbackVisual = CategoryVisuals.resolveTypeFallback(
      entry.isTransfer ? 'transfer' : (entry.isIncome ? 'income' : 'expense'),
    );
    final Color resolvedColor = CategoryVisuals.colorFromValue(
      visual.colorValue ?? fallbackVisual.colorValue,
    );
    final IconData resolvedIcon = CategoryVisuals.iconForKey(
      visual.iconKey ?? fallbackVisual.iconKey,
    );
    final String typeLabel = entry.isTransfer
        ? context.l10n.tr('transfer')
        : (entry.isIncome
              ? context.l10n.tr('income')
              : context.l10n.tr('expense'));
    final String dateText = _formatHumanDate(entry.date);
    final String subtitleText = entry.isTransfer
        ? _getTransferSubtitle(context, entry, mainCurrency, market, isArabic)
        : [
            if (entry.description.trim().isNotEmpty) entry.description.trim(),
            if (dateText.isNotEmpty) dateText,
          ].join(' • ');
    return PremiumCard(
      onTap: () => _openActivityEntry(context, entry),
      child: ListTile(
        key: Key('activityTile_${entry.key}'),
        contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: resolvedColor.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(resolvedIcon, color: resolvedColor, size: 22),
        ),
        title: Text(
          entry.isTransfer
              ? (entry.transferTitle ?? entry.title(context))
              : entry.title(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                subtitleText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.colors.textSecondary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  _MetaPill(text: typeLabel),
                  _MetaPill(text: _formatHumanDate(entry.date)),
                ],
              ),
            ],
          ),
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
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
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: entry.isTransfer
                    ? tokens.colors.gold
                    : (entry.isIncome ? tokens.colors.success : expenseColor),
              ),
            ),
            const SizedBox(height: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: tokens.colors.textSecondary.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  CategoryVisual _resolveEntryVisual(
    AppStateModel state,
    _ActivityEntry entry,
  ) {
    if (entry.transaction != null) {
      final Transaction tx = entry.transaction!;
      final CategoryVisual? custom = state.categories.metadataFor(
        type: tx.type == 'income' ? 'income' : 'expense',
        name: tx.category,
      );
      final CategoryVisual resolved = CategoryVisuals.resolveCategoryVisual(
        categories: state.categories,
        type: tx.type,
        categoryName: tx.category,
      );
      final bool knownCategory =
          state.categories.income.contains(tx.category) ||
          state.categories.expense.contains(tx.category);
      if (custom != null || knownCategory) {
        return resolved;
      }
      return CategoryVisuals.resolveTypeFallback(tx.type);
    }
    if (entry.saving != null) {
      final String type = ZakatEngineService.normaliseAssetType(
        entry.saving!.assetType,
      );
      return CategoryVisuals.resolveTypeFallback(
        type == 'gold' || type == 'silver' ? 'transfer' : 'income',
      );
    }
    return CategoryVisuals.neutralFallback;
  }

  String _formatHumanDate(String raw) {
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      final DateTime? fallback = _tryParseLooseDate(raw);
      if (fallback == null) return raw;
      return DateFormat('dd MMM yyyy').format(fallback);
    }
    return DateFormat('dd MMM yyyy').format(parsed.toLocal());
  }

  DateTime? _tryParseLooseDate(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final List<String> parts = trimmed.split('-');
    if (parts.length != 3) return null;
    final int? year = int.tryParse(parts[0]);
    final int? month = int.tryParse(parts[1]);
    final int? day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  void _openActivityEntry(BuildContext context, _ActivityEntry entry) {
    final AppStateController controller = context.read<AppStateController>();
    if (entry.isTransfer) {
      final String titleStr = (entry.transferTitle ?? entry.title(context))
          .toLowerCase();
      if (titleStr.contains('gold sale') || titleStr.contains('silver sale')) {
        if (entry.transaction != null) {
          openSellMetalDialog(context, editTransaction: entry.transaction);
        }
      } else if (titleStr.contains('gold') || titleStr.contains('silver')) {
        Saving? targetSaving;
        if (entry.saving != null) {
          targetSaving = entry.saving;
        } else if (entry.transaction != null) {
          final String? pairId = entry.transaction!.exchangePairId;
          if (pairId != null && pairId.isNotEmpty) {
            targetSaving = controller.state.savings
                .where((Saving s) => s.id == pairId)
                .firstOrNull;
          }
          if (targetSaving == null) {
            final String targetType = titleStr.contains('gold')
                ? 'gold'
                : 'silver';
            targetSaving = controller.state.savings
                .where((Saving s) => s.assetType == targetType)
                .firstOrNull;
          }
        }
        if (targetSaving != null) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AddSavingScreen(initialSaving: targetSaving),
            ),
          );
        }
      } else if (titleStr.contains('exchange')) {
        final dynamic item = entry.saving ?? entry.transaction;
        if (item != null) {
          openEditCurrencyExchangeDialog(
            context,
            item,
            activityId: entry.exchangeActivityId,
          );
        }
      } else if (entry.transaction != null) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                AddTransactionScreen(initialTransaction: entry.transaction),
          ),
        );
      }
    } else if (entry.transaction != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              AddTransactionScreen(initialTransaction: entry.transaction),
        ),
      );
    } else if (entry.saving != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AddSavingScreen(initialSaving: entry.saving),
        ),
      );
    }
  }

  Widget _buildFilterIconButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active
              ? tokens.colors.gold.withValues(alpha: dark ? 0.20 : 0.14)
              : dark
              ? const Color(0xFF172422)
              : const Color(0xFFF4F2EA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? tokens.colors.gold.withValues(alpha: 0.35)
                : tokens.colors.divider,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: active ? tokens.colors.gold : tokens.colors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildUpcomingZakatCard(
    BuildContext context, {
    required Map<String, dynamic>? row,
    required double totalDueThisYear,
    required bool balancesHidden,
  }) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final String paymentDate = (row?['paymentDate'] ?? '').toString();
    final double totalZakat = ((row?['totalZakat'] ?? 0) as num).toDouble();
    final String nextDueLabel = paymentDate.isEmpty
        ? context.l10n.tr('upcoming')
        : _formatHumanDate(paymentDate);
    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 4,
            height: 92,
            decoration: BoxDecoration(
              color: tokens.colors.gold,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: tokens.colors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.event_available_outlined,
                        color: dark
                            ? tokens.colors.textPrimary
                            : tokens.colors.gold,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.tr('upcoming_zakat'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _SummaryMetric(
                        label: context.l10n.tr('next_due'),
                        value: paymentDate.isEmpty
                            ? _formatEgp(context, totalZakat)
                            : _formatEgp(context, totalZakat),
                        sublabel: nextDueLabel,
                        accentColor: dark
                            ? tokens.colors.textPrimary
                            : tokens.colors.hero,
                        showValue: !balancesHidden,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryMetric(
                        label: context.l10n.tr('total_due_this_year'),
                        value: _formatEgp(context, totalDueThisYear),
                        sublabel: context.l10n.tr('upcoming_zakat'),
                        accentColor: tokens.colors.gold,
                        showValue: !balancesHidden,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZakatFilterRow(BuildContext context) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color chipBg = dark
        ? const Color(0xFF172422)
        : const Color(0xFFF4F2EA);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Row(
                  children: <Widget>[
                    _buildFilterIconButton(
                      context,
                      icon: Icons.calendar_month_outlined,
                      active: _zakatDateFilter == 'Custom',
                      onTap: () => _selectCustomRange(context, isZakat: true),
                    ),
                    const SizedBox(width: 8),
                    ...<String>['All Time', '30D', '90D', 'YTD'].map((filter) {
                      final bool isSelected = _zakatDateFilter == filter;
                      final String label = filter == 'All Time'
                          ? context.l10n.tr('all')
                          : filter;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          selected: isSelected,
                          showCheckmark: false,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (isSelected)
                                const Icon(Icons.check_rounded, size: 14),
                              if (isSelected) const SizedBox(width: 4),
                              Text(label),
                            ],
                          ),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isSelected
                                ? tokens.colors.hero
                                : tokens.colors.textPrimary,
                          ),
                          backgroundColor: chipBg,
                          selectedColor: const Color(0xFFF2E5BF),
                          side: BorderSide(
                            color: isSelected
                                ? tokens.colors.gold.withValues(alpha: 0.35)
                                : tokens.colors.divider,
                          ),
                          onSelected: (_) =>
                              setState(() => _zakatDateFilter = filter),
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
        Row(
          children: <Widget>[
            _buildFilterIconButton(
              context,
              icon: Icons.filter_list_rounded,
              onTap: () => setState(() => _showUnpaidOnly = !_showUnpaidOnly),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              selected: _showUnpaidOnly,
              showCheckmark: false,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (_showUnpaidOnly)
                    const Icon(Icons.check_rounded, size: 14),
                  if (_showUnpaidOnly) const SizedBox(width: 4),
                  Text(context.l10n.tr('not_paid')),
                ],
              ),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: _showUnpaidOnly ? FontWeight.w700 : FontWeight.w600,
                color: _showUnpaidOnly
                    ? tokens.colors.hero
                    : tokens.colors.textPrimary,
              ),
              backgroundColor: chipBg,
              selectedColor: const Color(0xFFF2E5BF),
              side: BorderSide(
                color: _showUnpaidOnly
                    ? tokens.colors.gold.withValues(alpha: 0.35)
                    : tokens.colors.divider,
              ),
              onSelected: (bool selected) {
                setState(() => _showUnpaidOnly = selected);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScheduleCard(
    BuildContext context, {
    required Map<String, dynamic> row,
    required bool isPast,
    required bool isCurrent,
    required List<dynamic> entries,
    required double totalZakat,
    required bool isPaid,
    required bool balancesHidden,
  }) {
    final tokens = context.premiumTokens;
    final String monthKey = (row['monthKey'] ?? '').toString();
    final String paymentDate = (row['paymentDate'] ?? '').toString();
    final String monthTitle = _monthTitleFromKey(monthKey, paymentDate);
    final String dueLabel = paymentDate.isEmpty
        ? ''
        : 'Due on ${_formatHumanDate(paymentDate)}';
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final String status = isCurrent
        ? context.l10n.tr('due_now')
        : (isPast ? context.l10n.tr('past') : context.l10n.tr('upcoming'));
    final Color badgeColor = isCurrent
        ? tokens.colors.gold
        : (isPast ? tokens.colors.textSecondary : tokens.colors.gold);
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: Key('scheduleRow_$monthKey'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: tokens.colors.gold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.calendar_month_outlined,
                  color: dark ? tokens.colors.textPrimary : tokens.colors.hero,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      monthTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      dueLabel.isEmpty
                          ? '${entries.length} scheduled entries'
                          : '$dueLabel • ${entries.length} scheduled entries',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(label: status, color: badgeColor),
            ],
          ),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                balancesHidden ? '••••••' : _formatEgp(context, totalZakat),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  height: 1.0,
                  color: dark ? tokens.colors.textPrimary : tokens.colors.hero,
                ),
              ),
              Text(
                context.l10n.tr('total_due'),
                style: TextStyle(
                  fontSize: 9,
                  height: 1.0,
                  color: tokens.colors.textSecondary,
                ),
              ),
            ],
          ),
          children: <Widget>[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: tokens.colors.background.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tokens.colors.divider),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          isPaid
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
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
                    if (isPaid)
                      TextButton(
                        key: Key('toggleZakatPaid_$monthKey'),
                        style: TextButton.styleFrom(
                          foregroundColor: tokens.colors.gold,
                        ),
                        onPressed: () =>
                            context.read<AppStateController>().toggleZakatPaid(
                              monthKey: monthKey,
                              zakatAmountMainCurrency: totalZakat,
                              paymentDate: paymentDate,
                            ),
                        child: Text(context.l10n.tr('undo_paid')),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: <Widget>[
                          TextButton(
                            key: Key('markZakatPaid_$monthKey'),
                            style: TextButton.styleFrom(
                              foregroundColor: tokens.colors.emerald,
                            ),
                            onPressed: () => context
                                .read<AppStateController>()
                                .markZakatPaid(monthKey: monthKey),
                            child: Text(context.l10n.tr('mark_as_paid')),
                          ),
                          TextButton(
                            key: Key('toggleZakatPaid_$monthKey'),
                            style: TextButton.styleFrom(
                              foregroundColor: tokens.colors.gold,
                            ),
                            onPressed: () async {
                              try {
                                await context
                                    .read<AppStateController>()
                                    .payZakat(
                                      monthKey: monthKey,
                                      zakatAmountMainCurrency: totalZakat,
                                      paymentDate: paymentDate,
                                    );
                              } on StateError catch (error) {
                                if (!context.mounted) return;
                                showTopSnackBar(context, error.message);
                              }
                            },
                            child: Text(context.l10n.tr('pay')),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...entries.map((dynamic raw) {
              final Map<String, dynamic> entry = Map<String, dynamic>.from(
                raw as Map,
              );
              final String type = (entry['type'] ?? 'entry').toString();
              final double amount = ((entry['zakatAmount'] ?? 0) as num)
                  .toDouble();
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(
                  type.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  _formatHumanDate((entry['dueDateRaw'] ?? '').toString()),
                  style: TextStyle(color: tokens.colors.textSecondary),
                ),
                trailing: Text(
                  balancesHidden ? '••••••' : _formatEgp(context, amount),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _monthTitleFromKey(String monthKey, String paymentDate) {
    if (monthKey.length >= 7) {
      final String raw = '${monthKey.substring(0, 7)}-01';
      final DateTime? parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return DateFormat('MMMM yyyy').format(parsed.toLocal());
      }
    }
    final DateTime? parsed = DateTime.tryParse(paymentDate);
    if (parsed != null) {
      return DateFormat('MMMM yyyy').format(parsed.toLocal());
    }
    return monthKey.isNotEmpty ? monthKey : paymentDate;
  }

  Widget _buildScheduleView(
    BuildContext context,
    List<Map<String, dynamic>> schedule, {
    required Set<String> paidMonths,
    required bool balancesHidden,
    required double navSafeBottomPadding,
  }) {
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

    final Map<String, dynamic>? nextDue = filtered.isEmpty
        ? null
        : filtered.firstWhere(
            (Map<String, dynamic> row) => row['isPast'] != true,
            orElse: () => filtered.first,
          );
    final int currentYear = DateTime.now().year;
    final double totalDueThisYear = sorted.fold<double>(0, (
      double sum,
      Map<String, dynamic> row,
    ) {
      final DateTime paymentDate = _parseDate(
        (row['paymentDate'] ?? '').toString(),
      );
      if (paymentDate.year != currentYear) return sum;
      return sum + ((row['totalZakat'] ?? 0) as num).toDouble();
    });

    return ListView(
      key: const Key('zakatScheduleList'),
      padding: EdgeInsets.fromLTRB(0, 0, 0, navSafeBottomPadding),
      children: <Widget>[
        KeyedSubtree(
          key: const Key('upcomingZakatSummaryCard'),
          child: _buildUpcomingZakatCard(
            context,
            row: nextDue,
            totalDueThisYear: totalDueThisYear,
            balancesHidden: balancesHidden,
          ),
        ),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: const Key('zakatFilterRow'),
          child: _buildZakatFilterRow(context),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          EmptyStateCard(
            cardKey: const Key('zakatScheduleFilteredEmptyState'),
            icon: Icons.event_note_outlined,
            title: context.l10n.tr('zakat_schedule'),
            message: context.l10n.tr('schedule_empty_message'),
          )
        else
          ...filtered.map((Map<String, dynamic> row) {
            final String monthKey = (row['monthKey'] ?? '').toString();
            final bool isPast = row['isPast'] == true;
            final bool isCurrent = row['isCurrentMonth'] == true;
            final List<dynamic> entries =
                (row['entries'] as List<dynamic>? ?? const []);
            final double totalZakat = ((row['totalZakat'] ?? 0) as num)
                .toDouble();
            final bool isPaid = paidMonths.contains(monthKey);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: KeyedSubtree(
                key: Key('scheduleCard_$monthKey'),
                child: _buildScheduleCard(
                  context,
                  row: row,
                  isPast: isPast,
                  isCurrent: isCurrent,
                  entries: entries,
                  totalZakat: totalZakat,
                  isPaid: isPaid,
                  balancesHidden: balancesHidden,
                ),
              ),
            );
          }),
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
        double weight = tx.metalQuantity ?? 0.0;
        if (weight == 0.0) {
          final RegExp regex = RegExp(r'([0-9.]+)\s*g');
          final Match? match = regex.firstMatch(tx.description);
          if (match != null) {
            weight = double.tryParse(match.group(1) ?? '') ?? 0.0;
          }
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
        double weight = tx.metalQuantity ?? 0.0;
        if (weight == 0.0) {
          final RegExp regex = RegExp(r'([0-9.]+)\s*g');
          final Match? match = regex.firstMatch(tx.description);
          if (match != null) {
            weight = double.tryParse(match.group(1) ?? '') ?? 0.0;
          }
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

  // Kept for compatibility with earlier Activity card layouts.
  // ignore: unused_element
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

  // Kept for compatibility with earlier Activity summary layouts.
  // ignore: unused_element
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

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.colors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.colors.divider),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: tokens.colors.textSecondary,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.sublabel,
    required this.accentColor,
    required this.showValue,
  });

  final String label;
  final String value;
  final String sublabel;
  final Color accentColor;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color resolvedValueColor =
        dark && accentColor.toARGB32() == tokens.colors.hero.toARGB32()
        ? tokens.colors.textPrimary
        : accentColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: tokens.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          showValue ? value : '••••••',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: resolvedValueColor,
          ),
        ),
        if (sublabel.isNotEmpty) ...<Widget>[
          const SizedBox(height: 3),
          Text(
            sublabel,
            style: TextStyle(fontSize: 11, color: tokens.colors.textSecondary),
          ),
        ],
      ],
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
      exchangeActivityId: source.exchangePairId?.trim().isNotEmpty == true
          ? source.exchangePairId!.trim()
          : (targetSaving?.transferActivityId?.trim().isNotEmpty == true
                ? targetSaving!.transferActivityId!.trim()
                : null),
      transferDate:
          (sourceTransaction?.createdAt.isNotEmpty == true
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
      exchangeActivityId: saving.transferActivityId?.trim().isNotEmpty == true
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
      exchangeActivityId: saving.transferActivityId?.trim().isNotEmpty == true
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
