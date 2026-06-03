import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/investment_asset.dart';
import '../../services/app_state_controller.dart';

class AddInvestmentScreen extends StatefulWidget {
  const AddInvestmentScreen({super.key, this.initialInvestment});

  final InvestmentAsset? initialInvestment;

  bool get isEditMode => initialInvestment != null;

  @override
  State<AddInvestmentScreen> createState() => _AddInvestmentScreenState();
}

class _AddInvestmentScreenState extends State<AddInvestmentScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _currentValueController = TextEditingController();
  final TextEditingController _ownershipPctController = TextEditingController();
  final TextEditingController _purchasePriceController = TextEditingController();
  final TextEditingController _liabilityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final Uuid _uuid = const Uuid();

  late String _assetType;
  late String _currency;
  late DateTime _selectedDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final InvestmentAsset? initial = widget.initialInvestment;
    final String defaultEntryCurrency =
        context.read<AppStateController>().state.defaultEntryCurrency;
    _assetType = ZakatEngineService.isCompanyInvestmentType(initial?.investmentType)
        ? 'company_share'
        : 'property';
    _currency = initial?.currency.isNotEmpty == true
        ? initial!.currency
        : (defaultEntryCurrency.trim().isEmpty ? 'EGP' : defaultEntryCurrency);
    _selectedDate = _tryParseDate(initial?.valuationDate) ?? DateTime.now();

    if (initial != null) {
      _nameController.text = initial.location;
      _currentValueController.text = _fmt(initial.marketValue);
      _ownershipPctController.text = _fmt(initial.ownershipSharePct);
      _purchasePriceController.text = _fmt(initial.originalPrice);
      _liabilityController.text = _fmt(initial.loanBalance);
      _notesController.text = initial.description;
    } else {
      _ownershipPctController.text = '100';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentValueController.dispose();
    _ownershipPctController.dispose();
    _purchasePriceController.dispose();
    _liabilityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String defaultEntryCurrency =
        context.watch<AppStateController>().state.defaultEntryCurrency.trim().isEmpty
            ? 'EGP'
            : context.watch<AppStateController>().state.defaultEntryCurrency;
    if (!widget.isEditMode && _currency == 'EGP' && defaultEntryCurrency != 'EGP') {
      _currency = defaultEntryCurrency;
    }
    return Scaffold(
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
                DropdownButtonFormField<String>(
                  key: const Key('investmentTypeField'),
                  initialValue: _assetType,
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('asset_type'),
                    border: OutlineInputBorder(),
                  ),
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'property',
                      child: Text(context.l10n.tr('property')),
                    ),
                    DropdownMenuItem<String>(
                      value: 'company_share',
                      child: Text(context.l10n.tr('company_share')),
                    ),
                  ],
                  onChanged: (String? value) {
                    if (value == null) return;
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
                    if ((value ?? '').trim().isEmpty) return context.l10n.tr('name_required');
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('investmentCurrentValueField'),
                  controller: _currentValueController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('current_value'),
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    final double v = double.tryParse((value ?? '').trim()) ?? 0;
                    if (v <= 0) return context.l10n.tr('current_value_gt_zero');
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const Key('investmentCurrencyField'),
                  initialValue: _currency,
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('currency'),
                    border: OutlineInputBorder(),
                  ),
                  items: ZakatEngineService.supportedCurrencies
                      .map((String currency) => DropdownMenuItem<String>(
                            value: currency,
                            child: Text(ZakatEngineService.getCurrencySymbol(
                              currency,
                              isArabic: Localizations.localeOf(context)
                                      .languageCode
                                      .toLowerCase() ==
                                  'ar',
                            )),
                          ))
                      .toList(growable: false),
                  validator: (String? value) {
                    if ((value ?? '').isEmpty) return context.l10n.tr('currency_required');
                    return null;
                  },
                  onChanged: (String? value) {
                    if (value == null) return;
                    setState(() => _currency = value);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('investmentOwnershipField'),
                  controller: _ownershipPctController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('ownership_pct'),
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    final double pct =
                        double.tryParse((value ?? '').trim()) ?? -1;
                    if (pct < 0 || pct > 100) {
                      return context.l10n.tr('ownership_pct_range');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('investmentPurchasePriceField'),
                  controller: _purchasePriceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('purchase_price_optional'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('investmentLiabilityField'),
                  controller: _liabilityController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('remaining_liability_optional'),
                    border: OutlineInputBorder(),
                  ),
                ),
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
                      setState(() => _selectedDate = picked);
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
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    final InvestmentAsset? original = widget.initialInvestment;
    final double currentValue =
        double.parse(_currentValueController.text.trim());
    final double ownershipPct =
        double.parse(_ownershipPctController.text.trim());
    final double purchasePrice =
        double.tryParse(_purchasePriceController.text.trim()) ?? 0;
    final double liability = double.tryParse(_liabilityController.text.trim()) ?? 0;
    final String valuationDate = _dateIso(_selectedDate);

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
      totalPayable: original?.totalPayable ?? purchasePrice,
      paidAmount: original?.paidAmount ?? purchasePrice,
      remainingAmount: original?.remainingAmount ?? liability,
      installmentPlan: original?.installmentPlan ?? const <Map<String, dynamic>>[],
      valuationDate: valuationDate,
      marketValue: currentValue,
      marketValueDate: valuationDate,
      valuationSource: 'manual',
      loanBalance: liability,
      loanAsOfDate: valuationDate,
      paidAmountToDate: original?.paidAmountToDate ?? purchasePrice,
      ownershipSharePct: ownershipPct,
      country: original?.country ?? 'EG',
      location: _nameController.text.trim(),
      inflationRateAnnual: original?.inflationRateAnnual ?? 0,
      estimatedCurrentValue: currentValue,
      description: _notesController.text.trim(),
      noZakat: original?.noZakat ?? true,
      createdAt: original?.createdAt ?? DateTime.now().toIso8601String(),
    );

    final AppStateController controller = context.read<AppStateController>();
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
