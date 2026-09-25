import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../models/credit_card.dart';
import '../../models/transaction.dart';
import '../../services/app_state_controller.dart';
import 'edit_credit_card_screen.dart';

class CreditCardDetailsScreen extends StatelessWidget {
  const CreditCardDetailsScreen({
    super.key,
    required this.cardId,
    this.initialCard,
  });

  final String cardId;
  final CreditCard? initialCard;

  static const Map<String, List<Color>> _themes = <String, List<Color>>{
    'emerald': <Color>[Color(0xFF0B6B58), Color(0xFF032F29)],
    'obsidian': <Color>[Color(0xFF30343B), Color(0xFF0D0F12)],
    'graphite': <Color>[Color(0xFF62666D), Color(0xFF25272B)],
    'gold': <Color>[Color(0xFFB88A2E), Color(0xFF49300B)],
    'sapphire': <Color>[Color(0xFF1769AA), Color(0xFF08233F)],
    'ruby': <Color>[Color(0xFFB52A43), Color(0xFF420F1B)],
    'platinum': <Color>[Color(0xFFB8C1C9), Color(0xFF4A525A)],
    'copper': <Color>[Color(0xFFB86B45), Color(0xFF4A2418)],
  };

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  String _reminderOffsetLabel(int days, BuildContext context) {
    switch (days) {
      case 0:
        return context.l10n.tr('on_due_date');
      case 1:
        return context.l10n.tr('1_day_before');
      case 2:
        return context.l10n.tr('2_days_before');
      case 3:
        return context.l10n.tr('3_days_before');
      case 5:
        return context.l10n.tr('5_days_before');
      case 7:
        return context.l10n.tr('7_days_before');
      default:
        return '$days days before';
    }
  }

