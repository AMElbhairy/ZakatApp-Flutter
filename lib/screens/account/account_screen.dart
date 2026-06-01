import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/i18n/app_localizations.dart';
import '../../models/app_state.dart';
import '../../models/market_snapshot.dart';
import '../../models/recurring_transaction.dart';
import '../../services/app_state_controller.dart';
import '../../services/auth_controller.dart';
import '../../services/backup_restore_card.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  static const List<String> _supportedCurrencies = <String>[
    'EGP',
    'SAR',
    'USD',
    'AED',
    'KWD',
    'QAR',
  ];

  final TextEditingController _goldController = TextEditingController();
  final TextEditingController _silverController = TextEditingController();
  final TextEditingController _usdController = TextEditingController();
  final TextEditingController _sarController = TextEditingController();
  final TextEditingController _aedController = TextEditingController();
  final TextEditingController _kwdController = TextEditingController();
  final TextEditingController _qarController = TextEditingController();
  String _lastUpdated = '';
  bool _marketInitialized = false;
  bool _isRefreshingMarket = false;
  String _refreshMarketMessage = '';
  bool _manualOverrideExpanded = false;
  bool _categoriesExpanded = false;
  bool _recurringExpanded = false;
  bool _securityExpanded = false;
  bool _aiExpanded = false;

  @override
  void dispose() {
    _goldController.dispose();
    _silverController.dispose();
    _usdController.dispose();
    _sarController.dispose();
    _aedController.dispose();
    _kwdController.dispose();
    _qarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final authController = context.watch<AuthController?>();
    final state = controller.state;

    final String mainCurrency =
        state.mainCurrency.isEmpty ? 'EGP' : state.mainCurrency;
    final String defaultEntryCurrency =
        state.defaultEntryCurrency.isEmpty ? 'EGP' : state.defaultEntryCurrency;
    final String zakatMethod = state.zakatMethod == 'annual' ? 'annual' : 'hawl';
    final String languagePreference =
        state.languagePreference == 'ar' ? 'ar' : 'en';

    final _AnnualDate annualDate = _AnnualDate.parse(state.zakatAnnualDate);
    final MarketSnapshot snapshot = controller.currentMarketSnapshot;
    _syncMarketControllers(snapshot);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
        Text(context.l10n.tr('settings'),
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        _SectionCard(
          title: context.l10n.tr('language'),
          child: DropdownButtonFormField<String>(
            key: const Key('settingsLanguageField'),
            initialValue: languagePreference,
            decoration: InputDecoration(
              labelText: context.l10n.tr('language_label'),
              border: OutlineInputBorder(),
            ),
            items: <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: 'en',
                child: Text(context.l10n.tr('english')),
              ),
              DropdownMenuItem<String>(
                value: 'ar',
                child: Text(context.l10n.tr('arabic')),
              ),
            ],
            onChanged: (String? value) {
              if (value == null) return;
              context.read<AppStateController>().updateLanguagePreference(value);
            },
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: context.l10n.tr('account_section'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (authController == null || !authController.isSignedIn) ...<Widget>[
                Text(context.l10n.tr('signed_out_state')),
                if (authController?.error != null &&
                    authController!.error!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    authController.error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const Key('googleSignInButton'),
                  onPressed: authController == null || authController.isLoading
                      ? null
                      : () => context.read<AuthController?>()?.signIn(),
                  icon: const Icon(Icons.login),
                  label: Text(context.l10n.tr('sign_in_google')),
                ),
              ] else ...<Widget>[
                Text(
                  authController.currentUser?.name ?? '-',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(authController.currentUser?.email ?? '-'),
                const SizedBox(height: 10),
                Text(_syncHealthSummary(state.syncHealth)),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  key: const Key('googleSignOutButton'),
                  onPressed: authController.isLoading
                      ? null
                      : () => context.read<AuthController?>()?.signOut(),
                  icon: const Icon(Icons.logout),
                  label: Text(context.l10n.tr('sign_out')),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: context.l10n.tr('categories_section'),
          child: ExpansionTile(
            key: const Key('settingsCategoriesTile'),
            title: Text(context.l10n.tr('categories_manage')),
            initiallyExpanded: _categoriesExpanded,
            onExpansionChanged: (bool v) => setState(() => _categoriesExpanded = v),
            children: <Widget>[
              _buildCategoryBlock(context, type: 'income'),
              const SizedBox(height: 8),
              _buildCategoryBlock(context, type: 'expense'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: context.l10n.tr('recurring_section'),
          child: ExpansionTile(
            key: const Key('settingsRecurringTile'),
            title: Text(context.l10n.tr('recurring_manage')),
            initiallyExpanded: _recurringExpanded,
            onExpansionChanged: (bool v) => setState(() => _recurringExpanded = v),
            children: <Widget>[
              ...state.recurringTransactions
                  .map((RecurringTransaction item) => ListTile(
                        dense: true,
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.type} • ${item.amount} ${item.currency} • ${context.l10n.tr('day_of_month')}: ${item.dayOfMonth}',
                        ),
                        trailing: IconButton(
                          key: Key('deleteRecurring_${item.id}'),
                          onPressed: () => context
                              .read<AppStateController>()
                              .deleteRecurringTransaction(item.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ))
                  ,
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  key: const Key('addRecurringButton'),
                  onPressed: () => _showAddRecurringDialog(context),
                  child: Text(context.l10n.tr('add_recurring')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: context.l10n.tr('currency_section'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DropdownButtonFormField<String>(
                key: const Key('settingsMainCurrencyField'),
                initialValue:
                    _supportedCurrencies.contains(mainCurrency) ? mainCurrency : 'EGP',
                decoration: InputDecoration(
                  labelText: context.l10n.tr('main_currency'),
                  border: OutlineInputBorder(),
                ),
                items: _supportedCurrencies
                    .map((String c) =>
                        DropdownMenuItem<String>(value: c, child: Text(c)))
                    .toList(growable: false),
                onChanged: (String? value) {
                  if (value == null) return;
                  context.read<AppStateController>().updateMainCurrency(value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('settingsDefaultEntryCurrencyField'),
                initialValue: _supportedCurrencies.contains(defaultEntryCurrency)
                    ? defaultEntryCurrency
                    : 'EGP',
                decoration: InputDecoration(
                  labelText: context.l10n.tr('default_entry_currency'),
                  border: OutlineInputBorder(),
                ),
                items: _supportedCurrencies
                    .map((String c) =>
                        DropdownMenuItem<String>(value: c, child: Text(c)))
                    .toList(growable: false),
                onChanged: (String? value) {
                  if (value == null) return;
                  context.read<AppStateController>().updateDefaultEntryCurrency(value);
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  key: const Key('openCurrencyExchangeButton'),
                  onPressed: () => _openCurrencyExchangeDialog(context),
                  child: Text(context.l10n.tr('currency_exchange')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: context.l10n.tr('zakat_calculation_section'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DropdownButtonFormField<String>(
                key: const Key('settingsZakatMethodField'),
                initialValue: zakatMethod,
                decoration: InputDecoration(
                  labelText: context.l10n.tr('method'),
                  border: OutlineInputBorder(),
                ),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'hawl',
                    child: Text(context.l10n.tr('monthly_hawl')),
                  ),
                  DropdownMenuItem<String>(
                    value: 'annual',
                    child: Text(context.l10n.tr('annual')),
                  ),
                ],
                onChanged: (String? value) {
                  if (value == null) return;
                  context.read<AppStateController>().updateZakatMethod(value);
                },
              ),
              if (zakatMethod == 'annual') ...<Widget>[
                const SizedBox(height: 12),
                Row(
                  key: const Key('settingsAnnualDateSection'),
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: const Key('settingsHijriMonthField'),
                        initialValue: annualDate.month,
                        decoration: InputDecoration(
                          labelText: context.l10n.tr('hijri_month'),
                          border: OutlineInputBorder(),
                        ),
                        items: List<DropdownMenuItem<int>>.generate(
                          12,
                          (int index) {
                            final int m = index + 1;
                            return DropdownMenuItem<int>(
                              value: m,
                              child: Text(m.toString()),
                            );
                          },
                          growable: false,
                        ),
                        onChanged: (int? value) {
                          if (value == null) return;
                          final int d = annualDate.day > _hijriMonthLength(value)
                              ? _hijriMonthLength(value)
                              : annualDate.day;
                          _updateAnnualDate(value, d);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: const Key('settingsHijriDayField'),
                        initialValue: annualDate.day,
                        decoration: InputDecoration(
                          labelText: context.l10n.tr('hijri_day'),
                          border: OutlineInputBorder(),
                        ),
                        items: List<DropdownMenuItem<int>>.generate(
                          _hijriMonthLength(annualDate.month),
                          (int index) {
                            final int d = index + 1;
                            return DropdownMenuItem<int>(
                              value: d,
                              child: Text(d.toString()),
                            );
                          },
                          growable: false,
                        ),
                        onChanged: (int? value) {
                          if (value == null) return;
                          _updateAnnualDate(annualDate.month, value);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: context.l10n.tr('market_data_section'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(context.l10n.tr('auto_refresh_market')),
              const SizedBox(height: 10),
              Text('${context.l10n.tr('last_updated')}: ${_formatLastUpdatedForDisplay(_lastUpdated)}'),
              const SizedBox(height: 12),
              FilledButton.tonal(
                key: const Key('refreshMarketDataButton'),
                onPressed: _isRefreshingMarket ? null : _refreshMarketData,
                child: _isRefreshingMarket
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.l10n.tr('refresh_market_data')),
              ),
              if (_refreshMarketMessage.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(_localizedRefreshMessage(context, _refreshMarketMessage)),
              ],
              const SizedBox(height: 12),
              ExpansionTile(
                key: const Key('marketAdvancedOverrideTile'),
                title: Text(context.l10n.tr('advanced_manual_override')),
                initiallyExpanded: _manualOverrideExpanded,
                onExpansionChanged: (bool expanded) {
                  setState(() => _manualOverrideExpanded = expanded);
                },
                childrenPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      children: <Widget>[
                        TextFormField(
                          key: const Key('marketGoldField'),
                          controller: _goldController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: context.l10n.tr('gold_24k_price_per_gram_egp'),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          key: const Key('marketSilverField'),
                          controller: _silverController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: context.l10n.tr('silver_price_per_gram_egp'),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          key: const Key('marketUsdField'),
                          controller: _usdController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: context.l10n.tr('usd_to_egp'),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          key: const Key('marketSarField'),
                          controller: _sarController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: context.l10n.tr('sar_to_egp'),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          key: const Key('marketAedField'),
                          controller: _aedController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: context.l10n.tr('aed_to_egp'),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          key: const Key('marketKwdField'),
                          controller: _kwdController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: context.l10n.tr('kwd_to_egp'),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          key: const Key('marketQarField'),
                          controller: _qarController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: context.l10n.tr('qar_to_egp'),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton(
                            key: const Key('saveMarketDataButton'),
                            onPressed: _saveMarketData,
                            child: Text(context.l10n.tr('save_market_data')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: context.l10n.tr('backup_sync_section'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(_syncHealthSummary(state.syncHealth)),
              const SizedBox(height: 8),
              Text(context.l10n.tr('drive_backup_coming_soon')),
              const SizedBox(height: 10),
              BackupRestoreCard(controller: controller),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: context.l10n.tr('security_section'),
          child: ExpansionTile(
            key: const Key('settingsSecurityTile'),
            title: Text(context.l10n.tr('danger_zone')),
            initiallyExpanded: _securityExpanded,
            onExpansionChanged: (bool v) => setState(() => _securityExpanded = v),
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  key: const Key('deleteAllDataButton'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => _confirmDeleteAllData(context),
                  child: Text(context.l10n.tr('delete_all_data')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: context.l10n.tr('ai_section'),
          child: ExpansionTile(
            key: const Key('settingsAiTile'),
            title: const Text('Gemini'),
            initiallyExpanded: _aiExpanded,
            onExpansionChanged: (bool v) => setState(() => _aiExpanded = v),
            children: <Widget>[
              ListTile(
                title: Text(context.l10n.tr('coming_soon')),
                subtitle: Text(context.l10n.tr('ai_coming_soon')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: context.l10n.tr('appearance_section'),
          child: Text(context.l10n.tr('appearance_placeholder')),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: context.l10n.tr('about_section'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('ZakatApp'),
              SizedBox(height: 4),
              Text(context.l10n.tr('about_version')),
              SizedBox(height: 4),
              Text(context.l10n.tr('about_build')),
            ],
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildCategoryBlock(BuildContext context, {required String type}) {
    final AppStateController controller = context.read<AppStateController>();
    final List<String> categories = type == 'income'
        ? controller.state.categories.income
        : controller.state.categories.expense;
    final bool income = type == 'income';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          income ? context.l10n.tr('income_categories') : context.l10n.tr('expense_categories'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        ...categories.map(
          (String category) => ListTile(
            dense: true,
            title: Text(category),
            trailing: Wrap(
              spacing: 8,
              children: <Widget>[
                TextButton(
                  onPressed: () => _promptCategoryRename(context, type, category),
                  child: Text(context.l10n.tr('edit')),
                ),
                TextButton(
                  onPressed: () => _deleteCategory(context, type, category),
                  child: Text(context.l10n.tr('delete')),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            key: Key('addCategory_$type'),
            onPressed: () => _promptAddCategory(context, type),
            child: Text(context.l10n.tr('add')),
          ),
        ),
      ],
    );
  }

  Future<void> _promptAddCategory(BuildContext context, String type) async {
    final TextEditingController text = TextEditingController();
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(context.l10n.tr('add_category')),
        content: TextField(controller: text),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.tr('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, text.text.trim()),
            child: Text(context.l10n.tr('save')),
          ),
        ],
      ),
    );
    if (value == null || value.trim().isEmpty || !context.mounted) return;
    await context.read<AppStateController>().addCategory(type: type, name: value.trim());
  }

  Future<void> _promptCategoryRename(
    BuildContext context,
    String type,
    String currentName,
  ) async {
    final TextEditingController text = TextEditingController(text: currentName);
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(context.l10n.tr('edit')),
        content: TextField(controller: text),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.tr('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, text.text.trim()),
            child: Text(context.l10n.tr('save')),
          ),
        ],
      ),
    );
    if (value == null || value.trim().isEmpty || !context.mounted) return;
    await context.read<AppStateController>().renameCategory(
          type: type,
          from: currentName,
          to: value.trim(),
        );
  }

  Future<void> _deleteCategory(BuildContext context, String type, String name) async {
    final bool deleted = await context.read<AppStateController>().deleteCategory(
          type: type,
          name: name,
        );
    if (!deleted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.tr('category_in_use'))),
      );
    }
  }

  Future<void> _showAddRecurringDialog(BuildContext context) async {
    final TextEditingController name = TextEditingController();
    final TextEditingController amount = TextEditingController();
    final TextEditingController day = TextEditingController(text: '1');
    String type = 'income';
    String currency = context.read<AppStateController>().state.defaultEntryCurrency;
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext dialogContext, void Function(void Function()) setDialogState) {
          return AlertDialog(
            title: Text(context.l10n.tr('add_recurring')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(controller: name, decoration: InputDecoration(labelText: context.l10n.tr('name'))),
                  TextField(controller: amount, decoration: InputDecoration(labelText: context.l10n.tr('amount'))),
                  TextField(controller: day, decoration: InputDecoration(labelText: context.l10n.tr('day_of_month'))),
                  DropdownButton<String>(
                    value: type,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(value: 'income', child: Text('income')),
                      DropdownMenuItem<String>(value: 'expense', child: Text('expense')),
                    ],
                    onChanged: (String? v) => setDialogState(() => type = v ?? type),
                  ),
                  DropdownButton<String>(
                    value: currency.isEmpty ? 'EGP' : currency,
                    items: _supportedCurrencies
                        .map((String c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                        .toList(growable: false),
                    onChanged: (String? v) => setDialogState(() => currency = v ?? currency),
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
                onPressed: () => Navigator.pop(dialogContext, 'ok'),
                child: Text(context.l10n.tr('save')),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !context.mounted) return;
    final int parsedDay = int.tryParse(day.text.trim()) ?? 1;
    final double parsedAmount = double.tryParse(amount.text.trim()) ?? 0;
    if (name.text.trim().isEmpty || parsedAmount <= 0) return;
    final List<String> categories = type == 'income'
        ? context.read<AppStateController>().state.categories.income
        : context.read<AppStateController>().state.categories.expense;
    final String category = categories.isEmpty ? '' : categories.first;
    await context.read<AppStateController>().addRecurringTransaction(
          RecurringTransaction(
            id: 'rt-${DateTime.now().microsecondsSinceEpoch}',
            name: name.text.trim(),
            type: type,
            amount: parsedAmount,
            currency: currency.isEmpty ? 'EGP' : currency,
            category: category,
            description: '',
            dayOfMonth: parsedDay.clamp(1, 28),
            frequency: 'monthly',
            lastProcessed: null,
            enabled: true,
            skipMonth: '',
            createdAt: DateTime.now().toUtc().toIso8601String(),
          ),
        );
  }

  Future<void> _confirmDeleteAllData(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(context.l10n.tr('delete_all_data')),
        content: Text(context.l10n.tr('delete_all_confirm')),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.tr('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.tr('delete')),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppStateController>().clearLocalData();
    }
  }

  String _syncHealthSummary(SyncHealth health) {
    final String success = health.lastSuccessAt.isEmpty ? 'None' : health.lastSuccessAt;
    final String failure = health.lastFailureAt.isEmpty ? 'None' : health.lastFailureAt;
    final String error = health.lastError.isEmpty ? 'None' : health.lastError;
    return 'Last success: $success | Last failure: $failure | Pending writes: ${health.pendingWrites} | Last error: $error';
  }

  Future<void> _openCurrencyExchangeDialog(BuildContext context) async {
    final TextEditingController sourceAmount = TextEditingController();
    final TextEditingController targetAmount = TextEditingController();
    String sourceCurrency = context.read<AppStateController>().state.mainCurrency;
    if (sourceCurrency.trim().isEmpty) sourceCurrency = 'EGP';
    String targetCurrency = _supportedCurrencies.firstWhere(
      (String c) => c != sourceCurrency,
      orElse: () => 'USD',
    );
    String sourceType = 'both';
    final String date = DateTime.now().toUtc().toIso8601String().split('T').first;

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, void Function(void Function()) setDialogState) {
          return AlertDialog(
            title: Text(context.l10n.tr('currency_exchange')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: sourceType,
                    decoration:
                        InputDecoration(labelText: context.l10n.tr('exchange_source_type')),
                    items: <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(value: 'both', child: Text(context.l10n.tr('both'))),
                      DropdownMenuItem<String>(value: 'savings', child: Text(context.l10n.tr('savings'))),
                      DropdownMenuItem<String>(value: 'income', child: Text(context.l10n.tr('income'))),
                    ],
                    onChanged: (String? v) => setDialogState(() => sourceType = v ?? sourceType),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: sourceCurrency,
                    decoration:
                        InputDecoration(labelText: context.l10n.tr('source_currency')),
                    items: _supportedCurrencies
                        .map((String c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                        .toList(growable: false),
                    onChanged: (String? v) => setDialogState(() => sourceCurrency = v ?? sourceCurrency),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: targetCurrency,
                    decoration:
                        InputDecoration(labelText: context.l10n.tr('target_currency')),
                    items: _supportedCurrencies
                        .where((String c) => c != sourceCurrency)
                        .map((String c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                        .toList(growable: false),
                    onChanged: (String? v) => setDialogState(() => targetCurrency = v ?? targetCurrency),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: sourceAmount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: context.l10n.tr('source_amount')),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: targetAmount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: context.l10n.tr('target_amount')),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.l10n.tr('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(context.l10n.tr('confirm')),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true || !context.mounted) return;
    final double sAmount = double.tryParse(sourceAmount.text.trim()) ?? 0;
    final double tAmount = double.tryParse(targetAmount.text.trim()) ?? 0;
    if (sAmount <= 0 || tAmount <= 0 || sourceCurrency == targetCurrency) return;
    await context.read<AppStateController>().executeCurrencyExchange(
          date: date,
          sourceType: sourceType,
          sourceCurrency: sourceCurrency,
          targetCurrency: targetCurrency,
          sourceAmount: sAmount,
          targetAmount: tAmount,
        );
  }

  void _syncMarketControllers(MarketSnapshot snapshot) {
    if (_marketInitialized) return;
    _goldController.text = _fmt(snapshot.gold24kPricePerGramEgp);
    _silverController.text = _fmt(snapshot.silverPricePerGramEgp);
    _usdController.text = _fmt(snapshot.usdToEgp);
    _sarController.text = _fmt(snapshot.sarToEgp);
    _aedController.text = _fmt(snapshot.aedToEgp);
    _kwdController.text = _fmt(snapshot.kwdToEgp);
    _qarController.text = _fmt(snapshot.qarToEgp);
    _lastUpdated = snapshot.lastUpdated;
    _marketInitialized = true;
  }

  Future<void> _saveMarketData() async {
    final String lastUpdated = DateTime.now().toUtc().toIso8601String();

    final MarketSnapshot snapshot = MarketSnapshot(
      gold24kPricePerGramEgp: _asDouble(_goldController.text),
      silverPricePerGramEgp: _asDouble(_silverController.text),
      usdToEgp: _asDouble(_usdController.text),
      sarToEgp: _asDouble(_sarController.text),
      aedToEgp: _asDouble(_aedController.text),
      kwdToEgp: _asDouble(_kwdController.text),
      qarToEgp: _asDouble(_qarController.text),
      eurToEgp: 0,
      gbpToEgp: 0,
      bhdToEgp: 0,
      omrToEgp: 0,
      jodToEgp: 0,
      tryToEgp: 0,
      myrToEgp: 0,
      pkrToEgp: 0,
      idrToEgp: 0,
      lastUpdated: lastUpdated,
    );

    await context.read<AppStateController>().updateMarketSnapshot(snapshot);
    if (!mounted) return;
    setState(() => _lastUpdated = lastUpdated);
  }

  Future<void> _refreshMarketData() async {
    setState(() {
      _isRefreshingMarket = true;
      _refreshMarketMessage = '';
    });
    final result = await context.read<AppStateController>().refreshMarketData(force: true);
    if (!mounted) return;
    final MarketSnapshot updated = context.read<AppStateController>().currentMarketSnapshot;
    setState(() {
      _isRefreshingMarket = false;
      _marketInitialized = false;
      _syncMarketControllers(updated);
      _refreshMarketMessage = result.message;
    });
  }

  String _localizedRefreshMessage(BuildContext context, String raw) {
    if (raw == 'Market data refreshed.') return context.l10n.tr('market_data_refreshed');
    if (raw == 'Using last saved market data') return 'Using last saved market data';
    if (raw == 'No market data refreshed. Manual prices required.') {
      return '${context.l10n.tr('no_market_data_refreshed')} ${context.l10n.tr('manual_prices_required')}';
    }
    return raw;
  }

  Future<void> _updateAnnualDate(int month, int day) {
    final String mm = month.toString().padLeft(2, '0');
    final String dd = day.toString().padLeft(2, '0');
    return context.read<AppStateController>().updateZakatAnnualDate('$mm-$dd');
  }

  static int _hijriMonthLength(int month) {
    return month == 12 ? 30 : ((month % 2 == 1) ? 30 : 29);
  }

  static double _asDouble(String value) {
    return double.tryParse(value.trim()) ?? 0;
  }

  static String _fmt(double value) {
    if (value == 0) return '';
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
  }

  static String _formatLastUpdatedForDisplay(String raw) {
    if (raw.trim().isEmpty) return '-';
    final DateTime? parsed = _tryParseLegacyOrIso(raw);
    if (parsed == null) return raw;
    return DateFormat('yyyy-MM-dd HH:mm').format(parsed.toLocal());
  }

  static DateTime? _tryParseLegacyOrIso(String raw) {
    try {
      return DateTime.parse(raw);
    } catch (_) {}
    final RegExp legacy = RegExp(r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})$');
    final Match? match = legacy.firstMatch(raw.trim());
    if (match == null) return null;
    final int y = int.parse(match.group(1)!);
    final int m = int.parse(match.group(2)!);
    final int d = int.parse(match.group(3)!);
    final int hh = int.parse(match.group(4)!);
    final int mm = int.parse(match.group(5)!);
    return DateTime(y, m, d, hh, mm);
  }
}

class _AnnualDate {
  const _AnnualDate({required this.month, required this.day});

  final int month;
  final int day;

  factory _AnnualDate.parse(String raw) {
    final List<String> parts = raw.split('-');
    final int m = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 9 : 9;
    final int d = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
    final int safeMonth = m.clamp(1, 12);
    final int maxDay = _AccountScreenState._hijriMonthLength(safeMonth);
    final int safeDay = d.clamp(1, maxDay);
    return _AnnualDate(month: safeMonth, day: safeDay);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
