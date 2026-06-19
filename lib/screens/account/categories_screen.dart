import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/i18n/app_localizations.dart';
import '../../services/app_state_controller.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  static Route<void> route() {
    return CupertinoPageRoute<void>(builder: (_) => const CategoriesScreen());
  }

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String _selectedSection = 'Expense';

  void _showAddCategoryDialog(BuildContext context, String type) {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        final tokens = context.premiumTokens;
        return AlertDialog(
          backgroundColor: tokens.colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.card,
            side: BorderSide(color: tokens.colors.divider),
          ),
          title: Text(
            'Add Category',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: tokens.colors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Category Name',
                style: TextStyle(color: tokens.colors.textSecondary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                autofocus: true,
                style: TextStyle(color: tokens.colors.textPrimary),
                decoration: _fieldDecoration(
                  context,
                  hintText: 'e.g. Shopping',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: tokens.colors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final String name = nameController.text.trim();
                if (name.isNotEmpty) {
                  await context.read<AppStateController>().addCategory(
                    type: type.toLowerCase(),
                    name: name,
                  );
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditCategoryDialog(
    BuildContext context,
    String type,
    String oldName,
  ) {
    final TextEditingController nameController = TextEditingController(
      text: oldName,
    );
    showDialog(
      context: context,
      builder: (context) {
        final tokens = context.premiumTokens;
        return AlertDialog(
          backgroundColor: tokens.colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.card,
            side: BorderSide(color: tokens.colors.divider),
          ),
          title: Text(
            'Edit Category',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: tokens.colors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Category Name',
                style: TextStyle(color: tokens.colors.textSecondary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                autofocus: true,
                style: TextStyle(color: tokens.colors.textPrimary),
                decoration: _fieldDecoration(context),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: tokens.colors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final String newName = nameController.text.trim();
                if (newName.isNotEmpty && newName != oldName) {
                  await context.read<AppStateController>().renameCategory(
                    type: type.toLowerCase(),
                    from: oldName,
                    to: newName,
                  );
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateController>().state;
    final controller = context.read<AppStateController>();
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = dark
        ? tokens.colors.background
        : const Color(0xFFF0EBE0);

    final List<String> categories = _selectedSection == 'Expense'
        ? state.categories.expense
        : state.categories.income;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          context.l10n.tr('categories_manage'),
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
        onPressed: () => _showAddCategoryDialog(context, _selectedSection),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _buildSectionTabs(
              context,
              expenseCount: state.categories.expense.length,
              incomeCount: state.categories.income.length,
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildCategoryGroup(
              context,
              title: '$_selectedSection Categories',
              categories: categories,
              controller: controller,
            ),
            const SizedBox(height: 80), // spacing for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTabs(
    BuildContext context, {
    required int expenseCount,
    required int incomeCount,
  }) {
    final tokens = context.premiumTokens;
    final Color inactiveColor = tokens.colors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          _buildSectionTab(context, 'Expense', expenseCount, inactiveColor),
          const SizedBox(width: AppSpacing.md),
          _buildSectionTab(context, 'Income', incomeCount, inactiveColor),
        ],
      ),
    );
  }

  Widget _buildSectionTab(
    BuildContext context,
    String label,
    int count,
    Color inactiveColor,
  ) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final bool selected = _selectedSection == label;
    final String text = '$label ($count)';
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedSection = label),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: selected
                      ? (dark ? tokens.colors.textPrimary : tokens.colors.hero)
                      : inactiveColor,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 2,
                width: 26,
                decoration: BoxDecoration(
                  color: selected ? tokens.colors.gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGroup(
    BuildContext context, {
    required String title,
    required List<String> categories,
    required AppStateController controller,
  }) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color groupColor = dark
        ? tokens.colors.surface.withValues(alpha: 0.78)
        : const Color(0xFFFAF8F2);

    if (categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 72),
        child: Center(
          child: Text(
            'No categories found',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: tokens.colors.textSecondary),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: groupColor,
        borderRadius: AppRadii.card,
        border: Border.all(color: tokens.colors.divider.withValues(alpha: 0.5)),
      ),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length,
        onReorder: (int oldIndex, int newIndex) {
          controller.reorderCategories(
            type: _selectedSection.toLowerCase(),
            oldIndex: oldIndex,
            newIndex: newIndex,
          );
        },
        itemBuilder: (BuildContext context, int index) {
          final String cat = categories[index];
          return Column(
            key: ValueKey('cat_wrapper_$cat'),
            children: <Widget>[
              _buildCategoryRow(context, cat, controller),
              if (index != categories.length - 1)
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: tokens.colors.divider.withValues(alpha: 0.55),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryRow(
    BuildContext context,
    String categoryName,
    AppStateController controller,
  ) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = dark
        ? tokens.colors.textPrimary
        : const Color(0xFF042F2B);

    final Widget rowContent = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.drag_indicator_rounded,
            color: tokens.colors.textSecondary.withValues(alpha: 0.4),
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              context.l10n.translateCategory(categoryName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: tokens.colors.textSecondary.withValues(alpha: 0.5),
            size: 20,
          ),
        ],
      ),
    );

    return Slidable(
      key: Key('category_$categoryName'),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.25,
        children: <Widget>[
          CustomSlidableAction(
            onPressed: (BuildContext context) async {
              final bool success = await controller.deleteCategory(
                type: _selectedSection.toLowerCase(),
                name: categoryName,
              );
              if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Cannot delete category in use.'),
                    backgroundColor: tokens.colors.danger,
                  ),
                );
              }
            },
            backgroundColor: tokens.colors.danger.withValues(alpha: 0.14),
            foregroundColor: tokens.colors.danger,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.delete_outline_rounded, color: tokens.colors.danger),
                const SizedBox(height: 4),
                Text(
                  'Delete',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: tokens.colors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      child: InkWell(
        onTap: () =>
            _showEditCategoryDialog(context, _selectedSection, categoryName),
        child: rowContent,
      ),
    );
  }
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
