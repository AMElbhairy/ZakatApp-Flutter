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
  final TextEditingController _purchasePriceController =
      TextEditingController();
  final TextEditingController _liabilityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final Uuid _uuid = const Uuid();

  late String _assetType;
  late String _currency;
  late DateTime _selectedDate;
  bool _saving = false;

  bool _showInstallmentConfig = false;
  late List<Map<String, dynamic>> _installmentPlan;
  final TextEditingController _numInstallmentsController =
      TextEditingController();
  final TextEditingController _oneByOneAmountController =
      TextEditingController();
  DateTime _oneByOneDate = DateTime.now();
  DateTime _autoStartDate = DateTime.now().add(const Duration(days: 30));
  String _autoFrequency = 'monthly';
  String _scheduleInputMode = 'auto';

  @override
  void initState() {
    super.initState();
    final InvestmentAsset? initial = widget.initialInvestment;
    final String defaultEntryCurrency = context
        .read<AppStateController>()
        .state
        .defaultEntryCurrency;
    _assetType =
        ZakatEngineService.isCompanyInvestmentType(initial?.investmentType)
        ? 'company_share'
        : 'property';
    _currency = initial?.currency.isNotEmpty == true
        ? initial!.currency
        : (defaultEntryCurrency.trim().isEmpty ? 'EGP' : defaultEntryCurrency);
    _selectedDate = _tryParseDate(initial?.valuationDate) ?? DateTime.now();

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
      _liabilityController.text = _fmt(initial.loanBalance);
      _notesController.text = initial.description;
      _showInstallmentConfig = initial.loanBalance > 0;
    } else {
      _ownershipPctController.text = '100';
    }
    _liabilityController.addListener(_onLiabilityChanged);
  }

  void _onLiabilityChanged() {
    final double liability =
        double.tryParse(_liabilityController.text.trim()) ?? 0;
    final bool hasLiability = liability > 0;
    if (hasLiability != _showInstallmentConfig) {
      setState(() {
        _showInstallmentConfig = hasLiability;
      });
    }
  }

  @override
  void dispose() {
    _liabilityController.removeListener(_onLiabilityChanged);
    _nameController.dispose();
    _currentValueController.dispose();
    _ownershipPctController.dispose();
    _purchasePriceController.dispose();
    _liabilityController.dispose();
    _notesController.dispose();
    _numInstallmentsController.dispose();
    _oneByOneAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    if ((value ?? '').trim().isEmpty) {
                      return context.l10n.tr('name_required');
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
                    labelText: context.l10n.tr('current_value'),
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    final double v = double.tryParse((value ?? '').trim()) ?? 0;
                    if (v <= 0) {
                      return context.l10n.tr('current_value_gt_zero');
                    }
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
                      .map(
                        (String currency) => DropdownMenuItem<String>(
                          value: currency,
                          child: Text(
                            ZakatEngineService.getCurrencySymbol(
                              currency,
                              isArabic:
                                  Localizations.localeOf(
                                    context,
                                  ).languageCode.toLowerCase() ==
                                  'ar',
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                  validator: (String? value) {
                    if ((value ?? '').isEmpty) {
                      return context.l10n.tr('currency_required');
                    }
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('purchase_price_optional'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('investmentLiabilityField'),
                  controller: _liabilityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('remaining_liability_optional'),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_showInstallmentConfig) ...[
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
                      final double liability =
                          double.tryParse(_liabilityController.text.trim()) ??
                          0;
                      final double scheduledTotal = _installmentPlan.fold(
                        0.0,
                        (sum, item) =>
                            sum + ((item['amount'] ?? 0) as num).toDouble(),
                      );
                      final double remainingToSchedule =
                          liability - scheduledTotal;
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
                                        : (remainingToSchedule < -0.01
                                              ? Colors.red
                                              : Colors.green),
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
                          label: const Center(child: Text('Auto-Generate')),
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
                          label: const Center(child: Text('Add One-by-One')),
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
                      decoration: const InputDecoration(
                        labelText: 'Number of Installments',
                        border: OutlineInputBorder(),
                        hintText: 'e.g. 12',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _autoFrequency,
                      decoration: const InputDecoration(
                        labelText: 'Installment Frequency',
                        border: OutlineInputBorder(),
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: 'monthly',
                          child: Text('Monthly'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'quarterly',
                          child: Text('Quarterly'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'yearly',
                          child: Text('Yearly'),
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value == null) return;
                        setState(() => _autoFrequency = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('First Payment Date'),
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
                        label: const Text('Generate Remaining Liability'),
                        onPressed: () {
                          final double liability =
                              double.tryParse(
                                _liabilityController.text.trim(),
                              ) ??
                              0;
                          final double scheduledTotal = _installmentPlan.fold(
                            0.0,
                            (sum, item) =>
                                sum + ((item['amount'] ?? 0) as num).toDouble(),
                          );
                          final double remainingToSchedule =
                              liability - scheduledTotal;
                          final int? numInst = int.tryParse(
                            _numInstallmentsController.text.trim(),
                          );

                          if (numInst == null || numInst <= 0) {
                            showTopSnackBar(
                              context,
                              'Please enter a valid number of installments.',
                            );
                            return;
                          }
                          if (remainingToSchedule <= 0.01) {
                            showTopSnackBar(
                              context,
                              'No remaining liability left to schedule.',
                            );
                            return;
                          }

                          final double instAmount =
                              remainingToSchedule / numInst;
                          DateTime nextDate = _autoStartDate;
                          setState(() {
                            for (int i = 0; i < numInst; i++) {
                              _installmentPlan.add(<String, dynamic>{
                                'amount': double.parse(
                                  instAmount.toStringAsFixed(2),
                                ),
                                'date': _dateIso(nextDate),
                                'recurrenceDate': _dateIso(nextDate),
                                'isPaid': false,
                                'currency': _currency,
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
                          });
                          _numInstallmentsController.clear();
                        },
                      ),
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _oneByOneAmountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Installment Amount',
                        border: OutlineInputBorder(),
                        hintText: 'e.g. 1000',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Payment Date'),
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
                        label: const Text('Add Installment'),
                        onPressed: () {
                          final double? amount = double.tryParse(
                            _oneByOneAmountController.text.trim(),
                          );
                          if (amount == null || amount <= 0) {
                            showTopSnackBar(
                              context,
                              'Please enter a valid amount.',
                            );
                            return;
                          }
                          setState(() {
                            _installmentPlan.add(<String, dynamic>{
                              'amount': amount,
                              'date': _dateIso(_oneByOneDate),
                              'recurrenceDate': _dateIso(_oneByOneDate),
                              'isPaid': false,
                              'currency': _currency,
                            });
                          });
                          _oneByOneAmountController.clear();
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_installmentPlan.isNotEmpty) ...[
                    const Text(
                      'Scheduled Installments',
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
                              _currency,
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
                              'Installment #${index + 1} - $amountStr',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: isPaid
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: InkWell(
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      DateTime.tryParse(date) ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() {
                                    final String pickedDate = _dateIso(picked);
                                    _installmentPlan[index]['date'] =
                                        pickedDate;
                                    _installmentPlan[index]['recurrenceDate'] =
                                        pickedDate;
                                  });
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
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: isPaid,
                                  onChanged: (bool? val) {
                                    setState(() {
                                      _installmentPlan[index]['isPaid'] =
                                          val == true;
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
                                    setState(() {
                                      _installmentPlan.removeAt(index);
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
    final double currentValue = double.parse(
      _currentValueController.text.trim(),
    );
    final double ownershipPct = double.parse(
      _ownershipPctController.text.trim(),
    );
    final double purchasePrice =
        double.tryParse(_purchasePriceController.text.trim()) ?? 0;
    final double liability =
        double.tryParse(_liabilityController.text.trim()) ?? 0;
    final String valuationDate = _dateIso(_selectedDate);

    final List<Map<String, dynamic>> finalPlan = liability > 0
        ? InvestmentAsset.normalizeInstallmentPlan(_installmentPlan)
        : const <Map<String, dynamic>>[];

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
      paidAmount: original?.paidAmount ?? (purchasePrice - liability),
      remainingAmount: original?.remainingAmount ?? liability,
      installmentPlan: finalPlan,
      valuationDate: valuationDate,
      marketValue: currentValue,
      marketValueDate: valuationDate,
      valuationSource: 'manual',
      loanBalance: liability,
      loanAsOfDate: valuationDate,
      paidAmountToDate: original?.paidAmountToDate ?? (purchasePrice - liability),
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
