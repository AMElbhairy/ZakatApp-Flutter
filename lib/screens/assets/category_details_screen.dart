import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/theme/app_radii.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/compact_dropdown.dart';
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
    required this.categoryType, // 'cash', 'gold', 'silver', 'investments', 'property', 'other_assets', 'liabilities'
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
                  ZakatEngineService.normaliseInvestmentType(
                    a.investmentType,
                  ) ==
                  'real_estate',
            )
            .toList();
        titleKey = 'properties';
        headerIcon = Icons.home_outlined;
        break;
      case 'other_assets':
        items = investments
            .where(
              (a) =>
                  ZakatEngineService.normaliseInvestmentType(
                    a.investmentType,
                  ) ==
                  'car',
            )
            .toList();
        titleKey = 'vehicles';
        headerIcon = Icons.directions_car_outlined;
        break;
      case 'liabilities':
        items = investments
            .where(
              (InvestmentAsset asset) =>
                  ZakatEngineService.normaliseInvestmentType(
                    asset.investmentType,
                  ) ==
                  'liability',
            )
            .toList();
        titleKey = 'other_liabilities';
        headerIcon = Icons.account_balance_outlined;
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
          final String type = ZakatEngineService.normaliseInvestmentType(
            item.investmentType,
          );
          if (type == 'liability') {
            final double outstanding = item.installmentPlan.isNotEmpty
                ? item.installmentPlan
                      .where((inst) => inst['isPaid'] != true)
                      .fold<double>(0.0, (s, inst) {
                        final double amount = ((inst['amount'] ?? 0) as num)
                            .toDouble();
                        final String cur =
                            inst['currency']?.toString() ?? item.currency;
                        return s +
                            ZakatEngineService.convertToEgp(
                              amount,
                              cur,
                              market,
                            );
                      })
                : ZakatEngineService.convertToEgp(
                    item.loanBalance > 0
                        ? item.loanBalance
                        : item.remainingAmount,
                    item.currency,
                    market,
                  );
            categoryTotalVal -= ZakatEngineService.convertFromEgp(
              outstanding,
              mainCurrency,
              market,
            );
          } else {
            final double share = 1.0;
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
    double categoryLiabilitiesMain = 0.0;
    if (widget.categoryType == 'investments' ||
        widget.categoryType == 'property' ||
        widget.categoryType == 'other_assets') {
      double totalLiabsEgp = 0.0;
      for (final item in filteredItems) {
        if (item is InvestmentAsset) {
          final double unpaidLiabilityEgp = item.installmentPlan.isNotEmpty
              ? item.installmentPlan
                    .where((inst) => inst['isPaid'] != true)
                    .fold(0.0, (sum, inst) {
                      final String instCurrency =
                          (inst['currency']?.toString().isNotEmpty == true)
                          ? inst['currency'].toString()
                          : item.currency;
                      final double amount = ((inst['amount'] ?? 0) as num)
                          .toDouble();
                      return sum +
                          ZakatEngineService.convertToEgp(
                            amount,
                            instCurrency,
                            market,
                          );
                    })
              : ZakatEngineService.convertToEgp(
                  item.loanBalance,
                  item.currency,
                  market,
                );
          totalLiabsEgp += unpaidLiabilityEgp;
        }
      }
      categoryLiabilitiesMain = ZakatEngineService.convertFromEgp(
        totalLiabsEgp,
        mainCurrency,
        market,
      );
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
                                                    .tr(widget.categoryType == 'liabilities'
                                                        ? 'total_other_liabilities'
                                                        : 'total_assets')
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
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  // Left Column
                                  Expanded(
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
                                                    .tr(widget.categoryType == 'liabilities'
                                                        ? 'total_other_liabilities'
                                                        : 'total_assets')
                                                    .toUpperCase(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Color(0xFFFFC928),
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 1.0,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment:
                                              AlignmentDirectional.centerStart,
                                          child: Text(
                                            formattedTotal,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 26,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (widget.categoryType ==
                                                'investments' ||
                                            widget.categoryType == 'property' ||
                                            widget.categoryType ==
                                                'other_assets') ...[
                                          const SizedBox(height: 10),
                                          Text(
                                            context.l10n
                                                .tr('liabilities')
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              color: Color(0xFFFFC928),
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.0,
                                              fontSize: 9,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: AlignmentDirectional
                                                .centerStart,
                                            child: Text(
                                              ZakatEngineService.formatCurrency(
                                                categoryLiabilitiesMain,
                                                mainCurrency,
                                                isArabic: isArabic,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // Right Column
                                  Container(
                                    padding: const EdgeInsetsDirectional.only(
                                      start: 12,
                                    ),
                                    decoration: const BoxDecoration(
                                      border: BorderDirectional(
                                        start: BorderSide(
                                          color: Colors.white24,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Row(
                                          children: <Widget>[
                                            Icon(
                                              Icons.layers_outlined,
                                              color: Colors.white.withValues(
                                                alpha: 0.75,
                                              ),
                                              size: 14,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${filteredItems.length} ${context.l10n.tr('entries')}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (widget.categoryType == 'gold' &&
                                            totalGold24kGrams > 0) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            '${totalGold24kGrams.toStringAsFixed(1)} g 24K',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                        if (widget.categoryType == 'silver' &&
                                            totalSilverGrams > 0) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            '${totalSilverGrams.toStringAsFixed(1)} g SILVER',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                        if (showProfitLoss) ...[
                                          const SizedBox(height: 8),
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
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${profitAmount >= 0 ? '+' : ''}${profitPct.toStringAsFixed(1)}%',
                                                style: TextStyle(
                                                  color: profitAmount >= 0
                                                      ? Colors.greenAccent
                                                      : Colors.redAccent,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
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
                              label = context.l10n.tr('all_time');
                            } else if (filter == '30D') {
                              label = context.l10n.tr('period_30d');
                            } else if (filter == '90D') {
                              label = context.l10n.tr('period_90d');
                            } else if (filter == 'YTD') {
                              label = context.l10n.tr('period_ytd');
                            } else if (filter == 'Custom') {
                              label = context.l10n.tr('period_custom');
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
                            : (widget.categoryType == 'liabilities'
                                ? context.l10n.tr('no_liabilities_yet')
                                : context.l10n.tr('no_assets_yet')),
                        message: isCashCategory
                            ? context.l10n.tr('no_available_cash_message')
                            : (widget.categoryType == 'liabilities'
                                ? context.l10n.tr('liabilities_empty_message')
                                : context.l10n.tr('assets_empty_message')),
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
        originalAmountStr =
            'Purchased: ${saving.amount.toStringAsFixed(2)} g (${saving.unit}k) • ${saving.remainingAmount.toStringAsFixed(2)} g available';
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
        originalAmountStr =
            'Purchased: ${saving.amount.toStringAsFixed(2)} g • ${saving.remainingAmount.toStringAsFixed(2)} g available';
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

    final bool isMetal =
        saving.assetType == 'gold' || saving.assetType == 'silver';
    final String karatSuffix = saving.assetType == 'gold'
        ? ' | ${saving.unit}K'
        : (saving.assetType == 'silver' ? ' | 999' : '');
    final String metalTitle = isMetal
        ? '$displayTitle$karatSuffix'
        : displayTitle;
    final String rightSubText = isMetal
        ? '${saving.remainingAmount.toStringAsFixed(2)} g'
        : originalAmountStr;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slidable(
        key: Key('dismiss_saving_${saving.id}'),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: isMetal ? 0.56 : 0.28,
          children: [
            if (isMetal)
              CustomSlidableAction(
                key: Key('sell_action_saving_${saving.id}'),
                onPressed: (BuildContext slidableContext) {
                  openSellMetalDialog(context, saving: saving);
                },
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.sell_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      saving.assetType == 'gold'
                          ? context.l10n.tr('sell_gold')
                          : context.l10n.tr('sell_silver'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
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
          padding: const EdgeInsets.all(10.0),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (saving.assetType == 'gold')
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.layers_rounded,
                    color: Color(0xFFD4AF37),
                    size: 22,
                  ),
                )
              else if (saving.assetType == 'silver')
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF94A3B8).withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.layers_rounded,
                    color: Color(0xFF94A3B8),
                    size: 22,
                  ),
                )
              else
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            metalTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w700,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : const Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formattedValue,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF34D399)
                                : const Color(0xFF065F46),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          _savingDisplayDate(saving).split('T').first,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFA3B8B5)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                        Text(
                          rightSubText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFA3B8B5)
                                : const Color(0xFF475569),
                          ),
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

    String displayTitle = title;
    String? amountExchangedText;

    final String lowerTitle = title.toLowerCase().trim();
    if (lowerTitle.startsWith('currency exchange in:')) {
      displayTitle = isArabic ? 'تحويل عملة' : 'Currency exchange';
      final String afterIn = title
          .substring(
            lowerTitle.indexOf('currency exchange in:') +
                'currency exchange in:'.length,
          )
          .trim();
      final List<String> parts = afterIn.split(RegExp(r'→|->|–|-'));
      if (parts.isNotEmpty) {
        final String originalExchanged = parts[0].trim();
        amountExchangedText = isArabic
            ? 'المبلغ المحول: $originalExchanged'
            : 'Amount Exchanged : $originalExchanged';
      }
    } else {
      final List<String> parts = title.split(
        RegExp(r'\s+from\s+', caseSensitive: false),
      );
      if (parts.length > 1) {
        final String rawPrefix = parts[0].trim();
        final String rawSuffix = parts[1].trim();
        final String lowerPrefix = rawPrefix.toLowerCase();

        if (lowerPrefix.contains('bank transfer')) {
          displayTitle = isArabic ? 'تحويل بنكي' : 'Bank Transfer';
        } else if (lowerPrefix.contains('account deposit') ||
            lowerPrefix.contains('salary deposit')) {
          displayTitle = isArabic ? 'إيداع في الحساب' : 'Account Deposit';
        } else if (lowerPrefix.contains('deposit')) {
          displayTitle = isArabic ? 'إيداع' : 'Deposit';
        } else if (lowerPrefix.contains('transfer')) {
          displayTitle = isArabic ? 'تحويل' : 'Transfer';
        } else if (lowerPrefix.contains('income')) {
          displayTitle = isArabic ? 'دخل' : 'Income';
        } else {
          displayTitle = rawPrefix;
        }

        amountExchangedText = isArabic ? 'من: $rawSuffix' : 'From: $rawSuffix';
      }
    }

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
      padding: const EdgeInsets.only(bottom: 8),
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
          padding: const EdgeInsets.all(10.0),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Color(0xFF10B981),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : const Color(0xFF1F2937),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              ZakatEngineService.formatCurrency(
                                valueInMain,
                                mainCurrency,
                                isArabic: isArabic,
                              ),
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              source.date.split('T').first,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFA3B8B5)
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                            if (amountExchangedText != null)
                              Text(
                                amountExchangedText,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFA3B8B5)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    _buildBadge(
                      label:
                          '${isArabic ? 'الأصلي' : 'Original'}: ${original.replaceAll(RegExp(r'\.\d{2}'), '')}',
                      textColor: const Color(0xFFB45309),
                      bgColor: const Color(0xFFFEF3C7),
                      darkTextColor: const Color(0xFFFBBF24),
                      darkBgColor: const Color(0xFF2C220E),
                      isDark: Theme.of(context).brightness == Brightness.dark,
                    ),
                    _buildBadge(
                      label:
                          '${isArabic ? 'المتبقي' : 'Remaining'}: ${remaining.replaceAll(RegExp(r'\.\d{2}'), '')}',
                      textColor: const Color(0xFF0F766E),
                      bgColor: const Color(0xFFCCFBF1),
                      darkTextColor: const Color(0xFF99F6E4),
                      darkBgColor: const Color(0xFF042F2E),
                      isDark: Theme.of(context).brightness == Brightness.dark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required Color textColor,
    required Color bgColor,
    required Color darkTextColor,
    required Color darkBgColor,
    required bool isDark,
  }) {
    final resolvedTextColor = isDark ? darkTextColor : textColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? darkBgColor : bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: resolvedTextColor.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: resolvedTextColor,
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
          padding: const EdgeInsets.all(10.0),
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
                radius: 22,
                child: Icon(
                  _cashCategoryIcon(tx.category),
                  color: isExpense
                      ? const Color(0xFFBE123C)
                      : const Color(0xFF047857),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
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
    final double unpaidLiabilityEgp = asset.installmentPlan.isNotEmpty
        ? asset.installmentPlan.where((item) => item['isPaid'] != true).fold(
            0.0,
            (sum, item) {
              final String itemCurrency =
                  (item['currency']?.toString().isNotEmpty == true)
                  ? item['currency'].toString()
                  : asset.currency;
              final double amount = ((item['amount'] ?? 0) as num).toDouble();
              return sum +
                  ZakatEngineService.convertToEgp(amount, itemCurrency, market);
            },
          )
        : ZakatEngineService.convertToEgp(
            asset.loanBalance,
            asset.currency,
            market,
          );
    final double unpaidLiabilityMain = ZakatEngineService.convertFromEgp(
      unpaidLiabilityEgp,
      mainCurrency,
      market,
    );
    final double share = 1.0;
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

    final String type = ZakatEngineService.normaliseInvestmentType(
      asset.investmentType,
    );
    final String formattedValue = type == 'liability'
        ? '-${ZakatEngineService.formatCurrency(unpaidLiabilityMain, mainCurrency, isArabic: isArabic)}'
        : ZakatEngineService.formatCurrency(
            grossValueInMainCurrency,
            mainCurrency,
            isArabic: isArabic,
          );

    double paidInstallmentsInAssetCurrency = 0.0;
    for (final Map<String, dynamic> item in asset.installmentPlan) {
      if (item['isPaid'] == true) {
        final String itemCurrency =
            (item['currency']?.toString().isNotEmpty == true)
            ? item['currency'].toString()
            : asset.currency;
        final double amount = ((item['amount'] ?? 0) as num).toDouble();
        if (itemCurrency == asset.currency) {
          paidInstallmentsInAssetCurrency += amount;
        } else {
          final double amountEgp = ZakatEngineService.convertToEgp(
            amount,
            itemCurrency,
            market,
          );
          paidInstallmentsInAssetCurrency += ZakatEngineService.convertFromEgp(
            amountEgp,
            asset.currency,
            market,
          );
        }
      }
    }
    final double initialPaid = asset.paidAmount >= 0 ? asset.paidAmount : 0.0;
    final double totalPaidAssetCurrency =
        initialPaid + paidInstallmentsInAssetCurrency;

    final double totalPaidEgp = ZakatEngineService.convertToEgp(
      totalPaidAssetCurrency,
      asset.currency,
      market,
    );
    final double totalPaidMain = ZakatEngineService.convertFromEgp(
      totalPaidEgp,
      mainCurrency,
      market,
    );
    final String paidValueFormatted = ZakatEngineService.formatCurrency(
      totalPaidMain,
      mainCurrency,
      isArabic: isArabic,
    );

    final String displayTitle = asset.location.isNotEmpty
        ? asset.location
        : (type == 'company_investment'
              ? context.l10n.tr('company_shares')
              : (type == 'car'
                    ? (context.l10n.tr('car') ?? 'Car')
                    : (type == 'liability'
                          ? (context.l10n.tr('liability') ?? 'Liability / Loan')
                          : context.l10n.tr('property'))));

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
          padding: const EdgeInsets.all(10.0),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AddInvestmentScreen(initialInvestment: asset),
              ),
            );
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color:
                      (type == 'company_investment'
                              ? const Color(0xFF10B981)
                              : (type == 'car'
                                    ? const Color(0xFF0284C7)
                                    : (type == 'liability'
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFFD97706))))
                          .withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  type == 'company_investment'
                      ? Icons.pie_chart_rounded
                      : (type == 'car'
                            ? Icons.directions_car_outlined
                            : (type == 'liability'
                                  ? Icons.payment_outlined
                                  : Icons.home_work_rounded)),
                  color: type == 'company_investment'
                      ? const Color(0xFF10B981)
                      : (type == 'car'
                            ? const Color(0xFF0284C7)
                            : (type == 'liability'
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFD97706))),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w700,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : const Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formattedValue,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: type == 'liability'
                                ? (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFF87171)
                                      : const Color(0xFFB91C1C))
                                : (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFF065F46)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          '${asset.valuationDate}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFA3B8B5)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                        if (asset.paidAmount >= 0 ||
                            paidInstallmentsInAssetCurrency > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF042F2E)
                                  : const Color(0xFF0F766E),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(
                                        0xFF99F6E4,
                                      ).withValues(alpha: 0.25)
                                    : Colors.transparent,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              isArabic
                                  ? 'مدفوع: $paidValueFormatted'
                                  : 'Paid: $paidValueFormatted',
                              style: TextStyle(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF99F6E4)
                                    : Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (unpaidLiabilityMain > 0) ...[
                      const SizedBox(height: 6),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showInstallmentSchedule(
                            context,
                            asset,
                            mainCurrency,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          child: Ink(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
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
                                  size: 12,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    isArabic
                                        ? 'الأقساط: ${ZakatEngineService.formatCurrency(unpaidLiabilityMain, mainCurrency, isArabic: isArabic)} متبقية'
                                        : 'Installments: ${ZakatEngineService.formatCurrency(unpaidLiabilityMain, mainCurrency, isArabic: isArabic)} remaining',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFFFC928),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Color(0xFFFFC928),
                                  size: 9,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        content: CompactDropdownFormField<String>(
          value: selected,
          labelText: context.l10n.tr('select_payment_category'),
          items: categories,
          itemLabel: ctx.l10n.translateCategory,
          onChanged: (String v) => selected = v,
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

  void _showInstallmentSchedule(
    BuildContext context,
    InvestmentAsset asset,
    String mainCurrency,
  ) {
    final tokens = context.premiumTokens;
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final AppStateController controller = context.read<AppStateController>();
    final MarketData market = MarketData.fromJson(controller.state.marketData);

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
            final double unpaidLiabilityEgp =
                latestAsset.installmentPlan.isNotEmpty
                ? latestAsset.installmentPlan
                      .where((item) => item['isPaid'] != true)
                      .fold(0.0, (sum, item) {
                        final String itemCurrency =
                            (item['currency']?.toString().isNotEmpty == true)
                            ? item['currency'].toString()
                            : latestAsset.currency;
                        final double amount = ((item['amount'] ?? 0) as num)
                            .toDouble();
                        return sum +
                            ZakatEngineService.convertToEgp(
                              amount,
                              itemCurrency,
                              market,
                            );
                      })
                : ZakatEngineService.convertToEgp(
                    latestAsset.loanBalance,
                    latestAsset.currency,
                    market,
                  );
            final double unpaidLiabilityMain =
                ZakatEngineService.convertFromEgp(
                  unpaidLiabilityEgp,
                  mainCurrency,
                  market,
                );

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
                        isArabic
                            ? 'جدول الأقساط - ${latestAsset.location}'
                            : 'Installment Schedule - ${latestAsset.location}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: tokens.colors.textPrimary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isArabic
                            ? 'الالتزامات المتبقية: ${ZakatEngineService.formatCurrency(unpaidLiabilityMain, mainCurrency, isArabic: isArabic)}'
                            : 'Remaining Liability: ${ZakatEngineService.formatCurrency(unpaidLiabilityMain, mainCurrency, isArabic: isArabic)}',
                        style: TextStyle(
                          color: tokens.colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: plan.isEmpty
                            ? Center(
                                child: Text(
                                  isArabic
                                      ? 'لا توجد أقساط مجدولة.'
                                      : 'No installments scheduled.',
                                ),
                              )
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
                                              final List<Map<String, dynamic>>
                                              sortedPlan =
                                                  InvestmentAsset.sortInstallmentPlan(
                                                    updatedPlan,
                                                  );

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
                                                installmentPlan: sortedPlan,
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
                                                yearlyGrowthRate: latestAsset
                                                    .yearlyGrowthRate,
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
                                            if (isPaid)
                                              TextButton(
                                                key: Key(
                                                  'toggleInstallmentPaid_${latestAsset.id}_$index',
                                                ),
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
                                                  foregroundColor: Colors.grey,
                                                ),
                                                onPressed: () async {
                                                  await controller
                                                      .toggleInstallmentPaid(
                                                        assetId: latestAsset.id,
                                                        installmentIndex: index,
                                                        paymentCategory: '',
                                                      );
                                                  setModalState(() {});
                                                  setState(() {});
                                                },
                                                child: Text(
                                                  context.l10n.tr(
                                                    'mark_as_unpaid',
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              )
                                            else
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                alignment: WrapAlignment.end,
                                                children: <Widget>[
                                                  TextButton(
                                                    key: Key(
                                                      'markInstallmentPaid_${latestAsset.id}_$index',
                                                    ),
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
                                                      foregroundColor:
                                                          tokens.colors.emerald,
                                                    ),
                                                    onPressed: () async {
                                                      await controller
                                                          .markInstallmentPaid(
                                                            assetId:
                                                                latestAsset.id,
                                                            installmentIndex:
                                                                index,
                                                          );
                                                      setModalState(() {});
                                                      setState(() {});
                                                    },
                                                    child: Text(
                                                      context.l10n.tr(
                                                        'mark_as_paid',
                                                      ),
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                  TextButton(
                                                    key: Key(
                                                      'toggleInstallmentPaid_${latestAsset.id}_$index',
                                                    ),
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
                                                      foregroundColor:
                                                          tokens.colors.gold,
                                                    ),
                                                    onPressed: () async {
                                                      try {
                                                        final List<String>
                                                        expenseCategories =
                                                            controller
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
                                                              .payInstallment(
                                                                assetId:
                                                                    latestAsset
                                                                        .id,
                                                                installmentIndex:
                                                                    index,
                                                                paymentCategory:
                                                                    category,
                                                              );
                                                        } else {
                                                          return;
                                                        }
                                                      } on StateError catch (
                                                        error
                                                      ) {
                                                        if (!context.mounted) {
                                                          return;
                                                        }
                                                        showTopSnackBar(
                                                          context,
                                                          error.message,
                                                        );
                                                        return;
                                                      }
                                                      setModalState(() {});
                                                      setState(() {});
                                                    },
                                                    child: Text(
                                                      context.l10n.tr('pay'),
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
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

  void _navigateToAdd(BuildContext context) {
    if (widget.categoryType == 'cash') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const AddTransactionScreen(cashMode: true),
        ),
      );
    } else if (widget.categoryType == 'gold' ||
        widget.categoryType == 'silver') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              AddSavingScreen(initialAssetType: widget.categoryType),
        ),
      );
    } else if (widget.categoryType == 'investments' ||
        widget.categoryType == 'property' ||
        widget.categoryType == 'other_assets' ||
        widget.categoryType == 'liabilities') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AddInvestmentScreen(
            initialAssetType: widget.categoryType == 'investments'
                ? 'company_share'
                : (widget.categoryType == 'liabilities'
                    ? 'liability'
                    : (widget.categoryType == 'other_assets'
                        ? 'car'
                        : 'property')),
          ),
        ),
      );
    }
  }
}
