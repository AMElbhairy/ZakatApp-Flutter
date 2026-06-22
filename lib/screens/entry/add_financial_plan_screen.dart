import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/zakat_engine.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/currency_dropdown_form_field.dart';
import '../../models/financial_plan.dart';
import '../../models/investment_asset.dart';
import '../../models/transaction.dart';
import '../../models/saving.dart';
import '../../services/app_state_controller.dart';
import '../../services/projection_service.dart';

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
  final TextEditingController _manualBalanceController =
      TextEditingController();
  final Map<String, TextEditingController> _manualBreakdownControllers =
      <String, TextEditingController>{
        'cash': TextEditingController(),
        'gold': TextEditingController(),
        'silver': TextEditingController(),
        'real_estate': TextEditingController(),
        'company_investment': TextEditingController(),
        'other': TextEditingController(),
        'liability': TextEditingController(),
      };
  final TextEditingController _monthlyIncomeController =
      TextEditingController();
  final TextEditingController _monthlyExpensesController =
      TextEditingController();
  final TextEditingController _durationYearsController =
      TextEditingController();
  final Uuid _uuid = const Uuid();

  late String _projectionCurrency;
  late DateTime _startDate;
  String _startingBalanceMode = 'snapshot'; // 'snapshot' or 'manual'
  bool _includeInstallments = true;
  bool _includeZakat = true;
  bool _saving = false;
  bool _refreshSnapshotOnSave = false;
  bool _includeManualBreakdown = false;

  @override
  void initState() {
    super.initState();
    final AppStateController controller = context.read<AppStateController>();
    final FinancialPlan? initial = widget.initialPlan;

    _projectionCurrency = initial != null
        ? initial.projectionCurrency
        : (controller.state.mainCurrency.isNotEmpty == true
              ? controller.state.mainCurrency
              : 'EGP');
    _startDate = _parseDate(initial?.startDate) ?? DateTime.now();

    if (initial != null) {
      _nameController.text = initial.name;
      _startingBalanceMode = initial.startingBalanceMode;
      _manualBalanceController.text = _fmt(initial.startingBalance);
      _monthlyIncomeController.text = _fmt(initial.monthlyIncome);
      _monthlyExpensesController.text = _fmt(initial.monthlyExpenses);
      _durationYearsController.text = initial.durationYears.toString();
      _includeInstallments = initial.includeInstallments;
      _includeZakat = initial.includeZakat;
      if (initial.startingBalanceMode == 'manual' &&
          initial.startingAssetBreakdown.isNotEmpty) {
        _includeManualBreakdown = true;
        for (final MapEntry<String, TextEditingController> entry
            in _manualBreakdownControllers.entries) {
          entry.value.text = _fmt(
            initial.startingAssetBreakdown[entry.key] ?? 0,
          );
        }
      }
    } else {
      _durationYearsController.text = '5';
      _manualBalanceController.text = '0';
      _monthlyIncomeController.text = '0';
      _monthlyExpensesController.text = '0';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _manualBalanceController.dispose();
    for (final TextEditingController controller
        in _manualBreakdownControllers.values) {
      controller.dispose();
    }
    _monthlyIncomeController.dispose();
    _monthlyExpensesController.dispose();
    _durationYearsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditMode
              ? (isArabic ? 'تعديل الخطة المالية' : 'Edit Financial Plan')
              : (isArabic ? 'إنشاء خطة مالية' : 'Create Financial Plan'),
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
                TextFormField(
                  key: const Key('planNameField'),
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'اسم الخطة' : 'Plan Name',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if ((value ?? '').trim().isEmpty) {
                      return isArabic
                          ? 'الرجاء إدخال اسم الخطة'
                          : 'Please enter plan name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CurrencyDropdownFormField(
                  value: _projectionCurrency,
                  labelText: isArabic ? 'عملة الخطة' : 'Plan Currency',
                  currencies: const <String>[
                    'EGP',
                    'USD',
                    'EUR',
                    'GBP',
                    'SAR',
                    'AED',
                    'KWD',
                    'QAR',
                  ],
                  onChanged: (String val) {
                    setState(() => _projectionCurrency = val);
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(isArabic ? 'تاريخ البدء' : 'Start Date'),
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
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('planDurationYearsField'),
                  controller: _durationYearsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isArabic
                        ? 'المدة (سنوات, ١ - ١٢)'
                        : 'Duration (Years, 1-12)',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    final int years = int.tryParse((value ?? '').trim()) ?? 0;
                    if (years <= 0 || years > 12) {
                      return isArabic
                          ? 'الرجاء إدخال مدة بين ١ و ١٢ سنة'
                          : 'Please enter a duration between 1 and 12 years';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  isArabic ? 'رصيد البدء' : 'Starting Balance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                RadioGroup<String>(
                  groupValue: _startingBalanceMode,
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() => _startingBalanceMode = value);
                    }
                  },
                  child: Column(
                    children: <Widget>[
                      RadioListTile<String>(
                        title: Text(
                          isArabic
                              ? 'استخدام الرصيد الحالي للثروة'
                              : 'Use Current Balance',
                        ),
                        value: 'snapshot',
                      ),
                      RadioListTile<String>(
                        title: Text(isArabic ? 'إدخال يدوي' : 'Enter Manually'),
                        value: 'manual',
                      ),
                    ],
                  ),
                ),
                if (_startingBalanceMode == 'manual') ...<Widget>[
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('planStartingBalanceField'),
                    controller: _manualBalanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: isArabic
                          ? 'الرصيد الابتدائي اليدوي'
                          : 'Manual Starting Balance',
                      suffixText: ZakatEngineService.getCurrencySymbol(
                        _projectionCurrency,
                        isArabic: isArabic,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (String? value) {
                      final double v =
                          double.tryParse((value ?? '').trim()) ?? -1;
                      if (v < 0) {
                        return isArabic
                            ? 'الرجاء إدخال رصيد بدء صحيح'
                            : 'Please enter a valid starting balance';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    key: const Key('planManualBreakdownToggle'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      isArabic
                          ? 'إضافة تفصيل الأصول والالتزامات'
                          : 'Add Assets and Liabilities Breakdown',
                    ),
                    subtitle: Text(
                      isArabic
                          ? 'يجب أن يساوي إجمالي الأصول ناقص الالتزامات رصيد البداية.'
                          : 'Total assets minus liabilities must equal the starting balance.',
                    ),
                    value: _includeManualBreakdown,
                    onChanged: (bool? value) {
                      setState(() => _includeManualBreakdown = value ?? false);
                    },
                  ),
                  if (_includeManualBreakdown) ...<Widget>[
                    const SizedBox(height: 8),
                    ..._manualBreakdownControllers.entries.map(
                      (
                        MapEntry<String, TextEditingController> entry,
                      ) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          key: Key('planManualBreakdown_${entry.key}'),
                          controller: entry.value,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: _manualBreakdownLabel(
                              entry.key,
                              isArabic,
                            ),
                            suffixText: ZakatEngineService.getCurrencySymbol(
                              _projectionCurrency,
                              isArabic: isArabic,
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (String? value) {
                            final String raw = (value ?? '').trim();
                            if (raw.isEmpty) return null;
                            final double? amount = double.tryParse(raw);
                            if (amount == null || amount < 0) {
                              return isArabic
                                  ? 'الرجاء إدخال قيمة صحيحة'
                                  : 'Please enter a valid value';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ],
                ],
                if (widget.isEditMode &&
                    _startingBalanceMode == 'snapshot') ...<Widget>[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: Text(
                      isArabic
                          ? 'تحديث لقطة الرصيد الحالي للثروة'
                          : 'Refresh Starting Balance Snapshot',
                    ),
                    subtitle: Text(
                      isArabic
                          ? 'سيقوم هذا بتحديث رصيد البداية بلقطة جديدة للثروة الحالية.'
                          : 'This will update the starting balance with a new snapshot of current wealth.',
                    ),
                    value: _refreshSnapshotOnSave,
                    onChanged: (bool? value) {
                      setState(() => _refreshSnapshotOnSave = value ?? false);
                    },
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('planMonthlySavingField'),
                  controller: _monthlyIncomeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: isArabic
                        ? 'الدخل الشهري المتوقع'
                        : 'Monthly Income',
                    suffixText: ZakatEngineService.getCurrencySymbol(
                      _projectionCurrency,
                      isArabic: isArabic,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    final double v =
                        double.tryParse((value ?? '').trim()) ?? -1;
                    if (v < 0) {
                      return isArabic
                          ? 'الرجاء إدخال قيمة صحيحة'
                          : 'Please enter a valid value';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('planMonthlyExpenseField'),
                  controller: _monthlyExpensesController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: isArabic
                        ? 'المصاريف الشهرية المتوقعة'
                        : 'Monthly Expenses',
                    suffixText: ZakatEngineService.getCurrencySymbol(
                      _projectionCurrency,
                      isArabic: isArabic,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    final double v =
                        double.tryParse((value ?? '').trim()) ?? -1;
                    if (v < 0) {
                      return isArabic
                          ? 'الرجاء إدخال قيمة صحيحة'
                          : 'Please enter a valid value';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isArabic
                        ? 'تضمين الأقساط القادمة كتدفقات خارجة'
                        : 'Include Upcoming Installments',
                  ),
                  value: _includeInstallments,
                  onChanged: (bool value) =>
                      setState(() => _includeInstallments = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isArabic
                        ? 'خصم الزكاة السنوية تلقائياً (٢.٥٪)'
                        : 'Subtract Annual Zakat (2.5%)',
                  ),
                  value: _includeZakat,
                  onChanged: (bool value) =>
                      setState(() => _includeZakat = value),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: AppPrimaryButton(
                    key: const Key('savePlanButton'),
                    onPressed: _saving ? null : _submit,
                    label: _saving
                        ? (isArabic ? 'جاري الحفظ...' : 'Saving...')
                        : (widget.isEditMode
                              ? (isArabic ? 'تحديث الخطة' : 'Update Plan')
                              : (isArabic ? 'حفظ الخطة' : 'Save Plan')),
                    icon: Icons.check,
                  ),
                ),
                const SizedBox(height: 120),
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

    final AppStateController controller = context.read<AppStateController>();
    final FinancialPlan? original = widget.initialPlan;

    double startingBalance = 0;
    String startingBalanceDate = _dateIso(_startDate);
    String snapshotWealthCurrency = _projectionCurrency;
    Map<String, double> startingAssetBreakdown = <String, double>{};
    double startingAssets = 0.0;
    double startingLiabilities = 0.0;
    double startingNetWorth = 0.0;
    double startingNisabSnapshot = 0.0;
    double startingGoldPriceSnapshot = 0.0;
    Map<String, double> startingFxSnapshot = <String, double>{};

    final bool preserveSnapshot =
        widget.isEditMode &&
        original != null &&
        _startingBalanceMode == 'snapshot' &&
        !_refreshSnapshotOnSave;

    if (preserveSnapshot) {
      startingBalance = original.startingBalance;
      startingBalanceDate = original.startingBalanceDate;
      snapshotWealthCurrency = original.snapshotWealthCurrency;
      startingAssetBreakdown = original.startingAssetBreakdown;
      startingAssets = original.startingAssets;
      startingLiabilities = original.startingLiabilities;
      startingNetWorth = original.startingNetWorth;
      startingNisabSnapshot = original.startingNisabSnapshot;
      startingGoldPriceSnapshot = original.startingGoldPriceSnapshot;
      startingFxSnapshot = original.startingFxSnapshot;
    } else {
      if (_startingBalanceMode == 'snapshot') {
        final List<Transaction> transactions = controller.state.transactions;
        final List<Saving> savings = controller.state.savings;
        final List<InvestmentAsset> investments = controller.state.investments;
        final MarketData marketData = MarketData.fromJson(
          controller.state.marketData,
        );
        final String mainCurrency =
            controller.state.mainCurrency.isNotEmpty == true
            ? controller.state.mainCurrency
            : 'EGP';

        final NisabTotals totals = ZakatEngineService.computeNisabTotals(
          savings: savings,
          marketData: marketData,
        );
        final double cashEgp = ZakatEngineService.calculateTotalCashWealthEgp(
          transactions: transactions,
          savings: savings,
          marketData: marketData,
          lastRollover: controller.state.lastRollover,
        );
        final double goldEgp = totals.totalGold24k * marketData.goldPrice24kEgp;
        final double silverEgp =
            totals.totalSilverGrams * marketData.silverPriceEgp;
        double investmentsEgp = 0.0;
        for (final InvestmentAsset asset in investments) {
          investmentsEgp +=
              ZakatEngineService.calculateInvestmentEstimatedValueEgp(
                asset: asset,
                marketData: marketData,
              );
        }
        final double totalAssetsEgp =
            cashEgp + goldEgp + silverEgp + investmentsEgp;

        double totalLiabilitiesEgp = 0.0;
        for (final InvestmentAsset asset in investments) {
          final double liability =
              (asset.loanBalance.isFinite && asset.loanBalance > 0
                      ? asset.loanBalance
                      : asset.remainingAmount)
                  .clamp(0.0, double.infinity);
          if (liability > 0) {
            totalLiabilitiesEgp += ZakatEngineService.convertToEgp(
              liability,
              asset.currency,
              marketData,
            );
          }
        }

        startingAssets = ProjectionService.convertToCurrency(
          amount: totalAssetsEgp,
          from: 'EGP',
          to: _projectionCurrency,
          marketData: marketData,
        );
        startingLiabilities = ProjectionService.convertToCurrency(
          amount: totalLiabilitiesEgp,
          from: 'EGP',
          to: _projectionCurrency,
          marketData: marketData,
        );
        startingNetWorth = startingAssets - startingLiabilities;
        startingBalance = startingNetWorth;
        startingBalanceDate = _dateIso(DateTime.now());
        snapshotWealthCurrency = mainCurrency;
        startingAssetBreakdown = _calculateSnapshotAssetBreakdown(
          transactions: transactions,
          savings: savings,
          investments: investments,
          marketData: marketData,
          projectionCurrency: _projectionCurrency,
          mainCurrency: mainCurrency,
          lastRollover: controller.state.lastRollover,
        );
        startingNisabSnapshot = ZakatEngineService.cashNisabThresholdEgp(
          marketData,
          zakatNisabBasis: controller.state.zakatNisabBasis,
        );
        startingGoldPriceSnapshot = marketData.goldPrice24kEgp;
        startingFxSnapshot = Map<String, double>.from(marketData.ratesToEgp);
      } else {
        startingNetWorth =
            double.tryParse(_manualBalanceController.text.trim()) ?? 0;
        if (_includeManualBreakdown) {
          startingAssetBreakdown = _manualBreakdownValues();
          startingAssets = startingAssetBreakdown.entries
              .where(
                (MapEntry<String, double> entry) => entry.key != 'liability',
              )
              .fold<double>(0.0, (
                double total,
                MapEntry<String, double> entry,
              ) {
                return total + entry.value;
              });
          startingLiabilities = startingAssetBreakdown['liability'] ?? 0.0;
          final double calculatedNetWorth =
              startingAssets - startingLiabilities;
          if ((calculatedNetWorth - startingNetWorth).abs() > 0.01) {
            if (mounted) {
              setState(() => _saving = false);
              final bool isArabic =
                  Localizations.localeOf(context).languageCode.toLowerCase() ==
                  'ar';
              showTopSnackBar(
                context,
                isArabic
                    ? 'تفصيل البداية لا يطابق رصيد البداية. صافي الثروة المحسوب: ${_fmt(calculatedNetWorth)}'
                    : 'Starting breakdown does not match starting balance. Calculated net worth: ${_fmt(calculatedNetWorth)}',
                kind: AppToastKind.warning,
              );
            }
            return;
          }
        } else {
          startingAssets = startingNetWorth;
          startingLiabilities = 0.0;
          startingAssetBreakdown = <String, double>{};
        }
        startingBalance = startingNetWorth;
        startingBalanceDate = _dateIso(_startDate);
        snapshotWealthCurrency = _projectionCurrency;
        startingNisabSnapshot = 0.0;
        startingGoldPriceSnapshot = 0.0;
        startingFxSnapshot = <String, double>{};
      }
    }

    final double monthlyIncome =
        double.tryParse(_monthlyIncomeController.text.trim()) ?? 0;
    final double monthlyExpenses =
        double.tryParse(_monthlyExpensesController.text.trim()) ?? 0;
    final int durationYears = int.parse(_durationYearsController.text.trim());

    final FinancialPlan plan = FinancialPlan(
      id: original?.id ?? _uuid.v4(),
      name: _nameController.text.trim(),
      startDate: _dateIso(_startDate),
      projectionCurrency: _projectionCurrency,
      startingBalance: startingBalance,
      startingBalanceDate: startingBalanceDate,
      startingBalanceMode: _startingBalanceMode,
      snapshotWealthCurrency: snapshotWealthCurrency,
      startingAssetBreakdown: startingAssetBreakdown,
      monthlyIncome: monthlyIncome,
      monthlyExpenses: monthlyExpenses,
      includeInstallments: _includeInstallments,
      includeZakat: _includeZakat,
      durationYears: durationYears,
      createdAt:
          original?.createdAt ?? DateTime.now().toUtc().toIso8601String(),
      isActive: true,
      startingAssets: startingAssets,
      startingLiabilities: startingLiabilities,
      startingNetWorth: startingNetWorth,
      startingNisabSnapshot: startingNisabSnapshot,
      startingGoldPriceSnapshot: startingGoldPriceSnapshot,
      startingFxSnapshot: startingFxSnapshot,
    );

    if (widget.isEditMode) {
      await controller.updateFinancialPlan(plan);
    } else {
      await controller.addFinancialPlan(plan);
    }

    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Map<String, double> _manualBreakdownValues() {
    final Map<String, double> values = <String, double>{};
    for (final MapEntry<String, TextEditingController> entry
        in _manualBreakdownControllers.entries) {
      final double value = double.tryParse(entry.value.text.trim()) ?? 0.0;
      if (value > 0 || entry.key == 'liability') {
        values[entry.key] = value;
      }
    }
    return values;
  }

  String _manualBreakdownLabel(String key, bool isArabic) {
    switch (key) {
      case 'cash':
        return isArabic ? 'النقد' : 'Cash';
      case 'gold':
        return isArabic ? 'الذهب' : 'Gold';
      case 'silver':
        return isArabic ? 'الفضة' : 'Silver';
      case 'real_estate':
        return isArabic ? 'العقارات' : 'Real Estate';
      case 'company_investment':
        return isArabic ? 'استثمارات الشركات' : 'Company Investments';
      case 'other':
        return isArabic ? 'أصول أخرى' : 'Other Assets';
      case 'liability':
        return isArabic ? 'الالتزامات' : 'Liabilities';
      default:
        return key;
    }
  }

  Map<String, double> _calculateSnapshotAssetBreakdown({
    required List<Transaction> transactions,
    required List<Saving> savings,
    required List<InvestmentAsset> investments,
    required MarketData marketData,
    required String projectionCurrency,
    required String mainCurrency,
    String? lastRollover,
  }) {
    final NisabTotals totals = ZakatEngineService.computeNisabTotals(
      savings: savings,
      marketData: marketData,
    );

    final double cashEgp = ZakatEngineService.calculateTotalCashWealthEgp(
      transactions: transactions,
      savings: savings,
      marketData: marketData,
      lastRollover: lastRollover,
    );

    final double goldEgp = totals.totalGold24k * marketData.goldPrice24kEgp;
    final double silverEgp =
        totals.totalSilverGrams * marketData.silverPriceEgp;

    final Map<String, double> investmentGroupEgp = <String, double>{};
    for (final InvestmentAsset asset in investments) {
      final String type = ZakatEngineService.normaliseInvestmentType(
        asset.investmentType,
      );
      final double assetValueEgp =
          ZakatEngineService.calculateInvestmentEstimatedValueEgp(
            asset: asset,
            marketData: marketData,
          );
      investmentGroupEgp[type] =
          (investmentGroupEgp[type] ?? 0.0) + assetValueEgp;
    }

    double liabilityEgp = 0.0;
    for (final InvestmentAsset asset in investments) {
      final double liability =
          (asset.loanBalance.isFinite && asset.loanBalance > 0
                  ? asset.loanBalance
                  : asset.remainingAmount)
              .clamp(0.0, double.infinity);
      if (liability > 0) {
        liabilityEgp += ZakatEngineService.convertToEgp(
          liability,
          asset.currency,
          marketData,
        );
      }
    }

    final Map<String, double> breakdown = <String, double>{};
    if (cashEgp > 0) {
      breakdown['cash'] = ProjectionService.convertToCurrency(
        amount: cashEgp,
        from: 'EGP',
        to: projectionCurrency,
        marketData: marketData,
      );
    }
    if (goldEgp > 0) {
      breakdown['gold'] = ProjectionService.convertToCurrency(
        amount: goldEgp,
        from: 'EGP',
        to: projectionCurrency,
        marketData: marketData,
      );
    }
    if (silverEgp > 0) {
      breakdown['silver'] = ProjectionService.convertToCurrency(
        amount: silverEgp,
        from: 'EGP',
        to: projectionCurrency,
        marketData: marketData,
      );
    }
    investmentGroupEgp.forEach((String type, double valueEgp) {
      if (valueEgp > 0) {
        breakdown[type] = ProjectionService.convertToCurrency(
          amount: valueEgp,
          from: 'EGP',
          to: projectionCurrency,
          marketData: marketData,
        );
      }
    });

    final double liabilityInProj = ProjectionService.convertToCurrency(
      amount: liabilityEgp,
      from: 'EGP',
      to: projectionCurrency,
      marketData: marketData,
    );
    breakdown['liability'] = liabilityInProj;

    return breakdown;
  }

  static DateTime? _parseDate(String? value) {
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
