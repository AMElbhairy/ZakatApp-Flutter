import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/i18n/app_localizations.dart';
import '../../core/privacy/app_privacy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/motion/app_motion.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/compact_dropdown.dart';
import '../../core/widgets/compact_selection_dialog.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../models/market_snapshot.dart';
import '../../core/utils/currency_presentation.dart';
import 'categories_screen.dart';
import 'market_snapshot_screen.dart';
import 'merchant_rules_screen.dart';
import 'recurring_transactions_screen.dart';
import 'diagnostics_screen.dart';
import 'cloud_backup_screen.dart';
import 'zakat_calculation_explanation_screen.dart';
import 'about_zakah_wealth_screen.dart';
import 'shortcut_setup_guide_screen.dart';
import 'policy_detail_screen.dart';
import '../../core/services/zakat_engine.dart';
import '../../models/user_profile.dart';
import '../../services/app_state_controller.dart';
import '../../services/account_deletion_auth_backend.dart';
import '../../services/account_deletion_service.dart';
import '../../services/account_reauthentication_service.dart';
import '../../services/auth_controller.dart';
import '../../services/cloud_backup_controller.dart';
import '../../services/android_sms_capture_service.dart';
import '../../features/onboarding/android_smart_capture_setup_screen.dart';
import '../../features/auth/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../services/diagnostics_flags.dart';
import '../../services/backup_restore_card.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final ScrollController _scrollController = ScrollController();

  final TextEditingController _aiKey1Controller = TextEditingController();
  final TextEditingController _aiKey2Controller = TextEditingController();
  bool _isRefreshingMarket = false;
  bool _aiExpanded = false;
  bool _aiInitialized = false;
  int _selectedAiKeyIndex = 0;
  bool _isTestingConnection = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _aiKey1Controller.dispose();
    _aiKey2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final authController = context.watch<AuthController?>();
    CloudBackupController? backupController;
    try {
      backupController = context.watch<CloudBackupController>();
    } catch (_) {
      backupController = null;
    }
    final state = controller.state;

    final String mainCurrency = state.mainCurrency.isEmpty
        ? 'EGP'
        : state.mainCurrency;
    final String defaultEntryCurrency = state.defaultEntryCurrency.isEmpty
        ? 'EGP'
        : state.defaultEntryCurrency;
    final String financialMonthCycle = state.financialMonthCycle == 'custom'
        ? 'custom'
        : 'calendar';
    final int financialMonthStartDay = state.financialMonthStartDay.clamp(
      1,
      28,
    );
    final String zakatMethod = state.zakatMethod == 'annual'
        ? 'annual'
        : 'hawl';
    final String zakatNisabBasis = ZakatEngineService.normalizeZakatNisabBasis(
      state.zakatNisabBasis,
    );
    final String themeMode = switch (state.themeMode) {
      'light' => 'light',
      'dark' => 'dark',
      _ => 'system',
    };

    final _AnnualDate annualDate = _AnnualDate.parse(state.zakatAnnualDate);
    final MarketSnapshot snapshot = controller.currentMarketSnapshot;
    final MarketData marketData = MarketData.fromJson(state.marketData);
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    _syncAiControllers(state.aiSettings);

    final double navSafeBottomPadding =
        112 + MediaQuery.paddingOf(context).bottom;
    return Stack(
      children: <Widget>[
        SingleChildScrollView(
          controller:
              PrimaryScrollController.maybeOf(context) ?? _scrollController,
          padding: EdgeInsets.fromLTRB(
            ResponsiveLayout.compactHorizontalPadding(context, wide: 20),
            16,
            ResponsiveLayout.compactHorizontalPadding(context, wide: 20),
            navSafeBottomPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AnimatedSection(
                child: _SettingsProfileHeader(
                  name: authController?.currentUser?.displayName,
                  email: authController?.currentUser?.email,
                  photoUrl: authController?.currentUser?.photoUrl,
                  connected: authController?.isSignedIn == true,
                  backupEnabled:
                      backupController?.automaticBackupEnabled == true,
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
                          if ((appStateController.state.biometricLockEnabled ||
                                  appStateController
                                      .state
                                      .biometricExportEnabled) &&
                              await BiometricService.canAuthenticate()) {
                            final bool
                            auth = await BiometricService.authenticate(
                              reason:
                                  'Confirm identity to sign out and clear local data',
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
              ),
              const SizedBox(height: 18),
              AnimatedSection(
                delay: const Duration(milliseconds: 35),
                child: _MarketSnapshotCard(
                  snapshot: snapshot,
                  marketData: marketData,
                  isArabic: isArabic,
                  title: context.l10n.tr('market_data_section'),
                  displayCurrency: mainCurrency,
                  refreshing: _isRefreshingMarket,
                  onRefresh: _isRefreshingMarket ? null : _refreshMarketData,
                  onViewAll: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        settings: const AppPrivacyRouteSettings(
                          privacy: ScreenPrivacyClassification.sensitive,
                        ),
                        builder: (_) => const MarketSnapshotScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSection(
                delay: const Duration(milliseconds: 70),
                child: _BackupOverviewCard(
                  controller: backupController,
                  isArabic: isArabic,
                  onOpenDetails: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        settings: const AppPrivacyRouteSettings(
                          privacy: ScreenPrivacyClassification.sensitive,
                        ),
                        builder: (_) => const CloudBackupScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSection(
                delay: const Duration(milliseconds: 105),
                child: _WealthZakatCard(
                  supportedCurrencies: CurrencyPresentation.marketCurrencyCodes,
                  mainCurrency: mainCurrency,
                  defaultCurrency: defaultEntryCurrency,
                  financialMonthCycle: financialMonthCycle,
                  financialMonthStartDay: financialMonthStartDay,
                  zakatMethod: zakatMethod,
                  nisabBasis: zakatNisabBasis,
                  annualDate: annualDate,
                  onMainCurrencyChanged: (String value) {
                    context.read<AppStateController>().updateMainCurrency(
                      value,
                    );
                  },
                  onDefaultCurrencyChanged: (String value) {
                    context
                        .read<AppStateController>()
                        .updateDefaultEntryCurrency(value);
                  },
                  onFinancialMonthCycleChanged: (String value) {
                    context
                        .read<AppStateController>()
                        .updateFinancialMonthCycle(value);
                  },
                  onFinancialMonthStartDayChanged: (int value) {
                    context
                        .read<AppStateController>()
                        .updateFinancialMonthStartDay(value);
                  },
                  onZakatMethodChanged: (String value) {
                    context.read<AppStateController>().updateZakatMethod(value);
                  },
                  onNisabBasisChanged: (String value) {
                    context.read<AppStateController>().updateZakatNisabBasis(
                      value,
                    );
                  },
                  onAnnualDateChanged: (int month, int day) {
                    return _updateAnnualDate(month, day);
                  },
                  isArabic: isArabic,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSection(
                delay: const Duration(milliseconds: 140),
                child: _CompactSectionCard(
                  title: context.l10n.tr('preferences_section'),
                  icon: Icons.tune_rounded,
                  children: <Widget>[
                    _ActionSettingTile(
                      key: const Key('settingsLanguageTile'),
                      icon: Icons.language_outlined,
                      title: context.l10n.tr('language'),
                      subtitle: isArabic ? 'العربية' : 'English',
                      onTap: () async {
                        final String? selected =
                            await showCompactSelectionDialog<String>(
                              context: context,
                              title: context.l10n.tr('language'),
                              options: const <String>['en', 'ar'],
                              selectedValueLabel:
                                  state.languagePreference == 'ar'
                                  ? 'ar'
                                  : 'en',
                              optionLabel: (String value) => value == 'ar'
                                  ? context.l10n.tr('arabic')
                                  : context.l10n.tr('english'),
                            );
                        if (selected == null || !context.mounted) return;
                        await context
                            .read<AppStateController>()
                            .updateLanguagePreference(selected);
                      },
                    ),
                    _ActionSettingTile(
                      key: const Key('settingsCategoriesTile'),
                      icon: Icons.folder_outlined,
                      title: context.l10n.tr('categories_section'),
                      subtitle: isArabic
                          ? 'اللغة، العملة، الفئات والمزيد'
                          : 'Language, Currency, Categories and more',
                      onTap: () {
                        Navigator.of(context).push(CategoriesScreen.route());
                      },
                    ),
                    _ActionSettingTile(
                      key: const Key('settingsMerchantRulesTile'),
                      icon: Icons.rule_folder_outlined,
                      title: context.l10n.tr('merchant_rules_section'),
                      subtitle: isArabic
                          ? 'إدارة قواعد التصنيف التلقائي'
                          : 'Manage auto-categorization rules',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            settings: const AppPrivacyRouteSettings(
                              privacy: ScreenPrivacyClassification.sensitive,
                            ),
                            builder: (_) => const MerchantRulesScreen(),
                          ),
                        );
                      },
                    ),
                    _ActionSettingTile(
                      key: const Key('settingsRecurringTile'),
                      icon: Icons.event_repeat_outlined,
                      title: context.l10n.tr('recurring_section'),
                      subtitle: isArabic
                          ? 'إدارة العمليات المتكررة'
                          : 'Manage recurring transactions',
                      onTap: () {
                        Navigator.of(
                          context,
                        ).push(RecurringTransactionsScreen.route());
                      },
                    ),
                    if (defaultTargetPlatform == TargetPlatform.android) ...[
                      _ToggleSettingTile(
                        key: const Key('settingsSmsCaptureToggle'),
                        icon: Icons.sms_outlined,
                        title: isArabic
                            ? 'الالتقاط التلقائي لرسائل البنوك'
                            : 'Automatic Bank SMS Capture',
                        subtitle: isArabic
                            ? 'فحص رسائل البنوك محليًا على أندرويد'
                            : 'Scan incoming bank SMS locally on Android',
                        value: state.androidSmsAutoCaptureEnabled,
                        onChanged: (bool enabled) async {
                          if (enabled) {
                            final bool smsGranted =
                                await AndroidSmsCaptureService.hasSmsPermission();
                            final bool batteryIgnored =
                                await AndroidSmsCaptureService.isBatteryOptimizationIgnored();
                            if (!smsGranted || !batteryIgnored) {
                              if (!context.mounted) return;
                              final bool? completed =
                                  await Navigator.of(context).push<bool>(
                                    MaterialPageRoute<bool>(
                                      builder: (_) =>
                                          const AndroidSmartCaptureSetupScreen(),
                                    ),
                                  );
                              if (completed != true || !context.mounted) {
                                return;
                              }
                              return;
                            }
                          }
                          if (!context.mounted) return;
                          await context
                              .read<AppStateController>()
                              .setAndroidSmsAutoCaptureEnabled(enabled);
                        },
                      ),
                      _ActionSettingTile(
                        key: const Key('settingsSmsCaptureGuide'),
                        icon: Icons.assignment_outlined,
                        title: isArabic
                            ? 'دليل إعداد التقاط الرسائل'
                            : 'SMS Capture Setup Guide',
                        subtitle: isArabic
                            ? 'إعداد وضبط أذونات التقاط الرسائل'
                            : 'Configure SMS capture permissions',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const AndroidSmartCaptureSetupScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                    if (defaultTargetPlatform == TargetPlatform.iOS)
                      _ActionSettingTile(
                        key: const Key('settingsShortcutGuide'),
                        icon: Icons.shortcut_outlined,
                        title: isArabic
                            ? 'دليل تفعيل الاختصارات'
                            : 'Shortcut Activation Guide',
                        subtitle: isArabic
                            ? 'ربط وتفعيل اختصارات Siri للرسائل البنكية'
                            : 'Link and configure Siri Shortcuts for bank alerts',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ShortcutSetupGuideScreen(),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSection(
                delay: const Duration(milliseconds: 175),
                child: _SecurityPrivacyCard(
                  key: const Key('settingsSecurityTile'),
                  biometricLockEnabled: state.biometricLockEnabled,
                  biometricAutoLockDelay: state.biometricAutoLockDelay,
                  biometricHideWealthEnabled: state.biometricHideWealthEnabled,
                  biometricExportEnabled: state.biometricExportEnabled,
                  biometricRestoreEnabled: state.biometricRestoreEnabled,
                  onDeleteAccount: () => _confirmDeleteAccount(context),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSection(
                delay: const Duration(milliseconds: 210),
                child: _AppearanceAiRow(
                  themeMode: themeMode,
                  title: context.l10n.tr('appearance_section'),
                  onThemeTap: () async {
                    final AppStateController appStateController = context
                        .read<AppStateController>();
                    final String? selected = await _showChoiceDialog<String>(
                      context: context,
                      title: context.l10n.tr('theme_mode'),
                      options: const <String>['system', 'light', 'dark'],
                      optionLabel: (String value) => switch (value) {
                        'light' => context.l10n.tr('theme_light'),
                        'dark' => context.l10n.tr('theme_dark'),
                        _ => context.l10n.tr('theme_system'),
                      },
                    );
                    if (selected == null || !mounted) return;
                    appStateController.updateThemeMode(selected);
                  },
                  aiExpanded: _aiExpanded,
                  isTestingConnection: _isTestingConnection,
                  selectedAiKeyIndex: _selectedAiKeyIndex,
                  onAiTap: () => setState(() => _aiExpanded = !_aiExpanded),
                  onTestAiConnection: () => _testAiConnection(),
                  onSaveAiKeys: () => _saveAiKeys(),
                  onSelectedAiKeyChanged: (int value) {
                    setState(() => _selectedAiKeyIndex = value);
                  },
                  aiKey1Controller: _aiKey1Controller,
                  aiKey2Controller: _aiKey2Controller,
                  isArabic: isArabic,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSection(
                delay: const Duration(milliseconds: 245),
                child: _AboutCard(isArabic: isArabic),
              ),
              if (kDebugMode && enableDeveloperDiagnostics) ...<Widget>[
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Developer Diagnostics',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      FilledButton.tonalIcon(
                        key: const Key('developerDiagnosticsButton'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const DiagnosticsScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.bug_report_outlined),
                        label: const Text('Developer Diagnostics'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final state = context.read<AppStateController>().state;
    final authController = context.read<AuthController?>();
    final l10n = context.l10n;
    final UserProfile? user = authController?.currentUser;
    if (user == null) return;
    if ((state.biometricLockEnabled || state.biometricExportEnabled) &&
        await BiometricService.canAuthenticate()) {
      final auth = await BiometricService.authenticate(
        reason: 'Confirm identity to delete this account',
        isSensitiveAction: true,
      );
      if (!auth) return;
    }
    if (!context.mounted) return;
    final TextEditingController confirmController = TextEditingController();
    bool? ok;
    try {
      ok = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) {
          bool canConfirm = false;
          return StatefulBuilder(
            builder: (BuildContext dialogContext, StateSetter setState) {
              void refreshConfirmState(String value) {
                final bool nextCanConfirm =
                    value.trim().toLowerCase() == 'delete';
                if (nextCanConfirm != canConfirm) {
                  setState(() {
                    canConfirm = nextCanConfirm;
                  });
                }
              }

              return AlertDialog(
                title: Text(l10n.tr('delete_account')),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text('Type DELETE to confirm account deletion.'),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('deleteAccountConfirmField'),
                      controller: confirmController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'DELETE',
                        hintText: 'DELETE',
                      ),
                      onChanged: refreshConfirmState,
                    ),
                  ],
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(l10n.tr('cancel')),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.redStrong,
                    ),
                    onPressed: canConfirm
                        ? () => Navigator.pop(dialogContext, true)
                        : null,
                    child: Text(l10n.tr('delete')),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      confirmController.dispose();
    }
    if (ok == true && context.mounted) {
      final AppStateController appStateController = context
          .read<AppStateController>();
      final FirebaseAccountDeletionAuthBackend authBackend =
          FirebaseAccountDeletionAuthBackend();
      final AccountDeletionService deletionService = AccountDeletionService(
        appStateController: appStateController,
        authController: authController!,
        authBackend: authBackend,
        reauthenticationService: AccountReauthenticationService(
          authBackend: authBackend,
          promptPassword: (UserProfile reauthUser) {
            return _promptPasswordForReauthentication(context, reauthUser);
          },
          chooseMethod:
              ({required List<AccountReauthMethod> availableMethods}) {
                return _chooseReauthMethod(context, availableMethods);
              },
        ),
        deleteCloudBackupData: (UserProfile user) async {
          CloudBackupController? cloudBackupController;
          try {
            cloudBackupController = context.read<CloudBackupController>();
          } catch (_) {
            cloudBackupController = null;
          }
          if (cloudBackupController != null) {
            await cloudBackupController.deleteCloudBackupData();
          }
        },
      );
      try {
        await deletionService.deleteAccount();
      } catch (error, stackTrace) {
        debugPrint('AccountScreen.deleteAccount failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        if (!context.mounted) return;
        showTopSnackBar(
          context,
          _presentDeleteAccountError(error),
          kind: AppToastKind.error,
        );
      }
    }
  }

  Future<String?> _promptPasswordForReauthentication(
    BuildContext context,
    UserProfile user,
  ) async {
    final TextEditingController passwordController = TextEditingController();
    try {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(context.l10n.tr('delete_account')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                user.email.isEmpty
                    ? 'Re-enter your password to continue.'
                    : 'Re-enter the password for ${user.email} to continue.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.l10n.tr('password'),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.tr('continue')),
            ),
          ],
        ),
      );
      if (confirmed != true) return null;
      return passwordController.text;
    } finally {
      passwordController.dispose();
    }
  }

  Future<AccountReauthMethod?> _chooseReauthMethod(
    BuildContext context,
    List<AccountReauthMethod> availableMethods,
  ) async {
    final bool hasGoogle = availableMethods.contains(
      AccountReauthMethod.google,
    );
    final bool hasPassword = availableMethods.contains(
      AccountReauthMethod.password,
    );
    if (!hasGoogle || !hasPassword) {
      return availableMethods.isEmpty ? null : availableMethods.first;
    }
    final bool? google = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(context.l10n.tr('delete_account')),
        content: Text(
          'Choose how to reauthenticate before deleting your account.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Continue with Password'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue with Google'),
          ),
        ],
      ),
    );
    if (google == null) return null;
    return google ? AccountReauthMethod.google : AccountReauthMethod.password;
  }

  String _presentDeleteAccountError(Object error) {
    if (error is StateError) {
      final String message = error.message.trim();
      if (message.isNotEmpty) return message;
    }
    final String raw = error.toString().trim();
    const String prefix = 'Bad state: ';
    return raw.startsWith(prefix) ? raw.substring(prefix.length) : raw;
  }

  Future<void> _refreshMarketData() async {
    setState(() {
      _isRefreshingMarket = true;
    });
    final result = await context.read<AppStateController>().refreshMarketData(
      force: true,
    );
    if (!mounted) return;
    setState(() {
      _isRefreshingMarket = false;
    });
    showTopSnackBar(
      context,
      _localizedRefreshMessage(context, result.message),
      kind: result.success ? AppToastKind.success : AppToastKind.warning,
    );
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

String _formatAgeText(String raw, {required bool isArabic}) {
  final DateTime? parsed = _AccountScreenState._tryParseLegacyOrIso(raw);
  if (parsed == null) return isArabic ? 'تم التحديث' : 'Updated';
  final DateTime now = DateTime.now();
  final Duration delta = now.difference(parsed.toLocal());
  if (delta.inMinutes < 1) {
    return isArabic ? 'تم التحديث منذ لحظات' : 'Updated moments ago';
  }
  if (delta.inHours < 1) {
    final int mins = delta.inMinutes;
    return isArabic ? 'تم التحديث منذ $mins د' : 'Updated $mins min ago';
  }
  if (delta.inDays < 1) {
    final int hours = delta.inHours;
    return isArabic ? 'تم التحديث منذ $hours س' : 'Updated $hours h ago';
  }
  return isArabic
      ? 'تم التحديث ${DateFormat('yyyy-MM-dd').format(parsed.toLocal())}'
      : 'Updated ${DateFormat('MMM d, yyyy').format(parsed.toLocal())}';
}

String _formatClockLabel(DateTime? value, {required bool isArabic}) {
  if (value == null) return isArabic ? 'غير متاح' : 'Unavailable';
  final DateTime local = value.toLocal();
  final String time = DateFormat('h:mm a').format(local);
  final DateTime today = DateTime.now();
  final bool isSameDay =
      today.year == local.year &&
      today.month == local.month &&
      today.day == local.day;
  if (isSameDay) {
    return isArabic ? 'اليوم $time' : 'Today $time';
  }
  return isArabic
      ? DateFormat('yyyy-MM-dd h:mm a').format(local)
      : DateFormat('MMM d, h:mm a').format(local);
}

String _formatCountdownLabel(DateTime? value, {required bool isArabic}) {
  if (value == null) return isArabic ? 'غير محدد' : 'Not set';
  final Duration delta = value.toLocal().difference(DateTime.now());
  if (delta.isNegative || delta.inMinutes <= 0) {
    return isArabic ? 'الآن' : 'Now';
  }
  final int hours = delta.inHours;
  final int mins = delta.inMinutes.remainder(60);
  if (hours > 0) {
    return isArabic ? 'بعد $hours س $mins د' : 'In ${hours}h ${mins}m';
  }
  return isArabic ? 'بعد $mins د' : 'In ${mins}m';
}

String _formatEveryIntervalLabel(Duration interval, {required bool isArabic}) {
  final int minutes = interval.inMinutes;
  if (minutes < 60) {
    return isArabic ? 'كل $minutes دقيقة' : 'Every $minutes min';
  }
  final int hours = interval.inHours;
  final int mins = minutes.remainder(60);
  if (mins == 0) {
    if (hours == 1) {
      return isArabic ? 'كل ساعة' : 'Every 1 hour';
    }
    return isArabic ? 'كل $hours ساعات' : 'Every $hours hours';
  }
  if (hours == 1) {
    return isArabic ? 'كل ساعة و$mins دقيقة' : 'Every 1 hour $mins min';
  }
  return isArabic ? 'كل $hours س $mins د' : 'Every ${hours}h ${mins}m';
}

Future<T?> _showChoiceDialog<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required String Function(T value) optionLabel,
}) {
  return showCompactSelectionDialog<T>(
    context: context,
    title: title,
    options: options,
    optionLabel: optionLabel,
  );
}

class _MarketSnapshotCard extends StatelessWidget {
  const _MarketSnapshotCard({
    required this.snapshot,
    required this.marketData,
    required this.isArabic,
    required this.title,
    required this.displayCurrency,
    required this.refreshing,
    required this.onRefresh,
    required this.onViewAll,
  });

  final MarketSnapshot snapshot;
  final MarketData marketData;
  final bool isArabic;
  final String title;
  final String displayCurrency;
  final bool refreshing;
  final VoidCallback? onRefresh;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool compact = ResponsiveLayout.isCompact(context);

    return PremiumCard(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        14,
        compact ? 12 : 16,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (compact) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.show_chart_rounded, size: 20, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  key: const Key('viewAllMarketSnapshotButton'),
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: Text(
                    context.l10n.tr('view_all'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  key: const Key('refreshMarketDataOverviewButton'),
                  onPressed: onRefresh,
                  visualDensity: VisualDensity.compact,
                  icon: refreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ] else ...<Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.show_chart_rounded, size: 20, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('viewAllMarketSnapshotButton'),
                  onPressed: onViewAll,
                  child: Text(context.l10n.tr('view_all')),
                ),
                IconButton(
                  key: const Key('refreshMarketDataOverviewButton'),
                  onPressed: onRefresh,
                  icon: refreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _StatCard(
                  icon: Icons.brightness_7_outlined,
                  label: isArabic ? 'ذهب 24K' : 'Gold',
                  value: _price(snapshot.gold24kPricePerGramEgp),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.circle_outlined,
                  label: isArabic ? 'فضة' : 'Silver',
                  value: _price(snapshot.silverPricePerGramEgp),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _formatAgeText(snapshot.lastUpdated, isArabic: isArabic),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.95),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _price(double valueEgp) {
    if (valueEgp <= 0) return isArabic ? 'غير متوفر' : 'Unavailable';
    final double converted = ZakatEngineService.convertFromEgp(
      valueEgp,
      displayCurrency,
      marketData,
    );
    if (converted.isNaN) return isArabic ? 'غير متوفر' : 'Unavailable';
    return '${ZakatEngineService.formatCurrency(converted, displayCurrency)}/g';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool compact = ResponsiveLayout.isCompact(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: compact ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.95),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupOverviewCard extends StatelessWidget {
  const _BackupOverviewCard({
    required this.controller,
    required this.isArabic,
    required this.onOpenDetails,
  });

  final CloudBackupController? controller;
  final bool isArabic;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool compact = ResponsiveLayout.isCompact(context);
    final bool connected = controller?.isDriveConnected == true;
    final String backupStatus = connected
        ? (isArabic ? 'متصل' : 'Connected')
        : (isArabic ? 'غير متصل' : 'Disconnected');
    final DateTime? lastBackupAt = controller?.lastBackupAt;
    final DateTime? nextCheckAt = controller?.nextEligibleBackupAt;
    final Duration interval =
        controller?.minimumInterval ?? const Duration(hours: 3);

    return PremiumCard(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        14,
        compact ? 12 : 16,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (compact) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.cloud_outlined, size: 20, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic ? 'نسخ Google Drive' : 'Google Drive Backup',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 26),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: connected
                            ? colors.primary.withValues(alpha: 0.12)
                            : colors.errorContainer.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.85),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        backupStatus,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: connected ? colors.primary : colors.error,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: onOpenDetails,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                ),
              ],
            ),
          ] else ...<Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.cloud_outlined, size: 20, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic ? 'نسخ Google Drive' : 'Google Drive Backup',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minHeight: 26),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: connected
                        ? colors.primary.withValues(alpha: 0.12)
                        : colors.errorContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.85),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    backupStatus,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: connected ? colors.primary : colors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: onOpenDetails,
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _InfoColumn(
                  label: isArabic ? 'آخر نسخة' : 'Last Backup',
                  value: _formatClockLabel(lastBackupAt, isArabic: isArabic),
                ),
              ),
              Expanded(
                child: _InfoColumn(
                  label: isArabic ? 'النسخ التلقائي' : 'Automatic Backup',
                  value: _formatEveryIntervalLabel(
                    interval,
                    isArabic: isArabic,
                  ),
                ),
              ),
              Expanded(
                child: _InfoColumn(
                  label: isArabic ? 'الفحص التالي' : 'Next Check',
                  value: _formatCountdownLabel(nextCheckAt, isArabic: isArabic),
                ),
              ),
            ],
          ),
          if (!connected) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              isArabic
                  ? 'اربط Google Drive لتفعيل النسخ المشفر.'
                  : 'Connect Google Drive to enable encrypted backups.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            isArabic ? 'النسخ الاحتياطي المحلي (JSON)' : 'Local JSON Backup',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          BackupRestoreCard(controller: context.read<AppStateController>()),
        ],
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool compact = ResponsiveLayout.isCompact(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            maxLines: compact ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.95),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _WealthZakatCard extends StatelessWidget {
  const _WealthZakatCard({
    required this.supportedCurrencies,
    required this.mainCurrency,
    required this.defaultCurrency,
    required this.financialMonthCycle,
    required this.financialMonthStartDay,
    required this.zakatMethod,
    required this.nisabBasis,
    required this.annualDate,
    required this.onMainCurrencyChanged,
    required this.onDefaultCurrencyChanged,
    required this.onFinancialMonthCycleChanged,
    required this.onFinancialMonthStartDayChanged,
    required this.onZakatMethodChanged,
    required this.onNisabBasisChanged,
    required this.onAnnualDateChanged,
    required this.isArabic,
  });

  final List<String> supportedCurrencies;
  final String mainCurrency;
  final String defaultCurrency;
  final String financialMonthCycle;
  final int financialMonthStartDay;
  final String zakatMethod;
  final String nisabBasis;
  final _AnnualDate annualDate;
  final ValueChanged<String> onMainCurrencyChanged;
  final ValueChanged<String> onDefaultCurrencyChanged;
  final ValueChanged<String> onFinancialMonthCycleChanged;
  final ValueChanged<int> onFinancialMonthStartDayChanged;
  final ValueChanged<String> onZakatMethodChanged;
  final ValueChanged<String> onNisabBasisChanged;
  final Future<void> Function(int month, int day) onAnnualDateChanged;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final bool isRtl =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final bool compact = ResponsiveLayout.isCompact(context);
    return PremiumCard(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        14,
        compact ? 12 : 16,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.account_balance_wallet_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic ? 'الثروة والزكاة' : 'Wealth & Zakat',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ActionSettingTile(
            key: const Key('settingsMainCurrencyField'),
            icon: Icons.account_balance_wallet_outlined,
            title: context.l10n.tr('main_currency'),
            subtitle: CurrencyPresentation.selectorLabel(
              _currencyValue(mainCurrency),
              isRtl: isRtl,
            ),
            onTap: () async {
              final String? selected = await _showChoiceDialog<String>(
                context: context,
                title: context.l10n.tr('main_currency'),
                options: supportedCurrencies,
                optionLabel: (String value) =>
                    CurrencyPresentation.selectorLabel(value, isRtl: isRtl),
              );
              if (selected != null) onMainCurrencyChanged(selected);
            },
          ),
          _ActionSettingTile(
            key: const Key('settingsDefaultEntryCurrencyField'),
            icon: Icons.payments_outlined,
            title: context.l10n.tr('default_entry_currency'),
            subtitle: CurrencyPresentation.selectorLabel(
              _currencyValue(defaultCurrency),
              isRtl: isRtl,
            ),
            onTap: () async {
              final String? selected = await _showChoiceDialog<String>(
                context: context,
                title: context.l10n.tr('default_entry_currency'),
                options: supportedCurrencies,
                optionLabel: (String value) =>
                    CurrencyPresentation.selectorLabel(value, isRtl: isRtl),
              );
              if (selected != null) onDefaultCurrencyChanged(selected);
            },
          ),
          _ActionSettingTile(
            key: const Key('settingsMonthlyCycleField'),
            icon: Icons.date_range_outlined,
            title: isArabic ? 'دورة الشهر' : 'Monthly Cycle',
            subtitle: financialMonthCycle == 'custom'
                ? '${isArabic ? 'يبدأ في اليوم' : 'Starts on day'} $financialMonthStartDay'
                : (isArabic ? 'الشهر الميلادي' : 'Calendar month'),
            onTap: () async {
              final String? selected = await _showChoiceDialog<String>(
                context: context,
                title: isArabic ? 'دورة الشهر' : 'Monthly Cycle',
                options: const <String>['calendar', 'custom'],
                optionLabel: (String value) => value == 'custom'
                    ? (isArabic ? 'مخصص' : 'Custom start day')
                    : (isArabic ? 'الشهر الميلادي' : 'Calendar month'),
              );
              if (selected == null) return;
              onFinancialMonthCycleChanged(selected);
              if (selected == 'custom') {
                final int? picked = await _showChoiceDialog<int>(
                  context: context,
                  title: isArabic ? 'يوم البداية' : 'Start Day',
                  options: List<int>.generate(28, (int index) => index + 1),
                  optionLabel: (int value) => value.toString(),
                );
                if (picked != null) {
                  onFinancialMonthStartDayChanged(picked);
                }
              }
            },
          ),
          _ActionSettingTile(
            key: const Key('settingsZakatMethodField'),
            icon: Icons.auto_awesome_outlined,
            title: context.l10n.tr('method'),
            subtitle: zakatMethod == 'annual'
                ? context.l10n.tr('annual')
                : context.l10n.tr('monthly_hawl'),
            onTap: () async {
              final String? selected = await _showChoiceDialog<String>(
                context: context,
                title: context.l10n.tr('method'),
                options: const <String>['hawl', 'annual'],
                optionLabel: (String value) => value == 'annual'
                    ? context.l10n.tr('annual')
                    : context.l10n.tr('monthly_hawl'),
              );
              if (selected != null) onZakatMethodChanged(selected);
            },
          ),
          _ActionSettingTile(
            key: const Key('settingsZakatNisabBasisField'),
            icon: Icons.science_outlined,
            title: context.l10n.tr('cash_nisab'),
            subtitle: nisabBasis.contains('silver')
                ? context.l10n.tr('nisab_silver_595')
                : context.l10n.tr('nisab_gold_85'),
            onTap: () async {
              final String? selected = await _showChoiceDialog<String>(
                context: context,
                title: context.l10n.tr('cash_nisab'),
                options: const <String>[
                  ZakatEngineService.nisabBasisGold85,
                  ZakatEngineService.nisabBasisSilver595,
                ],
                optionLabel: (String value) =>
                    value == ZakatEngineService.nisabBasisSilver595
                    ? context.l10n.tr('nisab_silver_595')
                    : context.l10n.tr('nisab_gold_85'),
              );
              if (selected != null) onNisabBasisChanged(selected);
            },
          ),
          _ActionSettingTile(
            key: const Key('settingsZakatExplanationField'),
            icon: Icons.info_outline,
            title: context.l10n.tr('how_calculation_works'),
            subtitle: context.l10n.tr('how_calculation_works_subtitle'),
            onTap: () {
              Navigator.of(context).push(ZakatCalculationExplanationScreen.route());
            },
          ),
          if (zakatMethod == 'annual') ...<Widget>[
            Column(
              key: const Key('settingsAnnualDateSection'),
              children: <Widget>[
                _ActionSettingTile(
                  key: const Key('settingsHijriMonthField'),
                  icon: Icons.date_range_outlined,
                  title: context.l10n.tr('hijri_month'),
                  subtitle: annualDate.month.toString(),
                  onTap: () async {
                    final int? selected = await _showChoiceDialog<int>(
                      context: context,
                      title: context.l10n.tr('hijri_month'),
                      options: List<int>.generate(12, (int index) => index + 1),
                      optionLabel: (int value) => value.toString(),
                    );
                    if (selected != null) {
                      final int nextDay =
                          annualDate.day >
                              _AccountScreenState._hijriMonthLength(selected)
                          ? _AccountScreenState._hijriMonthLength(selected)
                          : annualDate.day;
                      await onAnnualDateChanged(selected, nextDay);
                    }
                  },
                ),
                _ActionSettingTile(
                  key: const Key('settingsHijriDayField'),
                  icon: Icons.date_range_outlined,
                  title: context.l10n.tr('hijri_day'),
                  subtitle: annualDate.day.toString(),
                  onTap: () async {
                    final int? selected = await _showChoiceDialog<int>(
                      context: context,
                      title: context.l10n.tr('hijri_day'),
                      options: List<int>.generate(
                        _AccountScreenState._hijriMonthLength(annualDate.month),
                        (int index) => index + 1,
                      ),
                      optionLabel: (int value) => value.toString(),
                    );
                    if (selected != null) {
                      await onAnnualDateChanged(annualDate.month, selected);
                    }
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _currencyValue(String currency) => currency.isEmpty ? 'EGP' : currency;
}

class _CompactSectionCard extends StatelessWidget {
  const _CompactSectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool compact = ResponsiveLayout.isCompact(context);
    return PremiumCard(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        14,
        compact ? 12 : 16,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 20, color: colors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 18 : null,
                    height: compact ? 1.05 : null,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 6),
          ...children,
        ],
      ),
    );
  }
}

class _ActionSettingTile extends StatelessWidget {
  const _ActionSettingTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool compact = ResponsiveLayout.isCompact(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 7 : 9),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: colors.primary),
            ),
            SizedBox(width: compact ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: ResponsiveLayout.isCompact(context)
                          ? 13.5
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ToggleSettingTile extends StatelessWidget {
  const _ToggleSettingTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color iconColor = colors.primary;
    final bool compact = ResponsiveLayout.isCompact(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 7 : 9),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _DropdownSettingTile extends StatelessWidget {
  const _DropdownSettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final List<String> items;
  final String Function(String value) itemLabel;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool compact = ResponsiveLayout.isCompact(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 7 : 9),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: colors.primary),
          ),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: CompactDropdownButton<String>(
              value: value,
              labelText: title,
              items: items,
              itemLabel: itemLabel,
              onChanged: (String next) => onChanged(next),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityPrivacyCard extends StatelessWidget {
  const _SecurityPrivacyCard({
    super.key,
    required this.biometricLockEnabled,
    required this.biometricAutoLockDelay,
    required this.biometricHideWealthEnabled,
    required this.biometricExportEnabled,
    required this.biometricRestoreEnabled,
    required this.onDeleteAccount,
  });

  final bool biometricLockEnabled;
  final String biometricAutoLockDelay;
  final bool biometricHideWealthEnabled;
  final bool biometricExportEnabled;
  final bool biometricRestoreEnabled;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool compact = ResponsiveLayout.isCompact(context);
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    return PremiumCard(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        14,
        compact ? 12 : 16,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.shield_outlined, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                context.l10n.tr('security_section'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _ToggleSettingTile(
            icon: Icons.fingerprint_outlined,
            title: isArabic ? 'القفل البيومتري' : 'Biometric Lock',
            subtitle: isArabic
                ? 'استخدم Face ID أو بصمة الإصبع'
                : 'Use Face ID or fingerprint',
            value: biometricLockEnabled,
            onChanged: (bool val) async {
              final bool canAuth = await BiometricService.canAuthenticate();
              if (!canAuth) {
                if (!context.mounted) return;
                showTopSnackBar(
                  context,
                  'Biometrics are not available or configured on this device.',
                  kind: AppToastKind.warning,
                );
                return;
              }
              final bool authenticated = await BiometricService.authenticate(
                reason: val
                    ? 'Confirm identity to enable Biometric App Lock'
                    : 'Confirm identity to disable Biometric App Lock',
              );
              if (authenticated && context.mounted) {
                context.read<AppStateController>().updateBiometricLockEnabled(
                  val,
                );
              }
            },
          ),
          _DropdownSettingTile(
            icon: Icons.timer_outlined,
            title: isArabic ? 'مهلة القفل التلقائي' : 'Auto Lock Delay',
            subtitle: isArabic
                ? 'الوقت قبل أن يقفل التطبيق نفسه'
                : 'Delay before the app locks itself',
            value: biometricAutoLockDelay,
            items: const <String>[
              'immediate',
              '30_seconds',
              '1_minute',
              '5_minutes',
            ],
            itemLabel: (String value) => switch (value) {
              'immediate' => isArabic ? 'فورًا' : 'Immediately',
              '30_seconds' => isArabic ? '30 ثانية' : '30 Seconds',
              '1_minute' => isArabic ? 'دقيقة واحدة' : '1 Minute',
              '5_minutes' => isArabic ? '5 دقائق' : '5 Minutes',
              _ => value,
            },
            onChanged: (String? val) {
              if (val != null) {
                context.read<AppStateController>().updateBiometricAutoLockDelay(
                  val,
                );
              }
            },
          ),
          _ToggleSettingTile(
            icon: Icons.visibility_off_outlined,
            title: isArabic ? 'إخفاء قيم الثروة' : 'Hide Wealth Values',
            subtitle: isArabic
                ? 'إخفاء الأرصدة في التطبيق بالكامل'
                : 'Hide balances throughout the app',
            value: biometricHideWealthEnabled,
            onChanged: (bool val) {
              context
                  .read<AppStateController>()
                  .updateBiometricHideWealthEnabled(val);
            },
          ),
          const SizedBox(height: 2),
          Text(
            isArabic ? 'حماية البيانات' : 'Data Protection',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          _ToggleSettingTile(
            icon: Icons.lock_outline_rounded,
            title: isArabic
                ? 'حماية التصدير والحذف'
                : 'Protect Exports & Delete',
            subtitle: isArabic
                ? 'يُطلب التأكيد قبل التصدير أو حذف البيانات'
                : 'Require approval before exporting or deleting data',
            value: biometricExportEnabled,
            onChanged: (bool val) {
              context.read<AppStateController>().updateBiometricExportEnabled(
                val,
              );
            },
          ),
          _ToggleSettingTile(
            icon: Icons.restore_outlined,
            title: isArabic
                ? 'حماية الاستعادة والاستيراد'
                : 'Protect Restore & Import',
            subtitle: isArabic
                ? 'يُطلب التأكيد قبل الاستعادة أو الاستيراد'
                : 'Require approval before restore or import actions',
            value: biometricRestoreEnabled,
            onChanged: (bool val) {
              context.read<AppStateController>().updateBiometricRestoreEnabled(
                val,
              );
            },
          ),
          const SizedBox(height: 4),
          InkWell(
            key: const Key('deleteAccountButton'),
            onTap: onDeleteAccount,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.dangerous_outlined,
                      size: 20,
                      color: colors.error,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Danger Zone',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.error,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Delete data or account',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: colors.error),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceAiRow extends StatelessWidget {
  const _AppearanceAiRow({
    required this.themeMode,
    required this.title,
    required this.onThemeTap,
    required this.aiExpanded,
    required this.isTestingConnection,
    required this.selectedAiKeyIndex,
    required this.onAiTap,
    required this.onTestAiConnection,
    required this.onSaveAiKeys,
    required this.onSelectedAiKeyChanged,
    required this.aiKey1Controller,
    required this.aiKey2Controller,
    required this.isArabic,
  });

  final String themeMode;
  final String title;
  final VoidCallback onThemeTap;
  final bool aiExpanded;
  final bool isTestingConnection;
  final int selectedAiKeyIndex;
  final VoidCallback onAiTap;
  final VoidCallback onTestAiConnection;
  final VoidCallback onSaveAiKeys;
  final ValueChanged<int> onSelectedAiKeyChanged;
  final TextEditingController aiKey1Controller;
  final TextEditingController aiKey2Controller;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool compact = ResponsiveLayout.isCompact(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _MiniSummaryCard(
                key: const Key('settingsThemeModeField'),
                icon: Icons.palette_outlined,
                title: title,
                subtitle: isArabic ? 'وضع النظام' : 'Theme Mode',
                value: switch (themeMode) {
                  'light' => context.l10n.tr('theme_light'),
                  'dark' => context.l10n.tr('theme_dark'),
                  _ => context.l10n.tr('theme_system'),
                },
                onTap: onThemeTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniSummaryCard(
                icon: Icons.auto_awesome_outlined,
                title: isArabic ? 'المساعد الذكي' : 'AI Assistant',
                subtitle: isArabic ? 'جيميني' : 'Gemini',
                value: isTestingConnection ? '...' : context.l10n.tr('enabled'),
                onTap: onAiTap,
                trailing: Icon(
                  aiExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: AppMotion.smallDuration,
          curve: AppMotion.curve,
          child: aiExpanded
              ? Column(
                  children: <Widget>[
                    const SizedBox(height: 12),
                    PremiumCard(
                      padding: EdgeInsets.fromLTRB(
                        ResponsiveLayout.isCompact(context) ? 12 : 16,
                        14,
                        ResponsiveLayout.isCompact(context) ? 12 : 16,
                        14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            'Gemini',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: aiKey1Controller,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: isArabic
                                  ? 'مفتاح جيميني 1'
                                  : 'Gemini Key 1',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.vpn_key),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: aiKey2Controller,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: isArabic
                                  ? 'مفتاح جيميني 2'
                                  : 'Gemini Key 2',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.vpn_key),
                            ),
                          ),
                          const SizedBox(height: 12),
                          CompactDropdownFormField<int>(
                            value: selectedAiKeyIndex,
                            labelText: 'Default Key',
                            items: const <int>[0, 1],
                            itemLabel: (int value) =>
                                value == 0 ? 'Key 1' : 'Key 2',
                            onChanged: (int value) =>
                                onSelectedAiKeyChanged(value),
                          ),
                          const SizedBox(height: 14),
                          compact
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    OutlinedButton.icon(
                                      onPressed: isTestingConnection
                                          ? null
                                          : onTestAiConnection,
                                      icon: isTestingConnection
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.wifi),
                                      label: const Text(
                                        'Test Connection',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    FilledButton.icon(
                                      onPressed: onSaveAiKeys,
                                      icon: const Icon(Icons.save),
                                      label: Text(
                                        isArabic
                                            ? 'حفظ مفاتيح الذكاء الاصطناعي'
                                            : 'Save AI Keys',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: <Widget>[
                                    OutlinedButton.icon(
                                      onPressed: isTestingConnection
                                          ? null
                                          : onTestAiConnection,
                                      icon: isTestingConnection
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.wifi),
                                      label: const Text('Test Connection'),
                                    ),
                                    const SizedBox(width: 12),
                                    FilledButton.icon(
                                      onPressed: onSaveAiKeys,
                                      icon: const Icon(Icons.save),
                                      label: Text(
                                        isArabic
                                            ? 'حفظ مفاتيح الذكاء الاصطناعي'
                                            : 'Save AI Keys',
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _MiniSummaryCard extends StatelessWidget {
  const _MiniSummaryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool compact = ResponsiveLayout.isCompact(context);
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        height: compact ? 122 : 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 20, color: colors.primary),
                const Spacer(),
                if (trailing case final Widget widget) widget,
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.isArabic});

  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final String version = const String.fromEnvironment(
      'APP_VERSION',
      defaultValue: '1.2.0',
    );
    final String buildNumber = const String.fromEnvironment(
      'APP_BUILD_NUMBER',
      defaultValue: '16',
    );

    return _CompactSectionCard(
      title: context.l10n.tr('about_section'),
      icon: Icons.info_outline,
      children: <Widget>[
        _ActionSettingTile(
          icon: Icons.account_balance_wallet_outlined,
          title: context.l10n.tr('about_zakah_wealth'),
          subtitle: isArabic
              ? 'رفيق متميز للزكاة وإدارة الثروة'
              : 'A premium zakah and wealth companion',
          onTap: () {
            Navigator.of(context).push(
              AboutZakahWealthScreen.route(
                version: version,
                buildNumber: buildNumber,
              ),
            );
          },
        ),

        _ActionSettingTile(
          icon: Icons.privacy_tip_outlined,
          title: isArabic ? 'سياسة الخصوصية' : 'Privacy Policy',
          subtitle: isArabic
              ? 'اقرأ كيف تتم معالجة بياناتك'
              : 'Read how your data is handled',
          onTap: () {
            Navigator.of(context).push(PolicyDetailScreen.route(type: 'privacy'));
          },
        ),
        _ActionSettingTile(
          icon: Icons.description_outlined,
          title: isArabic ? 'شروط الخدمة' : 'Terms of Service',
          subtitle: isArabic ? 'راجع شروط الاستخدام' : 'Review the usage terms',
          onTap: () {
            Navigator.of(context).push(PolicyDetailScreen.route(type: 'terms'));
          },
        ),
        _ActionSettingTile(
          icon: Icons.support_agent_outlined,
          title: isArabic ? 'الدعم والملاحظات' : 'Support & Feedback',
          subtitle: isArabic
              ? 'أرسل ملاحظاتك أو احصل على المساعدة'
              : 'Send feedback or get help',
          onTap: () {
            Navigator.of(context).push(PolicyDetailScreen.route(type: 'support'));
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            isArabic
                ? 'ملاحظة الخصوصية: يظل الالتقاط التلقائي لرسائل البنوك على الجهاز، ويتجاهل رسائل OTP، ويمكن تعطيله في أي وقت.'
                : 'Privacy note: Automatic Bank SMS Capture stays on-device, ignores OTP messages, and can be disabled anytime.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

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
    required this.backupEnabled,
    required this.isLoading,
    required this.onSignIn,
    required this.onSignOut,
  });

  final String? name;
  final String? email;
  final String? photoUrl;
  final bool connected;
  final bool backupEnabled;
  final bool isLoading;
  final VoidCallback? onSignIn;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final String displayName = (name ?? '').trim().isEmpty
        ? 'Zakah Wealth'
        : name!.trim();
    final String emailValue = (email ?? '').trim();
    final String initial = displayName.characters.first.toUpperCase();
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 430;
        final bool veryCompact = constraints.maxWidth < 360;
        final double chipGap = veryCompact ? 6 : 8;
        final Widget actionButton = SizedBox(
          width: compact ? double.infinity : null,
          height: 36,
          child: connected
              ? OutlinedButton.icon(
                  key: const Key('googleSignOutButton'),
                  onPressed: isLoading ? null : onSignOut,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.white,
                    side: BorderSide(
                      color: AppColors.white.withValues(alpha: 0.24),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 12 : 14,
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: Text(
                    isArabic ? 'تسجيل الخروج' : 'Sign Out',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : FilledButton.icon(
                  key: const Key('googleSignInButton'),
                  onPressed: isLoading ? null : onSignIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.emeraldSoft,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 12 : 14,
                    ),
                  ),
                  icon: const Icon(Icons.login_rounded, size: 16),
                  label: Text(
                    context.l10n.tr('sign_in_google'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
        );

        return Container(
          key: const Key('settingsProfileHeader'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.emeraldSoft,
                AppColors.backgroundHeroDark,
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.emeraldSoft.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.gold,
                          backgroundImage:
                              (photoUrl != null && photoUrl!.trim().isNotEmpty)
                              ? NetworkImage(photoUrl!)
                              : null,
                          child:
                              (photoUrl != null && photoUrl!.trim().isNotEmpty)
                              ? null
                              : Text(
                                  initial,
                                  style: const TextStyle(
                                    color: AppColors.emeraldSoft,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                displayName,
                                maxLines: compact ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (emailValue.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 2),
                                Text(
                                  emailValue,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.white.withValues(
                                      alpha: 0.70,
                                    ),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: chipGap,
                      runSpacing: chipGap,
                      children: <Widget>[
                        _ProfileChip(
                          icon: connected
                              ? Icons.check_circle_outline
                              : Icons.link,
                          label: isArabic ? 'Google متصل' : 'Google Connected',
                          active: connected,
                        ),
                        _ProfileChip(
                          icon: backupEnabled
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_off_outlined,
                          label: isArabic ? 'النسخ مفعّل' : 'Backup Enabled',
                          active: backupEnabled,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    actionButton,
                  ],
                )
              : Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.gold,
                      backgroundImage:
                          (photoUrl != null && photoUrl!.trim().isNotEmpty)
                          ? NetworkImage(photoUrl!)
                          : null,
                      child: (photoUrl != null && photoUrl!.trim().isNotEmpty)
                          ? null
                          : Text(
                              initial,
                              style: const TextStyle(
                                color: AppColors.emeraldSoft,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (emailValue.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              emailValue,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.white.withValues(alpha: 0.70),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              _ProfileChip(
                                icon: connected
                                    ? Icons.check_circle_outline
                                    : Icons.link,
                                label: isArabic
                                    ? 'Google متصل'
                                    : 'Google Connected',
                                active: connected,
                              ),
                              _ProfileChip(
                                icon: backupEnabled
                                    ? Icons.cloud_done_outlined
                                    : Icons.cloud_off_outlined,
                                label: isArabic
                                    ? 'النسخ مفعّل'
                                    : 'Backup Enabled',
                                active: backupEnabled,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    actionButton,
                  ],
                ),
        );
      },
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bool compact = ResponsiveLayout.isCompact(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: ResponsiveLayout.chipPadding(
        context,
        wideHorizontal: 10,
        compactHorizontal: 8,
        veryCompactHorizontal: 6,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: active ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: AppColors.white),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.white.withValues(alpha: 0.92),
              fontSize: compact ? 10.5 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}


