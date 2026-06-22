import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/recurring_transaction.dart';
import '../../services/app_state_controller.dart';

class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({super.key});

  static Route<void> route() {
    return CupertinoPageRoute<void>(
      builder: (_) => const RecurringTransactionsScreen(),
    );
  }

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends State<RecurringTransactionsScreen> {
  static const List<String> _supportedCurrencies = <String>[
    'EGP',
    'SAR',
    'USD',
    'AED',
    'KWD',
    'QAR',
  ];

  final Uuid _uuid = const Uuid();

  void _showRecurringDialog({RecurringTransaction? existing}) {
    final AppStateController controller = context.read<AppStateController>();
    final TextEditingController name = TextEditingController(
      text: existing?.name ?? '',
    );
    final TextEditingController amount = TextEditingController(
      text: existing?.amount.toString() ?? '',
    );
    final TextEditingController day = TextEditingController(
      text: (existing?.dayOfMonth ?? 1).toString(),
    );
    final TextEditingController description = TextEditingController(
      text: existing?.description ?? '',
    );
    String type = existing?.type ?? 'income';
    final String existingCurrency = existing?.currency.trim() ?? '';
    String currency = existingCurrency.isNotEmpty
        ? existingCurrency
        : (controller.state.defaultEntryCurrency.isEmpty
              ? 'EGP'
              : controller.state.defaultEntryCurrency);

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final tokens = context.premiumTokens;
        return StatefulBuilder(
          builder:
              (
                BuildContext dialogContext,
                void Function(void Function()) setDialogState,
              ) {
                final List<String> categories = type == 'income'
                    ? controller.state.categories.income
                    : controller.state.categories.expense;
                final String existingCategory = existing?.category.trim() ?? '';
                final String selectedCategory =
                    existingCategory.isNotEmpty &&
                        categories.contains(existingCategory)
                    ? existingCategory
                    : (categories.isEmpty ? '' : categories.first);

                return AlertDialog(
                  backgroundColor: tokens.colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadii.card,
                    side: BorderSide(color: tokens.colors.divider),
                  ),
                  title: Text(
                    existing == null
                        ? context.l10n.tr('add_recurring')
                        : context.l10n.tr('edit'),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextField(
                          controller: name,
                          decoration: InputDecoration(
                            labelText: context.l10n.tr('name'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: context.l10n.tr('amount'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: day,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: context.l10n.tr('day_of_month'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        DropdownButtonFormField<String>(
                          value: type,
                          decoration: InputDecoration(
                            labelText: context.l10n.tr('type'),
                          ),
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem<String>(
                              value: 'income',
                              child: Text('income'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'expense',
                              child: Text('expense'),
                            ),
                          ],
                          onChanged: (String? value) {
                            if (value == null) return;
                            setDialogState(() => type = value);
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        DropdownButtonFormField<String>(
                          value: currency.isEmpty ? 'EGP' : currency,
                          decoration: InputDecoration(
                            labelText: context.l10n.tr('currency'),
                          ),
                          items: _supportedCurrencies
                              .map(
                                (String code) => DropdownMenuItem<String>(
                                  value: code,
                                  child: Text(
                                    ZakatEngineService.getCurrencySymbol(
                                      code,
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
                            setDialogState(() => currency = value);
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: description,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: context.l10n.tr('notes'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${context.l10n.tr('category')}: ${selectedCategory.isEmpty ? '-' : selectedCategory}',
                            style: TextStyle(
                              color: tokens.colors.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(context.l10n.tr('cancel')),
                    ),
                    FilledButton(
                      onPressed: () async {
                        final String trimmedName = name.text.trim();
                        final double parsedAmount =
                            double.tryParse(amount.text.trim()) ?? 0;
                        final int parsedDay =
                            int.tryParse(day.text.trim()) ?? 1;
                        if (trimmedName.isEmpty || parsedAmount <= 0) return;

                        final RecurringTransaction recurring =
                            (existing ??
                                    RecurringTransaction(
                                      id: 'rt-${_uuid.v4()}',
                                      name: trimmedName,
                                      type: type,
                                      amount: parsedAmount,
                                      currency: currency.isEmpty
                                          ? 'EGP'
                                          : currency,
                                      category: selectedCategory,
                                      description: description.text.trim(),
                                      dayOfMonth: parsedDay.clamp(1, 28),
                                      frequency: 'monthly',
                                      lastProcessed: null,
                                      enabled: true,
                                      skipMonth: '',
                                      createdAt: DateTime.now()
                                          .toUtc()
                                          .toIso8601String(),
                                    ))
                                .copyWith(
                                  name: trimmedName,
                                  type: type,
                                  amount: parsedAmount,
                                  currency: currency.isEmpty ? 'EGP' : currency,
                                  category: selectedCategory,
                                  description: description.text.trim(),
                                  dayOfMonth: parsedDay.clamp(1, 28),
                                );

                        if (existing == null) {
                          await controller.addRecurringTransaction(recurring);
                        } else {
                          await controller.updateRecurringTransaction(
                            recurring,
                          );
                        }
                        Navigator.pop(dialogContext);
                      },
                      child: Text(
                        existing == null
                            ? context.l10n.tr('save')
                            : context.l10n.tr('save'),
                      ),
                    ),
                  ],
                );
              },
        );
      },
    );
  }

  Future<void> _toggleRecurring(RecurringTransaction item, bool enabled) async {
    await context.read<AppStateController>().updateRecurringTransaction(
      item.copyWith(enabled: enabled),
    );
  }

  Future<void> _deleteRecurring(RecurringTransaction item) async {
    await context.read<AppStateController>().deleteRecurringTransaction(
      item.id,
    );
  }

  String _statusLabel(BuildContext context, bool enabled) {
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    if (isArabic) {
      return enabled ? 'نشط' : 'غير نشط';
    }
    return enabled ? 'Active' : 'Inactive';
  }

  @override
  Widget build(BuildContext context) {
    final AppStateController controller = context.watch<AppStateController>();
    final List<RecurringTransaction> recurring =
        controller.state.recurringTransactions;
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = dark
        ? tokens.colors.background
        : const Color(0xFFF0EBE0);
    final int activeCount = recurring
        .where((RecurringTransaction item) => item.enabled)
        .length;
    final int inactiveCount = recurring.length - activeCount;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          context.l10n.tr('recurring_section'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: tokens.colors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: dark ? tokens.colors.textPrimary : tokens.colors.hero,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: tokens.colors.hero,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showRecurringDialog(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: <Widget>[
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.l10n.tr('recurring_section'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    recurring.isEmpty
                        ? 'No recurring transactions yet'
                        : '${recurring.length} total · $activeCount active · $inactiveCount inactive',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (recurring.isEmpty)
              EmptyStateCard(
                icon: Icons.event_repeat_outlined,
                title: context.l10n.tr('recurring_section'),
                message: 'Create recurring payments or income on a schedule.',
                action: AppPrimaryButton(
                  onPressed: _showRecurringDialog,
                  label: context.l10n.tr('add_recurring'),
                  icon: Icons.add,
                ),
              )
            else
              ...recurring.map(
                (RecurringTransaction item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Slidable(
                    key: Key('recurringSlidable_${item.id}'),
                    endActionPane: ActionPane(
                      motion: const StretchMotion(),
                      extentRatio: 0.45,
                      children: <Widget>[
                        SlidableAction(
                          onPressed: (_) =>
                              _showRecurringDialog(existing: item),
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          icon: Icons.edit_outlined,
                          label: context.l10n.tr('edit'),
                        ),
                        SlidableAction(
                          onPressed: (_) => _deleteRecurring(item),
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          icon: Icons.delete_outline,
                          label: context.l10n.tr('delete'),
                        ),
                      ],
                    ),
                    child: PremiumCard(
                      onTap: () => _showRecurringDialog(existing: item),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  item.name,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${item.type} · ${item.amount.toStringAsFixed(item.amount.truncateToDouble() == item.amount ? 0 : 2)} ${item.currency}',
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${context.l10n.tr('day_of_month')}: ${item.dayOfMonth} · ${item.frequency}',
                                  style: TextStyle(
                                    color: tokens.colors.textSecondary,
                                  ),
                                ),
                                if (item.category.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${context.l10n.tr('category')}: ${item.category}',
                                    style: TextStyle(
                                      color: tokens.colors.textSecondary,
                                    ),
                                  ),
                                ],
                                if (item.description.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 4),
                                  Text(
                                    item.description,
                                    style: TextStyle(
                                      color: tokens.colors.textSecondary,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Switch.adaptive(
                                value: item.enabled,
                                onChanged: (bool value) =>
                                    _toggleRecurring(item, value),
                              ),
                              Text(
                                _statusLabel(context, item.enabled),
                                style: TextStyle(
                                  color: item.enabled
                                      ? const Color(0xFF0F766E)
                                      : tokens.colors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
