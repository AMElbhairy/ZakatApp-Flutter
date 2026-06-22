import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/saving.dart';
import '../../models/transaction.dart';
import '../../services/app_state_controller.dart';
import '../../services/reconciliation_service.dart';

class AddSavingScreen extends StatefulWidget {
  const AddSavingScreen({super.key, this.initialSaving, this.initialAssetType});

  final Saving? initialSaving;
  final String? initialAssetType;

  bool get isEditMode => initialSaving != null;

  @override
  State<AddSavingScreen> createState() => _AddSavingScreenState();
}

class _AddSavingScreenState extends State<AddSavingScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _purchaseAmountController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final Uuid _uuid = const Uuid();

  late String _assetType;
  late String _cashCurrency;
  String? _goldPurity;
  late DateTime _selectedDate;
  late String _purchaseCurrency;
  bool _linkPurchaseToCashEntries = false;
  bool _saving = false;
  final Map<String, TextEditingController> _allocationControllers =
      <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    final Saving? initial = widget.initialSaving;
    final String defaultEntryCurrency = context
        .read<AppStateController>()
        .state
        .defaultEntryCurrency;
    _assetType = initial?.assetType ?? widget.initialAssetType ?? 'cash';
    _selectedDate = _tryParseDate(initial?.dateAcquired) ?? DateTime.now();

    if (initial != null) {
      _amountController.text = initial.amount.toStringAsFixed(
        initial.amount.truncateToDouble() == initial.amount ? 0 : 2,
      );
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
      _purchaseCurrency = initial.purchaseCurrency.isEmpty
          ? 'EGP'
          : initial.purchaseCurrency;
      _purchaseAmountController.text = initial.purchaseAmount > 0
          ? initial.purchaseAmount.toStringAsFixed(
              initial.purchaseAmount.truncateToDouble() ==
                      initial.purchaseAmount
                  ? 0
                  : 2,
            )
          : '';
      _linkPurchaseToCashEntries = initial.fundingAllocations.isNotEmpty;
      if (_linkPurchaseToCashEntries) {
        for (final Map<String, dynamic> alloc in initial.fundingAllocations) {
          final String sourceId = (alloc['sourceId'] ?? '').toString();
          final double amount = _asDouble(alloc['amount']);
          if (sourceId.isNotEmpty && amount > 0) {
            _allocationController(sourceId).text = amount.toStringAsFixed(
              amount.truncateToDouble() == amount ? 0 : 2,
            );
          }
        }
      }
    } else {
      _cashCurrency = defaultEntryCurrency.trim().isEmpty
          ? 'EGP'
          : defaultEntryCurrency;
      _goldPurity = '24';
      _purchaseCurrency = _cashCurrency;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _purchaseAmountController.dispose();
    _notesController.dispose();
    for (final TextEditingController controller
        in _allocationControllers.values) {
      controller.dispose();
    }
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
        _assetType == 'cash' &&
        _cashCurrency == 'EGP' &&
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
                      value: 'cash',
                      child: Text(context.l10n.tr('cash')),
                    ),
                    DropdownMenuItem<String>(
                      value: 'gold',
                      child: Text(context.l10n.tr('gold')),
                    ),
                    DropdownMenuItem<String>(
                      value: 'silver',
                      child: Text(context.l10n.tr('silver')),
                    ),
                  ],
                  onChanged: (String? value) {
                    if (value == null) return;
                    setState(() {
                      _assetType = value;
                      if (_assetType == 'cash') {
                        _linkPurchaseToCashEntries = false;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('savingAmountField'),
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
                    onChanged: (String? value) {
                      if (value == null) return;
                      setState(() => _cashCurrency = value);
                    },
                    validator: (String? value) {
                      if ((value ?? '').isEmpty) {
                        return context.l10n.tr('currency_required');
                      }
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
                if (_assetType != 'cash') ...<Widget>[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const Key('savingPurchaseCurrencyField'),
                    initialValue: _purchaseCurrency,
                    decoration: const InputDecoration(
                      labelText: 'Purchase currency',
                      border: OutlineInputBorder(),
                    ),
                    items: ZakatEngineService.supportedCurrencies
                        .map(
                          (String currency) => DropdownMenuItem<String>(
                            value: currency,
                            child: Text(currency),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (String? value) {
                      if (value == null) return;
                      setState(() {
                        _purchaseCurrency = value;
                        _autoAllocateFunding();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('savingPurchaseAmountField'),
                    controller: _purchaseAmountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Purchase amount',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      if (_linkPurchaseToCashEntries) {
                        setState(_autoAllocateFunding);
                      }
                    },
                    validator: (String? value) {
                      final double amount =
                          double.tryParse((value ?? '').trim()) ?? 0;
                      if (_assetType != 'cash' && amount <= 0) {
                        return context.l10n.tr('amount_gt_zero');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    key: const Key('linkMetalPurchaseToCashEntries'),
                    contentPadding: EdgeInsets.zero,
                    value: _linkPurchaseToCashEntries,
                    title: const Text('Link this purchase to cash entries'),
                    onChanged: (bool? value) {
                      setState(() {
                        _linkPurchaseToCashEntries = value ?? false;
                        if (_linkPurchaseToCashEntries) {
                          _autoAllocateFunding();
                        } else {
                          _clearAllocations();
                        }
                      });
                    },
                  ),
                  if (_linkPurchaseToCashEntries)
                    _buildFundingAllocationSection(context),
                ],
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
    final double purchaseAmount = _assetType == 'cash'
        ? amount
        : double.parse(_purchaseAmountController.text.trim());
    final List<Map<String, dynamic>> fundingAllocations =
        _linkPurchaseToCashEntries
        ? _selectedFundingAllocations()
        : <Map<String, dynamic>>[];
    final double allocationTotal = fundingAllocations.fold<double>(
      0,
      (double sum, Map<String, dynamic> allocation) =>
          sum + _asDouble(allocation['amount']),
    );
    if (_linkPurchaseToCashEntries &&
        (allocationTotal - purchaseAmount).abs() > 0.01) {
      setState(() => _saving = false);
      showTopSnackBar(
        context,
        'Funding allocations must equal purchase amount.',
      );
      return;
    }
    if (_linkPurchaseToCashEntries) {
      final double availableFunding = _fundingSources().fold<double>(
        0,
        (double sum, _FundingSource source) => sum + source.available,
      );
      if (purchaseAmount - availableFunding > 0.01) {
        setState(() => _saving = false);
        showTopSnackBar(
          context,
          'Cannot link this purchase to more cash than is currently available.',
        );
        return;
      }
    }

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
      purchaseCurrency: _assetType == 'cash'
          ? _cashCurrency
          : _purchaseCurrency,
      purchaseAmount: purchaseAmount,
      createdAt: original?.createdAt ?? DateTime.now().toIso8601String(),
      sourceIncomeId: original?.sourceIncomeId,
      exchangeSourceSavingId: original?.exchangeSourceSavingId,
      exchangeSourceIncomeId: original?.exchangeSourceIncomeId,
      internalTransfer: original?.internalTransfer,
      internalTransferType: original?.internalTransferType,
      fundingAllocations: fundingAllocations,
    );

    final AppStateController controller = context.read<AppStateController>();
    try {
      if (widget.isEditMode) {
        await controller.updateSaving(entry);
      } else if (fundingAllocations.isNotEmpty) {
        await controller.addSavingWithFundingAllocations(entry);
      } else {
        await controller.addSaving(entry);
      }
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showTopSnackBar(context, error.message);
      return;
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

  Widget _buildFundingAllocationSection(BuildContext context) {
    final List<_FundingSource> sources = _fundingSources();
    if (sources.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('No available cash entries for this currency.'),
      );
    }

    final List<_FundingSource> linkedSources = sources
        .where((_FundingSource s) => s.isHistorical)
        .toList();
    final List<_FundingSource> additionalSources = sources
        .where((_FundingSource s) => !s.isHistorical)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (linkedSources.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          const Text(
            'Linked Cash Sources',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          ...linkedSources.map(
            (_FundingSource source) => _buildSourceCard(context, source),
          ),
        ],
        if (additionalSources.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          const Text(
            'Additional Available Cash Sources',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          ...additionalSources.map(
            (_FundingSource source) => _buildSourceCard(context, source),
          ),
        ],
      ],
    );
  }

  Widget _buildSourceCard(BuildContext context, _FundingSource source) {
    final TextEditingController controller = _allocationController(source.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${source.label} • ${source.date}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Available: ${source.available.toStringAsFixed(2)} ${source.currency}',
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: Key('fundingAllocation_${source.id}'),
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount used',
                border: OutlineInputBorder(),
              ),
              validator: (String? value) {
                final double amount =
                    double.tryParse((value ?? '').trim()) ?? 0;
                if (amount < 0) return 'Invalid amount';
                if (amount - source.available > 0.01) {
                  return 'Cannot exceed available amount';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getSourceDescription(String sourceId, String sourceType) {
    final AppStateController controller = context.read<AppStateController>();
    if (sourceType == 'savings') {
      final Saving? s = controller.state.savings
          .where((Saving saving) => saving.id == sourceId)
          .firstOrNull;
      if (s != null) {
        return s.description.isNotEmpty ? s.description : 'Cash Savings';
      }
    } else if (sourceType == 'income') {
      final Transaction? tx = controller.state.transactions
          .where((Transaction t) => t.id == sourceId)
          .firstOrNull;
      if (tx != null) {
        return tx.description.isNotEmpty
            ? tx.description
            : (tx.category.isNotEmpty ? tx.category : 'Income');
      }
    }
    return 'Cash';
  }

  List<_FundingSource> _fundingSources() {
    final AppStateController controller = context.read<AppStateController>();
    final String targetCurrency = _purchaseCurrency.trim().toUpperCase();

    final List<CashSource> availableSources = controller
        .getAvailableCashSources(currency: targetCurrency, newestFirst: true);

    final List<_FundingSource> sources = <_FundingSource>[];
    final Set<String> addedIds = <String>{};

    final Saving? initial = widget.initialSaving;
    if (initial != null) {
      for (final Map<String, dynamic> alloc in initial.fundingAllocations) {
        final String sourceId = (alloc['sourceId'] ?? '').toString();
        if (sourceId.isEmpty || addedIds.contains(sourceId)) continue;

        final String sourceType = (alloc['sourceType'] ?? '').toString();
        final String sourceDate = (alloc['sourceDate'] ?? '').toString();
        final double allocatedAmount = _asDouble(alloc['amount']);

        final CashSource? match = availableSources
            .where((CashSource s) => s.id == sourceId)
            .firstOrNull;

        final double currentAvailable = match?.availableAmount ?? 0.0;
        final double limit = currentAvailable + allocatedAmount;

        sources.add(
          _FundingSource(
            id: sourceId,
            sourceType: sourceType,
            date: sourceDate.isNotEmpty ? sourceDate : (match?.date ?? ''),
            available: limit,
            currency: targetCurrency,
            label: _getSourceDescription(sourceId, sourceType),
            isHistorical: true,
          ),
        );
        addedIds.add(sourceId);
      }
    }

    for (final CashSource source in availableSources) {
      if (addedIds.contains(source.id)) continue;
      sources.add(
        _FundingSource(
          id: source.id,
          sourceType: source.sourceType,
          date: source.date,
          available: source.availableAmount,
          currency: source.currency,
          label: _getSourceDescription(source.id, source.sourceType),
          isHistorical: false,
        ),
      );
      addedIds.add(source.id);
    }

    return sources;
  }

  TextEditingController _allocationController(String sourceId) {
    return _allocationControllers.putIfAbsent(
      sourceId,
      () => TextEditingController(),
    );
  }

  void _autoAllocateFunding() {
    _clearAllocations();
    final double purchaseAmount =
        double.tryParse(_purchaseAmountController.text.trim()) ?? 0;
    if (purchaseAmount <= 0) return;

    double remaining = purchaseAmount;
    for (final _FundingSource source in _fundingSources()) {
      if (remaining <= 0.005) break;
      final double allocation = source.available < remaining
          ? source.available
          : remaining;
      _allocationController(source.id).text = allocation.toStringAsFixed(
        allocation.truncateToDouble() == allocation ? 0 : 2,
      );
      remaining -= allocation;
    }
  }

  void _clearAllocations() {
    for (final TextEditingController controller
        in _allocationControllers.values) {
      controller.text = '';
    }
  }

  List<Map<String, dynamic>> _selectedFundingAllocations() {
    final Map<String, _FundingSource> byId = <String, _FundingSource>{
      for (final _FundingSource source in _fundingSources()) source.id: source,
    };
    final List<Map<String, dynamic>> allocations = <Map<String, dynamic>>[];
    for (final MapEntry<String, TextEditingController> entry
        in _allocationControllers.entries) {
      final _FundingSource? source = byId[entry.key];
      if (source == null) continue;
      final double amount = double.tryParse(entry.value.text.trim()) ?? 0;
      if (amount <= 0.005) continue;
      allocations.add(<String, dynamic>{
        'sourceType': source.sourceType,
        'sourceId': source.id,
        'sourceDate': source.date,
        'currency': source.currency,
        'amount': amount,
      });
    }
    return allocations;
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _FundingSource {
  const _FundingSource({
    required this.id,
    required this.sourceType,
    required this.date,
    required this.available,
    required this.currency,
    required this.label,
    this.isHistorical = false,
  });

  final String id;
  final String sourceType;
  final String date;
  final double available;
  final String currency;
  final String label;
  final bool isHistorical;
}
