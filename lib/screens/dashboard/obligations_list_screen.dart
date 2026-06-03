import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/i18n/app_localizations.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/services/zakat_schedule_service.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/investment_asset.dart';
import '../../models/saving.dart';
import '../../models/transaction.dart';
import '../../services/app_state_controller.dart';

class ObligationsListScreen extends StatefulWidget {
  const ObligationsListScreen({
    super.key,
    required this.filterMode, // 'this_month', 'next_month', or 'total'
  });

  final String filterMode;

  @override
  State<ObligationsListScreen> createState() => _ObligationsListScreenState();
}

class _ObligationsListScreenState extends State<ObligationsListScreen> {
  static bool _isArabic(BuildContext context) {
    return Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
  }

  static String _formatDisplay(
    BuildContext context,
    double value,
    String currencyCode,
  ) {
    final String symbol = ZakatEngineService.getCurrencySymbol(
      currencyCode,
      isArabic: _isArabic(context),
    );
    final double absVal = value.abs();
    final String formatted = absVal == absVal.toInt()
        ? NumberFormat('#,###', 'en_US').format(absVal)
        : NumberFormat('#,##0.##', 'en_US').format(absVal);

    if (_isArabic(context)) {
      if (value < 0) {
        return '\u200E$symbol $formatted-';
      }
      return '\u200E$symbol $formatted';
    } else {
      if (value < 0) {
        return '\u200E$symbol -$formatted';
      }
      return '\u200E$symbol $formatted';
    }
  }

  static String _formatOrMissing(
    BuildContext context,
    double valueEgp,
    bool hasMarketData,
    String mainCurrency,
    MarketData marketData,
  ) {
    if (!hasMarketData) return context.l10n.tr('market_data_required');
    final String displayCurrency = mainCurrency.trim().isEmpty
        ? 'EGP'
        : mainCurrency.trim();
    final double displayValue = ZakatEngineService.convertFromEgp(
      valueEgp,
      displayCurrency,
      marketData,
    );
    if (displayValue.isNaN) return context.l10n.tr('market_data_required');
    return _formatDisplay(context, displayValue, displayCurrency);
  }

  static String _getAssetName(BuildContext context, InvestmentAsset asset) {
    if (asset.description.isNotEmpty) return asset.description;
    if (asset.location.isNotEmpty) return asset.location;
    return ZakatEngineService.isCompanyInvestmentType(asset.investmentType)
        ? context.l10n.tr('company_shares')
        : context.l10n.tr('property');
  }

