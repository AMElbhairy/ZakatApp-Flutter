// ignore_for_file: avoid_print
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_localizations.dart';
import '../services/zakat_engine.dart';
import '../utils/amount_parser.dart';
import '../../models/currency_exchange_edit_request.dart';
import '../../models/transaction.dart';
import '../../models/saving.dart';
import '../../services/app_state_controller.dart';
import 'app_ui.dart';
import 'currency_dropdown_form_field.dart';

Future<void> openEditCurrencyExchangeDialog(
  BuildContext context,
  dynamic item,
  {String? activityId}
) async {
  final AppStateController controller = context.read<AppStateController>();
  final CurrencyExchangeEditRequest? editRequest =
      activityId != null && activityId.trim().isNotEmpty
      ? resolveCurrencyExchangeEditRequestByActivityId(
          transactions: controller.state.transactions,
          savings: controller.state.savings,
          activityId: activityId,
        )
      : (item is Transaction || item is Saving)
      ? resolveCurrencyExchangeEditRequest(
          transactions: controller.state.transactions,
          savings: controller.state.savings,
          item: item,
        )
      : null;
  if (kDebugMode) {
    print(
      '[ExchangeDebug][openEditDialog] item=${item.runtimeType} '
      'activityId=$activityId '
      'resolved=${editRequest != null} '
      'txId=${item is Transaction ? item.id : null} '
      'txPair=${item is Transaction ? item.exchangePairId : null} '
      'savingId=${item is Saving ? item.id : null} '
      'savingActivity=${item is Saving ? item.transferActivityId : null}',
    );
  }
  if (editRequest == null) return;

  final String initSourceCurrency = editRequest.sourceCurrency;
  final String initTargetCurrency = editRequest.targetCurrency;
  final double initSourceAmount = editRequest.sourceAmount;
  final double initTargetAmount = editRequest.targetAmount;
  final String initDate = editRequest.date;

  final TextEditingController sourceAmountController = TextEditingController(
    text: initSourceAmount.toStringAsFixed(
      initSourceAmount.truncateToDouble() == initSourceAmount ? 0 : 2,
    ),
  );
  final TextEditingController targetAmountController = TextEditingController(
    text: initTargetAmount.toStringAsFixed(
      initTargetAmount.truncateToDouble() == initTargetAmount ? 0 : 2,
    ),
  );
  String sourceCurrency = initSourceCurrency;
  String targetCurrency = initTargetCurrency;
  String date = initDate;

  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => StatefulBuilder(
      builder: (BuildContext ctx, void Function(void Function()) setDialogState) {
        double available = controller.getAvailableBalance(
          currency: sourceCurrency,
        );
        if (sourceCurrency == initSourceCurrency) {
          available += initSourceAmount;
        }

        return AlertDialog(
          title: Text(context.l10n.tr('currency_exchange')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CurrencyDropdownFormField(
                  key: const Key('exchangeSourceCurrencyField'),
                  value: sourceCurrency,
                  labelText: context.l10n.tr('source_currency'),
                  currencies: ZakatEngineService.supportedCurrencies,
                  onChanged: (String nextCurrency) {
                    setDialogState(() {
                      if (nextCurrency == targetCurrency) {
                        targetCurrency = sourceCurrency;
                      }
                      sourceCurrency = nextCurrency;
                    });
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6.0, bottom: 2.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      Localizations.localeOf(context).languageCode == 'ar'
                          ? 'الرصيد المتاح: ${available.toStringAsFixed(2)} $sourceCurrency'
                          : 'Available balance: ${available.toStringAsFixed(2)} $sourceCurrency',
                      style: TextStyle(
                        color: available <= 0 ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                CurrencyDropdownFormField(
                  key: const Key('exchangeTargetCurrencyField'),
                  value: targetCurrency,
                  labelText: context.l10n.tr('target_currency'),
                  currencies: ZakatEngineService.supportedCurrencies
                      .where((String currency) => currency != sourceCurrency)
                      .toList(growable: false),
                  onChanged: (String nextCurrency) {
                    setDialogState(() => targetCurrency = nextCurrency);
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: sourceAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('source_amount'),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: targetAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('target_amount'),
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
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.tr('cancel')),
            ),
            FilledButton(
              onPressed: () {
                final double sAmt =
                    tryParseAmount(sourceAmountController.text) ?? 0;
                final double tAmt =
                    tryParseAmount(targetAmountController.text) ?? 0;
                if (sAmt <= 0 || tAmt <= 0 || sAmt > available) {
                  showTopSnackBar(
                    context,
                    Localizations.localeOf(context).languageCode == 'ar'
                        ? 'مبلغ غير صالح أو يتجاوز الرصيد المتاح'
                        : 'Invalid amount or exceeds available balance',
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text(context.l10n.tr('save')),
            ),
          ],
        );
      },
    ),
  );

  if (ok != true || !context.mounted) return;

  final double sAmount = tryParseAmount(sourceAmountController.text) ?? 0;
  final double tAmount = tryParseAmount(targetAmountController.text) ?? 0;

  try {
    if (kDebugMode) {
      print(
        '[ExchangeDebug][submitEditDialog] activityId=${editRequest.oldActivityId} '
        'date=$date source=$sourceCurrency $sAmount target=$targetCurrency $tAmount',
      );
    }
    await controller.updateCurrencyExchange(
      CurrencyExchangeEditRequest(
        oldActivityId: editRequest.oldActivityId,
        oldTargetSavingIds: editRequest.oldTargetSavingIds,
        oldSourceSavingDeductions: editRequest.oldSourceSavingDeductions,
        date: date,
        sourceCurrency: sourceCurrency,
        targetCurrency: targetCurrency,
        sourceAmount: sAmount,
        targetAmount: tAmount,
      ),
    );
    if (context.mounted) {
      showTopSnackBar(
        context,
        Localizations.localeOf(context).languageCode == 'ar'
            ? 'تم تعديل التحويل بنجاح'
            : 'Currency exchange updated successfully',
      );
    }
  } catch (e) {
    if (context.mounted) {
      showTopSnackBar(
        context,
        Localizations.localeOf(context).languageCode == 'ar'
            ? 'فشل تعديل التحويل: $e'
            : 'Failed to update exchange: $e',
      );
    }
  }
}
