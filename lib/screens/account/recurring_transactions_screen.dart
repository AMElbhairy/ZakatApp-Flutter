import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/privacy/app_privacy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/utils/category_visuals.dart';
import '../../models/recurring_transaction.dart';
import '../../services/app_state_controller.dart';
import 'edit_recurring_transaction_screen.dart';

class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({super.key});

  static Route<void> route() {
    return CupertinoPageRoute<void>(
      settings: const AppPrivacyRouteSettings(
        privacy: ScreenPrivacyClassification.sensitive,
      ),
      builder: (_) => const RecurringTransactionsScreen(),
    );
  }

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends State<RecurringTransactionsScreen> {

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
    final Color bgColor = tokens.colors.background;

    final int activeCount = recurring
        .where((RecurringTransaction item) => item.enabled)
        .length;
    final int inactiveCount = recurring.length - activeCount;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
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
        backgroundColor: tokens.colors.gold,
        child: const Icon(Icons.add, color: AppColors.white),
        onPressed: () => Navigator.push(
          context,
          EditRecurringTransactionScreen.route(),
        ),
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
                      color: tokens.colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    recurring.isEmpty
                        ? 'No recurring transactions yet'
                        : '${recurring.length} total · $activeCount active · $inactiveCount inactive',
                    style: TextStyle(color: tokens.colors.textSecondary),
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
                  onPressed: () => Navigator.push(
                    context,
                    EditRecurringTransactionScreen.route(),
                  ),
                  label: context.l10n.tr('add_recurring'),
                  icon: Icons.add,
                ),
              )
            else
              ...recurring.map(
                (RecurringTransaction item) {
                  final visual = CategoryVisuals.resolveCategoryVisual(
                    categories: controller.state.categories,
                    type: item.type,
                    categoryName: item.category,
                  );
                  final IconData catIcon = CategoryVisuals.iconForKey(visual.iconKey);
                  final Color catColor = CategoryVisuals.colorFromValue(visual.colorValue);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Slidable(
                      key: Key('recurringSlidable_${item.id}'),
                      endActionPane: ActionPane(
                        motion: const StretchMotion(),
                        extentRatio: 0.45,
                        children: <Widget>[
                          SlidableAction(
                            onPressed: (_) => Navigator.push(
                              context,
                              EditRecurringTransactionScreen.route(existing: item),
                            ),
                            backgroundColor: AppColors.tealAccent,
                            foregroundColor: AppColors.white,
                            icon: Icons.edit_outlined,
                            label: context.l10n.tr('edit'),
                          ),
                          SlidableAction(
                            onPressed: (_) => _deleteRecurring(item),
                            backgroundColor: AppColors.redAccent,
                            foregroundColor: AppColors.white,
                            icon: Icons.delete_outline,
                            label: context.l10n.tr('delete'),
                          ),
                        ],
                      ),
                      child: PremiumCard(
                        onTap: () => Navigator.push(
                          context,
                          EditRecurringTransactionScreen.route(existing: item),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            // Circular Category Icon background
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                catIcon,
                                color: catColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: tokens.colors.textPrimary,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.amount.toStringAsFixed(item.amount.truncateToDouble() == item.amount ? 0 : 2)} ${item.currency} · ${item.type}',
                                    style: TextStyle(
                                      color: tokens.colors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        'Day ${item.dayOfMonth} · ${item.frequency}',
                                        style: TextStyle(
                                          color: tokens.colors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      // Mode badge: Auto-Add vs Reminder Only
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: (item.autoAdd
                                                  ? tokens.colors.success
                                                  : tokens.colors.gold)
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.autoAdd ? 'Auto-add' : 'Reminder only',
                                          style: TextStyle(
                                            color: item.autoAdd
                                                ? tokens.colors.success
                                                : tokens.colors.gold,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.reminderEnabled) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.notifications_active_outlined,
                                          size: 13,
                                          color: tokens.colors.gold,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Alert ${item.reminderDayOffset == 0 ? 'Same Day' : '${item.reminderDayOffset}d before'} at ${item.reminderTime}',
                                          style: TextStyle(
                                            color: tokens.colors.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                Switch.adaptive(
                                  value: item.enabled,
                                  activeColor: tokens.colors.gold,
                                  onChanged: (bool value) =>
                                      _toggleRecurring(item, value),
                                ),
                                Text(
                                  _statusLabel(context, item.enabled),
                                  style: TextStyle(
                                    color: item.enabled
                                        ? tokens.colors.gold
                                        : tokens.colors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
