import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/utils/category_visuals.dart';
import '../../models/app_state.dart';
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
    _showCategoryEditorSheet(context, type: type);
  }

  void _showEditCategoryDialog(
    BuildContext context,
    String type,
    String oldName,
  ) {
    _showCategoryEditorSheet(context, type: type, initialName: oldName);
  }

  void _showCategoryEditorSheet(
    BuildContext context, {
    required String type,
    String? initialName,
  }) {
    final AppStateController controller = context.read<AppStateController>();
    final String normalizedType = type.toLowerCase();
    final bool isIncome = normalizedType == 'income';
    final AppCategories categories = controller.state.categories;
    final TextEditingController nameController = TextEditingController(
      text: initialName ?? '',
    );
    final CategoryVisual defaultVisual = initialName == null
        ? CategoryVisuals.resolveTypeFallback(normalizedType)
        : CategoryVisuals.resolveCategoryVisual(
            categories: categories,
            type: normalizedType,
            categoryName: initialName,
          );
    final CategoryVisual? existingCustom = initialName == null
        ? null
        : categories.metadataFor(type: normalizedType, name: initialName);
    final String initialIconKey =
        existingCustom?.iconKey ?? defaultVisual.iconKey ?? 'neutral';
    final int initialColorValue =
        existingCustom?.colorValue ?? defaultVisual.colorValue ?? 0xFF94A3B8;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (BuildContext sheetContext) {
        final tokens = sheetContext.premiumTokens;
        String query = '';
        String selectedIconKey = initialIconKey;
        int selectedColorValue = initialColorValue;

        CategoryVisual currentSelection() {
          return CategoryVisual(
            iconKey: selectedIconKey,
            colorValue: selectedColorValue,
          );
        }

        bool shouldPersistStyle() {
          final CategoryVisual selected = currentSelection();
          final bool sameAsDefault =
              selected.iconKey == defaultVisual.iconKey &&
              selected.colorValue == defaultVisual.colorValue;
          if (initialName == null) {
            return !sameAsDefault;
          }
          if (existingCustom != null) return true;
          return !sameAsDefault;
        }

        return StatefulBuilder(
          builder:
              (BuildContext context, void Function(void Function()) setState) {
                final bool dark =
                    Theme.of(context).brightness == Brightness.dark;
                final List<CategoryIconChoice> icons = CategoryVisuals
                    .iconChoices
                    .where(
                      (CategoryIconChoice choice) =>
                          choice.label.toLowerCase().contains(
                            query.toLowerCase(),
                          ) ||
                          choice.key.toLowerCase().contains(
                            query.toLowerCase(),
                          ),
                    )
                    .toList(growable: false);
                final CategoryVisual selected = currentSelection();
                return SafeArea(
                  child: Container(
                    decoration: BoxDecoration(
                      color: tokens.colors.background,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      border: Border.all(color: tokens.colors.divider),
                    ),
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 20,
                      bottom: 16 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: tokens.colors.textSecondary.withValues(
                                  alpha: 0.25,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: <Widget>[
                              IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const Spacer(),
                              Text(
                                initialName == null
                                    ? context.l10n.tr('create_category')
                                    : context.l10n.tr('edit_category'),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: tokens.colors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () async {
                                  final String name = nameController.text
                                      .trim();
                                  if (name.isEmpty) return;
                                  if (initialName == null) {
                                    await controller.addCategory(
                                      type: normalizedType,
                                      name: name,
                                      iconKey: shouldPersistStyle()
                                          ? selected.iconKey
                                          : null,
                                      colorValue: shouldPersistStyle()
                                          ? selected.colorValue
                                          : null,
                                    );
                                  } else {
                                    if (name != initialName) {
                                      await controller.renameCategory(
                                        type: normalizedType,
                                        from: initialName,
                                        to: name,
                                      );
                                    }
                                    if (shouldPersistStyle()) {
                                      await controller.updateCategoryMetadata(
                                        type: normalizedType,
                                        name: name,
                                        iconKey: selected.iconKey,
                                        colorValue: selected.colorValue,
                                      );
                                    }
                                  }
                                  if (context.mounted) Navigator.pop(context);
                                },
                                child: Text(context.l10n.tr('save')),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _CategoryPreviewCard(
                            name: nameController.text.trim().isEmpty
                                ? context.l10n.tr('category_preview')
                                : nameController.text.trim(),
                            typeLabel: isIncome
                                ? context.l10n.tr('income')
                                : context.l10n.tr('expense'),
                            visual: selected,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: nameController,
                            onChanged: (_) => setState(() {}),
                            decoration: _fieldDecoration(
                              context,
                              labelText: context.l10n.tr('category_name'),
                              hintText: 'e.g. Shopping',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.l10n.tr('choose_icon'),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: tokens.colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            decoration:
                                _fieldDecoration(
                                  context,
                                  hintText: context.l10n.tr('search_icons'),
                                ).copyWith(
                                  prefixIcon: const Icon(Icons.search_rounded),
                                ),
                            onChanged: (String value) {
                              setState(() => query = value);
                            },
                          ),
                          const SizedBox(height: 10),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: icons.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: 1,
                                ),
                            itemBuilder: (BuildContext context, int index) {
                              final CategoryIconChoice choice = icons[index];
                              final bool isSelected =
                                  selectedIconKey == choice.key;
                              return InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => setState(
                                  () => selectedIconKey = choice.key,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? tokens.colors.gold.withValues(
                                            alpha: 0.14,
                                          )
                                        : tokens.colors.surface,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isSelected
                                          ? tokens.colors.gold
                                          : tokens.colors.divider,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Icon(
                                        choice.icon,
                                        color: isSelected
                                            ? (dark
                                                  ? tokens.colors.textPrimary
                                                  : tokens.colors.hero)
                                            : tokens.colors.textSecondary,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        choice.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? (dark
                                                    ? tokens.colors.textPrimary
                                                    : tokens.colors.hero)
                                              : tokens.colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.l10n.tr('choose_color'),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: tokens.colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: CategoryVisuals.palette
                                .map((CategoryColorChoice choice) {
                                  final int choiceValue = choice.value
                                      .toARGB32();
                                  final bool isSelected =
                                      selectedColorValue == choiceValue;
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: () => setState(
                                      () => selectedColorValue = choiceValue,
                                    ),
                                    child: Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: choice.value,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? tokens.colors.hero
                                              : AppColors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check_rounded,
                                              color: AppColors.white,
                                              size: 18,
                                            )
                                          : null,
                                    ),
                                  );
                                })
                                .toList(growable: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
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
        : AppColors.mutedContainer;

    final List<String> categories = _selectedSection == 'Expense'
        ? state.categories.expense
        : state.categories.income;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
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
        child: const Icon(Icons.add, color: AppColors.white),
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
                  color: selected ? tokens.colors.gold : AppColors.transparent,
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
        : AppColors.sharedContainer;

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
        onReorderItem: (int oldIndex, int newIndex) {
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
        : AppColors.backgroundHeroDark;
    final CategoryVisual visual = CategoryVisuals.resolveCategoryVisual(
      categories: controller.state.categories,
      type: _selectedSection.toLowerCase(),
      categoryName: categoryName,
    );
    final Color accent = CategoryVisuals.colorFromValue(visual.colorValue);
    final IconData iconData = CategoryVisuals.iconForKey(visual.iconKey);

    final Widget rowContent = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: accent, size: 18),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _selectedSection,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
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
                showTopSnackBar(
                  context,
                  'Cannot delete category in use.',
                  kind: AppToastKind.error,
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

class _CategoryPreviewCard extends StatelessWidget {
  const _CategoryPreviewCard({
    required this.name,
    required this.typeLabel,
    required this.visual,
  });

  final String name;
  final String typeLabel;
  final CategoryVisual visual;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final Color accent = CategoryVisuals.colorFromValue(visual.colorValue);
    final IconData icon = CategoryVisuals.iconForKey(visual.iconKey);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.colors.surface,
        borderRadius: AppRadii.card,
        border: Border.all(color: tokens.colors.divider),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: tokens.colors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
