import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/privacy/app_privacy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/motion/app_motion.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/compact_dropdown.dart';
import '../../core/utils/currency_presentation.dart';
import '../../core/services/zakat_engine.dart';
import '../../models/recurring_transaction.dart';
import '../../services/app_state_controller.dart';

class EditRecurringTransactionScreen extends StatefulWidget {
  const EditRecurringTransactionScreen({super.key, this.existing});

  final RecurringTransaction? existing;

  static Route<void> route({RecurringTransaction? existing}) {
    return CupertinoPageRoute<void>(
      settings: const AppPrivacyRouteSettings(
        privacy: ScreenPrivacyClassification.sensitive,
      ),
      builder: (_) => EditRecurringTransactionScreen(existing: existing),
    );
  }

  @override
  State<EditRecurringTransactionScreen> createState() =>
      _EditRecurringTransactionScreenState();
}

class _EditRecurringTransactionScreenState
    extends State<EditRecurringTransactionScreen> {
  final Uuid _uuid = const Uuid();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _dayController;
  late final TextEditingController _descriptionController;

  late String _type;
  late String _currency;
  late String _category;
  late bool _autoAdd;
  late bool _reminderEnabled;
  late int _reminderDayOffset;
  late String _reminderTime;
  late String _frequency;
  late List<String> _customDates;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _amountController = TextEditingController(text: existing?.amount.toString() ?? '');
    _dayController = TextEditingController(text: (existing?.dayOfMonth ?? 1).toString());
    _descriptionController = TextEditingController(text: existing?.description ?? '');

    _type = existing?.type ?? 'expense';
    _autoAdd = existing?.autoAdd ?? true;
    _reminderEnabled = existing?.reminderEnabled ?? false;
    _reminderDayOffset = existing?.reminderDayOffset ?? 0;
    _reminderTime = existing?.reminderTime ?? '09:00';
    _frequency = existing?.frequency ?? 'monthly';
    _customDates = existing != null ? List<String>.from(existing.customDates) : <String>[];

    final controller = context.read<AppStateController>();
    final String existingCurrency = existing?.currency.trim() ?? '';
    _currency = existingCurrency.isNotEmpty
        ? existingCurrency
        : (controller.state.defaultEntryCurrency.isEmpty
            ? 'EGP'
            : controller.state.defaultEntryCurrency);

    _category = existing?.category.trim() ?? '';
    _updateCategoryOptions();
  }

  void _updateCategoryOptions() {
    final controller = context.read<AppStateController>();
    final List<String> categories = _type == 'income'
        ? controller.state.categories.income
        : controller.state.categories.expense;

    if (_category.isEmpty && categories.isNotEmpty) {
      _category = categories.first;
    } else if (!categories.contains(_category) && categories.isNotEmpty) {
      _category = categories.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _dayController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final parts = _reminderTime.split(':');
    final int hour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 9) : 9;
    final int minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );

    if (picked != null) {
      setState(() {
        final String h = picked.hour.toString().padLeft(2, '0');
        final String m = picked.minute.toString().padLeft(2, '0');
        _reminderTime = '$h:$m';
      });
    }
  }

  Future<void> _save() async {
    final String trimmedName = _nameController.text.trim();
    final double parsedAmount = double.tryParse(_amountController.text.trim()) ?? 0;
    final int parsedDay = int.tryParse(_dayController.text.trim()) ?? 1;

    if (trimmedName.isEmpty || parsedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid name and amount')),
      );
      return;
    }

    final controller = context.read<AppStateController>();
    final RecurringTransaction recurring = (widget.existing ??
            RecurringTransaction(
              id: 'rt-${_uuid.v4()}',
              name: trimmedName,
              type: _type,
              amount: parsedAmount,
              currency: _currency,
              category: _category,
              description: _descriptionController.text.trim(),
              dayOfMonth: parsedDay.clamp(1, 31),
              frequency: _frequency,
              lastProcessed: null,
              enabled: true,
              skipMonth: '',
              createdAt: DateTime.now().toUtc().toIso8601String(),
              autoAdd: _autoAdd,
              reminderEnabled: _reminderEnabled,
              reminderDayOffset: _reminderDayOffset,
              reminderTime: _reminderTime,
              customDates: _customDates,
            ))
        .copyWith(
          name: trimmedName,
          type: _type,
          amount: parsedAmount,
          currency: _currency,
          category: _category,
          description: _descriptionController.text.trim(),
          dayOfMonth: parsedDay.clamp(1, 31),
          autoAdd: _autoAdd,
          reminderEnabled: _reminderEnabled,
          reminderDayOffset: _reminderDayOffset,
          reminderTime: _reminderTime,
          frequency: _frequency,
          customDates: _customDates,
        );

    if (widget.existing == null) {
      await controller.addRecurringTransaction(recurring);
    } else {
      await controller.updateRecurringTransaction(recurring);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  InputDecoration _fieldDecoration(String label) {
    final tokens = context.premiumTokens;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: tokens.colors.textSecondary),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.card,
        borderSide: BorderSide(color: tokens.colors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadii.card,
        borderSide: BorderSide(color: tokens.colors.gold),
      ),
      filled: true,
      fillColor: tokens.colors.card,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = tokens.colors.background;

    final controller = context.watch<AppStateController>();
    final List<String> categories = _type == 'income'
        ? controller.state.categories.income
        : controller.state.categories.expense;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.existing == null
              ? context.l10n.tr('add_recurring')
              : context.l10n.tr('edit'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: tokens.colors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? tokens.colors.textPrimary : tokens.colors.hero,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              context.l10n.tr('save'),
              style: TextStyle(
                color: tokens.colors.gold,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Amount and Currency top card
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.tr('amount'),
                    style: TextStyle(
                      color: tokens.colors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: tokens.colors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '0.00',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      SizedBox(
                        width: 150,
                        child: CompactDropdownFormField<String>(
                          value: _currency,
                          labelText: context.l10n.tr('currency'),
                          items: ZakatEngineService.supportedCurrencies,
                          itemLabel: (String code) =>
                              CurrencyPresentation.selectorLabel(
                            code,
                            isRtl: Localizations.localeOf(context)
                                    .languageCode
                                    .toLowerCase() ==
                                'ar',
                          ),
                          onChanged: (String value) {
                            setState(() => _currency = value);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Text(
              'PAYMENT DETAILS',
              style: TextStyle(
                color: tokens.colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Main details card
            PremiumCard(
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    style: TextStyle(color: tokens.colors.textPrimary),
                    decoration: _fieldDecoration(context.l10n.tr('name')),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CompactDropdownFormField<String>(
                    value: _type,
                    labelText: context.l10n.tr('type'),
                    items: const <String>['income', 'expense'],
                    itemLabel: (String value) => context.l10n.tr(value),
                    onChanged: (String value) {
                      setState(() {
                        _type = value;
                        _updateCategoryOptions();
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CompactDropdownFormField<String>(
                    value: _category.isEmpty && categories.isNotEmpty
                        ? categories.first
                        : _category,
                    labelText: context.l10n.tr('category'),
                    items: categories,
                    itemLabel: context.l10n.translateCategory,
                    onChanged: (String value) {
                      setState(() => _category = value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CompactDropdownFormField<String>(
                    value: _frequency,
                    labelText: 'Frequency',
                    items: const <String>['monthly', 'quarterly', 'yearly', 'custom'],
                    itemLabel: (String value) {
                      switch (value) {
                        case 'monthly': return 'Monthly';
                        case 'quarterly': return 'Quarterly';
                        case 'yearly': return 'Yearly';
                        case 'custom': return 'Custom Schedule';
                        default: return value;
                      }
                    },
                    onChanged: (String value) {
                      setState(() => _frequency = value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_frequency != 'custom') ...[
                    TextField(
                      controller: _dayController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: tokens.colors.textPrimary),
                      decoration: _fieldDecoration(context.l10n.tr('day_of_month')),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (_frequency == 'custom') ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Scheduled Dates',
                        style: TextStyle(
                          color: tokens.colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: tokens.colors.divider),
                        borderRadius: AppRadii.card,
                      ),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Column(
                        children: [
                          if (_customDates.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                              child: Text(
                                'No dates scheduled yet.',
                                style: TextStyle(
                                  color: tokens.colors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _customDates.length,
                              separatorBuilder: (_, __) => Divider(color: tokens.colors.divider),
                              itemBuilder: (context, index) {
                                final String dStr = _customDates[index];
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(left: AppSpacing.xs),
                                      child: Text(
                                        dStr,
                                        style: TextStyle(
                                          color: tokens.colors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          _customDates.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          const SizedBox(height: AppSpacing.sm),
                          TextButton.icon(
                            onPressed: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                              );
                              if (picked != null) {
                                final String formatted = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                if (!_customDates.contains(formatted)) {
                                  setState(() {
                                    _customDates.add(formatted);
                                    _customDates.sort();
                                  });
                                }
                              }
                            },
                            icon: Icon(Icons.add, color: tokens.colors.gold),
                            label: Text(
                              'Add Scheduled Date',
                              style: TextStyle(color: tokens.colors.gold, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 2,
                    style: TextStyle(color: tokens.colors.textPrimary),
                    decoration: _fieldDecoration(context.l10n.tr('notes')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Text(
              'SETTINGS & AUTOMATION',
              style: TextStyle(
                color: tokens.colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Settings card
            PremiumCard(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    title: Text(
                      'Auto-add to transactions',
                      style: TextStyle(
                        color: tokens.colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      'Automatically add transaction on the scheduled date',
                      style: TextStyle(color: tokens.colors.textSecondary, fontSize: 12),
                    ),
                    value: _autoAdd,
                    activeColor: tokens.colors.gold,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (bool value) {
                      setState(() => _autoAdd = value);
                    },
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    title: Text(
                      'Notification Reminder',
                      style: TextStyle(
                        color: tokens.colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      'Send notification alert for this payment',
                      style: TextStyle(color: tokens.colors.textSecondary, fontSize: 12),
                    ),
                    value: _reminderEnabled,
                    activeColor: tokens.colors.gold,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (bool value) {
                      setState(() => _reminderEnabled = value);
                    },
                  ),
                  if (_reminderEnabled) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Send Reminder',
                          style: TextStyle(
                            color: tokens.colors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        DropdownButton<int>(
                          value: _reminderDayOffset,
                          dropdownColor: tokens.colors.surface,
                          underline: const SizedBox(),
                          style: TextStyle(
                            color: tokens.colors.gold,
                            fontWeight: FontWeight.bold,
                          ),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Same day')),
                            DropdownMenuItem(value: 1, child: Text('1 day before')),
                            DropdownMenuItem(value: 2, child: Text('2 days before')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _reminderDayOffset = val);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Set Reminder Time',
                          style: TextStyle(
                            color: tokens.colors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        InkWell(
                          onTap: _selectTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: AppRadii.card,
                              border: Border.all(color: tokens.colors.divider),
                              color: tokens.colors.surface,
                            ),
                            child: Text(
                              _reminderTime,
                              style: TextStyle(
                                color: tokens.colors.gold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Delete button if existing
            if (widget.existing != null)
              PressScale(
                child: FilledButton(
                  onPressed: () async {
                    await controller.deleteRecurringTransaction(widget.existing!.id);
                    if (!mounted) return;
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.colors.danger,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(
                    context.l10n.tr('delete'),
                    style: TextStyle(
                      color: tokens.colors.surface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