  List<Map<String, dynamic>> _buildSchedule({
    required String zakatMethod,
    required String zakatAnnualDate,
    required List<Transaction> transactions,
    required List<Saving> savings,
    required List<InvestmentAsset> investments,
    required MarketData marketData,
  }) {
    if (zakatMethod == 'annual') {
      return ZakatScheduleService.calculateAnnualZakatSchedule(
        zakatAnnualDate: zakatAnnualDate,
        transactions: transactions
            .map((e) => e.toJson())
            .toList(growable: false),
        savings: savings.map((e) => e.toJson()).toList(growable: false),
        investments: investments.map((e) => e.toJson()).toList(growable: false),
        marketData: marketData,
      );
    }

    final List<Map<String, dynamic>> transactionJson = transactions
        .map((e) => e.toJson())
        .toList(growable: false);
    final List<Map<String, dynamic>> savingsJson = savings
        .map((e) => e.toJson())
        .toList(growable: false);

    final List<Map<String, dynamic>> monthly =
        ZakatScheduleService.calculateMonthlyZakatSchedule(
          transactions: transactionJson,
          savings: savingsJson,
          marketData: marketData,
        );
    final List<Map<String, dynamic>> savingsSchedule =
        ZakatScheduleService.calculateSavingsZakatSchedule(
          savings: savingsJson,
          transactions: transactionJson,
          marketData: marketData,
        );
    return <Map<String, dynamic>>[...monthly, ...savingsSchedule];
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
                    DropdownMenuItem<String>(value: c, child: Text(c)),
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

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final state = controller.state;
    final tokens = context.premiumTokens;

    final transactions = state.transactions;
    final savings = state.savings;
    final investments = state.investments;

    final market = MarketData.fromJson(state.marketData);
    final bool hasMarketData =
        market.goldPrice24kEgp > 0 && market.silverPriceEgp > 0;

    // Filter date keys
    final DateTime now = DateTime.now();
    final String thisMonthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final DateTime nextMonthDate = DateTime(now.year, now.month + 1, 1);
    final String nextMonthKey =
        '${nextMonthDate.year}-${nextMonthDate.month.toString().padLeft(2, '0')}';

    final List<Map<String, dynamic>> schedule = hasMarketData
        ? _buildSchedule(
            zakatMethod: state.zakatMethod,
            zakatAnnualDate: state.zakatAnnualDate,
            transactions: transactions,
            savings: savings,
            investments: investments,
            marketData: market,
          )
        : const <Map<String, dynamic>>[];

    // Extract all obligations
    final List<_ObligationItem> allItems = [];

    // 1. Zakat Obligations
    for (final row in schedule) {
      final String monthKey = (row['monthKey'] ?? '').toString();
      final double totalZakat = ((row['totalZakat'] ?? 0) as num).toDouble();
      final String paymentDate = (row['paymentDate'] ?? '').toString();
      final bool isPaid = state.zakatPaidMonths.contains(monthKey);

      allItems.add(
        _ObligationItem(
          id: monthKey,
          type: 'zakat',
          title: context.l10n.tr('obligation_type_zakat'),
          subtitle: monthKey,
          amountEgp: totalZakat,
          originalAmount: totalZakat,
          originalCurrency: 'EGP',
          dateStr: paymentDate,
          isPaid: isPaid,
          monthKey: monthKey,
        ),
      );
    }

    // 2. Installment Obligations
    for (final asset in investments) {
      for (int i = 0; i < asset.installmentPlan.length; i++) {
        final plan = asset.installmentPlan[i];
        final bool isPaid = plan['isPaid'] == true;
        final String rawDate = (plan['date'] ?? '').toString();
        final double amount = (plan['amount'] as num?)?.toDouble() ?? 0.0;
        final String currency = (plan['currency'] ?? asset.currency).toString();
        final double amountEgp = ZakatEngineService.convertToEgp(
          amount,
          currency,
          market,
        );

        allItems.add(
          _ObligationItem(
            id: asset.id,
            type: 'installment',
            title:
                '${context.l10n.tr('obligation_type_installment')} - ${_getAssetName(context, asset)}',
            subtitle: rawDate,
            amountEgp: amountEgp,
            originalAmount: amount,
            originalCurrency: currency,
            dateStr: rawDate,
            isPaid: isPaid,
            installmentIndex: i,
          ),
        );
      }
    }

    // Filter based on selected mode
    final List<_ObligationItem> filteredItems = allItems.where((item) {
      final String itemMonthKey =
          item.monthKey ??
          (() {
            final DateTime? parsed = DateTime.tryParse(item.dateStr);
            if (parsed == null) return '';
            return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}';
          })();

      if (widget.filterMode == 'this_month') {
        return itemMonthKey == thisMonthKey;
      } else if (widget.filterMode == 'next_month') {
        return itemMonthKey == nextMonthKey;
      } else {
        // total mode: shows both this month and next month obligations
        return itemMonthKey == thisMonthKey || itemMonthKey == nextMonthKey;
      }
    }).toList();

    // Sort by date (unpaid first, then sorted by date)
    filteredItems.sort((a, b) {
      if (a.isPaid != b.isPaid) {
        return a.isPaid ? 1 : -1;
      }
      return a.dateStr.compareTo(b.dateStr);
    });

    // Compute total unpaid for filter mode
    final double unpaidTotalEgp = filteredItems
        .where((item) => !item.isPaid)
        .fold(0.0, (sum, item) => sum + item.amountEgp);

    final String pageTitle = widget.filterMode == 'this_month'
        ? context.l10n.tr('obligations_this_month')
        : (widget.filterMode == 'next_month'
              ? context.l10n.tr('obligations_next_month')
              : context.l10n.tr('total_upcoming_obligations'));

