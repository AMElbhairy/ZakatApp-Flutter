import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;


import '../../core/i18n/app_localizations.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/app_state.dart';
import '../../models/backup_preview.dart';
import '../../models/market_snapshot.dart';
import '../../models/recurring_transaction.dart';
import '../../core/services/zakat_engine.dart';
import '../../services/app_state_controller.dart';
import '../../services/auth_controller.dart';
import '../../services/backup_restore_card.dart';
import '../../services/cloud_backup_controller.dart';

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
  final TextEditingController _aiKey1Controller = TextEditingController();
  final TextEditingController _aiKey2Controller = TextEditingController();
  String _lastUpdated = '';
  bool _marketInitialized = false;
  bool _isRefreshingMarket = false;
  String _refreshMarketMessage = '';
  bool _manualOverrideExpanded = false;
  bool _categoriesExpanded = false;
  bool _recurringExpanded = false;
  bool _securityExpanded = false;
  bool _aiExpanded = false;
  bool _aiInitialized = false;
  int _selectedAiKeyIndex = 0;
  bool _isTestingConnection = false;

  @override
  void dispose() {
    _goldController.dispose();
    _silverController.dispose();
    _usdController.dispose();
    _sarController.dispose();
    _aedController.dispose();
    _kwdController.dispose();
    _qarController.dispose();
    _aiKey1Controller.dispose();
    _aiKey2Controller.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final authController = context.watch<AuthController?>();
    final cloudBackupController = context.watch<CloudBackupController?>();
    final state = controller.state;

    final String mainCurrency = state.mainCurrency.isEmpty
        ? 'EGP'
        : state.mainCurrency;
    final String defaultEntryCurrency = state.defaultEntryCurrency.isEmpty
        ? 'EGP'
        : state.defaultEntryCurrency;
    final String zakatMethod = state.zakatMethod == 'annual'
        ? 'annual'
        : 'hawl';
    final String zakatNisabBasis = ZakatEngineService.normalizeZakatNisabBasis(
      state.zakatNisabBasis,
    );
    final String languagePreference = state.languagePreference == 'ar'
        ? 'ar'
        : 'en';
    final String themeMode = switch (state.themeMode) {
      'light' => 'light',
      'dark' => 'dark',
      _ => 'system',
    };

    final _AnnualDate annualDate = _AnnualDate.parse(state.zakatAnnualDate);
    final MarketSnapshot snapshot = controller.currentMarketSnapshot;
    _syncMarketControllers(snapshot);
    _syncAiControllers(state.aiSettings);


    final double navSafeBottomPadding =
        112 + MediaQuery.paddingOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, navSafeBottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            context.l10n.tr('settings'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
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
                context.read<AppStateController>().updateLanguagePreference(
                  value,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: context.l10n.tr('account_section'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (authController == null ||
                    !authController.isSignedIn) ...<Widget>[
                  Text(context.l10n.tr('signed_out_state')),
                  if (authController?.error != null &&
                      authController!.error!.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      authController.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    key: const Key('googleSignInButton'),
                    onPressed:
                        authController == null || authController.isLoading
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
              onExpansionChanged: (bool v) =>
                  setState(() => _categoriesExpanded = v),
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
              onExpansionChanged: (bool v) =>
                  setState(() => _recurringExpanded = v),
              children: <Widget>[
                ...state.recurringTransactions.map(
                  (RecurringTransaction item) => ListTile(
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
                  ),
                ),
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
                  initialValue: _supportedCurrencies.contains(mainCurrency)
                      ? mainCurrency
                      : 'EGP',
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('main_currency'),
                    border: OutlineInputBorder(),
                  ),
                  items: _supportedCurrencies
                      .map(
                        (String c) => DropdownMenuItem<String>(
                          value: c,
                          child: Text(
                            ZakatEngineService.getCurrencySymbol(
                              c,
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
                    context.read<AppStateController>().updateMainCurrency(
                      value,
                    );
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('settingsDefaultEntryCurrencyField'),
                  initialValue:
                      _supportedCurrencies.contains(defaultEntryCurrency)
                      ? defaultEntryCurrency
                      : 'EGP',
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('default_entry_currency'),
                    border: OutlineInputBorder(),
                  ),
                  items: _supportedCurrencies
                      .map(
                        (String c) => DropdownMenuItem<String>(
                          value: c,
                          child: Text(
                            ZakatEngineService.getCurrencySymbol(
                              c,
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
                    context
                        .read<AppStateController>()
                        .updateDefaultEntryCurrency(value);
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
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('settingsZakatNisabBasisField'),
                  initialValue: zakatNisabBasis,
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('cash_nisab'),
                    border: OutlineInputBorder(),
                  ),
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: ZakatEngineService.nisabBasisGold85,
                      child: Text(context.l10n.tr('nisab_gold_85')),
                    ),
                    DropdownMenuItem<String>(
                      value: ZakatEngineService.nisabBasisSilver595,
                      child: Text(context.l10n.tr('nisab_silver_595')),
                    ),
                  ],
                  onChanged: (String? value) {
                    if (value == null) return;
                    context.read<AppStateController>().updateZakatNisabBasis(
                      value,
                    );
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
                          items: List<DropdownMenuItem<int>>.generate(12, (
                            int index,
                          ) {
                            final int m = index + 1;
                            return DropdownMenuItem<int>(
                              value: m,
                              child: Text(m.toString()),
                            );
                          }, growable: false),
                          onChanged: (int? value) {
                            if (value == null) return;
                            final int d =
                                annualDate.day > _hijriMonthLength(value)
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
                Text(
                  '${context.l10n.tr('last_updated')}: ${_formatLastUpdatedForDisplay(_lastUpdated)}',
                ),
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
                  Text(
                    _localizedRefreshMessage(context, _refreshMarketMessage),
                  ),
                ],
                const SizedBox(height: 12),
                ExpansionTile(
                  key: const Key('marketAdvancedOverrideTile'),
                  title: Text(context.l10n.tr('advanced_manual_override')),
                  initiallyExpanded: _manualOverrideExpanded,
                  onExpansionChanged: (bool expanded) {
                    setState(() => _manualOverrideExpanded = expanded);
                  },
                  childrenPadding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 12,
                  ),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        children: <Widget>[
                          TextFormField(
                            key: const Key('marketGoldField'),
                            controller: _goldController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: context.l10n.tr(
                                'gold_24k_price_per_gram_egp',
                              ),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            key: const Key('marketSilverField'),
                            controller: _silverController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: context.l10n.tr(
                                'silver_price_per_gram_egp',
                              ),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            key: const Key('marketUsdField'),
                            controller: _usdController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: context.l10n.tr('usd_to_egp'),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            key: const Key('marketSarField'),
                            controller: _sarController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: context.l10n.tr('sar_to_egp'),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            key: const Key('marketAedField'),
                            controller: _aedController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: context.l10n.tr('aed_to_egp'),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            key: const Key('marketKwdField'),
                            controller: _kwdController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: context.l10n.tr('kwd_to_egp'),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            key: const Key('marketQarField'),
                            controller: _qarController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
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
                Text(
                  _cloudBackupSummary(cloudBackupController, authController),
                ),
                if (cloudBackupController != null &&
                    cloudBackupController.latestBackup?.effectiveUpdatedAt !=
                        null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    'Last cloud backup: ${_formatLastUpdatedForDisplay(cloudBackupController.latestBackup!.effectiveUpdatedAt!.toIso8601String())}',
                  ),
                ],
                if (cloudBackupController != null &&
                    cloudBackupController.statusMessage
                        .trim()
                        .isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(cloudBackupController.statusMessage),
                ],
                if (cloudBackupController != null &&
                    cloudBackupController.lastError
                        .trim()
                        .isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    cloudBackupController.lastError,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.tonal(
                      key: const Key('driveBackupNowButton'),
                      onPressed:
                          authController == null ||
                              !authController.isSignedIn ||
                              cloudBackupController == null ||
                              cloudBackupController.isBackingUp ||
                              cloudBackupController.isRestoring
                          ? null
                          : () => _handleCloudBackup(
                              context,
                              cloudBackupController,
                            ),
                      child: cloudBackupController?.isBackingUp == true
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Backup Now'),
                    ),
                    OutlinedButton(
                      key: const Key('driveRestoreFromCloudButton'),
                      onPressed:
                          authController == null ||
                              !authController.isSignedIn ||
                              cloudBackupController == null ||
                              cloudBackupController.isBackingUp ||
                              cloudBackupController.isRestoring
                          ? null
                          : () => _handleCloudRestore(
                              context,
                              cloudBackupController,
                            ),
                      child: cloudBackupController?.isRestoring == true
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Restore from Cloud'),
                    ),
                  ],
                ),
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
              onExpansionChanged: (bool v) =>
                  setState(() => _securityExpanded = v),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextFormField(
                        key: const Key('geminiKey1Field'),
                        controller: _aiKey1Controller,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: Localizations.localeOf(context).languageCode == 'ar'
                              ? 'مفتاح Gemini 1'
                              : 'Gemini Key 1',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.vpn_key),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('geminiKey2Field'),
                        controller: _aiKey2Controller,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: Localizations.localeOf(context).languageCode == 'ar'
                              ? 'مفتاح Gemini 2'
                              : 'Gemini Key 2',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.vpn_key),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        key: const Key('geminiDefaultKeyIndexField'),
                        value: _selectedAiKeyIndex,
                        decoration: InputDecoration(
                          labelText: Localizations.localeOf(context).languageCode == 'ar'
                              ? 'المفتاح الافتراضي'
                              : 'Default Key',
                          border: const OutlineInputBorder(),
                        ),
                        items: <DropdownMenuItem<int>>[
                          DropdownMenuItem<int>(
                            value: 0,
                            child: Text(
                              Localizations.localeOf(context).languageCode == 'ar'
                                  ? 'المفتاح 1'
                                  : 'Key 1',
                            ),
                          ),
                          DropdownMenuItem<int>(
                            value: 1,
                            child: Text(
                              Localizations.localeOf(context).languageCode == 'ar'
                                  ? 'المفتاح 2'
                                  : 'Key 2',
                            ),
                          ),
                        ],
                        onChanged: (int? value) {
                          if (value == null) return;
                          setState(() {
                            _selectedAiKeyIndex = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          OutlinedButton.icon(
                            key: const Key('testGeminiConnectionButton'),
                            onPressed: _isTestingConnection ? null : _testAiConnection,
                            icon: _isTestingConnection
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.wifi),
                            label: Text(
                              Localizations.localeOf(context).languageCode == 'ar'
                                  ? 'اختبار الاتصال'
                                  : 'Test Connection',
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            key: const Key('saveGeminiKeysButton'),
                            onPressed: _saveAiKeys,
                            icon: const Icon(Icons.save),
                            label: Text(
                              Localizations.localeOf(context).languageCode == 'ar'
                                  ? 'حفظ'
                                  : 'Save AI Keys',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: context.l10n.tr('appearance_section'),
            child: DropdownButtonFormField<String>(
              key: const Key('settingsThemeModeField'),
              initialValue: themeMode,
              decoration: InputDecoration(
                labelText: context.l10n.tr('theme_mode'),
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'system',
                  child: Text(context.l10n.tr('theme_system')),
                ),
                DropdownMenuItem<String>(
                  value: 'light',
                  child: Text(context.l10n.tr('theme_light')),
                ),
                DropdownMenuItem<String>(
                  value: 'dark',
                  child: Text(context.l10n.tr('theme_dark')),
                ),
              ],
              onChanged: (String? value) {
                if (value == null) return;
                context.read<AppStateController>().updateThemeMode(value);
              },
            ),
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
          income
              ? context.l10n.tr('income_categories')
              : context.l10n.tr('expense_categories'),
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
                  onPressed: () =>
                      _promptCategoryRename(context, type, category),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, text.text.trim()),
            child: Text(context.l10n.tr('save')),
          ),
        ],
      ),
    );
    if (value == null || value.trim().isEmpty || !context.mounted) return;
    await context.read<AppStateController>().addCategory(
      type: type,
      name: value.trim(),
    );
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.tr('cancel')),
          ),
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

  Future<void> _deleteCategory(
    BuildContext context,
    String type,
    String name,
  ) async {
    final bool deleted = await context
        .read<AppStateController>()
        .deleteCategory(type: type, name: name);
    if (!deleted && context.mounted) {
      showTopSnackBar(
        context,
        context.l10n.tr('category_in_use'),
      );
    }
  }

  Future<void> _showAddRecurringDialog(BuildContext context) async {
    final TextEditingController name = TextEditingController();
    final TextEditingController amount = TextEditingController();
    final TextEditingController day = TextEditingController(text: '1');
    String type = 'income';
    String currency = context
        .read<AppStateController>()
        .state
        .defaultEntryCurrency;
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder:
            (
              BuildContext dialogContext,
              void Function(void Function()) setDialogState,
            ) {
              return AlertDialog(
                title: Text(context.l10n.tr('add_recurring')),
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
                      TextField(
                        controller: amount,
                        decoration: InputDecoration(
                          labelText: context.l10n.tr('amount'),
                        ),
                      ),
                      TextField(
                        controller: day,
                        decoration: InputDecoration(
                          labelText: context.l10n.tr('day_of_month'),
                        ),
                      ),
                      DropdownButton<String>(
                        value: type,
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
                        onChanged: (String? v) =>
                            setDialogState(() => type = v ?? type),
                      ),
                      DropdownButton<String>(
                        value: currency.isEmpty ? 'EGP' : currency,
                        items: _supportedCurrencies
                            .map(
                              (String c) => DropdownMenuItem<String>(
                                value: c,
                                child: Text(
                                  ZakatEngineService.getCurrencySymbol(
                                    c,
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
                        onChanged: (String? v) =>
                            setDialogState(() => currency = v ?? currency),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.tr('cancel')),
          ),
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

  String _cloudBackupSummary(
    CloudBackupController? cloudBackupController,
    AuthController? authController,
  ) {
    if (authController == null || !authController.isSignedIn) {
      return 'Sign in with Google to enable hidden Google Drive backup.';
    }
    if (cloudBackupController == null) {
      return 'Google Drive backup is unavailable in this build.';
    }
    if (cloudBackupController.isChecking) {
      return 'Checking Google Drive backup...';
    }
    if (!cloudBackupController.hasCloudBackup) {
      return 'No cloud backup found yet.';
    }
    if (cloudBackupController.cloudBackupNewerThanLocal) {
      return 'A newer cloud backup is available.';
    }
    return 'Google Drive backup is connected.';
  }

  Future<void> _handleCloudBackup(
    BuildContext context,
    CloudBackupController cloudBackupController,
  ) async {
    bool force = false;
    if (cloudBackupController.cloudBackupNewerThanLocal) {
      final bool? overwrite = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Overwrite newer cloud backup?'),
          content: const Text(
            'The cloud backup is newer than the local data on this device. '
            'Backup Now will replace the newer cloud copy.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Overwrite'),
            ),
          ],
        ),
      );
      if (overwrite != true || !mounted) return;
      force = true;
    }

    final bool ok = await cloudBackupController.backupNow(
      forceIfCloudNewer: force,
    );
    if (!mounted) return;
    showTopSnackBar(
      this.context,
      ok ? 'Cloud backup completed.' : cloudBackupController.statusMessage,
    );
  }

  Future<void> _handleCloudRestore(
    BuildContext context,
    CloudBackupController cloudBackupController,
  ) async {
    final BackupPreview? preview = await cloudBackupController
        .previewLatestBackup();
    if (!mounted) return;
    if (preview == null) {
      showTopSnackBar(this.context, 'No cloud backup found.');
      return;
    }

    final bool? restore = await showDialog<bool>(
      context: this.context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Restore from Cloud'),
        content: Text(
          'Restore the latest Google Drive backup?\n\n'
          'Transactions: ${preview.transactionsCount}\n'
          'Savings: ${preview.savingsCount}\n'
          'Investments: ${preview.investmentsCount}\n'
          'Plans: ${preview.financialPlansCount}\n'
          'Exported: ${preview.exportedAt.isEmpty ? '-' : _formatLastUpdatedForDisplay(preview.exportedAt)}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (restore != true || !mounted) return;

    final bool ok = await cloudBackupController.restoreLatestBackup();
    if (!mounted) return;
    showTopSnackBar(
      this.context,
      ok ? 'Cloud restore completed.' : cloudBackupController.statusMessage,
    );
  }

  String _syncHealthSummary(SyncHealth health) {
    final String success = health.lastSuccessAt.isEmpty
        ? 'None'
        : health.lastSuccessAt;
    final String failure = health.lastFailureAt.isEmpty
        ? 'None'
        : health.lastFailureAt;
    final String error = health.lastError.isEmpty ? 'None' : health.lastError;
    return 'Last success: $success | Last failure: $failure | Pending writes: ${health.pendingWrites} | Last error: $error';
  }

  Future<void> _openCurrencyExchangeDialog(BuildContext context) async {
    final TextEditingController sourceAmount = TextEditingController();
    final TextEditingController targetAmount = TextEditingController();
    String sourceCurrency = context
        .read<AppStateController>()
        .state
        .mainCurrency;
    if (sourceCurrency.trim().isEmpty) sourceCurrency = 'EGP';
    String targetCurrency = _supportedCurrencies.firstWhere(
      (String c) => c != sourceCurrency,
      orElse: () => 'USD',
    );
    String sourceType = 'both';
    final String date = DateTime.now()
        .toUtc()
        .toIso8601String()
        .split('T')
        .first;

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder:
            (BuildContext ctx, void Function(void Function()) setDialogState) {
              final double available = context.read<AppStateController>().getAvailableBalance(
                    currency: sourceCurrency,
                    sourceType: sourceType,
                  );
              return AlertDialog(
                title: Text(context.l10n.tr('currency_exchange')),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      DropdownButtonFormField<String>(
                        initialValue: sourceType,
                        decoration: InputDecoration(
                          labelText: context.l10n.tr('exchange_source_type'),
                        ),
                        items: <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: 'both',
                            child: Text(context.l10n.tr('both')),
                          ),
                          DropdownMenuItem<String>(
                            value: 'savings',
                            child: Text(context.l10n.tr('savings')),
                          ),
                          DropdownMenuItem<String>(
                            value: 'income',
                            child: Text(context.l10n.tr('income')),
                          ),
                        ],
                        onChanged: (String? v) =>
                            setDialogState(() => sourceType = v ?? sourceType),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: sourceCurrency,
                        decoration: InputDecoration(
                          labelText: context.l10n.tr('source_currency'),
                        ),
                        items: _supportedCurrencies
                            .map(
                              (String c) => DropdownMenuItem<String>(
                                value: c,
                                child: Text(
                                  ZakatEngineService.getCurrencySymbol(
                                    c,
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
                        onChanged: (String? v) => setDialogState(
                          () => sourceCurrency = v ?? sourceCurrency,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0, bottom: 2.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            Localizations.localeOf(context).languageCode == 'ar'
                                ? 'الرصيد المتاح: ${available.toStringAsFixed(2)} $sourceCurrency'
                                : 'Available balance: ${available.toStringAsFixed(2)} $sourceCurrency',
                            style: TextStyle(
                              color: available <= 0 ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: targetCurrency,
                        decoration: InputDecoration(
                          labelText: context.l10n.tr('target_currency'),
                        ),
                        items: _supportedCurrencies
                            .where((String c) => c != sourceCurrency)
                            .map(
                              (String c) => DropdownMenuItem<String>(
                                value: c,
                                child: Text(
                                  ZakatEngineService.getCurrencySymbol(
                                    c,
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
                        onChanged: (String? v) => setDialogState(
                          () => targetCurrency = v ?? targetCurrency,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: sourceAmount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: context.l10n.tr('source_amount'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: targetAmount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: context.l10n.tr('target_amount'),
                        ),
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
                    onPressed: () {
                      final double sAmount = double.tryParse(sourceAmount.text.trim()) ?? 0;
                      if (sAmount <= 0) return;
                      if (sAmount > available) {
                        showTopSnackBar(
                          context,
                          Localizations.localeOf(context).languageCode == 'ar'
                              ? 'المبلغ المدخل أكبر من الرصيد المتاح'
                              : 'Amount entered exceeds available balance',
                        );
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
                    child: Text(context.l10n.tr('confirm')),
                  ),
                ],
              );
            },
      ),
    );

    if (ok != true || !context.mounted) {
      return;
    }
    final double sAmount = double.tryParse(sourceAmount.text.trim()) ?? 0;
    final double tAmount = double.tryParse(targetAmount.text.trim()) ?? 0;
    if (sAmount <= 0 || tAmount <= 0 || sourceCurrency == targetCurrency) {
      return;
    }
    try {
      await context.read<AppStateController>().executeCurrencyExchange(
        date: date,
        sourceType: sourceType,
        sourceCurrency: sourceCurrency,
        targetCurrency: targetCurrency,
        sourceAmount: sAmount,
        targetAmount: tAmount,
      );
      if (context.mounted) {
        showTopSnackBar(
          context,
          Localizations.localeOf(context).languageCode == 'ar'
              ? 'تم إجراء عملية التحويل بنجاح'
              : 'Currency exchange completed successfully',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showTopSnackBar(
          context,
          Localizations.localeOf(context).languageCode == 'ar'
              ? 'فشل التحويل: $e'
              : 'Exchange failed: $e',
        );
      }
    }
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
    final result = await context.read<AppStateController>().refreshMarketData(
      force: true,
    );
    if (!mounted) return;
    final MarketSnapshot updated = context
        .read<AppStateController>()
        .currentMarketSnapshot;
    setState(() {
      _isRefreshingMarket = false;
      _marketInitialized = false;
      _syncMarketControllers(updated);
      _refreshMarketMessage = result.message;
    });
  }

  String _localizedRefreshMessage(BuildContext context, String raw) {
    if (raw == 'Market data refreshed.') {
      return context.l10n.tr('market_data_refreshed');
    }
    if (raw == 'Using last saved market data') {
      return 'Using last saved market data';
    }
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

  void _syncAiControllers(Map<String, dynamic>? aiSettings) {
    if (_aiInitialized) return;
    if (aiSettings != null) {
      final List<dynamic>? keysList = aiSettings['keys'] as List<dynamic>?;
      if (keysList != null && keysList.isNotEmpty) {
        _aiKey1Controller.text = keysList[0]?.toString() ?? '';
        if (keysList.length > 1) {
          _aiKey2Controller.text = keysList[1]?.toString() ?? '';
        }
      }
      _selectedAiKeyIndex = (aiSettings['defaultKeyIndex'] as int?) ?? 0;
    }
    _aiInitialized = true;
  }

  Future<void> _saveAiKeys() async {
    final Map<String, dynamic> nextSettings = Map<String, dynamic>.from(
      context.read<AppStateController>().state.aiSettings ?? <String, dynamic>{},
    );
    nextSettings['keys'] = <String>[
      _aiKey1Controller.text.trim(),
      _aiKey2Controller.text.trim(),
    ];
    nextSettings['defaultKeyIndex'] = _selectedAiKeyIndex;
    
    await context.read<AppStateController>().updateAiSettings(nextSettings);
    
    if (!mounted) return;
    showTopSnackBar(
      context,
      Localizations.localeOf(context).languageCode == 'ar'
          ? 'تم حفظ مفاتيح الذكاء الاصطناعي بنجاح'
          : 'AI Keys saved successfully',
    );
  }

  Future<void> _testAiConnection() async {
    final String key = _selectedAiKeyIndex == 0
        ? _aiKey1Controller.text.trim()
        : _aiKey2Controller.text.trim();
    if (key.isEmpty) {
      showTopSnackBar(
        context,
        Localizations.localeOf(context).languageCode == 'ar'
            ? 'الرجاء إدخال مفتاح صالح للفحص'
            : 'Please enter a valid key to test',
      );
      return;
    }
    setState(() => _isTestingConnection = true);
    try {
      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=$key',
        ),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'contents': <Map<String, dynamic>>[
            <String, dynamic>{
              'parts': <Map<String, dynamic>>[
                <String, dynamic>{
                  'text': 'Reply with OK only.',
                },
              ],
            },
          ],
        }),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded.containsKey('candidates')) {
          if (mounted) {
            showTopSnackBar(
              context,
              Localizations.localeOf(context).languageCode == 'ar'
                  ? 'تم الاتصال بنجاح!'
                  : 'Connection successful!',
            );
          }
          return;
        }
      }
      throw Exception('API responded with code ${response.statusCode}: ${response.body}');
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          context,
          Localizations.localeOf(context).languageCode == 'ar'
              ? 'فشل الاتصال: $e'
              : 'Connection failed: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTestingConnection = false);
      }
    }
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
