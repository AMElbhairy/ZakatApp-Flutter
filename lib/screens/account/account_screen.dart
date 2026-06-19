import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/i18n/app_localizations.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/market_snapshot.dart';
import '../../models/recurring_transaction.dart';
import 'categories_screen.dart';
import 'merchant_rules_screen.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/utils/amount_parser.dart';
import '../../models/user_profile.dart';
import '../../services/app_state_controller.dart';
import '../../services/auth_controller.dart';
import '../../features/auth/auth_service.dart';
import '../../services/backup_restore_card.dart';
import '../../core/widgets/currency_dropdown_form_field.dart';
import '../../services/biometric_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _mainCurrencyKey = GlobalKey();
  final GlobalKey _zakatMethodKey = GlobalKey();
  final GlobalKey _marketDataKey = GlobalKey();

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
  bool _recurringExpanded = false;
  bool _securityExpanded = false;
  bool _aiExpanded = false;
  bool _aiInitialized = false;
  int _selectedAiKeyIndex = 0;
  bool _isTestingConnection = false;

  @override
  void dispose() {
    _scrollController.dispose();
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
    return Stack(
      children: <Widget>[
        SingleChildScrollView(
          controller:
              PrimaryScrollController.maybeOf(context) ?? _scrollController,
          padding: EdgeInsets.fromLTRB(16, 16, 16, navSafeBottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _SettingsProfileHeader(
                name: authController?.currentUser?.displayName,
                email: authController?.currentUser?.email,
                photoUrl: authController?.currentUser?.photoUrl,
                connected: authController?.isSignedIn == true,
                isLoading: authController?.isLoading == true,
                onSignIn: authController == null
                    ? null
                    : () => context.read<AuthController?>()?.signIn(
                        provider: AuthProvider.google,
                      ),
                onSignOut: authController == null
                    ? null
                    : () async {
                        final AppStateController appStateController = context
                            .read<AppStateController>();
                        final UserProfile? user = authController.currentUser;
                        if (user == null) {
                          await authController.signOut();
                          return;
                        }
                        if (appStateController.state.biometricExportEnabled &&
                            await BiometricService.canAuthenticate()) {
                          final bool auth = await BiometricService.authenticate(
                            reason:
                                'Confirm identity to back up before signing out',
                            isSensitiveAction: true,
                          );
                          if (!auth) return;
                        }

                        await appStateController.clearLocalDataForSignOut(
                          userId: user.id,
                        );
                        await authController.signOut();
                      },
              ),
              const SizedBox(height: 18),
              _SettingsOverview(
                mainCurrency: mainCurrency,
                defaultCurrency: defaultEntryCurrency,
                zakatMethod: zakatMethod,
                nisabBasis: zakatNisabBasis,
                goldPrice: snapshot.gold24kPricePerGramEgp,
                silverPrice: snapshot.silverPricePerGramEgp,
                lastUpdated: _formatLastUpdatedForDisplay(_lastUpdated),
                refreshing: _isRefreshingMarket,
                onRefresh: _isRefreshingMarket ? null : _refreshMarketData,
                isArabic:
                    Localizations.localeOf(
                      context,
                    ).languageCode.toLowerCase() ==
                    'ar',
                onTapMainCurrency: () {
                  Scrollable.ensureVisible(
                    _mainCurrencyKey.currentContext!,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: 0.1,
                  );
                },
                onTapDefaultCurrency: () {
                  Scrollable.ensureVisible(
                    _mainCurrencyKey.currentContext!,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: 0.1,
                  );
                },
                onTapZakatMethod: () {
                  Scrollable.ensureVisible(
                    _zakatMethodKey.currentContext!,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: 0.1,
                  );
                },
                onTapNisabBasis: () {
                  Scrollable.ensureVisible(
                    _zakatMethodKey.currentContext!,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: 0.1,
                  );
                },
                onTapMarket: () {
                  Scrollable.ensureVisible(
                    _marketDataKey.currentContext!,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: 0.1,
                  );
                },
              ),
              const SizedBox(height: 22),
              Text(
                context.l10n.tr('settings'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              _SectionCard(
                title: context.l10n.tr('preferences_section'),
                child: Column(
                  children: <Widget>[
                    _SettingsRowTile(
                      key: const Key('settingsLanguageTile'),
                      icon: Icons.language_outlined,
                      title: context.l10n.tr('language'),
                      value: languagePreference == 'ar' ? 'العربية' : 'English',
                      onTap: () async {
                        final String? selected = await showDialog<String>(
                          context: context,
                          builder: (BuildContext ctx) => SimpleDialog(
                            title: Text(context.l10n.tr('language_label')),
                            children: <Widget>[
                              SimpleDialogOption(
                                onPressed: () => Navigator.pop(ctx, 'en'),
                                child: Text(context.l10n.tr('english')),
                              ),
                              SimpleDialogOption(
                                onPressed: () => Navigator.pop(ctx, 'ar'),
                                child: Text(context.l10n.tr('arabic')),
                              ),
                            ],
                          ),
                        );
                        if (selected != null && context.mounted) {
                          context
                              .read<AppStateController>()
                              .updateLanguagePreference(selected);
                        }
                      },
                    ),
                    const Divider(height: 1, indent: 36),
                    _SettingsRowTile(
                      key: const Key('settingsCategoriesTile'),
                      icon: Icons.folder_outlined,
                      title: context.l10n.tr('categories_section'),
                      onTap: () {
                        Navigator.of(context).push(CategoriesScreen.route());
                      },
                    ),
                    const Divider(height: 1, indent: 36),
                    _SettingsRowTile(
                      key: const Key('settingsMerchantRulesTile'),
                      icon: Icons.rule_folder_outlined,
                      title: context.l10n.tr('merchant_rules_section'),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MerchantRulesScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 36),
                    _SettingsRowTile(
                      key: const Key('settingsRecurringTile'),
                      icon: Icons.event_repeat_outlined,
                      title: context.l10n.tr('recurring_section'),
                      onTap: () {
                        setState(
                          () => _recurringExpanded = !_recurringExpanded,
                        );
                      },
                    ),
                    if (_recurringExpanded)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 36,
                          top: 4,
                          bottom: 8,
                        ),
                        child: Column(
                          children: [
                            ...state.recurringTransactions.map(
                              (RecurringTransaction item) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
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
                                onPressed: () =>
                                    _showAddRecurringDialog(context),
                                child: Text(context.l10n.tr('add_recurring')),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Security',
                child: Column(
                  children: [
                    _buildSecuritySwitch(
                      context: context,
                      icon: Icons.fingerprint_outlined,
                      title: 'Biometric App Lock',
                      value: state.biometricLockEnabled,
                      onChanged: (bool val) async {
                        final canAuth =
                            await BiometricService.canAuthenticate();
                        if (!canAuth) {
                          if (!context.mounted) return;
                          showTopSnackBar(
                            context,
                            'Biometrics are not available or configured on this device.',
                            kind: AppToastKind.warning,
                          );
                          return;
                        }
                        final authenticated = await BiometricService.authenticate(
                          reason: val
                              ? 'Confirm identity to enable Biometric App Lock'
                              : 'Confirm identity to disable Biometric App Lock',
                        );
                        if (authenticated && context.mounted) {
                          context
                              .read<AppStateController>()
                              .updateBiometricLockEnabled(val);
                        }
                      },
                    ),
                    const Divider(height: 1, indent: 36),
                    _buildSecurityDropdown(
                      context: context,
                      icon: Icons.timer_outlined,
                      title: 'Auto Lock Delay',
                      value: state.biometricAutoLockDelay,
                      onChanged: (String? val) {
                        if (val != null) {
                          context
                              .read<AppStateController>()
                              .updateBiometricAutoLockDelay(val);
                        }
                      },
                    ),
                    const Divider(height: 1, indent: 36),
                    _buildSecuritySwitch(
                      context: context,
                      icon: Icons.visibility_off_outlined,
                      title: 'Hide Wealth Values',
                      value: state.biometricHideWealthEnabled,
                      onChanged: (bool val) {
                        context
                            .read<AppStateController>()
                            .updateBiometricHideWealthEnabled(val);
                      },
                    ),
                    const Divider(height: 1, indent: 36),
                    _buildSecuritySwitch(
                      context: context,
                      icon: Icons.lock_outline_rounded,
                      title: 'Protect Exports & Delete',
                      value: state.biometricExportEnabled,
                      onChanged: (bool val) {
                        context
                            .read<AppStateController>()
                            .updateBiometricExportEnabled(val);
                      },
                    ),
                    const Divider(height: 1, indent: 36),
                    _buildSecuritySwitch(
                      context: context,
                      icon: Icons.restore_outlined,
                      title: 'Protect Restore & Import',
                      value: state.biometricRestoreEnabled,
                      onChanged: (bool val) {
                        context
                            .read<AppStateController>()
                            .updateBiometricRestoreEnabled(val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                key: _mainCurrencyKey,
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
                key: _zakatMethodKey,
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
                        context.read<AppStateController>().updateZakatMethod(
                          value,
                        );
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
                        context
                            .read<AppStateController>()
                            .updateZakatNisabBasis(value);
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
                key: _marketDataKey,
                title: context.l10n.tr('market_data_section'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _MarketSummary(
                      goldPrice: snapshot.gold24kPricePerGramEgp,
                      silverPrice: snapshot.silverPricePerGramEgp,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${context.l10n.tr('last_updated')}: ${_formatLastUpdatedForDisplay(_lastUpdated)}',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      key: const Key('refreshMarketDataButton'),
                      onPressed: _isRefreshingMarket
                          ? null
                          : _refreshMarketData,
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
                        _localizedRefreshMessage(
                          context,
                          _refreshMarketMessage,
                        ),
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
                                keyboardType:
                                    const TextInputType.numberWithOptions(
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
                                keyboardType:
                                    const TextInputType.numberWithOptions(
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
                                keyboardType:
                                    const TextInputType.numberWithOptions(
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
                                keyboardType:
                                    const TextInputType.numberWithOptions(
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
                                keyboardType:
                                    const TextInputType.numberWithOptions(
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
                                keyboardType:
                                    const TextInputType.numberWithOptions(
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
                                keyboardType:
                                    const TextInputType.numberWithOptions(
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
                                  child: Text(
                                    context.l10n.tr('save_market_data'),
                                  ),
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
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.cloud_done_outlined,
                          size: 18,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cloud Sync: Active',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ExpansionTile(
                      title: Text(
                        context.l10n.tr('local_backup_options'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      tilePadding: EdgeInsets.zero,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: BackupRestoreCard(controller: controller),
                        ),
                      ],
                    ),
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
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
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
                  onExpansionChanged: (bool v) =>
                      setState(() => _aiExpanded = v),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.0,
                        vertical: 8.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextFormField(
                            key: const Key('geminiKey1Field'),
                            controller: _aiKey1Controller,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText:
                                  Localizations.localeOf(
                                        context,
                                      ).languageCode ==
                                      'ar'
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
                              labelText:
                                  Localizations.localeOf(
                                        context,
                                      ).languageCode ==
                                      'ar'
                                  ? 'مفتاح Gemini 2'
                                  : 'Gemini Key 2',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.vpn_key),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            key: const Key('geminiDefaultKeyIndexField'),
                            initialValue: _selectedAiKeyIndex,
                            decoration: InputDecoration(
                              labelText:
                                  Localizations.localeOf(
                                        context,
                                      ).languageCode ==
                                      'ar'
                                  ? 'المفتاح الافتراضي'
                                  : 'Default Key',
                              border: const OutlineInputBorder(),
                            ),
                            items: <DropdownMenuItem<int>>[
                              DropdownMenuItem<int>(
                                value: 0,
                                child: Text(
                                  Localizations.localeOf(
                                            context,
                                          ).languageCode ==
                                          'ar'
                                      ? 'المفتاح 1'
                                      : 'Key 1',
                                ),
                              ),
                              DropdownMenuItem<int>(
                                value: 1,
                                child: Text(
                                  Localizations.localeOf(
                                            context,
                                          ).languageCode ==
                                          'ar'
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
                                onPressed: _isTestingConnection
                                    ? null
                                    : _testAiConnection,
                                icon: _isTestingConnection
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.wifi),
                                label: Text(
                                  Localizations.localeOf(
                                            context,
                                          ).languageCode ==
                                          'ar'
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
                                  Localizations.localeOf(
                                            context,
                                          ).languageCode ==
                                          'ar'
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
                    const _CompactInfoRow(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Zakah Wealth',
                    ),
                    _CompactInfoRow(
                      icon: Icons.info_outline,
                      label: context.l10n.tr('about_version'),
                    ),
                    _CompactInfoRow(
                      icon: Icons.build_outlined,
                      label: context.l10n.tr('about_build'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
    final state = context.read<AppStateController>().state;
    final l10n = context.l10n;
    if (state.biometricExportEnabled &&
        await BiometricService.canAuthenticate()) {
      final auth = await BiometricService.authenticate(
        reason: 'Confirm identity to delete all local database data',
        isSensitiveAction: true,
      );
      if (!auth) return;
    }
    if (!context.mounted) return;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l10n.tr('delete_all_data')),
        content: Text(l10n.tr('delete_all_confirm')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.tr('delete')),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppStateController>().clearLocalData();
    }
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
    final String date = DateTime.now()
        .toUtc()
        .toIso8601String()
        .split('T')
        .first;

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, void Function(void Function()) setDialogState) {
          final double available = context
              .read<AppStateController>()
              .getAvailableBalance(currency: sourceCurrency);
          return AlertDialog(
            title: Text(context.l10n.tr('currency_exchange')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CurrencyDropdownFormField(
                    key: const Key('exchangeSourceCurrencyField'),
                    value: sourceCurrency,
                    labelText: context.l10n.tr('source_currency'),
                    currencies: _supportedCurrencies,
                    onChanged: (String nextCurrency) {
                      setDialogState(() {
                        if (nextCurrency == targetCurrency) {
                          targetCurrency = sourceCurrency;
                        }
                        sourceCurrency = nextCurrency;
                      });
                    },
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
                  CurrencyDropdownFormField(
                    key: const Key('exchangeTargetCurrencyField'),
                    value: targetCurrency,
                    labelText: context.l10n.tr('target_currency'),
                    currencies: _supportedCurrencies
                        .where((String currency) => currency != sourceCurrency)
                        .toList(growable: false),
                    onChanged: (String nextCurrency) {
                      setDialogState(() => targetCurrency = nextCurrency);
                    },
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
                  final double sAmount = tryParseAmount(sourceAmount.text) ?? 0;
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
    final double sAmount = tryParseAmount(sourceAmount.text) ?? 0;
    final double tAmount = tryParseAmount(targetAmount.text) ?? 0;
    if (sAmount <= 0 || tAmount <= 0 || sourceCurrency == targetCurrency) {
      return;
    }
    try {
      await context.read<AppStateController>().executeCurrencyExchange(
        date: date,
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
      context.read<AppStateController>().state.aiSettings ??
          <String, dynamic>{},
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
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{
          'contents': <Map<String, dynamic>>[
            <String, dynamic>{
              'parts': <Map<String, dynamic>>[
                <String, dynamic>{'text': 'Reply with OK only.'},
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
      throw Exception(
        'API responded with code ${response.statusCode}: ${response.body}',
      );
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

  Widget _buildSecuritySwitch({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: colors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityDropdown({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: colors.onSurfaceVariant,
            ),
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            items: const [
              DropdownMenuItem(value: 'immediate', child: Text('Immediately')),
              DropdownMenuItem(value: '30_seconds', child: Text('30 Seconds')),
              DropdownMenuItem(value: '1_minute', child: Text('1 Minute')),
              DropdownMenuItem(value: '5_minutes', child: Text('5 Minutes')),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
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
  const _SectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _sectionIcon(title),
                    size: 18,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  IconData _sectionIcon(String value) {
    final String title = value.toLowerCase();
    if (title.contains('currency') || title.contains('عملة')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (title.contains('zakat') || title.contains('زكاة')) {
      return Icons.auto_awesome_outlined;
    }
    if (title.contains('backup') || title.contains('نسخ')) {
      return Icons.cloud_outlined;
    }
    if (title.contains('market') || title.contains('سوق')) {
      return Icons.show_chart_rounded;
    }
    if (title.contains('security') || title.contains('أمان')) {
      return Icons.security_outlined;
    }
    if (title.contains('language') || title.contains('لغة')) {
      return Icons.language_outlined;
    }
    if (title.contains('appearance') || title.contains('مظهر')) {
      return Icons.palette_outlined;
    }
    if (title.contains('categor') || title.contains('فئات')) {
      return Icons.folder_outlined;
    }
    if (title.contains('recurring') || title.contains('متكررة')) {
      return Icons.event_repeat_outlined;
    }
    if (title.contains('about') || title.contains('حول')) {
      return Icons.info_outline;
    }
    if (title.contains('ai') || title.contains('ذكاء')) {
      return Icons.auto_awesome_outlined;
    }
    return Icons.tune_rounded;
  }
}

class _SettingsProfileHeader extends StatelessWidget {
  const _SettingsProfileHeader({
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.connected,
    required this.isLoading,
    required this.onSignIn,
    required this.onSignOut,
  });

  final String? name;
  final String? email;
  final String? photoUrl;
  final bool connected;
  final bool isLoading;
  final VoidCallback? onSignIn;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final String displayName = (name ?? '').trim().isEmpty
        ? 'Zakah Wealth'
        : name!.trim();
    final String initial = displayName.characters.first.toUpperCase();

    return Container(
      key: const Key('settingsProfileHeader'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF073D32), Color(0xFF01251F)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF073D32).withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 29,
            backgroundColor: const Color(0xFFD4AF37),
            backgroundImage: (photoUrl != null && photoUrl!.trim().isNotEmpty)
                ? NetworkImage(photoUrl!)
                : null,
            child: (photoUrl != null && photoUrl!.trim().isNotEmpty)
                ? null
                : Text(
                    initial,
                    style: const TextStyle(
                      color: Color(0xFF073D32),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if ((email ?? '').trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                SizedBox(
                  height: 32,
                  child: connected
                      ? OutlinedButton.icon(
                          key: const Key('googleSignOutButton'),
                          onPressed: isLoading ? null : onSignOut,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.24),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          icon: const Icon(Icons.logout_rounded, size: 15),
                          label: const Text('Sign Out'),
                        )
                      : FilledButton.icon(
                          key: const Key('googleSignInButton'),
                          onPressed: isLoading ? null : onSignIn,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            foregroundColor: const Color(0xFF073D32),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          icon: const Icon(Icons.login_rounded, size: 15),
                          label: const Text('Sign in with Google'),
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

class _SettingsOverview extends StatelessWidget {
  const _SettingsOverview({
    required this.mainCurrency,
    required this.defaultCurrency,
    required this.zakatMethod,
    required this.nisabBasis,
    required this.goldPrice,
    required this.silverPrice,
    required this.lastUpdated,
    required this.refreshing,
    required this.onRefresh,
    required this.isArabic,
    required this.onTapMainCurrency,
    required this.onTapDefaultCurrency,
    required this.onTapZakatMethod,
    required this.onTapNisabBasis,
    required this.onTapMarket,
  });

  final String mainCurrency;
  final String defaultCurrency;
  final String zakatMethod;
  final String nisabBasis;
  final double goldPrice;
  final double silverPrice;
  final String lastUpdated;
  final bool refreshing;
  final VoidCallback? onRefresh;
  final bool isArabic;
  final VoidCallback onTapMainCurrency;
  final VoidCallback onTapDefaultCurrency;
  final VoidCallback onTapZakatMethod;
  final VoidCallback onTapNisabBasis;
  final VoidCallback onTapMarket;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _OverviewCard(
          icon: Icons.account_balance_wallet_outlined,
          title: isArabic ? 'الثروة والزكاة' : 'Wealth & Zakat',
          children: <Widget>[
            _OverviewRow(
              label: isArabic ? 'العملة الرئيسية' : 'Main Currency',
              value: mainCurrency,
              onTap: onTapMainCurrency,
            ),
            _OverviewRow(
              label: isArabic ? 'عملة الإدخال' : 'Default Entry Currency',
              value: defaultCurrency,
              onTap: onTapDefaultCurrency,
            ),
            _OverviewRow(
              label: isArabic ? 'طريقة الزكاة' : 'Zakat Method',
              value: zakatMethod == 'annual' ? 'Annual' : 'Monthly Hawl',
              onTap: onTapZakatMethod,
            ),
            _OverviewRow(
              label: isArabic ? 'أساس النصاب' : 'Nisab Basis',
              value: nisabBasis.contains('silver') ? 'Silver' : 'Gold',
              onTap: onTapNisabBasis,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _OverviewCard(
          icon: Icons.show_chart_rounded,
          title: isArabic ? 'ملخص الأسعار' : 'Market Snapshot',
          trailing: IconButton(
            key: const Key('refreshMarketDataOverviewButton'),
            tooltip: isArabic ? 'تحديث البيانات' : 'Refresh Data',
            onPressed: onRefresh,
            icon: refreshing
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 20),
          ),
          children: <Widget>[
            _OverviewRow(
              label: isArabic ? 'الذهب' : 'Gold',
              value: _price(goldPrice),
              onTap: onTapMarket,
            ),
            _OverviewRow(
              label: isArabic ? 'الفضة' : 'Silver',
              value: _price(silverPrice),
              onTap: onTapMarket,
            ),
            _OverviewRow(
              label: isArabic ? 'آخر تحديث' : 'Last Refresh',
              value: lastUpdated,
            ),
          ],
        ),
      ],
    );
  }

  String _price(double value) =>
      value <= 0 ? '-' : 'E£ ${value.toStringAsFixed(2)}/g';
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.icon,
    required this.title,
    required this.children,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 19, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (onTap != null) ...[
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded, size: 17),
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: content,
    );
  }
}

class _MarketSummary extends StatelessWidget {
  const _MarketSummary({required this.goldPrice, required this.silverPrice});

  final double goldPrice;
  final double silverPrice;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _MarketValue(label: 'Gold', value: goldPrice),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MarketValue(label: 'Silver', value: silverPrice),
        ),
      ],
    );
  }
}

class _MarketValue extends StatelessWidget {
  const _MarketValue({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 3),
          Text(
            value <= 0 ? '-' : 'E£ ${value.toStringAsFixed(2)}/g',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _CompactInfoRow extends StatelessWidget {
  const _CompactInfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _SettingsRowTile extends StatelessWidget {
  const _SettingsRowTile({
    super.key,
    required this.icon,
    required this.title,
    this.value = '',
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            if (value.isNotEmpty) ...[
              Text(
                value,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}
