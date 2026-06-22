import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_localizations.dart';
import '../services/zakat_engine.dart';
import '../utils/amount_parser.dart';
import '../../models/transaction.dart';
import '../../models/saving.dart';
import '../../services/app_state_controller.dart';
import 'app_ui.dart';
import 'currency_dropdown_form_field.dart';

Future<void> openSellMetalDialog(
  BuildContext context, {
  Saving? saving,
  Transaction? editTransaction,
}) async {
  final AppStateController controller = context.read<AppStateController>();

  Saving? targetMetalSaving = saving;
  double originalWeightToSell = 0.0;
  bool initDepositIntoCash = true;
  String initSellingCurrency = 'EGP';
  String initTargetCashCurrency = 'EGP';
  double initSellingAmount = 0.0;
  double initWeightToSell = 0.0;
  String initDate = DateTime.now().toUtc().toIso8601String().split('T').first;
  String initNotes = '';

  if (editTransaction != null) {
    // Edit mode
    final String? savingId = editTransaction.exchangePairId;
    targetMetalSaving = controller.state.savings
        .where((Saving s) => s.id == savingId)
        .firstOrNull;
    if (targetMetalSaving == null) return;

    // Parse weight to sell from description
    final RegExp regex = RegExp(r'([0-9.]+)\s*g');
    final Match? match = regex.firstMatch(editTransaction.description);
    if (match != null) {
      originalWeightToSell = double.tryParse(match.group(1) ?? '') ?? 0.0;
    }
    initWeightToSell = originalWeightToSell;
    initSellingCurrency = editTransaction.currency;
    initSellingAmount = editTransaction.amount;
    initDate = editTransaction.date;

    // Check if there's a linked cash proceeds saving
    final Saving? linkedCash = controller.state.savings
        .where(
          (Saving s) =>
              s.transferActivityId == editTransaction.id &&
              s.assetType == 'cash',
        )
        .firstOrNull;
    if (linkedCash != null) {
      initDepositIntoCash = true;
      initTargetCashCurrency = linkedCash.unit;
      initNotes = linkedCash.description;
    } else {
      initDepositIntoCash = false;
    }
  }

  if (targetMetalSaving == null) return;
  final Saving metalSaving = targetMetalSaving;

  final double availableWeight = editTransaction != null
      ? metalSaving.remainingAmount + originalWeightToSell
      : metalSaving.remainingAmount;

  final TextEditingController weightController = TextEditingController(
    text: initWeightToSell > 0
        ? initWeightToSell.toStringAsFixed(
            initWeightToSell.truncateToDouble() == initWeightToSell ? 0 : 2,
          )
        : '',
  );
  final TextEditingController amountController = TextEditingController(
    text: initSellingAmount > 0
        ? initSellingAmount.toStringAsFixed(
            initSellingAmount.truncateToDouble() == initSellingAmount ? 0 : 2,
          )
        : '',
  );
  final TextEditingController notesController = TextEditingController(
    text: initNotes,
  );

  String sellingCurrency = initSellingCurrency;
  String targetCashCurrency = initTargetCashCurrency;
  bool depositIntoCash = initDepositIntoCash;
  String date = initDate;

  await showDialog<void>(
    context: context,
    builder: (BuildContext ctx) => StatefulBuilder(
      builder: (BuildContext ctx, void Function(void Function()) setDialogState) {
        final double weightToSell =
            tryParseAmount(weightController.text.trim()) ?? 0.0;
        final double sellingAmount =
            tryParseAmount(amountController.text.trim()) ?? 0.0;

        // Calculate Cost Basis & Gain/Loss for Live Preview
        double costBasis = 0.0;
        double gainLoss = 0.0;
        if (metalSaving.amount > 0 && weightToSell > 0) {
          costBasis =
              (metalSaving.purchaseAmount / metalSaving.amount) * weightToSell;
          gainLoss = sellingAmount - costBasis;
        }

        final String costBasisStr = ZakatEngineService.formatCurrency(
          costBasis,
          metalSaving.purchaseCurrency,
          isArabic: false,
        );
        final String gainLossStr = ZakatEngineService.formatCurrency(
          gainLoss,
          sellingCurrency,
          isArabic: false,
        );

        return AlertDialog(
          title: Text(
            metalSaving.assetType == 'gold'
                ? context.l10n.tr('sell_gold')
                : context.l10n.tr('sell_silver'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  initialValue: metalSaving.description.isNotEmpty
                      ? metalSaving.description
                      : (metalSaving.assetType == 'gold' ? 'Gold' : 'Silver'),
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'Asset'),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool stacked =
                        constraints.maxWidth < 360 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.15;
                    final Widget availableWeightField = TextFormField(
                      initialValue: '${availableWeight.toStringAsFixed(2)} g',
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Available Weight',
                      ),
                    );
                    final Widget sellAllButton = ElevatedButton(
                      onPressed: () {
                        setDialogState(() {
                          weightController.text = availableWeight
                              .toStringAsFixed(2);
                        });
                      },
                      child: Text(context.l10n.tr('sell_all')),
                    );

                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          availableWeightField,
                          const SizedBox(height: 8),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: sellAllButton,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: <Widget>[
                        Expanded(child: availableWeightField),
                        const SizedBox(width: 8),
                        sellAllButton,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('sellWeightField'),
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('weight_to_sell'),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 8),
                CurrencyDropdownFormField(
                  key: const Key('sellCurrencyField'),
                  value: sellingCurrency,
                  labelText: context.l10n.tr('selling_currency'),
                  currencies: ZakatEngineService.supportedCurrencies,
                  onChanged: (String nextCurrency) {
                    setDialogState(() {
                      sellingCurrency = nextCurrency;
                      if (depositIntoCash) {
                        targetCashCurrency = nextCurrency;
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('sellAmountField'),
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('selling_amount'),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),

                // Live Preview Card
                if (weightToSell > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Live Preview',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(context.l10n.tr('estimated_cost_basis')),
                            Text(
                              costBasisStr,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(context.l10n.tr('realized_gain_loss')),
                            Text(
                              (gainLoss >= 0 ? '+' : '') + gainLossStr,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: gainLoss >= 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),

                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: depositIntoCash,
                  title: Text(context.l10n.tr('deposit_into_cash')),
                  onChanged: (bool? value) {
                    setDialogState(() {
                      depositIntoCash = value ?? true;
                    });
                  },
                ),
                if (depositIntoCash)
                  CurrencyDropdownFormField(
                    value: targetCashCurrency,
                    labelText: context.l10n.tr('target_cash_currency'),
                    currencies: ZakatEngineService.supportedCurrencies,
                    onChanged: (String nextCurrency) {
                      setDialogState(() => targetCashCurrency = nextCurrency);
                    },
                  ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('notes'),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.tr('date')),
                  subtitle: Text(date),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.tryParse(date) ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        final String y = picked.year.toString();
                        final String m = picked.month.toString().padLeft(
                          2,
                          '0',
                        );
                        final String d = picked.day.toString().padLeft(2, '0');
                        date = '$y-$m-$d';
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.tr('cancel')),
            ),
            FilledButton(
              onPressed: () async {
                final double wSell =
                    tryParseAmount(weightController.text) ?? 0.0;
                final double sAmt =
                    tryParseAmount(amountController.text) ?? 0.0;

                if (wSell <= 0.0 || wSell - availableWeight > 0.005) {
                  showTopSnackBar(context, 'Invalid weight to sell');
                  return;
                }
                if (sAmt <= 0.0) {
                  showTopSnackBar(
                    context,
                    'Selling amount must be greater than zero',
                  );
                  return;
                }
                if (depositIntoCash && targetCashCurrency.trim().isEmpty) {
                  showTopSnackBar(context, 'Target cash currency is required');
                  return;
                }

                // Close Dialog
                Navigator.pop(ctx);

                // Run Save Logic
                final String activityId =
                    editTransaction?.id ??
                    'tx_${DateTime.now().millisecondsSinceEpoch}_sale';
                final String createdAt =
                    editTransaction?.createdAt ??
                    DateTime.now().toUtc().toIso8601String();

                // Compute realized gains/losses
                final double calcCostBasis = metalSaving.amount > 0
                    ? (metalSaving.purchaseAmount / metalSaving.amount) * wSell
                    : 0.0;
                final double calcRealizedGain = sAmt - calcCostBasis;

                final Transaction transferTx = Transaction(
                  id: activityId,
                  type: 'transfer',
                  date: date,
                  amount: sAmt,
                  currency: sellingCurrency,
                  category: metalSaving.assetType == 'gold'
                      ? 'Gold Sale'
                      : 'Silver Sale',
                  description:
                      '${wSell.toStringAsFixed(2)}g ${metalSaving.assetType == 'gold' ? 'Gold' : 'Silver'} -> $sellingCurrency ${sAmt.toStringAsFixed(2)}',
                  createdAt: createdAt,
                  rolledOver: false,
                  activityType: 'transfer',
                  exchangePairId: metalSaving.id,
                  costBasis: calcCostBasis,
                  saleValue: sAmt,
                  realizedGain: calcRealizedGain,
                  realizedGainLossCurrency: sellingCurrency,
                  metalQuantity: wSell,
                );

                Saving? cashSaving;
                if (depositIntoCash) {
                  String cashSavingId = 'sav_${DateTime.now().millisecondsSinceEpoch}_cash';
                  if (editTransaction != null) {
                    final Saving? existing = controller.state.savings
                        .where(
                          (s) =>
                              s.transferActivityId == activityId &&
                              s.assetType == 'cash',
                        )
                        .firstOrNull;
                    if (existing != null) {
                      cashSavingId = existing.id;
                    }
                  }
                  cashSaving = Saving(
                    id: cashSavingId,
                    assetType: 'cash',
                    dateAcquired: date,
                    amount: sAmt,
                    remainingAmount: sAmt,
                    unit: targetCashCurrency,
                    purchaseCurrency: sellingCurrency,
                    purchaseAmount: sAmt,
                    description: notesController.text.trim().isNotEmpty
                        ? notesController.text.trim()
                        : '${metalSaving.assetType == 'gold' ? 'Gold' : 'Silver'} Sale proceeds',
                    internalTransfer: true,
                    internalTransferType: 'precious_metals_sale',
                    createdAt: createdAt,
                    transferActivityId: activityId,
                  );
                }

                if (editTransaction != null) {
                  await controller.updateMetalSale(
                    oldTransactionId: activityId,
                    transaction: transferTx,
                    generatedTargetSaving: cashSaving,
                  );
                } else {
                  await controller.executeMetalSale(
                    transaction: transferTx,
                    generatedTargetSaving: cashSaving,
                  );
                }

                if (context.mounted) {
                  showTopSnackBar(
                    context,
                    editTransaction != null
                        ? 'Sale updated successfully'
                        : 'Sale recorded successfully',
                  );
                }
              },
              child: Text(context.l10n.tr('save')),
            ),
          ],
        );
      },
    ),
  );
}
