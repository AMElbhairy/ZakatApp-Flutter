import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/theme/app_radii.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/investment_asset.dart';
import '../../models/saving.dart';
import '../../models/transaction.dart';
import '../../services/app_state_controller.dart';
import '../../services/reconciliation_service.dart';
import '../entry/add_investment_screen.dart';
import '../entry/add_saving_screen.dart';
import '../entry/add_transaction_screen.dart';
import '../../core/widgets/currency_exchange_dialog.dart';
import '../../core/widgets/sell_metal_dialog.dart';

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

  String _getFlagEmoji(String currency) {
    switch (currency.trim().toUpperCase()) {
      case 'USD':
        return '🇺🇸';
      case 'EGP':
        return '🇪🇬';
      case 'SAR':
        return '🇸🇦';
      case 'AED':
        return '🇦🇪';
      case 'KWD':
        return '🇰🇼';
      case 'QAR':
        return '🇶🇦';
      case 'EUR':
        return '🇪🇺';
      case 'GBP':
        return '🇬🇧';
      case 'BHD':
        return '🇧🇭';
      case 'OMR':
        return '🇴🇲';
      case 'JOD':
        return '🇯🇴';
      case 'TRY':
        return '🇹🇷';
      case 'MYR':
        return '🇲🇾';
      case 'PKR':
        return '🇵🇰';
      case 'IDR':
        return '🇮🇩';
      default:
        return '🏳️';
    }
  }

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

  String _savingDisplayDate(Saving saving) {
    if ((saving.exchangeSourceSavingId ?? '').isNotEmpty &&
        saving.createdAt.isNotEmpty) {
      return saving.createdAt;
    }
    return saving.dateAcquired;
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
        final Set<String> cashCurrencies = <String>{
          ...transactions.map(
            (Transaction transaction) => transaction.currency,
          ),
          ...savings
              .where((Saving saving) => saving.assetType == 'cash')
              .map((Saving saving) => saving.unit),
        }..removeWhere((String currency) => currency.trim().isEmpty);
        items = cashCurrencies
            .expand(
              (String currency) => controller.getAvailableCashSources(
                currency: currency,
                newestFirst: true,
              ),
            )
            .toList(growable: false);
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
    bool includesSelectedDate(String dateStr) {
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
    }

    final List<dynamic> filteredItems = items.where((item) {
      String dateStr;
      if (item is Saving) {
        dateStr = _savingDisplayDate(item);
      } else if (item is CashSource) {
        dateStr = item.date;
      } else if (item is Transaction) {
        dateStr = item.date;
      } else {
        dateStr = (item as InvestmentAsset).valuationDate;
      }
      return includesSelectedDate(dateStr);
    }).toList();

    // Sorting items descending by date
    filteredItems.sort((a, b) {
      String dateAStr;
      String dateBStr;
      if (a is Saving) {
        dateAStr = _savingDisplayDate(a);
      } else if (a is CashSource) {
        dateAStr = a.date;
      } else if (a is Transaction) {
        dateAStr = a.date;
      } else {
        dateAStr = (a as InvestmentAsset).valuationDate;
      }
      if (b is Saving) {
        dateBStr = _savingDisplayDate(b);
      } else if (b is CashSource) {
        dateBStr = b.date;
      } else if (b is Transaction) {
        dateBStr = b.date;
      } else {
        dateBStr = (b as InvestmentAsset).valuationDate;
      }
      final DateTime dateA = _parseDate(dateAStr) ?? DateTime(2000);
      final DateTime dateB = _parseDate(dateBStr) ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    Map<String, double> cashByCurrency = <String, double>{};

    // Compute Category Totals in Main Currency
    double categoryTotalVal = 0.0;
    if (widget.categoryType == 'cash') {
      for (final CashSource source in filteredItems.whereType<CashSource>()) {
        cashByCurrency[source.currency] =
            (cashByCurrency[source.currency] ?? 0) + source.availableAmount;
      }
      categoryTotalVal = cashByCurrency.entries.fold<double>(
        0,
        (double sum, MapEntry<String, double> entry) =>
            sum +
            ZakatEngineService.convertFromEgp(
              ZakatEngineService.convertToEgp(entry.value, entry.key, market),
              mainCurrency,
              market,
            ),
      );
    } else {
      for (final item in filteredItems) {
        if (item is Saving) {
          if (item.assetType == 'gold') {
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
        } else if (item is InvestmentAsset) {
          final double share = (item.ownershipSharePct / 100).clamp(0, 1);
          final double gross = ZakatEngineService.convertToEgp(
            item.marketValue * share,
            item.currency,
            market,
          );
          categoryTotalVal += ZakatEngineService.convertFromEgp(
            gross,
            mainCurrency,
            market,
          );
        }
      }
    }

    final String formattedTotal = ZakatEngineService.formatCurrency(
      categoryTotalVal,
      mainCurrency,
      isArabic: isArabic,
    );
    final bool isCashCategory = widget.categoryType == 'cash';
    final List<MapEntry<String, double>> cashEntries = cashByCurrency.entries
        .toList(growable: false);

    double profitAmount = 0.0;
    double profitPct = 0.0;
    bool showProfitLoss = false;
    double totalGold24kGrams = 0.0;
    double totalSilverGrams = 0.0;

    if (widget.categoryType == 'gold') {
      double totalPurchaseCost = 0.0;
      for (final item in filteredItems) {
        if (item is Saving && item.assetType == 'gold') {
          totalGold24kGrams += ZakatEngineService.convertToGold24k(
            item.remainingAmount,
            item.unit,
          );
          final String pCurr = item.purchaseCurrency.trim().isEmpty
              ? mainCurrency
              : item.purchaseCurrency;
          final double pCostEgp = ZakatEngineService.convertToEgp(
            item.purchaseAmount,
            pCurr,
            market,
          );
          final double pCostMain = ZakatEngineService.convertFromEgp(
            pCostEgp,
            mainCurrency,
            market,
          );
          totalPurchaseCost += pCostMain;
        }
      }
      if (totalPurchaseCost > 0) {
        profitAmount = categoryTotalVal - totalPurchaseCost;
        profitPct = (profitAmount / totalPurchaseCost) * 100;
        showProfitLoss = true;
      }
    } else if (widget.categoryType == 'silver') {
      double totalPurchaseCost = 0.0;
      for (final item in filteredItems) {
        if (item is Saving && item.assetType == 'silver') {
          totalSilverGrams += ZakatEngineService.convertToSilverGrams(
            item.remainingAmount,
          );
          final String pCurr = item.purchaseCurrency.trim().isEmpty
              ? mainCurrency
              : item.purchaseCurrency;
          final double pCostEgp = ZakatEngineService.convertToEgp(
            item.purchaseAmount,
            pCurr,
            market,
          );
          final double pCostMain = ZakatEngineService.convertFromEgp(
            pCostEgp,
            mainCurrency,
            market,
          );
          totalPurchaseCost += pCostMain;
        }
      }
      if (totalPurchaseCost > 0) {
        profitAmount = categoryTotalVal - totalPurchaseCost;
        profitPct = (profitAmount / totalPurchaseCost) * 100;
        showProfitLoss = true;
      }
    }

    final tokens = context.premiumTokens;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color borderColor = isDark
        ? const Color(0xFFFFC928).withValues(alpha: 0.45)
        : const Color(0xFFC5A059).withValues(alpha: 0.65);
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;
    final Alignment gradientBegin = isRtl
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final Alignment gradientEnd = isRtl
        ? Alignment.centerRight
        : Alignment.centerLeft;
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
                padding: EdgeInsets.zero,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: AppRadii.hero,
                    border: Border.all(color: borderColor, width: 1.5),
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: <Color>[Color(0xFF01332B), Color(0xFF00221C)],
                    ),
                  ),
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return LinearGradient(
                                begin: gradientBegin,
                                end: gradientEnd,
                                colors: <Color>[
                                  Colors.white.withValues(
                                    alpha: isDark ? 0.20 : 0.38,
                                  ),
                                  Colors.white.withValues(
                                    alpha: isDark ? 0.01 : 0.05,
                                  ),
                                ],
                                stops: const <double>[0.0, 1.0],
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.dstIn,
                            child: Image.asset(
                              'assets/images/hero_pattern_watermark.png',
                              fit: BoxFit.cover,
                              alignment: AlignmentDirectional.topEnd,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: isCashCategory && cashByCurrency.isNotEmpty
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Expanded(
                                    flex: 58,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Row(
                                          children: <Widget>[
                                            CircleAvatar(
                                              backgroundColor: Colors.white
                                                  .withValues(alpha: 0.15),
                                              radius: 16,
                                              child: Icon(
                                                headerIcon,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                context.l10n
                                                    .tr('total_assets')
                                                    .toUpperCase(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Color(0xFFFFC928),
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.8,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        SizedBox(
                                          width: double.infinity,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: AlignmentDirectional
                                                .centerStart,
                                            child: Text(
                                              formattedTotal,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 28,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
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
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 42,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 3,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: const Color(
                                                  0xFFFFC928,
                                                ).withValues(alpha: 0.25),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              '${cashEntries.length} ${context.l10n.tr('currency')}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFFFFC928),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          alignment: WrapAlignment.end,
                                          runAlignment: WrapAlignment.start,
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: cashEntries
                                              .map((entry) {
                                                final String formatted =
                                                    ZakatEngineService.formatCurrency(
                                                      entry.value,
                                                      entry.key,
                                                      isArabic: isArabic,
                                                    );
                                                return Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.05,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: <Widget>[
                                                      Text(
                                                        _getFlagEmoji(
                                                          entry.key,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        formatted,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: 0.88,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              })
                                              .toList(growable: false),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: Colors.white
                                                .withValues(alpha: 0.15),
                                            radius: 18,
                                            child: Icon(
                                              headerIcon,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            context.l10n
                                                .tr('total_assets')
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              color: Color(0xFFFFC928),
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.0,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (widget.categoryType == 'gold' &&
                                          totalGold24kGrams > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: const Color(
                                                0xFFFFC928,
                                              ).withValues(alpha: 0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${totalGold24kGrams.toStringAsFixed(1)} g',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '24K EQUIV',
                                                style: TextStyle(
                                                  color: const Color(
                                                    0xFFFFC928,
                                                  ),
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 8,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (widget.categoryType == 'silver' &&
                                          totalSilverGrams > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: const Color(
                                                0xFFFFC928,
                                              ).withValues(alpha: 0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${totalSilverGrams.toStringAsFixed(1)} g',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'SILVER',
                                                style: TextStyle(
                                                  color: const Color(
                                                    0xFFFFC928,
                                                  ),
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 8,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: Text(
                                        formattedTotal,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Text(
                                        '${filteredItems.length} ${context.l10n.tr('entries')}',
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (showProfitLoss)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Icon(
                                              profitAmount >= 0
                                                  ? Icons.trending_up
                                                  : Icons.trending_down,
                                              color: profitAmount >= 0
                                                  ? Colors.greenAccent
                                                  : Colors.redAccent,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${ZakatEngineService.formatCurrency(profitAmount, mainCurrency, isArabic: isArabic, showSign: true)} (${profitAmount >= 0 ? '+' : ''}${profitPct.toStringAsFixed(1)}%)',
                                              style: TextStyle(
                                                color: profitAmount >= 0
                                                    ? Colors.greenAccent
                                                    : Colors.redAccent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Date Filters Row
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth - 32,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.calendar_month_outlined,
                            size: 20,
                            color: tokens.colors.textPrimary,
                          ),
                          const SizedBox(width: 8),
                          ...<String>[
                            'All Time',
                            '30D',
                            '90D',
                            'YTD',
                            'Custom',
                          ].map((filter) {
                            final bool isSelected =
                                _selectedDateFilter == filter;
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: ChoiceChip(
                                labelPadding: EdgeInsets.zero,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                visualDensity: const VisualDensity(
                                  horizontal: -1,
                                  vertical: -1,
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                labelStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
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
                );
              },
            ),

            // Assets List
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: EmptyStateCard(
                        cardKey: const Key('assetsEmptyState'),
                        title: isCashCategory
                            ? context.l10n.tr('no_available_cash')
                            : context.l10n.tr('no_assets_yet'),
                        message: isCashCategory
                            ? context.l10n.tr('no_available_cash_message')
                            : context.l10n.tr('assets_empty_message'),
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
                        } else if (item is CashSource) {
                          return _buildCashSourceTile(
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
      if (saving.remainingAmount < saving.amount) {
        originalAmountStr = 'Purchased: ${saving.amount.toStringAsFixed(2)} g (${saving.unit}k) • ${saving.remainingAmount.toStringAsFixed(2)} g available';
      } else {
        originalAmountStr =
            '${saving.remainingAmount.toStringAsFixed(2)} g • ${saving.unit}k';
      }
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
      if (saving.remainingAmount < saving.amount) {
        originalAmountStr = 'Purchased: ${saving.amount.toStringAsFixed(2)} g • ${saving.remainingAmount.toStringAsFixed(2)} g available';
      } else {
        originalAmountStr = '${saving.remainingAmount.toStringAsFixed(2)} g';
      }
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
      child: Slidable(
        key: Key('dismiss_saving_${saving.id}'),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.28,
          children: [
            CustomSlidableAction(
              key: Key('delete_action_saving_${saving.id}'),
              onPressed: (BuildContext slidableContext) {
                _confirmDeleteSaving(context, saving);
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
          onTap: () {
            if (saving.exchangeSourceSavingId != null &&
                saving.exchangeSourceSavingId!.isNotEmpty) {
              _openEditCurrencyExchangeDialog(context, saving);
            } else {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AddSavingScreen(initialSaving: saving),
                ),
              );
            }
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
                      '${_savingDisplayDate(saving).split('T').first} • $originalAmountStr',
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
                  if (saving.assetType == 'gold' || saving.assetType == 'silver')
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (String val) {
                        if (val == 'buy_more') {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AddSavingScreen(initialAssetType: saving.assetType),
                            ),
                          );
                        } else if (val == 'sell') {
                          openSellMetalDialog(context, saving: saving);
                        } else if (val == 'edit') {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AddSavingScreen(initialSaving: saving),
                            ),
                          );
                        } else if (val == 'delete') {
                          _confirmDeleteSaving(context, saving);
                        }
                      },
                      itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'buy_more',
                          child: Text(
                            saving.assetType == 'gold'
                                ? context.l10n.tr('buy_more_gold')
                                : context.l10n.tr('buy_more_silver'),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'sell',
                          child: Text(
                            saving.assetType == 'gold'
                                ? context.l10n.tr('sell_gold')
                                : context.l10n.tr('sell_silver'),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Text(
                            saving.assetType == 'gold'
                                ? context.l10n.tr('edit_gold')
                                : context.l10n.tr('edit_silver'),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text(context.l10n.tr('delete')),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashSourceTile(
    BuildContext context,
    CashSource source,
    String mainCurrency,
    MarketData market,
    bool isArabic,
  ) {
    final String remaining = ZakatEngineService.formatCurrency(
      source.availableAmount,
      source.currency,
      isArabic: isArabic,
    );
    final String original = ZakatEngineService.formatCurrency(
      source.originalAmount,
      source.currency,
      isArabic: isArabic,
    );
    final double valueInMain = ZakatEngineService.convertFromEgp(
      ZakatEngineService.convertToEgp(
        source.availableAmount,
        source.currency,
        market,
      ),
      mainCurrency,
      market,
    );
    final String title = source.description.trim().isEmpty
        ? context.l10n.tr('cash')
        : source.description;
    final AppStateController controller = context.read<AppStateController>();
    final Saving? saving = source.sourceType == 'savings'
        ? controller.state.savings
              .where((Saving saving) => saving.id == source.id)
              .firstOrNull
        : null;
    final Transaction? transaction = source.sourceType == 'income'
        ? controller.state.transactions
              .where((Transaction transaction) => transaction.id == source.id)
              .firstOrNull
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: Key('dismiss_cash_source_${source.sourceType}_${source.id}'),
        endActionPane: (saving != null || transaction != null)
            ? ActionPane(
                motion: const ScrollMotion(),
                extentRatio: 0.28,
                children: [
                  CustomSlidableAction(
                    key: Key('delete_action_cash_source_${source.id}'),
                    onPressed: (BuildContext slidableContext) {
                      if (saving != null) {
                        _confirmDeleteSaving(context, saving);
                      } else if (transaction != null) {
                        _confirmDeleteTransaction(context, transaction);
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
              )
            : null,
        child: PremiumCard(
          onTap: () {
            if (saving != null) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AddSavingScreen(initialSaving: saving),
                ),
              );
            } else if (transaction != null) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AddTransactionScreen(
                    initialTransaction: transaction,
                    cashMode: true,
                  ),
                ),
              );
            }
          },
          child: ListTile(
            key: Key('cashSource_${source.sourceType}_${source.id}'),
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              child: Icon(Icons.account_balance_wallet_outlined),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${source.date.split('T').first} • Original: $original • Remaining: $remaining',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  ZakatEngineService.formatCurrency(
                    valueInMain,
                    mainCurrency,
                    isArabic: isArabic,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionTile(
    BuildContext context,
    Transaction tx,
    String mainCurrency,
    MarketData market,
    bool isArabic,
  ) {
    final bool isExpense = tx.type == 'expense';
    final double displayAmount = tx.amount;
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
      isExpense ? -txAmountMain : txAmountMain,
      mainCurrency,
      isArabic: isArabic,
      showSign: true,
    );

    final String displayTitle = tx.description.isNotEmpty
        ? tx.description
        : tx.category;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: Key('dismiss_transaction_${tx.id}'),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.28,
          children: [
            CustomSlidableAction(
              key: Key('delete_action_transaction_${tx.id}'),
              onPressed: (BuildContext slidableContext) {
                _confirmDeleteTransaction(context, tx);
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
          onTap: () {
            if (tx.category == 'Currency Exchange') {
              _openEditCurrencyExchangeDialog(context, tx);
            } else {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AddTransactionScreen(
                    initialTransaction: tx,
                    cashMode: tx.type == 'income',
                  ),
                ),
              );
            }
          },
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: isExpense
                    ? const Color(0xFFFFE4E6)
                    : const Color(0xFFD1FAE5),
                radius: 18,
                child: Icon(
                  _cashCategoryIcon(tx.category),
                  color: isExpense
                      ? const Color(0xFFBE123C)
                      : const Color(0xFF047857),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    formattedValue,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isExpense ? const Color(0xFFBE123C) : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
    final double grossValueInMainCurrency = ZakatEngineService.convertFromEgp(
      gross,
      mainCurrency,
      market,
    );

    final String formattedValue = ZakatEngineService.formatCurrency(
      grossValueInMainCurrency,
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
      child: Slidable(
        key: Key('dismiss_investment_${asset.id}'),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.28,
          children: [
            CustomSlidableAction(
              key: Key('delete_action_investment_${asset.id}'),
              onPressed: (BuildContext slidableContext) {
                _confirmDeleteInvestment(context, asset);
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
                    if (asset.loanBalance > 0) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showInstallmentSchedule(context, asset),
                            borderRadius: BorderRadius.circular(6),
                            child: Ink(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFFFC928,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(
                                    0xFFFFC928,
                                  ).withValues(alpha: 0.45),
                                  width: 0.7,
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.calendar_today,
                                    color: Color(0xFFFFC928),
                                    size: 10,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Installments: ${ZakatEngineService.formatCurrency(asset.loanBalance, asset.currency, isArabic: isArabic)} remaining',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFFFFC928),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Color(0xFFFFC928),
                                    size: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    formattedValue,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
      ).push(
        MaterialPageRoute<void>(
          builder: (_) => AddSavingScreen(
            initialAssetType: widget.categoryType,
          ),
        ),
      );
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

  Future<String?> _pickInstallmentCategory(
    BuildContext context,
    List<String> categories,
  ) async {
    if (categories.isEmpty) return 'Other Expense';
    String selected = categories.first;
    return showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(context.l10n.tr('select_payment_category')),
        content: DropdownButtonFormField<String>(
          initialValue: selected,
          items: categories
              .map(
                (String c) =>
                    DropdownMenuItem<String>(
                  value: c,
                  child: Text(ctx.l10n.translateCategory(c)),
                ),
              )
              .toList(growable: false),
          onChanged: (String? v) => selected = v ?? selected,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(selected),
            child: Text(context.l10n.tr('save')),
          ),
        ],
      ),
    );
  }

  void _showInstallmentSchedule(BuildContext context, InvestmentAsset asset) {
    final tokens = context.premiumTokens;
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final AppStateController controller = context.read<AppStateController>();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: tokens.colors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final latestAsset = controller.state.investments.firstWhere(
              (a) => a.id == asset.id,
              orElse: () => asset,
            );
            final plan = latestAsset.installmentPlan;

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (BuildContext context, ScrollController scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: tokens.colors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Installment Schedule - ${latestAsset.location}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: tokens.colors.textPrimary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Remaining Liability: ${ZakatEngineService.formatCurrency(latestAsset.loanBalance, latestAsset.currency, isArabic: isArabic)}',
                        style: TextStyle(
                          color: tokens.colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: plan.isEmpty
                            ? Center(child: Text('No installments scheduled.'))
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: plan.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final inst = plan[index];
                                  final bool isPaid = inst['isPaid'] == true;
                                  final double amount =
                                      (inst['amount'] as num?)?.toDouble() ??
                                      0.0;
                                  final String rawDate =
                                      InvestmentAsset.installmentDueDate(inst);
                                  final String currency =
                                      (inst['currency'] ?? latestAsset.currency)
                                          .toString();
                                  final String amountStr =
                                      ZakatEngineService.formatCurrency(
                                        amount,
                                        currency,
                                        isArabic: isArabic,
                                      );
                                  final String title = rawDate.isEmpty
                                      ? 'Installment #${index + 1}'
                                      : rawDate;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Card(
                                      color: tokens.colors.surface,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: tokens.colors.divider,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: ListTile(
                                        title: Text(
                                          title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: InkWell(
                                          onTap: () async {
                                            final DateTime? picked =
                                                await showDatePicker(
                                                  context: context,
                                                  initialDate:
                                                      DateTime.tryParse(
                                                        rawDate,
                                                      ) ??
                                                      DateTime.now(),
                                                  firstDate: DateTime(2000),
                                                  lastDate: DateTime(2100),
                                                );
                                            if (picked != null) {
                                              final List<Map<String, dynamic>>
                                              updatedPlan = plan
                                                  .map(
                                                    (e) =>
                                                        Map<
                                                          String,
                                                          dynamic
                                                        >.from(e),
                                                  )
                                                  .toList();
                                              final String formattedDate =
                                                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                              updatedPlan[index]['date'] =
                                                  formattedDate;
                                              updatedPlan[index]['recurrenceDate'] =
                                                  formattedDate;

                                              final updatedAsset = InvestmentAsset(
                                                id: latestAsset.id,
                                                investmentType:
                                                    latestAsset.investmentType,
                                                assetSubtype:
                                                    latestAsset.assetSubtype,
                                                ownershipType:
                                                    latestAsset.ownershipType,
                                                valuationMode:
                                                    latestAsset.valuationMode,
                                                currency: latestAsset.currency,
                                                originalPrice:
                                                    latestAsset.originalPrice,
                                                totalInterest:
                                                    latestAsset.totalInterest,
                                                totalPayable:
                                                    latestAsset.totalPayable,
                                                paidAmount:
                                                    latestAsset.paidAmount,
                                                remainingAmount:
                                                    latestAsset.remainingAmount,
                                                installmentPlan: updatedPlan,
                                                valuationDate:
                                                    latestAsset.valuationDate,
                                                marketValue:
                                                    latestAsset.marketValue,
                                                marketValueDate:
                                                    latestAsset.marketValueDate,
                                                valuationSource:
                                                    latestAsset.valuationSource,
                                                loanBalance:
                                                    latestAsset.loanBalance,
                                                loanAsOfDate:
                                                    latestAsset.loanAsOfDate,
                                                paidAmountToDate: latestAsset
                                                    .paidAmountToDate,
                                                ownershipSharePct: latestAsset
                                                    .ownershipSharePct,
                                                country: latestAsset.country,
                                                location: latestAsset.location,
                                                inflationRateAnnual: latestAsset
                                                    .inflationRateAnnual,
                                                estimatedCurrentValue:
                                                    latestAsset
                                                        .estimatedCurrentValue,
                                                description:
                                                    latestAsset.description,
                                                noZakat: latestAsset.noZakat,
                                                createdAt:
                                                    latestAsset.createdAt,
                                              );
                                              await controller.updateInvestment(
                                                updatedAsset,
                                              );
                                              setModalState(() {});
                                              setState(() {});
                                            }
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4.0,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  rawDate,
                                                  style: TextStyle(
                                                    color: tokens
                                                        .colors
                                                        .textSecondary,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons.edit_calendar,
                                                  size: 12,
                                                  color: tokens
                                                      .colors
                                                      .textSecondary,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              amountStr,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isPaid
                                                    ? Colors.grey
                                                    : tokens.colors.textPrimary,
                                                decoration: isPaid
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            TextButton(
                                              style: TextButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                foregroundColor: isPaid
                                                    ? Colors.grey
                                                    : tokens.colors.emerald,
                                              ),
                                              onPressed: () async {
                                                if (isPaid) {
                                                  await controller
                                                      .toggleInstallmentPaid(
                                                        assetId: latestAsset.id,
                                                        installmentIndex: index,
                                                        paymentCategory: '',
                                                      );
                                                } else {
                                                  final List<String>
                                                  expenseCategories = controller
                                                      .state
                                                      .categories
                                                      .expense;
                                                  final String? category =
                                                      await _pickInstallmentCategory(
                                                        context,
                                                        expenseCategories,
                                                      );
                                                  if (category != null) {
                                                    await controller
                                                        .toggleInstallmentPaid(
                                                          assetId:
                                                              latestAsset.id,
                                                          installmentIndex:
                                                              index,
                                                          paymentCategory:
                                                              category,
                                                        );
                                                  }
                                                }
                                                setModalState(() {});
                                                setState(() {});
                                              },
                                              child: Text(
                                                isPaid
                                                    ? context.l10n.tr(
                                                        'mark_as_unpaid',
                                                      )
                                                    : context.l10n.tr('pay'),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
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
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openEditCurrencyExchangeDialog(
    BuildContext context,
    dynamic item,
  ) async {
    await openEditCurrencyExchangeDialog(context, item);
  }
}
