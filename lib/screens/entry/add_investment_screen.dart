import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/sensitive_content_scope.dart';
import 'package:uuid/uuid.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/widgets/compact_dropdown.dart';
import '../../core/utils/currency_presentation.dart';
import '../../core/utils/amount_parser.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/investment_asset.dart';
import '../../services/app_state_controller.dart';

class AddInvestmentScreen extends StatefulWidget {
  const AddInvestmentScreen({
    super.key,
    this.initialInvestment,
    this.initialAssetType,
  });

  final InvestmentAsset? initialInvestment;
  final String? initialAssetType;

  bool get isEditMode => initialInvestment != null;

  @override
  State<AddInvestmentScreen> createState() => _AddInvestmentScreenState();
}

class _AddInvestmentScreenState extends State<AddInvestmentScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _currentValueController = TextEditingController();
  final TextEditingController _ownershipPctController = TextEditingController();
  final TextEditingController _purchasePriceController =
      TextEditingController();
  final TextEditingController _liabilityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _growthRateController = TextEditingController();
  final Uuid _uuid = const Uuid();

  late String _assetType;
  late String _currency;
  late DateTime _selectedDate;
  bool _saving = false;

  bool _showInstallmentConfig = false;
  late List<Map<String, dynamic>> _installmentPlan;
  final TextEditingController _numInstallmentsController =
      TextEditingController();
  final TextEditingController _totalInstallmentsAmountController =
      TextEditingController();
  final TextEditingController _oneByOneAmountController =
      TextEditingController();
  DateTime _oneByOneDate = DateTime.now();
  DateTime _autoStartDate = DateTime.now().add(const Duration(days: 30));
  String _autoFrequency = 'monthly';
  String _scheduleInputMode = 'auto';
  late String _oneByOneCurrency;
  late String _autoCurrency;

  double _calculateLiabilityFromInstallments(MarketData market) {
    double totalUnpaidInAssetCurrency = 0.0;
    for (final Map<String, dynamic> item in _installmentPlan) {
      if (item['isPaid'] == true) continue;
      final String itemCurrency = (item['currency']?.toString().isNotEmpty == true)
          ? item['currency'].toString()
          : _currency;
      final double amount = ((item['amount'] ?? 0) as num).toDouble();
      final double amountEgp = ZakatEngineService.convertToEgp(
        amount,
        itemCurrency,
        market,
      );
      final double inAssetCur = ZakatEngineService.convertFromEgp(
        amountEgp,
        _currency,
        market,
      );
      totalUnpaidInAssetCurrency += inAssetCur;
    }
    return double.parse(totalUnpaidInAssetCurrency.toStringAsFixed(2));
  }

  void _updateLiabilityFromInstallments(MarketData market) {
    final double totalUnpaid = _calculateLiabilityFromInstallments(market);
    _liabilityController.text = _fmt(totalUnpaid);
  }

  @override
  void initState() {
    super.initState();
    final InvestmentAsset? initial = widget.initialInvestment;
    final String defaultEntryCurrency = context
        .read<AppStateController>()
        .state
        .defaultEntryCurrency;
    _assetType = initial != null
        ? (ZakatEngineService.isCompanyInvestmentType(initial.investmentType)
            ? 'company_share'
            : 'property')
        : (widget.initialAssetType ?? 'property');
    _currency = initial?.currency.isNotEmpty == true
        ? initial!.currency
        : (defaultEntryCurrency.trim().isEmpty ? 'EGP' : defaultEntryCurrency);
    _selectedDate = _tryParseDate(initial?.valuationDate) ?? DateTime.now();
    _oneByOneCurrency = _currency;
    _autoCurrency = _currency;

    _installmentPlan = initial?.installmentPlan != null
        ? List<Map<String, dynamic>>.from(
            initial!.installmentPlan.map((e) => Map<String, dynamic>.from(e)),
          )
        : <Map<String, dynamic>>[];

    if (initial != null) {
      _nameController.text = initial.location;
      _currentValueController.text = _fmt(initial.marketValue);
      _ownershipPctController.text = _fmt(initial.ownershipSharePct);
      _purchasePriceController.text = _fmt(initial.originalPrice);
      _notesController.text = initial.description;
      _showInstallmentConfig = initial.loanBalance > 0;
      _growthRateController.text = initial.yearlyGrowthRate > 0 ? _fmt(initial.yearlyGrowthRate) : '';
    } else {
      _ownershipPctController.text = '100';
    }
    _purchasePriceController.addListener(_onGrowthInputsChanged);
    _growthRateController.addListener(_onGrowthInputsChanged);
    if (initial != null && initial.yearlyGrowthRate > 0 && initial.originalPrice > 0) {
      _calculateCurrentValue();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final controller = context.read<AppStateController>();
        final market = MarketData.fromJson(controller.state.marketData);
        _updateLiabilityFromInstallments(market);
      }
    });
  }

  void _calculateCurrentValue() {
    final double purchasePrice =
        tryParseAmount(_purchasePriceController.text) ?? 0;
    final double growthRate =
        tryParseAmount(_growthRateController.text) ?? 0;

    if (purchasePrice <= 0 || growthRate == 0) {
      return;
    }

    final DateTime valDate = _selectedDate;
    final DateTime today = DateTime.now();

    final int diffDays = today.difference(valDate).inDays;
    if (diffDays <= 0) {
      _currentValueController.text = _fmt(purchasePrice);
      return;
    }

    final double t = diffDays / 365.25;
    final double r = growthRate / 100.0;

    final double calculatedValue = purchasePrice * math.pow(1.0 + r, t);
    _currentValueController.text = _fmt(calculatedValue);
  }

  void _onGrowthInputsChanged() {
    _calculateCurrentValue();
  }

  void _showEditInstallmentDialog(int index) {
    final Map<String, dynamic> item = _installmentPlan[index];
    final TextEditingController amountController = TextEditingController(
      text: item['amount']?.toString() ?? '',
    );
    String selectedCurrency = item['currency'] ?? _currency;
    DateTime selectedDate =
        DateTime.tryParse(InvestmentAsset.installmentDueDate(item)) ??
            DateTime.now();

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final bool isArabic =
            Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter dialogSetState) {
            return AlertDialog(
              title: Text(
                isArabic
                    ? 'تعديل القسط #${index + 1}'
                    : 'Edit Installment #${index + 1}',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: context.l10n.tr('amount'),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CompactDropdownFormField<String>(
                      value: selectedCurrency,
                      labelText: context.l10n.tr('currency'),
                      items: ZakatEngineService.supportedCurrencies,
                      itemLabel: (String currency) =>
                          CurrencyPresentation.selectorLabel(
                            currency,
                            isRtl:
                                Localizations.localeOf(
                                  context,
                                ).languageCode.toLowerCase() == 'ar',
                          ),
                      onChanged: (String value) {
                        dialogSetState(() => selectedCurrency = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.tr('date')),
                      subtitle: Text(_dateIso(selectedDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          dialogSetState(() => selectedDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final double? amount = tryParseAmount(amountController.text);
                    if (amount == null || amount <= 0) {
                      showTopSnackBar(
                        context,
                        'Please enter a valid amount.',
                      );
                      return;
                    }
                    final controller = context.read<AppStateController>();
                    final market = MarketData.fromJson(controller.state.marketData);
                    setState(() {
                      _installmentPlan[index]['amount'] = amount;
                      _installmentPlan[index]['currency'] = selectedCurrency;
                      final String dateStr = _dateIso(selectedDate);
                      _installmentPlan[index]['date'] = dateStr;
                      _installmentPlan[index]['recurrenceDate'] = dateStr;
                      _updateLiabilityFromInstallments(market);
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _purchasePriceController.removeListener(_onGrowthInputsChanged);
    _growthRateController.removeListener(_onGrowthInputsChanged);
    _nameController.dispose();
    _currentValueController.dispose();
    _ownershipPctController.dispose();
    _purchasePriceController.dispose();
    _liabilityController.dispose();
    _notesController.dispose();
    _growthRateController.dispose();
    _numInstallmentsController.dispose();
    _totalInstallmentsAmountController.dispose();
    _oneByOneAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final String defaultEntryCurrency =
        context
            .watch<AppStateController>()
            .state
            .defaultEntryCurrency
            .trim()
            .isEmpty
        ? 'EGP'
        : context.watch<AppStateController>().state.defaultEntryCurrency;
    if (!widget.isEditMode &&
        _currency == 'EGP' &&
        defaultEntryCurrency != 'EGP') {
      _currency = defaultEntryCurrency;
    }
    return SensitiveContentScope(
      child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditMode
              ? context.l10n.tr('edit_investment_title')
              : context.l10n.tr('add_investment_title'),
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
                CompactDropdownFormField<String>(
                  key: const Key('investmentTypeField'),
                  value: _assetType,
                  labelText: context.l10n.tr('asset_type'),
                  items: const <String>['property', 'company_share'],
                  itemLabel: (String value) => switch (value) {
                    'property' => context.l10n.tr('property'),
                    'company_share' => context.l10n.tr('company_share'),
                    _ => value,
                  },
                  onChanged: (String value) {
                    setState(() => _assetType = value);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('investmentNameField'),
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('name'),
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if ((value ?? '').trim().isEmpty) {
                      return context.l10n.tr('name_required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('investmentPurchasePriceField'),
                  controller: _purchasePriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('purchase_price'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    final double v = tryParseAmount(value) ?? 0;
                    if (v <= 0) {
                      return context.l10n.tr('purchase_price_gt_zero');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CompactDropdownFormField<String>(
                  key: const Key('investmentCurrencyField'),
                  value: _currency,
                  labelText: context.l10n.tr('currency'),
                  items: ZakatEngineService.supportedCurrencies,
                  itemLabel: (String currency) =>
                      CurrencyPresentation.selectorLabel(
                        currency,
                        isRtl:
                            Localizations.localeOf(
                              context,
                            ).languageCode.toLowerCase() == 'ar',
                      ),
                  validator: (String? value) {
                    if ((value ?? '').isEmpty) {
                      return context.l10n.tr('currency_required');
                    }
                    return null;
                  },
                  onChanged: (String value) {
                    setState(() => _currency = value);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('investmentOwnershipField'),
                  controller: _ownershipPctController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('ownership_pct'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    final double pct =
                        tryParseAmount(value) ?? -1;
                    if (pct < 0 || pct > 100) {
                      return context.l10n.tr('ownership_pct_range');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('investmentCurrentValueField'),
                  controller: _currentValueController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('current_value_optional'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    final String trimmed = (value ?? '').trim();
                    if (trimmed.isEmpty) return null;
                    final double v = tryParseAmount(trimmed) ?? 0;
                    if (v < 0) {
                      return context.l10n.tr('current_value_negative');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('investmentGrowthRateField'),
                  controller: _growthRateController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('yearly_growth_rate'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  key: const Key('includeInstallmentsSwitch'),
                  title: Text(context.l10n.tr('include_installments')),
                  value: _showInstallmentConfig,
                  onChanged: (bool value) {
                    setState(() {
                      _showInstallmentConfig = value;
                      if (!value) {
                        _installmentPlan.clear();
                        _liabilityController.text = '0';
                      } else {
                        final controller = context.read<AppStateController>();
                        final market = MarketData.fromJson(controller.state.marketData);
                        _updateLiabilityFromInstallments(market);
                      }
                    });
                  },
                ),
                if (_showInstallmentConfig) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('investmentLiabilityField'),
                    controller: _liabilityController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: context.l10n.tr('remaining_liability_optional'),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Theme.of(context).disabledColor.withValues(alpha: 0.05),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.tr('installment_schedule'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (BuildContext ctx) {
                      final controller = context.read<AppStateController>();
                      final market = MarketData.fromJson(controller.state.marketData);
                      final double liability =
                          tryParseAmount(_liabilityController.text) ?? 0;

                      double scheduledTotal = 0.0;
                      for (final Map<String, dynamic> item in _installmentPlan) {
                        final String itemCurrency = (item['currency']?.toString().isNotEmpty == true)
                            ? item['currency'].toString()
                            : _currency;
                        final double amount = ((item['amount'] ?? 0) as num).toDouble();
                        final double amountEgp = ZakatEngineService.convertToEgp(
                          amount,
                          itemCurrency,
                          market,
                        );
                        final double inAssetCur = ZakatEngineService.convertFromEgp(
                          amountEgp,
                          _currency,
                          market,
                        );
                        scheduledTotal += inAssetCur;
                      }

                      final double remainingToSchedule =
                          (liability - scheduledTotal).clamp(0.0, double.infinity);
                      final String liabilityStr =
                          ZakatEngineService.formatCurrency(
                            liability,
                            _currency,
                            isArabic:
                                Localizations.localeOf(
                                  context,
                                ).languageCode.toLowerCase() ==
                                'ar',
                          );
                      final String scheduledTotalStr =
                          ZakatEngineService.formatCurrency(
                            scheduledTotal,
                            _currency,
                            isArabic:
                                Localizations.localeOf(
                                  context,
                                ).languageCode.toLowerCase() ==
                                'ar',
                          );
                      final String remainingToScheduleStr =
                          ZakatEngineService.formatCurrency(
                            remainingToSchedule,
                            _currency,
                            isArabic:
                                Localizations.localeOf(
                                  context,
                                ).languageCode.toLowerCase() ==
                                'ar',
                          );
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Liability:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  liabilityStr,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Scheduled:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  scheduledTotalStr,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Remaining to Schedule:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  remainingToScheduleStr,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: remainingToSchedule > 0.01
                                        ? Colors.orange
                                        : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text(context.l10n.tr('auto_generate'))),
                          selected: _scheduleInputMode == 'auto',
                          onSelected: (bool selected) {
                            if (selected) {
                              setState(() => _scheduleInputMode = 'auto');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text(context.l10n.tr('add_one_by_one'))),
                          selected: _scheduleInputMode == 'manual',
                          onSelected: (bool selected) {
                            if (selected) {
                              setState(() => _scheduleInputMode = 'manual');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_scheduleInputMode == 'auto') ...[
                    TextFormField(
                      controller: _numInstallmentsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.l10n.tr('number_of_installments'),
                        border: OutlineInputBorder(),
                        hintText: 'e.g. 12',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('investmentTotalInstallmentsAmountField'),
                      controller: _totalInstallmentsAmountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: context.l10n.tr('total_installments_amount'),
                        border: const OutlineInputBorder(),
                        hintText: 'e.g. 50000',
                      ),
                      validator: (String? value) {
                        if (_showInstallmentConfig &&
                            _scheduleInputMode == 'auto' &&
                            _installmentPlan.isEmpty) {
                          final double? amt = tryParseAmount(value);
                          if (amt == null || amt <= 0) {
                            return context.l10n.tr('total_installments_amount_required');
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    CompactDropdownFormField<String>(
                      key: const Key('investmentAutoCurrencyField'),
                      value: _autoCurrency,
                      labelText: context.l10n.tr('currency'),
                      items: ZakatEngineService.supportedCurrencies,
                      itemLabel: (String currency) =>
                          CurrencyPresentation.selectorLabel(
                            currency,
                            isRtl:
                                Localizations.localeOf(
                                  context,
                                ).languageCode.toLowerCase() == 'ar',
                          ),
                      onChanged: (String value) {
                        setState(() => _autoCurrency = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    CompactDropdownFormField<String>(
                      value: _autoFrequency,
                      labelText: context.l10n.tr('installment_frequency'),
                      items: const <String>['monthly', 'quarterly', 'yearly'],
                      itemLabel: (String value) => switch (value) {
                        'monthly' => isArabic ? 'شهري' : 'Monthly',
                        'quarterly' => isArabic ? 'ربع سنوي' : 'Quarterly',
                        'yearly' => isArabic ? 'سنوي' : 'Yearly',
                        _ => value,
                      },
                      onChanged: (String value) {
                        setState(() => _autoFrequency = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.tr('first_payment_date')),
                      subtitle: Text(_dateIso(_autoStartDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _autoStartDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _autoStartDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.flash_on),
                        label: Text(context.l10n.tr('generate_installments')),
                        onPressed: () {
                          final double? totalAmount = tryParseAmount(
                            _totalInstallmentsAmountController.text,
                          );
                          final int? numInst = int.tryParse(
                            _numInstallmentsController.text.trim(),
                          );

                          if (totalAmount == null || totalAmount <= 0) {
                        showTopSnackBar(
                          context,
                          isArabic
                              ? 'يرجى إدخال إجمالي صالح لمبلغ الأقساط.'
                              : 'Please enter a valid total installments amount.',
                        );
                            return;
                          }
                          if (numInst == null || numInst <= 0) {
                            showTopSnackBar(
                              context,
                              isArabic
                                  ? 'يرجى إدخال عدد صحيح صالح للأقساط.'
                                  : 'Please enter a valid number of installments.',
                            );
                            return;
                          }

                          final double instAmount = totalAmount / numInst;
                          DateTime nextDate = _autoStartDate;
                          final controller = context.read<AppStateController>();
                          final market = MarketData.fromJson(controller.state.marketData);
                          setState(() {
                            for (int i = 0; i < numInst; i++) {
                              _installmentPlan.add(<String, dynamic>{
                                'amount': double.parse(
                                  instAmount.toStringAsFixed(2),
                                ),
                                'date': _dateIso(nextDate),
                                'recurrenceDate': _dateIso(nextDate),
                                'isPaid': false,
                                'currency': _autoCurrency,
                              });

                              if (_autoFrequency == 'monthly') {
                                nextDate = DateTime(
                                  nextDate.year,
                                  nextDate.month + 1,
                                  nextDate.day,
                                );
                              } else if (_autoFrequency == 'quarterly') {
                                nextDate = DateTime(
                                  nextDate.year,
                                  nextDate.month + 3,
                                  nextDate.day,
                                );
                              } else if (_autoFrequency == 'yearly') {
                                nextDate = DateTime(
                                  nextDate.year + 1,
                                  nextDate.month,
                                  nextDate.day,
                                );
                              }
                            }
                            _updateLiabilityFromInstallments(market);
                          });
                          _numInstallmentsController.clear();
                          _totalInstallmentsAmountController.clear();
                        },
                      ),
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _oneByOneAmountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: context.l10n.tr('installment_amount'),
                        border: OutlineInputBorder(),
                        hintText: 'e.g. 1000',
                      ),
                    ),
                    const SizedBox(height: 12),
                    CompactDropdownFormField<String>(
                      key: const Key('investmentOneByOneCurrencyField'),
                      value: _oneByOneCurrency,
                      labelText: context.l10n.tr('currency'),
                      items: ZakatEngineService.supportedCurrencies,
                      itemLabel: (String currency) =>
                          CurrencyPresentation.selectorLabel(
                            currency,
                            isRtl:
                                Localizations.localeOf(
                                  context,
                                ).languageCode.toLowerCase() == 'ar',
                          ),
                      onChanged: (String value) {
                        setState(() => _oneByOneCurrency = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.tr('date')),
                      subtitle: Text(_dateIso(_oneByOneDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _oneByOneDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _oneByOneDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(context.l10n.tr('add')),
                        onPressed: () {
                          final double? amount = tryParseAmount(
                            _oneByOneAmountController.text,
                          );
                          if (amount == null || amount <= 0) {
                            showTopSnackBar(
                              context,
                              isArabic
                                  ? 'يرجى إدخال مبلغ صالح.'
                                  : 'Please enter a valid amount.',
                            );
                            return;
                          }
                          final controller = context.read<AppStateController>();
                          final market = MarketData.fromJson(controller.state.marketData);
                          setState(() {
                            _installmentPlan.add(<String, dynamic>{
                              'amount': amount,
                              'date': _dateIso(_oneByOneDate),
                              'recurrenceDate': _dateIso(_oneByOneDate),
                              'isPaid': false,
                              'currency': _oneByOneCurrency,
                            });
                            _updateLiabilityFromInstallments(market);
                          });
                          _oneByOneAmountController.clear();
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_installmentPlan.isNotEmpty) ...[
                    Text(
                      context.l10n.tr('scheduled_installments'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _installmentPlan.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Map<String, dynamic> item =
                            _installmentPlan[index];
                        final double amount = ((item['amount'] ?? 0) as num)
                            .toDouble();
                        final String date = InvestmentAsset.installmentDueDate(
                          item,
                        );
                        final bool isPaid = item['isPaid'] == true;
                        final String amountStr =
                            ZakatEngineService.formatCurrency(
                              amount,
                              item['currency'] ?? _currency,
                              isArabic:
                                  Localizations.localeOf(
                                    context,
                                  ).languageCode.toLowerCase() ==
                                  'ar',
                            );
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            dense: true,
                            title: Text(
                              isArabic
                                  ? 'القسط #${index + 1} - $amountStr'
                                  : 'Installment #${index + 1} - $amountStr',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: isPaid
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: () async {
                                      final DateTime? picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            DateTime.tryParse(date) ?? DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        final controller = context.read<AppStateController>();
                                        final market = MarketData.fromJson(controller.state.marketData);
                                        setState(() {
                                          final String pickedDate = _dateIso(picked);
                                          _installmentPlan[index]['date'] =
                                              pickedDate;
                                          _installmentPlan[index]['recurrenceDate'] =
                                              pickedDate;
                                          _updateLiabilityFromInstallments(market);
                                        });
                                      }
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          date,
                                          style: TextStyle(
                                            color: Theme.of(context).hintColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.edit_calendar,
                                          size: 12,
                                          color: Theme.of(context).hintColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (index == _installmentPlan.length - 1)
                                    InkWell(
                                      onTap: () {
                                        final DateTime? current =
                                            DateTime.tryParse(date);
                                        if (current != null) {
                                          int year = current.year;
                                          int month = current.month + 1;
                                          if (month > 12) {
                                            year += 1;
                                            month = 1;
                                          }
                                          final int daysInMonth =
                                              DateUtils.getDaysInMonth(
                                                year,
                                                month,
                                              );
                                          final int day =
                                              current.day > daysInMonth
                                                  ? daysInMonth
                                                  : current.day;
                                          final DateTime nextMonth = DateTime(
                                            year,
                                            month,
                                            day,
                                          );
                                          final controller = context.read<AppStateController>();
                                          final market = MarketData.fromJson(controller.state.marketData);
                                          setState(() {
                                            _installmentPlan.add(<String,
                                                dynamic>{
                                              'amount': amount,
                                              'date': _dateIso(nextMonth),
                                              'recurrenceDate':
                                                  _dateIso(nextMonth),
                                              'isPaid': false,
                                              'currency':
                                                  item['currency'] ??
                                                  _currency,
                                            });
                                            _updateLiabilityFromInstallments(market);
                                          });
                                        }
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.control_point_duplicate,
                                            size: 12,
                                            color:
                                                Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            context.l10n.tr(
                                              'repeat',
                                            ),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      _showEditInstallmentDialog(index),
                                ),
                                Checkbox(
                                  value: isPaid,
                                  onChanged: (bool? val) {
                                    final controller = context.read<AppStateController>();
                                    final market = MarketData.fromJson(controller.state.marketData);
                                    setState(() {
                                      _installmentPlan[index]['isPaid'] =
                                          val == true;
                                      _updateLiabilityFromInstallments(market);
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    final controller = context.read<AppStateController>();
                                    final market = MarketData.fromJson(controller.state.marketData);
                                    setState(() {
                                      _installmentPlan.removeAt(index);
                                      _updateLiabilityFromInstallments(market);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('investmentNotesField'),
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('notes'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.tr('valuation_date')),
                  subtitle: Text(_dateIso(_selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                        _calculateCurrentValue();
                      });
                    }
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: AppPrimaryButton(
                    key: const Key('saveInvestmentButton'),
                    onPressed: _saving ? null : _submit,
                    label: _saving
                        ? context.l10n.tr('saving_progress')
                        : (widget.isEditMode
                              ? context.l10n.tr('update_investment')
                              : context.l10n.tr('save_investment')),
                    icon: Icons.check,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    final InvestmentAsset? original = widget.initialInvestment;
    final double ownershipPct = double.parse(
      _ownershipPctController.text.trim(),
    );
    final double purchasePrice =
        tryParseAmount(_purchasePriceController.text) ?? 0;
    
    final String rawCurrentValue = _currentValueController.text.trim();
    final double currentValue = rawCurrentValue.isEmpty
        ? purchasePrice
        : (tryParseAmount(rawCurrentValue) ?? purchasePrice);

    final AppStateController controller = context.read<AppStateController>();
    final MarketData market = MarketData.fromJson(controller.state.marketData);

    double liability = tryParseAmount(_liabilityController.text) ?? 0;
    if (_showInstallmentConfig && _installmentPlan.isNotEmpty) {
      liability = _calculateLiabilityFromInstallments(market);
    }

    final String valuationDate = _dateIso(_selectedDate);

    final List<Map<String, dynamic>> finalPlan = liability > 0
        ? InvestmentAsset.normalizeInstallmentPlan(_installmentPlan)
        : const <Map<String, dynamic>>[];

    final double growthRate =
        tryParseAmount(_growthRateController.text) ?? 0;

    final double finalRemainingAmount = liability;
    final double finalPaidAmount = purchasePrice > liability
        ? (purchasePrice - liability)
        : (purchasePrice > 0 ? 0.0 : (original?.paidAmount ?? 0.0));
    final double finalPaidAmountToDate = finalPaidAmount;

    final InvestmentAsset asset = InvestmentAsset(
      id: original?.id ?? _uuid.v4(),
      investmentType: _assetType == 'company_share'
          ? 'company_investment'
          : 'real_estate',
      assetSubtype: _assetType,
      ownershipType: liability > 0 ? 'installment' : 'fully_owned',
      valuationMode: 'net_fair',
      currency: _currency,
      originalPrice: purchasePrice,
      totalInterest: original?.totalInterest ?? 0,
      totalPayable: purchasePrice > 0 ? purchasePrice : (original?.totalPayable ?? purchasePrice),
      paidAmount: finalPaidAmount,
      remainingAmount: finalRemainingAmount,
      installmentPlan: finalPlan,
      valuationDate: valuationDate,
      marketValue: currentValue,
      marketValueDate: valuationDate,
      valuationSource: 'manual',
      loanBalance: liability,
      loanAsOfDate: valuationDate,
      paidAmountToDate: finalPaidAmountToDate,
      ownershipSharePct: ownershipPct,
      country: original?.country ?? 'EG',
      location: _nameController.text.trim(),
      inflationRateAnnual: original?.inflationRateAnnual ?? 0,
      estimatedCurrentValue: currentValue,
      description: _notesController.text.trim(),
      noZakat: original?.noZakat ?? true,
      createdAt: original?.createdAt ?? DateTime.now().toIso8601String(),
      yearlyGrowthRate: growthRate,
    );

    if (widget.isEditMode) {
      await controller.updateInvestment(asset);
    } else {
      await controller.addInvestment(asset);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  static DateTime? _tryParseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  static String _dateIso(DateTime date) {
    final String y = date.year.toString();
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _fmt(double value) {
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
  }
}
