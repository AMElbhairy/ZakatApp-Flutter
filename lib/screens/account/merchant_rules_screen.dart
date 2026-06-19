import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../models/merchant_rule.dart';
import '../../services/app_state_controller.dart';
import '../../services/smart_capture_parser.dart';
import '../../core/i18n/app_localizations.dart';

class MerchantRulesScreen extends StatefulWidget {
  const MerchantRulesScreen({super.key});

  @override
  State<MerchantRulesScreen> createState() => _MerchantRulesScreenState();
}

class _MerchantRulesScreenState extends State<MerchantRulesScreen> {
  String _selectedSection = 'All'; // All, Built-in, Learned, Custom
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  void _showAddCustomRuleDialog(
    BuildContext context,
    AppStateController controller,
  ) {
    final nameController = TextEditingController();
    final aliasesController = TextEditingController();
    String selectedCategory = controller.state.categories.expense.first;
    String selectedType = 'expense';
    bool autoApprove = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final tokens = context.premiumTokens;
            return AlertDialog(
              backgroundColor: tokens.colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadii.card,
                side: BorderSide(color: tokens.colors.divider),
              ),
              title: Text(
                'Add Custom Rule',
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
                        hintText: 'e.g. Talabat',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Transaction Type',
                      style: TextStyle(color: tokens.colors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      dropdownColor: tokens.colors.card,
                      initialValue: selectedType,
                      decoration: _fieldDecoration(context),
                      style: TextStyle(color: tokens.colors.textPrimary),
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
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            selectedType = val;
                            final cats = val == 'expense'
                                ? controller.state.categories.expense
                                : controller.state.categories.income;
                            if (!cats.contains(selectedCategory)) {
                              selectedCategory = cats.first;
                            }
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
                      dropdownColor: tokens.colors.card,
                      initialValue: selectedCategory,
                      decoration: _fieldDecoration(context),
                      style: TextStyle(color: tokens.colors.textPrimary),
                      items:
                          (selectedType == 'expense'
                                  ? controller.state.categories.expense
                                  : controller.state.categories.income)
                              .map(
                                (cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(context.l10n.translateCategory(cat)),
                                ),
                              )
                              .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            selectedCategory = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: Text(
                        'Auto Approve',
                        style: TextStyle(
                          color: tokens.colors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      value: autoApprove,
                      activeThumbColor: tokens.colors.gold,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() {
                          autoApprove = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: aliasesController,
                      style: TextStyle(color: tokens.colors.textPrimary),
                      decoration: _fieldDecoration(
                        context,
                        labelText: 'Aliases',
                        hintText: 'merchant.com, merchant app',
                      ),
                    ),
                  ],
                ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.colors.gold,
                    foregroundColor: tokens.colors.hero,
                  ),
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    controller.saveCustomMerchantRule(
                      MerchantRule(
                        merchantName: name,
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
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditRuleDialog(
    BuildContext context,
    AppStateController controller,
    MerchantRule rule,
  ) {
    final String originalKey = rule.merchantName.toLowerCase().trim();
    final bool isBuiltin =
        rule.isBuiltinOverride ||
        SmartCaptureParser.builtinMerchantCategoryMap.containsKey(originalKey);
    final nameController = TextEditingController(text: rule.merchantName);
    final aliasesController = TextEditingController(
      text: rule.aliases.join(', '),
    );
    String selectedCategory = rule.categoryId;
    String selectedType = rule.defaultType;
    bool autoApprove = rule.autoApprove;
    bool enabled = rule.enabled;

    showDialog<void>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          final tokens = context.premiumTokens;
          final categories = selectedType == 'expense'
              ? controller.state.categories.expense
              : controller.state.categories.income;
          if (!categories.contains(selectedCategory)) {
            selectedCategory = categories.first;
          }
          return AlertDialog(
            backgroundColor: tokens.colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadii.card,
              side: BorderSide(color: tokens.colors.divider),
            ),
            title: Text(
              'Edit Merchant Rule',
              style: TextStyle(color: tokens.colors.textPrimary),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isBuiltin)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Based on built-in template',
                        style: TextStyle(color: tokens.colors.gold),
                      ),
                    ),
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: tokens.colors.textPrimary),
                    decoration: _fieldDecoration(
                      context,
                      labelText: 'Merchant Name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    dropdownColor: tokens.colors.card,
                    decoration: _fieldDecoration(
                      context,
                      labelText: 'Transaction Type',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'expense',
                        child: Text('Expense'),
                      ),
                      DropdownMenuItem(value: 'income', child: Text('Income')),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        setDialogState(() => selectedType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    dropdownColor: tokens.colors.card,
                    decoration: _fieldDecoration(
                      context,
                      labelText: 'Category',
                    ),
                    items: categories
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
                  TextField(
                    controller: aliasesController,
                    style: TextStyle(color: tokens.colors.textPrimary),
                    decoration: _fieldDecoration(
                      context,
                      labelText: 'Aliases',
                      hintText: 'talabat.com, talabat app, طلبات',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Auto Approve',
                      style: TextStyle(color: tokens.colors.textPrimary),
                    ),
                    value: autoApprove,
                    onChanged: (bool value) {
                      setDialogState(() => autoApprove = value);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Rule Enabled',
                      style: TextStyle(color: tokens.colors.textPrimary),
                    ),
                    value: enabled,
                    onChanged: (bool value) {
                      setDialogState(() => enabled = value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              if (isBuiltin && rule.isBuiltinOverride)
                TextButton(
                  onPressed: () async {
                    await controller.resetBuiltinMerchantRule(
                      rule.merchantName,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Reset to Built-in Defaults'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final String merchantName = nameController.text.trim();
                  if (merchantName.isEmpty) return;
                  final List<String> aliases = aliasesController.text
                      .split(',')
                      .map((String alias) => alias.trim())
                      .where((String alias) => alias.isNotEmpty)
                      .toList(growable: false);
                  if (merchantName.toLowerCase() != originalKey) {
                    await controller.deleteMerchantRule(rule.merchantName);
                  }
                  await controller.saveCustomMerchantRule(
                    rule.copyWith(
                      merchantName: merchantName,
                      categoryId: selectedCategory,
                      defaultType: selectedType,
                      autoApprove: autoApprove,
                      aliases: aliases,
                      enabled: enabled,
                      source: isBuiltin ? 'custom' : rule.source,
                      isBuiltinOverride: isBuiltin,
                      builtinKey: isBuiltin
                          ? (rule.builtinKey ?? originalKey)
                          : rule.builtinKey,
                    ),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateController>().state;
    final controller = context.read<AppStateController>();
    final tokens = context.premiumTokens;

    // Collect all rules:
    final List<MerchantRule> builtinRules = SmartCaptureParser
        .builtinMerchantCategoryMap
        .entries
        .map((e) {
          final key = e.key;
          final override = state.merchantRules[key];
          return override?.copyWith(
                isBuiltinOverride: true,
                source: 'custom',
                builtinKey: key,
              ) ??
              MerchantRule(
                merchantName: SmartCaptureParser.normalizeMerchantName(key),
                categoryId: e.value,
                defaultType: 'expense',
                autoApprove: true,
                usageCount: 0,
                confidence: 1.0,
                source: 'builtin',
                aliases: SmartCaptureParser.aliasesForMerchant(key).toList(),
              );
        })
        .toList();

    final List<MerchantRule> learnedRules = state.merchantRules.values
        .where((r) => r.source == 'learned')
        .toList();

    final List<MerchantRule> customRules = state.merchantRules.values
        .where((r) => r.source == 'custom' && !r.isBuiltinOverride)
        .toList();

    List<MerchantRule> displayedRules = [];
    if (_selectedSection == 'All') {
      displayedRules = [...customRules, ...learnedRules, ...builtinRules];
    } else if (_selectedSection == 'Built-in') {
      displayedRules = builtinRules;
    } else if (_selectedSection == 'Learned') {
      displayedRules = learnedRules;
    } else if (_selectedSection == 'Custom') {
      displayedRules = customRules;
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      displayedRules = displayedRules.where((rule) {
        final aliases = SmartCaptureParser.aliasesForMerchant(
          rule.merchantName,
        );
        return rule.merchantName.toLowerCase().contains(query) ||
            rule.categoryId.toLowerCase().contains(query) ||
            rule.aliases.any((alias) => alias.toLowerCase().contains(query)) ||
            aliases.any((alias) => alias.toLowerCase().contains(query));
      }).toList();
    }

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        title: const Text('Merchant Rules'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Add Rule',
            onPressed: () => _showAddCustomRuleDialog(context, controller),
            icon: Icon(Icons.add, color: tokens.colors.gold),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCustomRuleDialog(context, controller),
        elevation: 10,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          120,
        ),
        children: <Widget>[
          _buildRulesHeader(context, controller, state),
          const SizedBox(height: AppSpacing.lg),
          _buildSectionTabs(
            context,
            customCount: customRules.length,
            learnedCount: learnedRules.length,
            builtinCount: builtinRules.length,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (displayedRules.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 72),
              child: Center(
                child: Text(
                  'No rules in this section',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: tokens.colors.textSecondary,
                  ),
                ),
              ),
            )
          else if (_selectedSection == 'All' && _searchQuery.isEmpty)
            Column(
              children: <Widget>[
                _buildRuleGroup(
                  context,
                  title: 'Built-in Rules',
                  rules: builtinRules,
                  controller: controller,
                  showHeader: true,
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildRuleGroup(
                  context,
                  title: 'Learned Rules',
                  rules: learnedRules,
                  controller: controller,
                  showHeader: true,
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildRuleGroup(
                  context,
                  title: 'Custom Rules',
                  rules: customRules,
                  controller: controller,
                  showHeader: true,
                ),
              ],
            )
          else
            _buildRuleGroup(
              context,
              title: 'Results',
              rules: displayedRules,
              controller: controller,
              showHeader: false,
            ),
        ],
      ),
    );
  }

  Widget _buildRulesHeader(
    BuildContext context,
    AppStateController controller,
    dynamic state,
  ) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color surfaceColor = dark
        ? tokens.colors.surface.withValues(alpha: 0.74)
        : const Color(0xFFF9F7F0);
    final Color fieldColor = dark
        ? tokens.colors.card.withValues(alpha: 0.88)
        : const Color(0xFFEBE7DD);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: AppRadii.card,
        border: Border.all(
          color: tokens.colors.divider.withValues(alpha: 0.65),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Enable Auto Approval',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: tokens.colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Switch(
                value: state.smartCaptureAutoApproveEnabled,
                activeThumbColor: tokens.colors.gold,
                activeTrackColor: tokens.colors.emerald.withValues(alpha: 0.35),
                onChanged: controller.setSmartCaptureAutoApproveEnabled,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'Transactions matching rules with >=95% confidence are approved automatically.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.colors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim();
              });
            },
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search merchants...',
              filled: true,
              fillColor: fieldColor,
              prefixIcon: Icon(Icons.search, color: tokens.colors.gold),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        color: tokens.colors.textSecondary,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: AppRadii.card,
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadii.card,
                borderSide: BorderSide(
                  color: tokens.colors.divider.withValues(alpha: 0.55),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadii.card,
                borderSide: BorderSide(color: tokens.colors.gold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTabs(
    BuildContext context, {
    required int customCount,
    required int learnedCount,
    required int builtinCount,
  }) {
    final tokens = context.premiumTokens;
    final Color inactiveColor = tokens.colors.textSecondary;
    return Row(
      children: <Widget>[
        _buildSectionTab(context, 'All', null, inactiveColor),
        const SizedBox(width: AppSpacing.md),
        _buildSectionTab(context, 'Custom', customCount, inactiveColor),
        const SizedBox(width: AppSpacing.md),
        _buildSectionTab(context, 'Learned', learnedCount, inactiveColor),
        const SizedBox(width: AppSpacing.md),
        _buildSectionTab(context, 'Built-in', builtinCount, inactiveColor),
      ],
    );
  }

  Widget _buildSectionTab(
    BuildContext context,
    String label,
    int? count,
    Color inactiveColor,
  ) {
    final tokens = context.premiumTokens;
    final bool selected = _selectedSection == label;
    final String text = count == null ? label : '$label ($count)';
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
                  color: selected ? tokens.colors.hero : inactiveColor,
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

  Widget _buildRuleGroup(
    BuildContext context, {
    required String title,
    required List<MerchantRule> rules,
    required AppStateController controller,
    required bool showHeader,
  }) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color groupColor = dark
        ? tokens.colors.surface.withValues(alpha: 0.78)
        : const Color(0xFFFAF8F2);
    if (rules.isEmpty && !showHeader) {
      return Padding(
        padding: const EdgeInsets.only(top: 72),
        child: Center(
          child: Text(
            'No rules in this section',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (showHeader) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                '$title (${rules.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: tokens.colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Divider(
              height: 1,
              color: tokens.colors.divider.withValues(alpha: 0.5),
            ),
          ],
          if (rules.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'No rules yet',
                style: TextStyle(color: tokens.colors.textSecondary),
              ),
            )
          else
            ...List<Widget>.generate(
              rules.length,
              (int index) => Column(
                children: <Widget>[
                  _buildRuleRow(context, rules[index], controller),
                  if (index != rules.length - 1)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: tokens.colors.divider.withValues(alpha: 0.55),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRuleRow(
    BuildContext context,
    MerchantRule rule,
    AppStateController controller,
  ) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = dark
        ? tokens.colors.textPrimary
        : const Color(0xFF042F2B);
    final Color subdued = tokens.colors.textSecondary;
    final String sourceLabel = rule.source == 'builtin'
        ? 'Built-in'
        : rule.source == 'learned'
        ? 'Learned'
        : 'Custom';
    final Color sourceColor = switch (rule.source) {
      'builtin' => tokens.colors.textSecondary,
      'learned' => tokens.colors.warning,
      _ => tokens.colors.emerald,
    };
    final Widget rowContent = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  rule.merchantName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Category: ${rule.categoryId} • Type: ${rule.defaultType.toUpperCase()}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: subdued,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    _smallBadge(
                      context,
                      label: sourceLabel,
                      color: sourceColor,
                    ),
                    _smallBadge(
                      context,
                      label: '${(rule.confidence * 100).toStringAsFixed(0)}%',
                      color: tokens.colors.gold,
                    ),
                    _smallBadge(
                      context,
                      label: rule.enabled ? 'Enabled' : 'Disabled',
                      color: rule.enabled
                          ? tokens.colors.success
                          : tokens.colors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            rule.enabled && rule.autoApprove
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked,
            color: rule.enabled && rule.autoApprove
                ? tokens.colors.gold
                : tokens.colors.textSecondary,
          ),
        ],
      ),
    );

    final bool isCustom = rule.source == 'custom' && !rule.isBuiltinOverride;

    if (isCustom) {
      return Slidable(
        key: Key('rule_${rule.merchantName}'),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.25,
          children: <Widget>[
            CustomSlidableAction(
              onPressed: (BuildContext context) {
                controller.deleteMerchantRule(rule.merchantName);
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
          onTap: () => _showEditRuleDialog(context, controller, rule),
          child: rowContent,
        ),
      );
    }

    return InkWell(
      onTap: () => _showEditRuleDialog(context, controller, rule),
      child: rowContent,
    );
  }

  Widget _smallBadge(
    BuildContext context, {
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadii.pill,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
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
