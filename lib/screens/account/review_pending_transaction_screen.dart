import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/app_ui.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/theme/app_radii.dart';
import '../../models/merchant_rule.dart';
import '../../models/pending_transaction.dart';
import '../../services/app_state_controller.dart';
import '../../services/smart_capture_parser.dart';
import '../../core/i18n/app_localizations.dart';

class ReviewPendingTransactionScreen extends StatefulWidget {
  const ReviewPendingTransactionScreen({
    super.key,
    required this.pendingTransaction,
  });

  final PendingTransaction pendingTransaction;

  @override
  State<ReviewPendingTransactionScreen> createState() =>
      _ReviewPendingTransactionScreenState();
}

class _ReviewPendingTransactionScreenState
    extends State<ReviewPendingTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _selectedType;
  late TextEditingController _amountController;
  late TextEditingController _currencyController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  String? _selectedCategory;

  // Type definitions
  final List<Map<String, String>> _types = [
    {'value': 'expense', 'label': 'Expense'},
    {'value': 'income', 'label': 'Income'},
    {'value': 'transfer', 'label': 'Transfer'},
    {'value': 'gold_purchase', 'label': 'Gold Purchase'},
    {'value': 'silver_purchase', 'label': 'Silver Purchase'},
    {'value': 'investment', 'label': 'Investment'},
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.pendingTransaction;
    _selectedType = p.suggestedType;
    if (!_types.any((t) => t['value'] == _selectedType)) {
      _selectedType = 'expense';
    }

    _amountController = TextEditingController(
      text: p.suggestedAmount?.toStringAsFixed(2) ?? '',
    );
    _currencyController = TextEditingController(
      text: p.suggestedCurrency ?? 'EGP',
    );
    _descriptionController = TextEditingController(
      text: p.suggestedDescription ?? p.merchantName ?? '',
    );

    // Parse creation date or use today
    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse(p.createdAt).toLocal();
    } catch (_) {
      parsedDate = DateTime.now();
    }
    _selectedDate = parsedDate;

    // Initialize category
    _initCategory();
  }

  void _initCategory() {
    final categories = context.read<AppStateController>().state.categories;
    final availableCategories = _getAvailableCategories(categories);

    if (_selectedType == 'expense') {
      if (availableCategories.contains(
        widget.pendingTransaction.suggestedCategory,
      )) {
        _selectedCategory = widget.pendingTransaction.suggestedCategory;
      } else if (availableCategories.contains('Uncategorized')) {
        _selectedCategory = 'Uncategorized';
      } else {
        _selectedCategory = availableCategories.isNotEmpty
            ? availableCategories.first
            : null;
      }
    } else if (_selectedType == 'income') {
      if (availableCategories.contains(
        widget.pendingTransaction.suggestedCategory,
      )) {
        _selectedCategory = widget.pendingTransaction.suggestedCategory;
      } else if (availableCategories.contains('Income')) {
        _selectedCategory = 'Income';
      } else {
        _selectedCategory = availableCategories.isNotEmpty
            ? availableCategories.first
            : null;
      }
    } else if (_selectedType == 'transfer') {
      _selectedCategory = 'Transfer';
    } else {
      _selectedCategory = null;
    }
  }

  List<String> _getAvailableCategories(dynamic categories) {
    if (_selectedType == 'expense') {
      return List<String>.from(categories.expense);
    } else if (_selectedType == 'income') {
      return List<String>.from(categories.income);
    }
    return const [];
  }

  @override
  void dispose() {
    _amountController.dispose();
    _currencyController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        final tokens = context.premiumTokens;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: tokens.colors.gold,
              onPrimary: tokens.colors.hero,
              surface: tokens.colors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _approve() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = context.read<AppStateController>();
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final p = widget.pendingTransaction;
    final bool isApproved =
        p.status == CaptureStatus.autoApproved ||
        p.status == CaptureStatus.manuallyApproved;

    try {
      if (isApproved) {
        await controller.editApprovedPendingTransaction(
          p.id,
          type: _selectedType,
          amount: amount,
          currency: _currencyController.text.trim(),
          category: _selectedCategory ?? '',
          description: _descriptionController.text.trim(),
          date: dateStr,
        );
      } else {
        await controller.approvePendingTransaction(
          p.id,
          type: _selectedType,
          amount: amount,
          currency: _currencyController.text.trim(),
          category: _selectedCategory ?? '',
          description: _descriptionController.text.trim(),
          date: dateStr,
        );
      }

      if (mounted) {
        showTopSnackBar(
          context,
          isApproved
              ? 'Transaction updated successfully'
              : 'Transaction added successfully',
          kind: AppToastKind.success,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          context,
          'Error: ${e.toString()}',
          kind: AppToastKind.error,
        );
      }
    }
  }

  void _reject() async {
    final controller = context.read<AppStateController>();
    try {
      await controller.rejectPendingTransaction(widget.pendingTransaction.id);
      if (mounted) {
        showTopSnackBar(
          context,
          'Transaction rejected',
          kind: AppToastKind.info,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          context,
          'Error: ${e.toString()}',
          kind: AppToastKind.error,
        );
      }
    }
  }

  void _createRuleFromReview() {
    final controller = context.read<AppStateController>();
    final tokens = context.premiumTokens;
    final pending = widget.pendingTransaction;
    final merchantName = pending.merchantName?.trim();
    if (merchantName == null || merchantName.isEmpty) {
      showTopSnackBar(
        context,
        'Merchant name is required to create a rule.',
        kind: AppToastKind.error,
      );
      return;
    }

    final String merchantKey = merchantName.toLowerCase().trim();
    final bool isBuiltin = SmartCaptureParser.builtinMerchantCategoryMap
        .containsKey(merchantKey);
    final nameController = TextEditingController(text: merchantName);
    final aliasesController = TextEditingController(
      text: pending.merchantRuleUsed ?? '',
    );
    final List<String> availableExpense = context
        .read<AppStateController>()
        .state
        .categories
        .expense;
    final List<String> availableIncome = context
        .read<AppStateController>()
        .state
        .categories
        .income;
    String selectedType = pending.suggestedType;
    if (selectedType != 'expense' && selectedType != 'income') {
      selectedType = 'expense';
    }
    String selectedCategory =
        pending.suggestedCategory ??
        (selectedType == 'income'
            ? (availableIncome.isNotEmpty ? availableIncome.first : 'Income')
            : (availableExpense.isNotEmpty
                  ? availableExpense.first
                  : 'Uncategorized'));
    bool autoApprove = pending.confidence >= 0.95;

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final availableCategories = selectedType == 'expense'
                ? availableExpense
                : availableIncome;
            if (availableCategories.isNotEmpty &&
                !availableCategories.contains(selectedCategory)) {
              selectedCategory = availableCategories.first;
            }

            return AlertDialog(
              backgroundColor: tokens.colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadii.card,
                side: BorderSide(color: tokens.colors.divider),
              ),
              title: Text(
                'Create Rule',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: tokens.colors.textPrimary,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Merchant Name',
                      style: TextStyle(color: tokens.colors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: tokens.colors.textPrimary),
                      decoration: _fieldDecoration(
                        context,
                        hintText: 'Merchant name',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Type',
                      style: TextStyle(color: tokens.colors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      dropdownColor: tokens.colors.card,
                      decoration: _fieldDecoration(context),
                      items: const [
                        DropdownMenuItem(
                          value: 'expense',
                          child: Text('Expense'),
                        ),
                        DropdownMenuItem(
                          value: 'income',
                          child: Text('Income'),
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedType = value;
                            final cats = value == 'expense'
                                ? availableExpense
                                : availableIncome;
                            selectedCategory = cats.isNotEmpty
                                ? cats.first
                                : (value == 'expense'
                                      ? 'Uncategorized'
                                      : 'Income');
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Category',
                      style: TextStyle(color: tokens.colors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      dropdownColor: tokens.colors.card,
                      decoration: _fieldDecoration(context),
                      items: availableCategories
                          .map(
                            (String category) => DropdownMenuItem<String>(
                              value: category,
                              child: Text(context.l10n.translateCategory(category)),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) {
                        if (value != null) {
                          setDialogState(() => selectedCategory = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aliases',
                      style: TextStyle(color: tokens.colors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: aliasesController,
                      style: TextStyle(color: tokens.colors.textPrimary),
                      decoration: _fieldDecoration(
                        context,
                        hintText: 'talabat.com, talabat app, طلبات',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Auto Approve',
                        style: TextStyle(color: tokens.colors.textPrimary),
                      ),
                      value: autoApprove,
                      activeThumbColor: tokens.colors.gold,
                      onChanged: (bool value) {
                        setDialogState(() => autoApprove = value);
                      },
                    ),
                    if (isBuiltin)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Built-in Override',
                          style: TextStyle(color: tokens.colors.textPrimary),
                        ),
                        value: true,
                        onChanged: null,
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: tokens.colors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.colors.gold,
                    foregroundColor: tokens.colors.hero,
                  ),
                  onPressed: () async {
                    final String enteredName = nameController.text.trim();
                    if (enteredName.isEmpty) return;
                    await controller.saveCustomMerchantRule(
                      MerchantRule(
                        merchantName: enteredName,
                        categoryId: selectedCategory,
                        defaultType: selectedType,
                        autoApprove: autoApprove,
                        usageCount: 0,
                        confidence: 1.0,
                        source: 'custom',
                        aliases: aliasesController.text
                            .split(',')
                            .map((String alias) => alias.trim())
                            .where((String alias) => alias.isNotEmpty)
                            .toList(growable: false),
                        isBuiltinOverride: isBuiltin,
                        builtinKey: isBuiltin ? merchantKey : null,
                      ),
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
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
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final state = context.watch<AppStateController>().state;
    final availableCategories = _getAvailableCategories(state.categories);
    final bool isApprovedCapture =
        widget.pendingTransaction.status == CaptureStatus.autoApproved ||
        widget.pendingTransaction.status == CaptureStatus.manuallyApproved;

    // If type requires category, and category is not in list, pick the first
    if ((_selectedType == 'expense' || _selectedType == 'income') &&
        (availableCategories.isNotEmpty) &&
        (_selectedCategory == null ||
            !availableCategories.contains(_selectedCategory))) {
      _selectedCategory = availableCategories.first;
    }

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(title: const Text('Review Transaction')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Read-only Details Section
                Card(
                  color: tokens.colors.hero,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadii.card,
                    side: BorderSide(color: tokens.colors.divider),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Original Capture Details',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        _buildReadOnlyRow(
                          'Source',
                          '${widget.pendingTransaction.sourceDisplayLabel}${widget.pendingTransaction.sourceIdentifier != null && widget.pendingTransaction.sourceIdentifier != widget.pendingTransaction.sourceDisplayLabel ? " (${widget.pendingTransaction.sourceIdentifier})" : ""}',
                        ),
                        if (widget.pendingTransaction.detectedBank != null) ...[
                          const SizedBox(height: 8),
                          _buildReadOnlyRow(
                            'Bank',
                            widget.pendingTransaction.detectedBank!,
                          ),
                        ],
                        const SizedBox(height: 8),
                        _buildReadOnlyRow(
                          'Confidence',
                          '${(widget.pendingTransaction.confidence * 100).toStringAsFixed(0)}%',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Raw Message:',
                          style: TextStyle(
                            color: tokens.colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: tokens.colors.surface,
                            borderRadius: AppRadii.card,
                          ),
                          child: Text(
                            widget.pendingTransaction.rawMessage,
                            style: TextStyle(
                              color: tokens.colors.textSecondary,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Editable Fields
                Text(
                  'Transaction Information',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),

                // Type selector dropdown
                _buildDropdownField<String>(
                  label: 'Type',
                  value: _selectedType,
                  items: _types
                      .map(
                        (t) => DropdownMenuItem<String>(
                          value: t['value'],
                          child: Text(t['label']!),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedType = val;
                        _initCategory();
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Amount
                _buildTextField(
                  label: 'Amount',
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Currency
                _buildTextField(
                  label: 'Currency',
                  controller: _currencyController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter currency code';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Category (only visible for Expense and Income)
                if (_selectedType == 'expense' ||
                    _selectedType == 'income') ...[
                  _buildDropdownField<String>(
                    label: 'Category',
                    value: _selectedCategory,
                    items: availableCategories
                        .map(
                          (c) => DropdownMenuItem<String>(
                            value: c,
                            child: Text(context.l10n.translateCategory(c)),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCategory = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Date Selector
                Text('Date', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.colors.surface,
                      borderRadius: AppRadii.card,
                      border: Border.all(color: tokens.colors.divider),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('yyyy-MM-dd').format(_selectedDate),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Icon(
                          Icons.calendar_today,
                          color: tokens.colors.gold,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                _buildTextField(
                  label: 'Description',
                  controller: _descriptionController,
                ),
                const SizedBox(height: 30),

                // Action Buttons
                if (isApprovedCapture)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: tokens.colors.textSecondary),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: tokens.colors.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tokens.colors.gold,
                            foregroundColor: tokens.colors.hero,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _approve,
                          child: const Text(
                            'Save',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: tokens.colors.danger),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _reject,
                          child: Text(
                            'Reject',
                            style: TextStyle(
                              color: tokens.colors.danger,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: tokens.colors.gold),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed:
                              widget.pendingTransaction.merchantName == null
                              ? null
                              : _createRuleFromReview,
                          child: Text(
                            'Create Rule',
                            style: TextStyle(
                              color: tokens.colors.gold,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tokens.colors.gold,
                            foregroundColor: tokens.colors.hero,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _approve,
                          child: const Text(
                            'Approve',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyRow(String label, String value) {
    final tokens = context.premiumTokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: tokens.colors.textSecondary, fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: _fieldDecoration(context),
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final tokens = context.premiumTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: tokens.colors.card,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: _fieldDecoration(context),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    String? labelText,
    String? hintText,
  }) {
    final tokens = context.premiumTokens;
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      filled: true,
      fillColor: tokens.colors.card,
      labelStyle: TextStyle(color: tokens.colors.textSecondary),
      hintStyle: TextStyle(color: tokens.colors.textSecondary),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.card,
        borderSide: BorderSide(color: tokens.colors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadii.card,
        borderSide: BorderSide(color: tokens.colors.gold),
      ),
    );
  }
}
