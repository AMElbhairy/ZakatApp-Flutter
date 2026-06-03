import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/investment_asset.dart';
import '../../models/saving.dart';
import '../../models/transaction.dart';
import '../../services/app_state_controller.dart';
import '../entry/add_investment_screen.dart';
import '../entry/add_saving_screen.dart';
import '../entry/add_transaction_screen.dart';

class CategoryDetailsScreen extends StatefulWidget {
  const CategoryDetailsScreen({
    super.key,
    required this.categoryType, // 'cash', 'gold', 'silver', 'investments', 'property', 'other'
  });

  final String categoryType;

  @override
  State<CategoryDetailsScreen> createState() => _CategoryDetailsScreenState();
}

class _CategoryDetailsScreenState extends State<CategoryDetailsScreen> {
  String _selectedDateFilter = 'All Time';
  DateTimeRange? _customDateRange;

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]) ?? DateTime.now().year;
        final m = int.tryParse(parts[1]) ?? DateTime.now().month;
        final d = int.tryParse(parts[2]) ?? DateTime.now().day;
        return DateTime(y, m, d);
      }
      return null;
    }
  }

  Future<void> _selectCustomRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange:
          _customDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedDateFilter = 'Custom';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStateController controller = context.watch<AppStateController>();
    final List<Saving> savings = controller.state.savings;
    final List<InvestmentAsset> investments = controller.state.investments;
    final List<Transaction> transactions = controller.state.transactions;
    final MarketData market = MarketData.fromJson(controller.state.marketData);

    final String mainCurrency = controller.state.mainCurrency.trim().isEmpty
        ? 'EGP'
        : controller.state.mainCurrency.trim();
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

    // Grouping
    List<dynamic> items = [];
    String titleKey = '';
    IconData headerIcon = Icons.folder_open;

    switch (widget.categoryType) {
      case 'cash':
        // Combine Saving(cash) + income Transactions
        final List<Saving> cashSavings = savings
            .where((s) => s.assetType == 'cash')
            .toList();
        final List<Transaction> cashTransactions = transactions
            .where((t) => t.type == 'income')
            .toList();
        items = [...cashSavings, ...cashTransactions];
        titleKey = 'cash';
        headerIcon = Icons.account_balance_wallet_outlined;
        break;
      case 'gold':
        items = savings.where((s) => s.assetType == 'gold').toList();
        titleKey = 'gold';
        headerIcon = Icons.auto_awesome;
        break;
      case 'silver':
        items = savings.where((s) => s.assetType == 'silver').toList();
        titleKey = 'silver';
        headerIcon = Icons.layers;
        break;
      case 'investments':
        items = investments
            .where(
              (a) =>
                  ZakatEngineService.isCompanyInvestmentType(a.investmentType),
            )
            .toList();
        titleKey = 'company_shares';
        headerIcon = Icons.show_chart;
        break;
      case 'property':
        items = investments
            .where(
              (a) =>
                  !ZakatEngineService.isCompanyInvestmentType(a.investmentType),
            )
            .toList();
        titleKey = 'property';
        headerIcon = Icons.home_outlined;
        break;
      case 'other':
        items = [];
        titleKey = 'other';
        headerIcon = Icons.more_horiz;
        break;
    }

    // Filter by Date
    final DateTime now = DateTime.now();
    final List<dynamic> filteredItems = items.where((item) {
      String dateStr;
      if (item is Saving) {
        dateStr = item.dateAcquired;
      } else if (item is Transaction) {
        dateStr = item.date;
      } else {
        dateStr = (item as InvestmentAsset).valuationDate;
      }
      final DateTime? date = _parseDate(dateStr);
      if (date == null) return true;

      switch (_selectedDateFilter) {
        case '30D':
          return date.isAfter(now.subtract(const Duration(days: 30))) ||
              date.isAtSameMomentAs(now.subtract(const Duration(days: 30)));
        case '90D':
          return date.isAfter(now.subtract(const Duration(days: 90))) ||
              date.isAtSameMomentAs(now.subtract(const Duration(days: 90)));
        case 'YTD':
          return date.year == now.year;
        case 'Custom':
          if (_customDateRange != null) {
            return (date.isAfter(_customDateRange!.start) ||
                    date.isAtSameMomentAs(_customDateRange!.start)) &&
                (date.isBefore(_customDateRange!.end) ||
                    date.isAtSameMomentAs(_customDateRange!.end));
          }
          return true;
        case 'All Time':
        default:
          return true;
      }
    }).toList();

    // Sorting items descending by date
    filteredItems.sort((a, b) {
      String dateAStr;
      String dateBStr;
      if (a is Saving) {
        dateAStr = a.dateAcquired;
      } else if (a is Transaction) {
        dateAStr = a.date;
      } else {
        dateAStr = (a as InvestmentAsset).valuationDate;
      }
      if (b is Saving) {
        dateBStr = b.dateAcquired;
      } else if (b is Transaction) {
        dateBStr = b.date;
      } else {
        dateBStr = (b as InvestmentAsset).valuationDate;
      }
      final DateTime dateA = _parseDate(dateAStr) ?? DateTime(2000);
      final DateTime dateB = _parseDate(dateBStr) ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    final Map<String, double> incomeRemainingById = <String, double>{};
    if (widget.categoryType == 'cash') {
      final List<Map<String, dynamic>> incomeLots =
          ZakatEngineService.getNetIncomeLots(
            transactions: transactions,
            marketData: market,
          );
      for (final Map<String, dynamic> lot in incomeLots) {
        incomeRemainingById[(lot['id'] ?? '').toString()] =
            ((lot['remainingAmount'] ?? 0) as num).toDouble();
      }
    }

    // Compute Category Totals in Main Currency
    double categoryTotalVal = 0.0;
    for (final item in filteredItems) {
      if (item is Saving) {
        if (item.assetType == 'cash') {
          categoryTotalVal += ZakatEngineService.convertFromEgp(
            ZakatEngineService.convertToEgp(
              item.remainingAmount,
              item.unit,
              market,
            ),
            mainCurrency,
            market,
          );
        } else if (item.assetType == 'gold') {
          final double gold24k = ZakatEngineService.convertToGold24k(
            item.remainingAmount,
            item.unit,
          );
          final double egpVal = gold24k * market.goldPrice24kEgp;
          categoryTotalVal += ZakatEngineService.convertFromEgp(
            egpVal,
            mainCurrency,
            market,
          );
        } else if (item.assetType == 'silver') {
          final double silverGrams = ZakatEngineService.convertToSilverGrams(
            item.remainingAmount,
          );
          final double egpVal = silverGrams * market.silverPriceEgp;
          categoryTotalVal += ZakatEngineService.convertFromEgp(
            egpVal,
            mainCurrency,
            market,
          );
        }
      } else if (item is Transaction) {
        // Income transactions count as cash
        final double displayAmount =
            incomeRemainingById[item.id] ?? item.remainingAmount ?? item.amount;
        categoryTotalVal += ZakatEngineService.convertFromEgp(
          ZakatEngineService.convertToEgp(displayAmount, item.currency, market),
          mainCurrency,
          market,
        );
      } else if (item is InvestmentAsset) {
        final double share = (item.ownershipSharePct / 100).clamp(0, 1);
        final double gross = ZakatEngineService.convertToEgp(
          item.marketValue * share,
          item.currency,
          market,
        );
        final double liability = ZakatEngineService.convertToEgp(
          item.loanBalance,
          item.currency,
          market,
        );
        categoryTotalVal += ZakatEngineService.convertFromEgp(
          gross - liability,
          mainCurrency,
          market,
        );
      }
    }

    final String formattedTotal = ZakatEngineService.formatCurrency(
      categoryTotalVal,
      mainCurrency,
      isArabic: isArabic,
    );

    final tokens = context.premiumTokens;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.tr(titleKey))),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Category Summary Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: PremiumCard(
                hero: true,
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      radius: 28,
                      child: Icon(headerIcon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            context.l10n.tr('total_assets'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedTotal,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${filteredItems.length} ${context.l10n.tr('entries')}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Date Filters Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 20,
                      color: tokens.colors.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    ...<String>['All Time', '30D', '90D', 'YTD', 'Custom'].map((
                      filter,
                    ) {
                      final bool isSelected = _selectedDateFilter == filter;
                      String label = filter;
                      if (filter == 'All Time') label = context.l10n.tr('all');
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
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            if (filter == 'Custom') {
                              _selectCustomRange(context);
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
            ),

            // Assets List
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: EmptyStateCard(
                        cardKey: const Key('assetsEmptyState'),
                        title: context.l10n.tr('no_assets_yet'),
                        message: context.l10n.tr('assets_empty_message'),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredItems.length,
                      itemBuilder: (BuildContext context, int index) {
                        final item = filteredItems[index];
                        if (item is Saving) {
                          return _buildSavingTile(
                            context,
                            item,
                            mainCurrency,
                            market,
                            isArabic,
                          );
                        } else if (item is Transaction) {
                          return _buildTransactionTile(
                            context,
                            item,
                            mainCurrency,
                            market,
                            isArabic,
                            remainingAmountOverride:
                                incomeRemainingById[item.id],
                          );
                        } else if (item is InvestmentAsset) {
                          return _buildInvestmentTile(
                            context,
                            item,
                            mainCurrency,
                            market,
                            isArabic,
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('addAssetFab'),
        onPressed: () => _navigateToAdd(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSavingTile(
    BuildContext context,
    Saving saving,
    String mainCurrency,
    MarketData market,
    bool isArabic,
  ) {
    String originalAmountStr = '';
    double assetValueInMainCurrency = 0.0;

    if (saving.assetType == 'cash') {
      originalAmountStr = ZakatEngineService.formatCurrency(
        saving.remainingAmount,
        saving.unit,
        isArabic: isArabic,
      );
      assetValueInMainCurrency = ZakatEngineService.convertFromEgp(
        ZakatEngineService.convertToEgp(
          saving.remainingAmount,
          saving.unit,
          market,
        ),
        mainCurrency,
        market,
      );
    } else if (saving.assetType == 'gold') {
      originalAmountStr =
          '${saving.remainingAmount.toStringAsFixed(2)} g • ${saving.unit}k';
      final double gold24k = ZakatEngineService.convertToGold24k(
        saving.remainingAmount,
        saving.unit,
      );
      final double egpVal = gold24k * market.goldPrice24kEgp;
      assetValueInMainCurrency = ZakatEngineService.convertFromEgp(
        egpVal,
        mainCurrency,
        market,
      );
    } else if (saving.assetType == 'silver') {
      originalAmountStr = '${saving.remainingAmount.toStringAsFixed(2)} g';
      final double silverGrams = ZakatEngineService.convertToSilverGrams(
        saving.remainingAmount,
      );
      final double egpVal = silverGrams * market.silverPriceEgp;
      assetValueInMainCurrency = ZakatEngineService.convertFromEgp(
        egpVal,
        mainCurrency,
        market,
      );
    }

    final String formattedValue = ZakatEngineService.formatCurrency(
      assetValueInMainCurrency,
      mainCurrency,
      isArabic: isArabic,
    );

    final String displayTitle = saving.description.isNotEmpty
        ? saving.description
        : (saving.assetType == 'cash'
              ? context.l10n.tr('cash')
              : (saving.assetType == 'gold'
                    ? context.l10n.tr('gold')
                    : context.l10n.tr('silver')));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AddSavingScreen(initialSaving: saving),
            ),
          );
        },
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    displayTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${saving.dateAcquired} • $originalAmountStr',
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  formattedValue,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _confirmDeleteSaving(context, saving),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(
    BuildContext context,
    Transaction tx,
    String mainCurrency,
    MarketData market,
    bool isArabic, {
    double? remainingAmountOverride,
  }) {
    final double displayAmount =
        remainingAmountOverride ?? tx.remainingAmount ?? tx.amount;
    final double txAmountMain = ZakatEngineService.convertFromEgp(
      ZakatEngineService.convertToEgp(displayAmount, tx.currency, market),
      mainCurrency,
      market,
    );

    final String originalAmountStr = ZakatEngineService.formatCurrency(
      displayAmount,
      tx.currency,
      isArabic: isArabic,
    );

    final String formattedValue = ZakatEngineService.formatCurrency(
      txAmountMain,
      mainCurrency,
      isArabic: isArabic,
    );

    final String displayTitle = tx.description.isNotEmpty
        ? tx.description
        : tx.category;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  AddTransactionScreen(initialTransaction: tx, cashMode: true),
            ),
          );
        },
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: const Color(0xFFD1FAE5),
              radius: 18,
              child: Icon(
                _cashCategoryIcon(tx.category),
                color: const Color(0xFF047857),
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    displayTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${tx.date} • $originalAmountStr • ${tx.category}',
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  formattedValue,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _confirmDeleteTransaction(context, tx),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _cashCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'salary':
        return Icons.work_outlined;
      case 'freelance':
        return Icons.laptop_outlined;
      case 'business':
        return Icons.store_outlined;
      case 'savings':
        return Icons.savings_outlined;
      case 'gift':
        return Icons.card_giftcard_outlined;
      case 'bonus':
        return Icons.star_outline;
      case 'rental income':
        return Icons.home_outlined;
      case 'investment returns':
        return Icons.trending_up;
      default:
        return Icons.attach_money;
    }
  }

  Widget _buildInvestmentTile(
    BuildContext context,
    InvestmentAsset asset,
    String mainCurrency,
    MarketData market,
    bool isArabic,
  ) {
    final double share = (asset.ownershipSharePct / 100).clamp(0, 1);
    final double gross = ZakatEngineService.convertToEgp(
      asset.marketValue * share,
      asset.currency,
      market,
    );
    final double liability = ZakatEngineService.convertToEgp(
      asset.loanBalance,
      asset.currency,
      market,
    );
    final double netValueInMainCurrency = ZakatEngineService.convertFromEgp(
      gross - liability,
      mainCurrency,
      market,
    );

    final String formattedValue = ZakatEngineService.formatCurrency(
      netValueInMainCurrency,
      mainCurrency,
      isArabic: isArabic,
    );

    final String displayTitle = asset.location.isNotEmpty
        ? asset.location
        : (ZakatEngineService.isCompanyInvestmentType(asset.investmentType)
              ? context.l10n.tr('company_shares')
              : context.l10n.tr('property'));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AddInvestmentScreen(initialInvestment: asset),
            ),
          );
        },
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    displayTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${asset.valuationDate} • ${asset.ownershipSharePct.toStringAsFixed(0)}% • '
                    '${ZakatEngineService.formatCurrency(asset.marketValue, asset.currency, isArabic: isArabic)}',
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  formattedValue,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _confirmDeleteInvestment(context, asset),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToAdd(BuildContext context) {
    if (widget.categoryType == 'cash') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const AddTransactionScreen(cashMode: true),
        ),
      );
    } else if (widget.categoryType == 'gold' ||
        widget.categoryType == 'silver') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AddSavingScreen()));
    } else if (widget.categoryType == 'investments' ||
        widget.categoryType == 'property') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AddInvestmentScreen()),
      );
    }
  }

  Future<void> _confirmDeleteSaving(BuildContext context, Saving saving) async {
    final bool? confirmed = await showDialog<bool>(
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
    );

    if (confirmed == true && context.mounted) {
      await context.read<AppStateController>().deleteSaving(saving.id);
    }
  }

  Future<void> _confirmDeleteInvestment(
    BuildContext context,
    InvestmentAsset asset,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.l10n.tr('delete_investment')),
          content: Text(context.l10n.tr('delete_investment_message')),
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
    );

    if (confirmed == true && context.mounted) {
      await context.read<AppStateController>().deleteInvestment(asset.id);
    }
  }

  Future<void> _confirmDeleteTransaction(
    BuildContext context,
    Transaction tx,
  ) async {
    final bool? confirmed = await showDialog<bool>(
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
    );

    if (confirmed == true && context.mounted) {
      await context.read<AppStateController>().deleteTransaction(tx.id);
    }
  }
}
