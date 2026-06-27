import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/currency_dropdown_form_field.dart';
import '../../core/utils/amount_parser.dart';
import '../../models/currency_exchange_edit_request.dart';
import '../../services/app_state_controller.dart';

class CurrencyExchangeScreen extends StatefulWidget {
  const CurrencyExchangeScreen({
    super.key,
    this.initialItem,
    this.initialActivityId,
  });

  final dynamic initialItem;
  final String? initialActivityId;

  bool get isEditMode => initialItem != null || initialActivityId != null;

  @override
  State<CurrencyExchangeScreen> createState() => _CurrencyExchangeScreenState();
}

class _CurrencyExchangeScreenState extends State<CurrencyExchangeScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _sourceAmountController = TextEditingController();
  final TextEditingController _targetAmountController = TextEditingController();

  late String _sourceCurrency;
  late String _targetCurrency;
  late DateTime _selectedDate;
  CurrencyExchangeEditRequest? _editRequest;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final AppStateController controller = context.read<AppStateController>();

    final CurrencyExchangeEditRequest? editRequest =
        widget.initialActivityId != null && widget.initialActivityId!.trim().isNotEmpty
        ? resolveCurrencyExchangeEditRequestByActivityId(
            transactions: controller.state.transactions,
            savings: controller.state.savings,
            activityId: widget.initialActivityId!,
          )
        : (widget.initialItem != null)
        ? resolveCurrencyExchangeEditRequest(
            transactions: controller.state.transactions,
            savings: controller.state.savings,
            item: widget.initialItem!,
          )
        : null;

    _editRequest = editRequest;

    if (editRequest != null) {
      _sourceCurrency = editRequest.sourceCurrency;
      _targetCurrency = editRequest.targetCurrency;
      _selectedDate = DateTime.tryParse(editRequest.date) ?? DateTime.now();
      _sourceAmountController.text = editRequest.sourceAmount.toStringAsFixed(
        editRequest.sourceAmount.truncateToDouble() == editRequest.sourceAmount ? 0 : 2,
      );
      _targetAmountController.text = editRequest.targetAmount.toStringAsFixed(
        editRequest.targetAmount.truncateToDouble() == editRequest.targetAmount ? 0 : 2,
      );
    } else {
      String mainCurr = controller.state.mainCurrency;
      if (mainCurr.trim().isEmpty) mainCurr = 'EGP';
      _sourceCurrency = mainCurr;
      _targetCurrency = ZakatEngineService.supportedCurrencies.firstWhere(
        (String c) => c != _sourceCurrency,
        orElse: () => 'USD',
      );
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _sourceAmountController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppStateController controller = context.watch<AppStateController>();
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final double available = controller.getAvailableBalance(
      currency: _sourceCurrency,
      date: _dateIso(_selectedDate),
    ) + ((_editRequest != null && _sourceCurrency == _editRequest!.sourceCurrency)
        ? _editRequest!.sourceAmount
        : 0.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditMode
              ? (isArabic ? 'تعديل التحويل' : 'Edit Exchange')
              : context.l10n.tr('currency_exchange'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CurrencyDropdownFormField(
                  key: const Key('exchangeSourceCurrencyField'),
                  value: _sourceCurrency,
                  labelText: context.l10n.tr('source_currency'),
                  currencies: ZakatEngineService.supportedCurrencies,
                  onChanged: (String nextCurrency) {
                    setState(() {
                      if (nextCurrency == _targetCurrency) {
                        _targetCurrency = _sourceCurrency;
                      }
                      _sourceCurrency = nextCurrency;
                    });
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6.0, bottom: 2.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      isArabic
                          ? 'الرصيد المتاح: ${available.toStringAsFixed(2)} $_sourceCurrency'
                          : 'Available balance: ${available.toStringAsFixed(2)} $_sourceCurrency',
                      style: TextStyle(
                        color: available <= 0 ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                CurrencyDropdownFormField(
                  key: const Key('exchangeTargetCurrencyField'),
                  value: _targetCurrency,
                  labelText: context.l10n.tr('target_currency'),
                  currencies: ZakatEngineService.supportedCurrencies
                      .where((String currency) => currency != _sourceCurrency)
                      .toList(growable: false),
                  onChanged: (String nextCurrency) {
                    setState(() => _targetCurrency = nextCurrency);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('exchangeSourceAmountField'),
                  controller: _sourceAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('source_amount'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    final double sAmt = tryParseAmount(value) ?? 0;
                    if (sAmt <= 0) {
                      return context.l10n.tr('amount_gt_zero');
                    }
                    if (sAmt > available) {
                      return isArabic
                          ? 'المبلغ المدخل أكبر من الرصيد المتاح'
                          : 'Amount entered exceeds available balance';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('exchangeTargetAmountField'),
                  controller: _targetAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('target_amount'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    final double tAmt = tryParseAmount(value) ?? 0;
                    if (tAmt <= 0) {
                      return context.l10n.tr('amount_gt_zero');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.tr('date')),
                  subtitle: Text(_dateLabel(_selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: AppPrimaryButton(
                    key: const Key('saveExchangeButton'),
                    onPressed: _saving
                        ? null
                        : () async {
                            if (!(_formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            setState(() => _saving = true);

                            final double sAmount = tryParseAmount(_sourceAmountController.text) ?? 0;
                            final double tAmount = tryParseAmount(_targetAmountController.text) ?? 0;

                            try {
                              if (widget.isEditMode && _editRequest != null) {
                                await controller.updateCurrencyExchange(
                                  CurrencyExchangeEditRequest(
                                    oldActivityId: _editRequest!.oldActivityId,
                                    oldTargetSavingIds: _editRequest!.oldTargetSavingIds,
                                    oldSourceSavingDeductions: _editRequest!.oldSourceSavingDeductions,
                                    date: _dateIso(_selectedDate),
                                    sourceCurrency: _sourceCurrency,
                                    targetCurrency: _targetCurrency,
                                    sourceAmount: sAmount,
                                    targetAmount: tAmount,
                                  ),
                                );
                                if (!context.mounted) return;
                                showTopSnackBar(
                                  context,
                                  isArabic
                                      ? 'تم تعديل التحويل بنجاح'
                                      : 'Currency exchange updated successfully',
                                );
                              } else {
                                await controller.executeCurrencyExchange(
                                  date: _dateIso(_selectedDate),
                                  sourceCurrency: _sourceCurrency,
                                  targetCurrency: _targetCurrency,
                                  sourceAmount: sAmount,
                                  targetAmount: tAmount,
                                );
                                if (!context.mounted) return;
                                showTopSnackBar(
                                  context,
                                  isArabic
                                      ? 'تم إجراء عملية التحويل بنجاح'
                                      : 'Currency exchange completed successfully',
                                );
                              }
                              Navigator.of(context).pop();
                            } catch (e) {
                              setState(() => _saving = false);
                              if (!context.mounted) return;
                              showTopSnackBar(
                                context,
                                isArabic ? 'فشل العملية: $e' : 'Operation failed: $e',
                              );
                            }
                          },
                    label: _saving
                        ? context.l10n.tr('saving_progress')
                        : context.l10n.tr('save'),
                    icon: Icons.check,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _dateIso(DateTime date) {
    final String y = date.year.toString();
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _dateLabel(DateTime date) {
    return _dateIso(date);
  }
}