  @override
  Widget build(BuildContext context) {
    final CreditCard? liveCard = context
        .select<AppStateController, CreditCard?>(
          (AppStateController c) => c.state.creditCards
              .where((CreditCard item) => item.id == cardId && !item.isArchived)
              .firstOrNull,
        );
    final CreditCard? card = liveCard ?? initialCard;

    final tokens = context.premiumTokens;
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

    if (card == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.tr('card_details'))),
        body: const Center(child: Text('Card not found')),
      );
    }

    final CreditCard? parentCard = card.parentCardId == null
        ? null
        : context
              .read<AppStateController>()
              .state
              .creditCards
              .where((CreditCard item) => item.id == card.parentCardId)
              .firstOrNull;

    final List<Color> colors = _themes[card.themeId] ?? _themes['emerald']!;
    final double util = card.utilization;

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        title: Text(context.l10n.tr('card_details')),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: context.l10n.tr('edit'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EditCreditCardScreen(card: card),
              ),
            ),
          ),
        ],
      ),
      body: RepaintBoundary(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              ResponsiveLayout.compactHorizontalPadding(context),
              16,
              ResponsiveLayout.compactHorizontalPadding(context),
              MediaQuery.paddingOf(context).bottom + 48,
            ),
            children: <Widget>[
              // Card Preview with RepaintBoundary
              RepaintBoundary(
                child: Container(
                  height: 210,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colors,
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            card.bankName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            card.network.displayName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (card.cardNickname.isNotEmpty)
                        Text(
                          card.cardNickname,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      const Spacer(),
                      Text(
                        '•••• ${card.last4Digits}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          letterSpacing: 2.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            'Limit: ${ZakatEngineService.formatCurrency(card.creditLimit, card.currency, isArabic: isArabic)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Owed: ${ZakatEngineService.formatCurrency(card.openingBalance, card.currency, isArabic: isArabic)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (parentCard != null) ...[
                PremiumCard(
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.account_tree_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Supplementary card of ${parentCard.bankName} •••• ${parentCard.last4Digits}. '
                          'Limit and owed balance are shared.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Financial Metrics
              _buildSectionHeader(
                context,
                context.l10n.tr('financial_details'),
              ),
              PremiumCard(
                child: Column(
                  children: <Widget>[
                    _metricRow(
                      context,
                      label: context.l10n.tr('current_balance_owed'),
                      value: ZakatEngineService.formatCurrency(
                        card.openingBalance,
                        card.currency,
                        isArabic: isArabic,
                      ),
                      isBold: true,
                      valueColor: Colors.redAccent,
                    ),
                    _divider(context),
                    _metricRow(
                      context,
                      label: context.l10n.tr('credit_limit'),
                      value: ZakatEngineService.formatCurrency(
                        card.creditLimit,
                        card.currency,
                        isArabic: isArabic,
                      ),
                    ),
                    _divider(context),
                    _metricRow(
                      context,
                      label: context.l10n.tr('available_credit'),
                      value: ZakatEngineService.formatCurrency(
                        card.availableCredit,
                        card.currency,
                        isArabic: isArabic,
                      ),
                      valueColor: Colors.greenAccent,
                    ),
                    _divider(context),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              context.l10n.tr('utilization'),
                              style: TextStyle(
                                color: tokens.colors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${util.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: util > 70
                                    ? Colors.redAccent
                                    : (util > 30
                                          ? Colors.amber
                                          : Colors.greenAccent),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (util / 100).clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: tokens.colors.surface,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              util > 70
                                  ? Colors.redAccent
                                  : (util > 30
                                        ? Colors.amber
                                        : Colors.greenAccent),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (card.minimumPaymentAmount != null &&
                        card.minimumPaymentAmount! > 0) ...[
                      _divider(context),
                      _metricRow(
                        context,
                        label: context.l10n.tr('minimum_payment_due'),
                        value: ZakatEngineService.formatCurrency(
                          card.minimumPaymentAmount!,
                          card.currency,
                          isArabic: isArabic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Billing Cycle
              _buildSectionHeader(context, context.l10n.tr('billing_cycle')),
              PremiumCard(
                child: Column(
                  children: <Widget>[
                    _metricRow(
                      context,
                      label: context.l10n.tr('statement_day'),
                      value: card.statementDay != null
                          ? 'Day ${card.statementDay} of month'
                          : 'Not specified',
                    ),
                    _divider(context),
                    _metricRow(
                      context,
                      label: context.l10n.tr('payment_due_day'),
                      value: card.paymentDueDay != null
                          ? 'Day ${card.paymentDueDay} of month'
                          : 'Not specified',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Payment Reminder
              _buildSectionHeader(context, context.l10n.tr('payment_reminder')),
              PremiumCard(
                child: Column(
                  children: <Widget>[
                    _metricRow(
                      context,
                      label: context.l10n.tr('payment_reminder'),
                      value: card.paymentReminderEnabled
                          ? 'Active'
                          : 'Disabled',
                      valueColor: card.paymentReminderEnabled
                          ? Colors.greenAccent
                          : null,
                    ),
                    if (card.paymentReminderEnabled) ...[
                      _divider(context),
                      _metricRow(
                        context,
                        label: context.l10n.tr('remind_me'),
                        value: _reminderOffsetLabel(
                          card.reminderDaysBefore,
                          context,
                        ),
                      ),
                      _divider(context),
                      _metricRow(
                        context,
                        label: context.l10n.tr('reminder_time'),
                        value: _formatTime(
                          card.reminderTimeHour,
                          card.reminderTimeMinute,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if ((card.expiryMonth != null && card.expiryYear != null) ||
                  card.notes.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildSectionHeader(
                  context,
                  context.l10n.tr('optional_details'),
                ),
                PremiumCard(
                  child: Column(
                    children: <Widget>[
                      if (card.expiryMonth != null &&
                          card.expiryYear != null) ...[
                        _metricRow(
                          context,
                          label: context.l10n.tr('expiry_date'),
                          value:
                              '${card.expiryMonth.toString().padLeft(2, '0')}/${card.expiryYear}',
                        ),
                      ],
                      if (card.notes.isNotEmpty) ...[
                        if (card.expiryMonth != null && card.expiryYear != null)
                          _divider(context),
                        _metricRow(
                          context,
                          label: context.l10n.tr('notes'),
                          value: card.notes,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),

              // Actions
              FilledButton.icon(
                onPressed: () => _showPayCard(context, card),
                icon: const Icon(Icons.payments_outlined),
                label: Text(context.l10n.tr('pay_credit_card')),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EditCreditCardScreen(card: card),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: Text(context.l10n.tr('edit_credit_card')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: context.premiumTokens.colors.border.withValues(alpha: 0.25),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final tokens = context.premiumTokens;
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: tokens.colors.gold,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _metricRow(
    BuildContext context, {
    required String label,
    required String value,
    bool isBold = false,
    Color? valueColor,
  }) {
    final tokens = context.premiumTokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(color: tokens.colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: 14,
              color: valueColor ?? tokens.colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showPayCard(BuildContext context, CreditCard card) async {
    final TextEditingController amountController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    String paymentMode = 'transfer';

    final double? paymentAmount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setSheetState,
              ) {
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          '${context.l10n.tr('pay_credit_card')} - ${card.bankName}',
                          style: Theme.of(sheetContext).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText:
                                '${context.l10n.tr('payment_amount')} (${card.currency})',
                            hintText: '0.00',
                          ),
                          validator: (value) {
                            final amount = double.tryParse(value ?? '') ?? 0;
                            return amount > 0
                                ? null
                                : context.l10n.tr('amount_gt_zero');
                          },
                        ),
                        const SizedBox(height: 20),
                        SegmentedButton<String>(
                          segments: <ButtonSegment<String>>[
                            ButtonSegment<String>(
                              value: 'transfer',
                              label: Text(context.l10n.tr('transfer')),
                            ),
                            ButtonSegment<String>(
                              value: 'expense',
                              label: Text(context.l10n.tr('expense')),
                            ),
                          ],
                          selected: <String>{paymentMode},
                          onSelectionChanged: (Set<String> selected) {
                            setSheetState(() => paymentMode = selected.first);
                          },
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;
                            Navigator.of(
                              sheetContext,
                            ).pop(double.parse(amountController.text));
                          },
                          child: Text(context.l10n.tr('payment')),
                        ),
                      ],
                    ),
                  ),
                );
              },
        );
      },
    );

    if (paymentAmount != null && paymentAmount > 0 && context.mounted) {
      final now = DateTime.now();
      final String dateIso =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final bool addAsExpense = paymentMode == 'expense';

      await context.read<AppStateController>().addTransaction(
        Transaction(
          id: const Uuid().v4(),
          type: addAsExpense ? 'expense' : 'transfer',
          date: dateIso,
          amount: paymentAmount,
          currency: card.currency,
          category: 'Credit Card Payment',
          description: 'Payment for ${card.bankName} •••• ${card.last4Digits}',
          createdAt: now.toUtc().toIso8601String(),
          rolledOver: false,
          creditCardPaymentId: addAsExpense ? card.id : null,
          transferSourceId: addAsExpense ? null : 'cash',
          transferDestinationId: addAsExpense ? null : card.id,
          activityType: addAsExpense ? null : 'transfer',
        ),
      );
    }
  }
}
