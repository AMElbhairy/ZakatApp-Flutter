import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/transaction.dart';
import '../../services/app_state_controller.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key, this.initialTransaction});

  final Transaction? initialTransaction;

  bool get isEditMode => initialTransaction != null;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final Uuid _uuid = const Uuid();

  late String _type;
  late String _currency;
  String? _category;
  late DateTime _selectedDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final Transaction? tx = widget.initialTransaction;
    final String defaultEntryCurrency =
        context.read<AppStateController>().state.defaultEntryCurrency;
    _type = tx?.type ?? 'income';
    _currency = tx?.currency ??
        (defaultEntryCurrency.trim().isEmpty ? 'EGP' : defaultEntryCurrency);
    _category = tx?.category;
    _selectedDate = _tryParseDate(tx?.date) ?? DateTime.now();
    if (tx != null) {
      _amountController.text = tx.amount.toStringAsFixed(
          tx.amount.truncateToDouble() == tx.amount ? 0 : 2);
      _notesController.text = tx.description;
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
    final AppStateController controller = context.watch<AppStateController>();
    final String defaultEntryCurrency =
        controller.state.defaultEntryCurrency.trim().isEmpty
            ? 'EGP'
            : controller.state.defaultEntryCurrency;
    if (!widget.isEditMode && _currency == 'EGP' && defaultEntryCurrency != 'EGP') {
      _currency = defaultEntryCurrency;
    }
    final List<String> categories = _type == 'income'
        ? controller.state.categories.income
        : controller.state.categories.expense;

    if (_category != null && !categories.contains(_category)) {
      _category = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditMode
              ? context.l10n.tr('edit_transaction')
              : context.l10n.tr('add_transaction'),
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
                SegmentedButton<String>(
                  segments: <ButtonSegment<String>>[
                    ButtonSegment<String>(
                      value: 'income',
                      label: Text(context.l10n.tr('income')),
                    ),
                    ButtonSegment<String>(
                      value: 'expense',
                      label: Text(context.l10n.tr('expense')),
                    ),
                  ],
                  selected: <String>{_type},
                  onSelectionChanged: (Set<String> selected) {
                    setState(() {
                      _type = selected.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('amountField'),
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('amount'),
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    final double amount =
                        double.tryParse((value ?? '').trim()) ?? 0;
                    if (amount <= 0) return context.l10n.tr('amount_gt_zero');
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const Key('currencyField'),
                  initialValue: _currency,
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
                    setState(() => _currency = value);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const Key('categoryField'),
                  initialValue: _category,
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('category'),
                    border: OutlineInputBorder(),
                  ),
                  items: categories
                      .map((String category) => DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          ))
                      .toList(growable: false),
                  onChanged: (String? value) {
                    setState(() => _category = value);
                  },
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.tr('category_required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('notesField'),
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
                    key: const Key('saveTransactionButton'),
                    onPressed: _saving
                        ? null
                        : () async {
                            if (!(_formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            setState(() => _saving = true);
                            final double amount =
                                double.parse(_amountController.text.trim());

                            final Transaction? original = widget.initialTransaction;
                            final Transaction transaction = Transaction(
                              id: original?.id ?? _uuid.v4(),
                              type: _type,
                              date: _dateIso(_selectedDate),
                              amount: amount,
                              currency: _currency,
                              category: _category!,
                              description: _notesController.text.trim(),
                              createdAt: original?.createdAt ??
                                  DateTime.now().toIso8601String(),
                              rolledOver: original?.rolledOver ?? false,
                              rolledAmount: original?.rolledAmount,
                              sourceIncomeId: original?.sourceIncomeId,
                              exchangePairId: original?.exchangePairId,
                              exchangeSourceIncomeId:
                                  original?.exchangeSourceIncomeId,
                              remainingAmount: original?.remainingAmount,
                            );

                            final AppStateController appStateController =
                                context.read<AppStateController>();
                            if (widget.isEditMode) {
                              await appStateController
                                  .updateTransaction(transaction);
                            } else {
                              await appStateController.addTransaction(transaction);
                            }
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          },
                    label: _saving
                        ? context.l10n.tr('saving_progress')
                        : (widget.isEditMode
                            ? context.l10n.tr('update_transaction')
                            : context.l10n.tr('save_transaction')),
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

  static String _dateLabel(DateTime date) {
    return _dateIso(date);
  }
}