    final String totalDisplay = _formatOrMissing(
      context,
      unpaidTotalEgp,
      hasMarketData,
      state.mainCurrency,
      market,
    );

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: tokens.colors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          pageTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: tokens.colors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 10),
              // Summary Banner Card
              PremiumCard(
                hero: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        context.l10n
                            .tr('total_upcoming_obligations')
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: Color(0xFFA3B8B5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        totalDisplay,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.tr('upcoming_obligations'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: filteredItems.isEmpty
                    ? Center(
                        child: EmptyStateCard(
                          icon: Icons.done_all_rounded,
                          title: context.l10n.tr('no_upcoming_obligations'),
                          message: context.l10n.tr('no_upcoming_obligations'),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredItems.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (BuildContext context, int index) {
                          final item = filteredItems[index];

                          final Widget leadingIcon = Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: item.isPaid
                                  ? Colors.grey.withValues(alpha: 0.12)
                                  : (item.type == 'zakat'
                                        ? const Color(
                                            0xFF10B981,
                                          ).withValues(alpha: 0.12)
                                        : const Color(
                                            0xFF3B82F6,
                                          ).withValues(alpha: 0.12)),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              item.type == 'zakat'
                                  ? Icons.mosque
                                  : Icons.credit_card_rounded,
                              size: 18,
                              color: item.isPaid
                                  ? Colors.grey
                                  : (item.type == 'zakat'
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF3B82F6)),
                            ),
                          );

                          final String amountDisplay = _formatDisplay(
                            context,
                            item.originalAmount,
                            item.originalCurrency,
                          );

                          // Display secondary EGP amount if original is not EGP
                          final String? egpEquivalent =
                              item.originalCurrency != 'EGP' && hasMarketData
                              ? '≈ ${ZakatEngineService.formatCurrency(item.amountEgp, 'EGP', isArabic: _isArabic(context))}'
                              : null;

                          return Opacity(
                            opacity: item.isPaid ? 0.55 : 1.0,
                            child: PremiumCard(
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: leadingIcon,
                                title: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: tokens.colors.textPrimary,
                                    decoration: item.isPaid
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                subtitle: Text(
                                  item.subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: tokens.colors.textSecondary,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          amountDisplay,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: tokens.colors.textPrimary,
                                            decoration: item.isPaid
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                        if (egpEquivalent != null)
                                          Text(
                                            egpEquivalent,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color:
                                                  tokens.colors.textSecondary,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      key: Key(
                                        'toggleObligation_${item.type}_${item.id}_$index',
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        foregroundColor: item.isPaid
                                            ? Colors.grey
                                            : tokens.colors.emerald,
                                      ),
                                      onPressed: () async {
                                        if (item.type == 'zakat') {
                                          await controller.toggleZakatPaid(
                                            monthKey: item.id,
                                            zakatAmountMainCurrency:
                                                item.amountEgp,
                                            paymentDate: item.dateStr,
                                          );
                                        } else {
                                          if (item.isPaid) {
                                            // Mark installment unpaid
                                            await controller
                                                .toggleInstallmentPaid(
                                                  assetId: item.id,
                                                  installmentIndex:
                                                      item.installmentIndex!,
                                                  paymentCategory: '',
                                                );
                                          } else {
                                            // Mark installment paid
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
                                                    assetId: item.id,
                                                    installmentIndex:
                                                        item.installmentIndex!,
                                                    paymentCategory: category,
                                                  );
                                            }
                                          }
                                        }
                                      },
                                      child: Text(
                                        item.isPaid
                                            ? context.l10n.tr('mark_as_unpaid')
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ObligationItem {
  _ObligationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.amountEgp,
    required this.originalAmount,
    required this.originalCurrency,
    required this.dateStr,
    required this.isPaid,
    this.monthKey,
    this.installmentIndex,
  });

  final String id;
  final String type;
  final String title;
  final String subtitle;
  final double amountEgp;
  final double originalAmount;
  final String originalCurrency;
  final String dateStr;
  final bool isPaid;
  final String? monthKey;
  final int? installmentIndex;
}
