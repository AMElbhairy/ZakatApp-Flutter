import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/saving.dart';
import '../../services/app_state_controller.dart';

class AddSavingScreen extends StatefulWidget {
  const AddSavingScreen({super.key, this.initialSaving});

  final Saving? initialSaving;

  bool get isEditMode => initialSaving != null;

  @override
  State<AddSavingScreen> createState() => _AddSavingScreenState();
}

class _AddSavingScreenState extends State<AddSavingScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final Uuid _uuid = const Uuid();

  late String _assetType;
  late String _cashCurrency;
  String? _goldPurity;
  late DateTime _selectedDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final Saving? initial = widget.initialSaving;
    final String defaultEntryCurrency =
        context.read<AppStateController>().state.defaultEntryCurrency;
    _assetType = initial?.assetType ?? 'cash';
    _selectedDate = _tryParseDate(initial?.dateAcquired) ?? DateTime.now();

    if (initial != null) {
      _amountController.text = initial.amount.toStringAsFixed(
          initial.amount.truncateToDouble() == initial.amount ? 0 : 2);
      _notesController.text = initial.description;
      if (initial.assetType == 'cash') {
        _cashCurrency = initial.unit.isEmpty ? 'EGP' : initial.unit;
        _goldPurity = '24';
      } else if (initial.assetType == 'gold') {
        _cashCurrency = 'EGP';
        _goldPurity = initial.unit.isEmpty ? '24' : initial.unit;
      } else {
        _cashCurrency = 'EGP';
        _goldPurity = '24';
      }
    } else {
      _cashCurrency =
          defaultEntryCurrency.trim().isEmpty ? 'EGP' : defaultEntryCurrency;
      _goldPurity = '24';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String defaultEntryCurrency =
        context.watch<AppStateController>().state.defaultEntryCurrency.trim().isEmpty
            ? 'EGP'
            : context.watch<AppStateController>().state.defaultEntryCurrency;
    if (!widget.isEditMode && _assetType == 'cash' && _cashCurrency == 'EGP' &&
        defaultEntryCurrency != 'EGP') {
      _cashCurrency = defaultEntryCurrency;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditMode
              ? context.l10n.tr('edit_saving_title')
              : context.l10n.tr('add_saving_title'),
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
                  key: const Key('savingTypeField'),
                  initialValue: _assetType,
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('type'),
                    border: OutlineInputBorder(),
                  ),
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                        value: 'cash', child: Text(context.l10n.tr('cash'))),
                    DropdownMenuItem<String>(
                        value: 'gold', child: Text(context.l10n.tr('gold'))),
                    DropdownMenuItem<String>(
                        value: 'silver', child: Text(context.l10n.tr('silver'))),
                  ],
                  onChanged: (String? value) {
                    if (value == null) return;
                    setState(() => _assetType = value);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('savingAmountField'),
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _assetType == 'cash'
                        ? context.l10n.tr('amount')
                        : context.l10n.tr('weight_grams'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    final double amount =
                        double.tryParse((value ?? '').trim()) ?? 0;
                    if (amount <= 0) return context.l10n.tr('amount_gt_zero');
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                if (_assetType == 'cash')
                  DropdownButtonFormField<String>(
                    key: const Key('savingCurrencyField'),
                    initialValue: _cashCurrency,
                    decoration: InputDecoration(
                      labelText: context.l10n.tr('currency'),
                      border: OutlineInputBorder(),
                    ),
                    items: ZakatEngineService.supportedCurrencies
                        .map((String currency) => DropdownMenuItem<String>(
                              value: currency,
                              child: Text(currency),
                            ))
                        .toList(growable: false),
                    onChanged: (String? value) {
                      if (value == null) return;
                      setState(() => _cashCurrency = value);
                    },
                    validator: (String? value) {
                      if ((value ?? '').isEmpty) return context.l10n.tr('currency_required');
                      return null;
                    },
                  ),
                if (_assetType == 'gold')
                  DropdownButtonFormField<String>(
                    key: const Key('savingGoldPurityField'),
                    initialValue: _goldPurity,
                    decoration: InputDecoration(
                      labelText: context.l10n.tr('gold_purity'),
                      border: OutlineInputBorder(),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(value: '24', child: Text('24K')),
                      DropdownMenuItem<String>(value: '21', child: Text('21K')),
                      DropdownMenuItem<String>(value: '18', child: Text('18K')),
                    ],
                    onChanged: (String? value) {
                      setState(() => _goldPurity = value);
                    },
                    validator: (String? value) {
                      if ((value ?? '').isEmpty) {
                        return context.l10n.tr('gold_purity_required');
                      }
                      return null;
                    },
                  ),
                if (_assetType == 'silver')
                  Text(
                    context.l10n.tr('silver_uses_grams'),
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('savingNotesField'),
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
                  title: Text(context.l10n.tr('date')),
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
                    key: const Key('saveSavingButton'),
                    onPressed: _saving ? null : _submit,
                    label: _saving
                        ? context.l10n.tr('saving_progress')
                        : (widget.isEditMode
                            ? context.l10n.tr('update_saving')
                            : context.l10n.tr('save_saving')),
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
    final double amount = double.parse(_amountController.text.trim());

    final Saving? original = widget.initialSaving;
    final String unit = _assetType == 'cash'
        ? _cashCurrency
        : (_assetType == 'gold' ? (_goldPurity ?? '24') : 'g');

    final Saving entry = Saving(
      id: original?.id ?? _uuid.v4(),
      assetType: _assetType,
      dateAcquired: _dateIso(_selectedDate),
      amount: amount,
      remainingAmount: amount,
      unit: unit,
      description: _notesController.text.trim(),
      linkedCashEntryId: original?.linkedCashEntryId,
      purchaseCurrency: _assetType == 'cash' ? _cashCurrency : 'EGP',
      purchaseAmount: amount,
      createdAt: original?.createdAt ?? DateTime.now().toIso8601String(),
      sourceIncomeId: original?.sourceIncomeId,
      exchangeSourceSavingId: original?.exchangeSourceSavingId,
      exchangeSourceIncomeId: original?.exchangeSourceIncomeId,
      internalTransfer: original?.internalTransfer,
      internalTransferType: original?.internalTransferType,
    );

    final AppStateController controller = context.read<AppStateController>();
    if (widget.isEditMode) {
      await controller.updateSaving(entry);
    } else {
      await controller.addSaving(entry);
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
}
