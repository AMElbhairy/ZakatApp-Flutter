import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/app_ui.dart';
import '../../core/widgets/compact_dropdown.dart';
import '../../core/widgets/currency_dropdown_form_field.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/theme/app_radii.dart';
import '../../core/utils/currency_presentation.dart';
import '../../models/app_state.dart';
import '../../models/credit_card.dart';
import '../../models/merchant_rule.dart';
import '../../models/pending_transaction.dart';
import '../../models/transaction.dart';
import '../../services/app_state_controller.dart';
import '../../services/smart_capture_parser.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/utils/amount_parser.dart';

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
  String _deductFrom = 'cash';

  // Type definitions.
  final List<String> _types = const <String>['expense', 'income'];

  @override
  void initState() {
    super.initState();
    final p = widget.pendingTransaction;
    _selectedType = p.suggestedType;
    if (!_types.contains(_selectedType)) {
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
      final String normalizedCreatedAt = normalizeTimestampText(p.createdAt);
      parsedDate = DateTime.parse(normalizedCreatedAt).toLocal();
    } catch (_) {
      parsedDate = DateTime.now();
    }
    _selectedDate = parsedDate;

    String? suggestedCardId = p.suggestedPaymentSourceId;
    if (suggestedCardId == null) {
      final String digits =
          SmartCaptureParser.parse(
            p.rawMessage,
          ).cardReference?.replaceAll(RegExp(r'\D'), '') ??
          '';
      if (digits.length >= 4) {
        final String last4 = digits.substring(digits.length - 4);
        final List<CreditCard> matches = context
            .read<AppStateController>()
            .state
            .creditCards
            .where(
              (CreditCard card) =>
                  !card.isArchived && card.last4Digits.trim() == last4,
            )
            .toList(growable: false);
        if (matches.length == 1) suggestedCardId = matches.single.id;
      }
    }
    if (suggestedCardId != null) {
      final String cardId = suggestedCardId;
      final List<CreditCard> matches = context
          .read<AppStateController>()
          .state
          .creditCards
          .where((CreditCard card) => !card.isArchived && card.id == cardId)
          .toList(growable: false);
      if (matches.length == 1) _deductFrom = cardId;
    }

    // Initialize category
    _initCategory();
  }

  void _initCategory() {
    final categories = context.read<AppStateController>().state.categories;
    final availableCategories = _getAvailableCategories(categories);
    final String? resolvedCategory = _resolvedCaptureCategory(
      context.read<AppStateController>().state,
    );

    if (_selectedType == 'expense') {
      if (availableCategories.contains(resolvedCategory)) {
        _selectedCategory = resolvedCategory;
      } else if (availableCategories.contains('Uncategorized')) {
        _selectedCategory = 'Uncategorized';
      } else {
        _selectedCategory = availableCategories.isNotEmpty
            ? availableCategories.first
            : null;
      }
    } else if (_selectedType == 'income') {
      if (availableCategories.contains(resolvedCategory)) {
        _selectedCategory = resolvedCategory;
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

  String? _resolvedCaptureCategory(AppStateModel state) {
    final PendingTransaction pending = widget.pendingTransaction;
    final String? linkedId = pending.linkedTransactionId;
    if (linkedId != null && linkedId.isNotEmpty) {
      final List<Transaction> matches = state.transactions
          .where((Transaction tx) => tx.id == linkedId)
          .toList(growable: false);
      final Transaction? linkedTransaction = matches.isNotEmpty
          ? matches.first
          : null;
      if (linkedTransaction != null &&
          linkedTransaction.category.trim().isNotEmpty) {
        return linkedTransaction.category;
      }
    }
    return pending.suggestedCategory;
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
    final dateStr = _dateIso(_selectedDate);
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
          paymentSourceId: _selectedType == 'expense' && _deductFrom != 'cash'
              ? _deductFrom
              : null,
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
          paymentSourceId: _selectedType == 'expense' && _deductFrom != 'cash'
              ? _deductFrom
              : null,
        );
      }

      if (mounted) {
        showTopSnackBar(
          context,
          isApproved
              ? context.l10n.tr('transaction_updated_successfully')
              : context.l10n.tr('transaction_added_successfully'),
          kind: AppToastKind.success,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          context,
          '${context.l10n.tr('error_prefix')}: ${e.toString()}',
          kind: AppToastKind.error,
        );
      }
    }
  }

  static String _dateIso(DateTime date) {
    final String y = date.year.toString();
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _reject() async {
    final controller = context.read<AppStateController>();
    try {
      await controller.rejectPendingTransaction(widget.pendingTransaction.id);
      if (mounted) {
        showTopSnackBar(
          context,
          context.l10n.tr('transaction_rejected'),
          kind: AppToastKind.info,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          context,
          '${context.l10n.tr('error_prefix')}: ${e.toString()}',
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
        context.l10n.tr('merchant_rules_merchant_name_required'),
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
                context.l10n.tr('merchant_rules_create'),
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
                      context.l10n.tr('merchant_rules_merchant_name'),
                      style: TextStyle(color: tokens.colors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: tokens.colors.textPrimary),
                      decoration: _fieldDecoration(
                        context,
                        hintText: context.l10n.tr(
                          'merchant_rules_merchant_name',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.tr('merchant_rules_type'),
                      style: TextStyle(color: tokens.colors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    CompactDropdownFormField<String>(
                      value: selectedType,
                      labelText: context.l10n.tr('merchant_rules_type'),
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                      items: const <String>['expense', 'income'],
                      itemLabel: (String value) => context.l10n.tr(value),
                      onChanged: (String value) {
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
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.tr('merchant_rules_category'),
                      style: TextStyle(color: tokens.colors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    CompactDropdownFormField<String>(
                      value: selectedCategory,
                      labelText: context.l10n.tr('merchant_rules_category'),
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                      items: availableCategories,
                      itemLabel: context.l10n.translateCategory,
                      onChanged: (String value) {
                        setDialogState(() => selectedCategory = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.tr('merchant_rules_aliases'),
                      style: TextStyle(color: tokens.colors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: aliasesController,
                      style: TextStyle(color: tokens.colors.textPrimary),
                      decoration: _fieldDecoration(
                        context,
                        hintText: context.l10n.tr(
                          'merchant_rules_example_aliases',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        context.l10n.tr('merchant_rules_auto_approve'),
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
                          context.l10n.tr('merchant_rules_based_on_builtin'),
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
                    context.l10n.tr('cancel'),
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
                  child: Text(context.l10n.tr('save')),
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
    final List<CreditCard> creditCards = state.creditCards
        .where((CreditCard card) => !card.isArchived)
        .toList(growable: false);
    final List<String> paymentSources = <String>[
      'cash',
      ...creditCards.map((CreditCard card) => card.id),
    ];
    if (!paymentSources.contains(_deductFrom)) _deductFrom = 'cash';
    final bool isApprovedCapture =
        widget.pendingTransaction.status == CaptureStatus.autoApproved ||
        widget.pendingTransaction.status == CaptureStatus.manuallyApproved;
    final String? resolvedCategory = _resolvedCaptureCategory(state);

    // If type requires category, and category is not in list, pick the first
    if ((_selectedType == 'expense' || _selectedType == 'income') &&
        (availableCategories.isNotEmpty) &&
        (_selectedCategory == null ||
            !availableCategories.contains(_selectedCategory))) {
      if (resolvedCategory != null &&
          availableCategories.contains(resolvedCategory)) {
        _selectedCategory = resolvedCategory;
      } else {
        _selectedCategory = availableCategories.first;
      }
    }

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        title: Text(context.l10n.tr('merchant_rules_review_transaction')),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.pendingTransaction.ignoreReason != null &&
                    widget.pendingTransaction.ignoreReason!.startsWith('Possible duplicate')) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: tokens.colors.warning.withOpacity(0.12),
                      borderRadius: AppRadii.card,
                      border: Border.all(
                        color: tokens.colors.warning.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: tokens.colors.warning,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isArabic(context)
                                    ? 'تنبيه: تكرار محتمل'
                                    : 'Warning: Possible Duplicate',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: tokens.colors.warning,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isArabic(context)
                                    ? 'تم التقاط هذه المعاملة لأنها تشبه معاملة سابقة قريبة جداً في التوقيت والتفاصيل. تم إيقاف الموافقة التلقائية حرصاً على الدقة.'
                                    : 'This transaction resembles a recent capture in amount, merchant, and timing. Auto-approval was suppressed. Please review carefully before approving.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: tokens.colors.textSecondary,
                                      height: 1.3,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                          context.l10n.tr(
                            'merchant_rules_original_capture_details',
                          ),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        _buildReadOnlyRow(
                          context.l10n.tr('merchant_rules_source'),
                          '${widget.pendingTransaction.sourceDisplayLabel}${widget.pendingTransaction.sourceIdentifier != null && widget.pendingTransaction.sourceIdentifier != widget.pendingTransaction.sourceDisplayLabel ? " (${widget.pendingTransaction.sourceIdentifier})" : ""}',
                        ),
                        if (widget.pendingTransaction.detectedBank != null) ...[
                          const SizedBox(height: 8),
                          _buildReadOnlyRow(
                            context.l10n.tr('merchant_rules_bank'),
                            widget.pendingTransaction.detectedBank!,
                          ),
                        ],
                        const SizedBox(height: 8),
                        _buildReadOnlyRow(
                          context.l10n.tr('merchant_rules_confidence'),
                          '${(widget.pendingTransaction.confidence * 100).toStringAsFixed(0)}%',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.l10n.tr('merchant_rules_raw_message'),
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
                  context.l10n.tr('merchant_rules_transaction_information'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),

                // Type selector dropdown
                _buildDropdownField<String>(
                  label: context.l10n.tr('merchant_rules_type'),
                  value: _selectedType,
                  items: _types,
                  itemLabel: (String value) => context.l10n.tr(value),
                  onChanged: (String val) {
                    setState(() {
                      _selectedType = val;
                      _initCategory();
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Amount
                _buildTextField(
                  label: context.l10n.tr('merchant_rules_amount'),
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.tr('enter_amount');
                    }
                    if (double.tryParse(value) == null) {
                      return context.l10n.tr('enter_valid_number');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Currency
                Text(
                  context.l10n.tr('merchant_rules_currency'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                CurrencyDropdownFormField(
                  value:
                      CurrencyPresentation.marketCurrencyCodes.contains(
                        _currencyController.text.trim().toUpperCase(),
                      )
                      ? _currencyController.text.trim().toUpperCase()
                      : 'EGP',
                  labelText: context.l10n.tr('merchant_rules_currency'),
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  currencies: CurrencyPresentation.marketCurrencyCodes,
                  onChanged: (String value) {
                    setState(() => _currencyController.text = value);
                  },
                ),
                const SizedBox(height: 16),

                // Category (only visible for Expense and Income)
                if (_selectedType == 'expense' ||
                    _selectedType == 'income') ...[
                  _buildDropdownField<String>(
                    label: context.l10n.tr('merchant_rules_category'),
                    value: _selectedCategory,
                    items: availableCategories,
                    itemLabel: context.l10n.translateCategory,
                    onChanged: (String val) {
                      setState(() {
                        _selectedCategory = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                if (_selectedType == 'expense') ...[
                  _buildDropdownField<String>(
                    label: context.l10n.tr('deduct_from'),
                    value: _deductFrom,
                    items: paymentSources,
                    itemLabel: (String source) {
                      if (source == 'cash') return context.l10n.tr('cash');
                      final CreditCard card = creditCards.firstWhere(
                        (CreditCard item) => item.id == source,
                      );
                      return '${card.bankName} ${card.cardNickname} **** ${card.last4Digits}';
                    },
                    onChanged: (String source) {
                      setState(() => _deductFrom = source);
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Date Selector
                Text(
                  context.l10n.tr('merchant_rules_date'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
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
                  label: context.l10n.tr('merchant_rules_description'),
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
                            side: BorderSide(
                              color: tokens.colors.textSecondary,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            context.l10n.tr('cancel'),
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
                          child: Text(
                            context.l10n.tr('save'),
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
                            context.l10n.tr('reject'),
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
                            context.l10n.tr('merchant_rules_create'),
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
                          child: Text(
                            context.l10n.tr('approve'),
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
    required List<T> items,
    required String Function(T value) itemLabel,
    required ValueChanged<T> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 6),
        CompactDropdownFormField<T>(
          value: value as T,
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.never,
          items: items,
          itemLabel: itemLabel,
          onChanged: onChanged,
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

  bool _isArabic(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'ar';
  }
}
