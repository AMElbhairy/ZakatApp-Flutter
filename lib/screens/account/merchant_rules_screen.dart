import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../models/merchant_rule.dart';
import '../../services/app_state_controller.dart';
import '../../services/smart_capture_parser.dart';

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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: tokens.colors.textPrimary),
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
                                  child: Text(cat),
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
                    decoration: _fieldDecoration(context, labelText: 'Category'),
                    items: categories
                        .map(
                          (String category) => DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
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
      appBar: AppBar(title: const Text('Merchant Rules')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCustomRuleDialog(context, controller),
        elevation: 10,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: [
          // Settings Header
          Container(
            color: tokens.colors.surface,
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Enable Auto Approval',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Switch(
                      value: state.smartCaptureAutoApproveEnabled,
                      activeThumbColor: tokens.colors.gold,
                      onChanged: (val) {
                        controller.setSmartCaptureAutoApproveEnabled(val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'When enabled, transactions matching rules with >=95% confidence will be approved automatically.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),

          // Search Input Field
          Container(
            color: tokens.colors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              style: TextStyle(color: tokens.colors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search merchants...',
                prefixIcon: Icon(
                  Icons.search,
                  color: tokens.colors.gold,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: tokens.colors.textSecondary,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Sections Bar
          Container(
            color: tokens.colors.surface,
            padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionButton('All'),
                _buildSectionButton('Custom', count: customRules.length),
                _buildSectionButton('Learned', count: learnedRules.length),
                _buildSectionButton('Built-in', count: builtinRules.length),
              ],
            ),
          ),

          Expanded(
            child: displayedRules.isEmpty
                ? Center(
                    child: Text(
                      'No rules in this section',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : _selectedSection == 'All' && _searchQuery.isEmpty
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                    children: [
                      _buildRuleSection(
                        context,
                        'Built-in Rules',
                        builtinRules,
                        controller,
                        initiallyExpanded: true,
                      ),
                      _buildRuleSection(
                        context,
                        'Learned Rules',
                        learnedRules,
                        controller,
                        initiallyExpanded: true,
                      ),
                      _buildRuleSection(
                        context,
                        'Custom Rules',
                        customRules,
                        controller,
                        initiallyExpanded: true,
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                    itemCount: displayedRules.length,
                    itemBuilder: (context, index) {
                      final rule = displayedRules[index];
                      return _buildRuleCard(context, rule, controller);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionButton(String label, {int? count}) {
    final tokens = context.premiumTokens;
    final bool isSelected = _selectedSection == label;
    final String text = count != null ? '$label ($count)' : label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSection = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? tokens.colors.gold : tokens.colors.hero,
          borderRadius: AppRadii.pill,
          boxShadow: isSelected ? tokens.floatingShadow : const <BoxShadow>[],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? tokens.colors.hero : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildRuleCard(
    BuildContext context,
    MerchantRule rule,
    AppStateController controller,
  ) {
    final tokens = context.premiumTokens;
    Color badgeColor;
    String badgeText;
    switch (rule.source) {
      case 'custom':
        badgeColor = Theme.of(context).colorScheme.primary;
        badgeText = 'Custom';
        break;
      case 'learned':
        badgeColor = tokens.colors.warning;
        badgeText = 'Learned';
        break;
      default:
        badgeColor = tokens.colors.textSecondary;
        badgeText = 'Built-in';
    }

    return Card(
      color: tokens.colors.hero,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.card,
        side: BorderSide(color: tokens.colors.divider),
      ),
      child: InkWell(
        onTap: () => _showEditRuleDialog(context, controller, rule),
        borderRadius: AppRadii.card,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          rule.merchantName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                        if (rule.source != 'builtin') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: badgeColor, width: 0.5),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Category: ${rule.categoryId}',
                      style: TextStyle(
                        color: tokens.colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Type: ${rule.defaultType.toUpperCase()}',
                      style: TextStyle(color: tokens.colors.gold, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Confidence: ${(rule.confidence * 100).toStringAsFixed(0)}% • Usages: ${rule.usageCount}',
                      style: TextStyle(
                        color: tokens.colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  if (rule.source == 'custom' && !rule.isBuiltinOverride)
                    IconButton(
                      icon: Icon(Icons.delete, color: tokens.colors.danger),
                      onPressed: () {
                        controller.deleteMerchantRule(rule.merchantName);
                      },
                    ),
                  IconButton(
                    tooltip: rule.enabled ? 'Disable Rule' : 'Enable Rule',
                    onPressed: () {
                      controller.setMerchantRuleEnabled(rule, !rule.enabled);
                    },
                    icon: Icon(
                      rule.enabled && rule.autoApprove
                          ? Icons.check_circle
                          : Icons.radio_button_off,
                      color: rule.enabled && rule.autoApprove
                          ? tokens.colors.success
                          : tokens.colors.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuleSection(
    BuildContext context,
    String title,
    List<MerchantRule> rules,
    AppStateController controller, {
    bool initiallyExpanded = false,
  }) {
    final tokens = context.premiumTokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        collapsedBackgroundColor: tokens.colors.surface,
        backgroundColor: tokens.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.card,
          side: BorderSide(color: tokens.colors.divider),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: AppRadii.card,
          side: BorderSide(color: tokens.colors.divider),
        ),
        iconColor: tokens.colors.gold,
        collapsedIconColor: tokens.colors.textSecondary,
        title: Text(
          '$title (${rules.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: tokens.colors.textPrimary,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: rules.isEmpty
            ? <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No rules yet',
                    style: TextStyle(color: tokens.colors.textSecondary),
                  ),
                ),
              ]
            : rules
                .map((rule) => _buildRuleCard(context, rule, controller))
                .toList(growable: false),
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
