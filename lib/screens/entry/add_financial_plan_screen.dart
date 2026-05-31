import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/zakat_engine.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/financial_plan.dart';
import '../../services/app_state_controller.dart';

class AddFinancialPlanScreen extends StatefulWidget {
  const AddFinancialPlanScreen({super.key, this.initialPlan});

  final FinancialPlan? initialPlan;

  bool get isEditMode => initialPlan != null;

  @override
  State<AddFinancialPlanScreen> createState() => _AddFinancialPlanScreenState();
}

class _AddFinancialPlanScreenState extends State<AddFinancialPlanScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _startingBalanceController = TextEditingController();
  final TextEditingController _monthlySavingController = TextEditingController();
  final TextEditingController _monthlyExpenseController = TextEditingController();
  final TextEditingController _annualReturnController = TextEditingController();
  final TextEditingController _durationYearsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final Uuid _uuid = const Uuid();

  late String _currency;
  late DateTime _startDate;
  bool _includeInstallments = false;
  bool _includeZakat = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final FinancialPlan? initial = widget.initialPlan;
    _currency = initial?.currency.isNotEmpty == true ? initial!.currency : 'EGP';
    _startDate = _parseDate(initial?.startDate) ?? DateTime.now();

    if (initial != null) {
      final Map<String, dynamic> context = initial.context ?? const <String, dynamic>{};
      _nameController.text = initial.name;
      _startingBalanceController.text = _fmt(_asDouble(context['startingBalance']));
      _monthlySavingController.text = _fmt(initial.monthlyIncome);
      _monthlyExpenseController.text = _fmt(initial.monthlyExpenses);
      _annualReturnController.text = _fmt(_asDouble(context['expectedAnnualReturnPct']));
      _durationYearsController.text = initial.durationYears.toString();
      _notesController.text = (context['notes'] ?? '').toString();
      _includeInstallments = initial.includeInstallments;
      _includeZakat = initial.includeZakat;
    } else {
      _durationYearsController.text = '1';
      _startingBalanceController.text = '0';
      _monthlySavingController.text = '0';
      _monthlyExpenseController.text = '0';
      _annualReturnController.text = '0';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startingBalanceController.dispose();
    _monthlySavingController.dispose();
    _monthlyExpenseController.dispose();
    _annualReturnController.dispose();
    _durationYearsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditMode ? 'Edit Plan' : 'Add Plan'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextFormField(
                  key: const Key('planNameField'),
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Plan Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if ((value ?? '').trim().isEmpty) return 'Name is required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('planStartingBalanceField'),
                  controller: _startingBalanceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Starting Balance',
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    final double v = double.tryParse((value ?? '').trim()) ?? -1;
                    if (v < 0) return 'Starting balance must be >= 0';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('planMonthlySavingField'),
                  controller: _monthlySavingController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Monthly Saving',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('planMonthlyExpenseField'),
                  controller: _monthlyExpenseController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Monthly Expense',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('planAnnualReturnField'),
                  controller: _annualReturnController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Expected Annual Return %',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('planDurationYearsField'),
                  controller: _durationYearsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration Years',
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    final int years = int.tryParse((value ?? '').trim()) ?? 0;
                    if (years <= 0) return 'Duration years must be > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const Key('planCurrencyField'),
                  initialValue: _currency,
                  decoration: const InputDecoration(
                    labelText: 'Currency',
                    border: OutlineInputBorder(),
                  ),
                  items: ZakatEngineService.supportedCurrencies
                      .map((String currency) => DropdownMenuItem<String>(
                            value: currency,
                            child: Text(currency),
                          ))
                      .toList(growable: false),
                  validator: (String? value) {
                    if ((value ?? '').isEmpty) return 'Currency is required';
                    return null;
                  },
                  onChanged: (String? value) {
                    if (value == null) return;
                    setState(() => _currency = value);
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start Date'),
                  subtitle: Text(_dateIso(_startDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _startDate = picked);
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include Installments'),
                  value: _includeInstallments,
                  onChanged: (bool value) =>
                      setState(() => _includeInstallments = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include Zakat'),
                  value: _includeZakat,
                  onChanged: (bool value) => setState(() => _includeZakat = value),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('planNotesField'),
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: AppPrimaryButton(
                    key: const Key('savePlanButton'),
                    onPressed: _saving ? null : _submit,
                    label: _saving
                        ? 'Saving...'
                        : (widget.isEditMode ? 'Update Plan' : 'Save Plan'),
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

    final FinancialPlan? original = widget.initialPlan;

    final double startingBalance =
        double.tryParse(_startingBalanceController.text.trim()) ?? 0;
    final double monthlySaving =
        double.tryParse(_monthlySavingController.text.trim()) ?? 0;
    final double monthlyExpense =
        double.tryParse(_monthlyExpenseController.text.trim()) ?? 0;
    final double expectedReturnPct =
        double.tryParse(_annualReturnController.text.trim()) ?? 0;
    final int durationYears = int.parse(_durationYearsController.text.trim());

    final Map<String, dynamic> contextData =
        Map<String, dynamic>.from(original?.context ?? const <String, dynamic>{});
    contextData['startingBalance'] = startingBalance;
    contextData['expectedAnnualReturnPct'] = expectedReturnPct;
    contextData['notes'] = _notesController.text.trim();

    final FinancialPlan plan = FinancialPlan(
      id: original?.id ?? _uuid.v4(),
      name: _nameController.text.trim(),
      startDate: _dateIso(_startDate),
      currency: _currency,
      monthlyIncome: monthlySaving,
      monthlyExpenses: monthlyExpense,
      includeInstallments: _includeInstallments,
      includeZakat: _includeZakat,
      durationYears: durationYears,
      context: contextData,
      createdAt: original?.createdAt ?? DateTime.now().toIso8601String(),
    );

    final AppStateController controller = context.read<AppStateController>();
    if (widget.isEditMode) {
      await controller.updateFinancialPlan(plan);
    } else {
      await controller.addFinancialPlan(plan);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
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
