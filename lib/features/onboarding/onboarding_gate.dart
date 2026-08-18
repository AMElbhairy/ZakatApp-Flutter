import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/motion/app_motion.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/utils/currency_presentation.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/compact_selection_dialog.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../features/auth/auth_brand_ui.dart';
import '../../features/onboarding/android_smart_capture_setup_screen.dart';
import '../../features/onboarding/startup_onboarding_flow.dart';
import '../../screens/account/account_screen.dart';
import '../../screens/account/cloud_backup_screen.dart';
import '../../screens/account/notifications_screen.dart';
import '../../screens/account/shortcut_setup_guide_screen.dart';
import '../../services/android_sms_capture_service.dart';
import '../../services/app_state_controller.dart';
import '../../repositories/app_state_repository.dart';
import '../../services/smart_capture_alert_service.dart';
import '../../services/cloud_backup_controller.dart';

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({
    super.key,
    required this.preferences,
    required this.child,
    this.skipInTests = true,
  });

  final SharedPreferences preferences;
  final Widget child;
  final bool skipInTests;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  late bool _completed;
  static const bool _enabled = true;
  static const int _onboardingVersion = 2;

  @override
  void initState() {
    super.initState();
    final bool legacyCompleted =
        widget.preferences.getBool(StorageKeys.onboardingCompletedKey) ?? false;
    final int completedVersion =
        widget.preferences.getInt(StorageKeys.onboardingCompletedVersionKey) ??
        0;
    final AppStateController controller = context.read<AppStateController>();
    final bool hasExistingAppState =
        controller.appStateLoadSource != AppStateLoadSource.missing ||
        controller.appStateRawStatePresent;

    final bool hasRunBefore =
        widget.preferences.getBool('has_run_before') ?? false;

    final bool isMidOnboarding =
        widget.preferences.containsKey(StorageKeys.onboardingStepKey);

    _completed =
        widget.skipInTests ||
        legacyCompleted ||
        completedVersion >= _onboardingVersion;

    if (!_completed && hasExistingAppState && hasRunBefore && !isMidOnboarding) {
      _completed = true;
      unawaited(_markCompleted(versioned: true));
    } else if (_completed && completedVersion < _onboardingVersion) {
      unawaited(_markCompleted(versioned: true));
    }
  }

  Future<void> _markCompleted({required bool versioned}) async {
    await widget.preferences.setBool(StorageKeys.onboardingCompletedKey, true);
    if (versioned) {
      await widget.preferences.setInt(
        StorageKeys.onboardingCompletedVersionKey,
        _onboardingVersion,
      );
    }
    await widget.preferences.remove(StorageKeys.onboardingStepKey);
  }

  Future<void> _completeFlow() async {
    await _markCompleted(versioned: true);
    if (!mounted) return;
    setState(() => _completed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    if (_completed) return widget.child;

    return StartupOnboardingFlow(
      preferences: widget.preferences,
      onComplete: _completeFlow,
    );
  }
}

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.onSkipToSetup,
    required this.onFinishOnboarding,
  });

  final VoidCallback onSkipToSetup;
  final VoidCallback onFinishOnboarding;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const int _pageCount = 7;
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _goToPage(int target) async {
    if (!mounted) return;
    if (AppMotion.reduceMotion(context)) {
      _controller.jumpToPage(target);
      return;
    }
    await _controller.animateToPage(
      target,
      duration: AppMotion.pageDuration,
      curve: AppMotion.curve,
    );
  }

  Future<void> _next() async {
    if (_index >= _pageCount - 1) return;
    await _goToPage(_index + 1);
  }

  Future<void> _skip() async {
    if (_index == 0) {
      widget.onSkipToSetup();
      return;
    }
    await _next();
  }

  Locale _locale(BuildContext context) {
    return Localizations.maybeLocaleOf(context) ??
        WidgetsBinding.instance.platformDispatcher.locale;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final AppLocalizations l10n = context.l10n;
    final Locale locale = _locale(context);
    final String family = AppTypography.familyFor(locale);
    final bool compact = MediaQuery.sizeOf(context).width < 420;
    final bool isArabic = locale.languageCode.toLowerCase() == 'ar';

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) {
        if (didPop) return;
        if (_index > 0) {
          unawaited(_goToPage(_index - 1));
        }
      },
      child: Scaffold(
        backgroundColor: tokens.colors.primarySurface,
        body: Stack(
          children: <Widget>[
            const AuthBrandBackdrop(tone: AuthBackdropTone.hero),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveLayout.compactHorizontalPadding(
                        context,
                        wide: 20,
                        compact: 16,
                        veryCompact: 12,
                      ),
                      vertical: AppSpacing.md,
                    ),
                    child: Column(
                      children: <Widget>[
                        _OnboardingHeader(
                          title: l10n.tr('brand_title'),
                          subtitle: _stageSubtitle(l10n),
                          family: family,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Expanded(
                          child: PageView(
                            controller: _controller,
                            onPageChanged: (int value) {
                              setState(() => _index = value);
                            },
                            children: <Widget>[
                              _WelcomePage(compact: compact, family: family),
                              _FeaturesPage(family: family),
                              _LanguagePage(family: family),
                              _CurrencyPage(family: family, isArabic: isArabic),
                              _SmartCapturePage(family: family),
                              _BackupPage(family: family),
                              _ReadyPage(family: family),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _OnboardingFooter(
                          index: _index,
                          pageCount: _pageCount,
                          onBack: _index > 0
                              ? () => unawaited(_goToPage(_index - 1))
                              : null,
                          onSkip: _index == 0
                              ? _skip
                              : (_index < 5 ? () => unawaited(_next()) : null),
                          onContinue: _index == 6
                              ? widget.onFinishOnboarding
                              : () => unawaited(_next()),
                          onPrimaryLabel: _primaryLabel(l10n),
                          onSecondaryLabel: _index == 0
                              ? l10n.tr('onboarding_skip')
                              : null,
                          activeFamily: family,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stageSubtitle(AppLocalizations l10n) {
    switch (_index) {
      case 0:
        return l10n.tr('onboarding_welcome_title');
      case 1:
        return l10n.tr('onboarding_features_title');
      case 2:
        return l10n.tr('onboarding_language_title');
      case 3:
        return l10n.tr('onboarding_currency_title');
      case 4:
        return l10n.tr('onboarding_android_capture_title');
      case 5:
        return l10n.tr('onboarding_backup_title');
      case 6:
        return l10n.tr('onboarding_ready_title');
      default:
        return l10n.tr('brand_tagline');
    }
  }

  String _primaryLabel(AppLocalizations l10n) {
    if (_index == 0) return l10n.tr('onboarding_continue');
    if (_index == 6) return l10n.tr('onboarding_start');
    return l10n.tr('onboarding_continue');
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.title,
    required this.subtitle,
    required this.family,
  });

  final String title;
  final String subtitle;
  final String family;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Column(
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AuthBrandHeader(
            title: title,
            subtitle: subtitle,
            logoSize: 62,
            centered: false,
            compact: true,
            framedLogo: false,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            context.l10n.tr('brand_trust_message'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.colors.secondaryText,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.compact, required this.family});

  final bool compact;
  final String family;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return _PageFrame(
      child: Column(
        children: <Widget>[
          _HeroIllustration(
            child: Image.asset(
              'assets/images/onboarding_vault.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  _BrandVaultIllustration(compact: compact),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.tr('onboarding_welcome_title'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.tr('onboarding_welcome_subtitle'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
          const SizedBox(height: AppSpacing.lg),
          _OnboardingStatRow(
            children: <Widget>[
              _OnboardingStatChip(
                icon: Icons.savings_rounded,
                label: context.l10n.tr('onboarding_track_wealth_title'),
              ),
              _OnboardingStatChip(
                icon: Icons.calculate_rounded,
                label: context.l10n.tr('onboarding_calculate_zakat_title'),
              ),
              _OnboardingStatChip(
                icon: Icons.lock_rounded,
                label: context.l10n.tr('onboarding_secure_backup_title'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeaturesPage extends StatelessWidget {
  const _FeaturesPage({required this.family});

  final String family;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<_FeatureCardData> cards = <_FeatureCardData>[
      _FeatureCardData(
        icon: Icons.account_balance_wallet_rounded,
        title: l10n.tr('onboarding_track_wealth_title'),
        body: l10n.tr('onboarding_track_wealth_body'),
      ),
      _FeatureCardData(
        icon: Icons.calculate_rounded,
        title: l10n.tr('onboarding_calculate_zakat_title'),
        body: l10n.tr('onboarding_calculate_zakat_body'),
      ),
      _FeatureCardData(
        icon: Icons.sms_rounded,
        title: l10n.tr('onboarding_smart_capture_title'),
        body: l10n.tr('onboarding_smart_capture_body'),
      ),
      _FeatureCardData(
        icon: Icons.cloud_done_rounded,
        title: l10n.tr('onboarding_secure_backup_title'),
        body: l10n.tr('onboarding_secure_backup_body'),
      ),
    ];

    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.tr('onboarding_features_title'),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.tr('onboarding_features_subtitle'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool twoColumn = constraints.maxWidth >= 560;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: cards
                    .map((_FeatureCardData card) {
                      final double width = twoColumn
                          ? (constraints.maxWidth - AppSpacing.md) / 2
                          : constraints.maxWidth;
                      return SizedBox(
                        width: width,
                        child: PremiumCard(
                          child: _FeatureCard(data: card, family: family),
                        ),
                      );
                    })
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LanguagePage extends StatelessWidget {
  const _LanguagePage({required this.family});

  final String family;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppStateController controller = context.watch<AppStateController>();
    final String currentLanguage = controller.state.languagePreference == 'ar'
        ? 'ar'
        : 'en';

    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _IllustrationTile(
            icon: Icons.language_rounded,
            title: l10n.tr('onboarding_language_title'),
            body: l10n.tr('onboarding_language_body'),
            imagePath: 'assets/images/onboarding_language.png',
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.tr('onboarding_language_title'),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.tr('onboarding_language_body'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<String>(
            segments: <ButtonSegment<String>>[
              ButtonSegment<String>(
                value: 'en',
                label: Text(l10n.tr('english')),
                icon: const Icon(Icons.translate_rounded),
              ),
              ButtonSegment<String>(
                value: 'ar',
                label: Text(l10n.tr('arabic')),
                icon: const Icon(Icons.translate_rounded),
              ),
            ],
            selected: <String>{currentLanguage},
            onSelectionChanged: (Set<String> selection) async {
              if (selection.isEmpty) return;
              await controller.updateLanguagePreference(selection.first);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            currentLanguage == 'ar' ? 'العربية' : 'English',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.premiumTokens.colors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyPage extends StatefulWidget {
  const _CurrencyPage({required this.family, required this.isArabic});

  final String family;
  final bool isArabic;

  @override
  State<_CurrencyPage> createState() => _CurrencyPageState();
}

class _CurrencyPageState extends State<_CurrencyPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _currencies() {
    const List<String> priority = <String>['SAR', 'EGP', 'AED', 'USD'];
    return <String>[
      ...priority,
      ...CurrencyPresentation.marketCurrencyCodes.where(
        (String code) => !priority.contains(code.trim().toUpperCase()),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppStateController controller = context.watch<AppStateController>();
    final String selectedCurrency = controller.state.mainCurrency.isEmpty
        ? 'EGP'
        : controller.state.mainCurrency;
    final List<String> currencies = _currencies();

    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _IllustrationTile(
            icon: Icons.payments_rounded,
            title: l10n.tr('onboarding_currency_title'),
            body: l10n.tr('onboarding_currency_body'),
            imagePath: 'assets/images/onboarding_currency.png',
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.tr('onboarding_currency_title'),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.tr('onboarding_currency_body'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: l10n.tr('search_notes'),
              prefixIcon: const Icon(Icons.search_rounded),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  CurrencyPresentation.selectorLabel(
                    selectedCurrency,
                    isRtl: widget.isArabic,
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.tr('onboarding_main_currency'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.premiumTokens.colors.secondaryText,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 260,
                  child: ListView.separated(
                    itemCount: currencies.where((String currency) {
                      final String query = _searchController.text
                          .trim()
                          .toLowerCase();
                      if (query.isEmpty) return true;
                      return currency.toLowerCase().contains(query);
                    }).length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (BuildContext context, int index) {
                      final List<String> filtered = currencies
                          .where((String currency) {
                            final String query = _searchController.text
                                .trim()
                                .toLowerCase();
                            if (query.isEmpty) return true;
                            return currency.toLowerCase().contains(query);
                          })
                          .toList(growable: false);
                      final String code = filtered[index];
                      final bool selected =
                          code.toUpperCase() == selectedCurrency.toUpperCase();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Text(
                          CurrencyPresentation.flagEmoji(code),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        title: Text(code),
                        trailing: selected
                            ? const Icon(Icons.check_circle_rounded)
                            : null,
                        onTap: () async {
                          await controller.updateMainCurrency(code);
                          await controller.updateDefaultEntryCurrency(code);
                        },
                      );
                    },
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

class _SmartCapturePage extends StatelessWidget {
  const _SmartCapturePage({required this.family});

  final String family;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final List<_FeatureCardData> features = isAndroid
        ? <_FeatureCardData>[
            _FeatureCardData(
              icon: Icons.sms_rounded,
              title: l10n.tr('onboarding_android_capture_line_1'),
              body: l10n.tr('onboarding_android_capture_line_2'),
            ),
            _FeatureCardData(
              icon: Icons.battery_charging_full_rounded,
              title: l10n.tr('onboarding_android_capture_line_3'),
              body: l10n.tr('onboarding_android_capture_line_4'),
            ),
            _FeatureCardData(
              icon: Icons.notifications_active_rounded,
              title: l10n.tr('onboarding_enable_smart_capture'),
              body: l10n.tr('onboarding_android_capture_body'),
            ),
          ]
        : <_FeatureCardData>[
            _FeatureCardData(
              icon: Icons.shortcut_rounded,
              title: l10n.tr('setup_ios_enable_title'),
              body: l10n.tr('setup_ios_enable_subtitle'),
            ),
            _FeatureCardData(
              icon: Icons.auto_fix_high_rounded,
              title: l10n.tr('setup_ios_create_automation_title'),
              body: l10n.tr('setup_ios_create_automation_subtitle'),
            ),
            _FeatureCardData(
              icon: Icons.bolt_rounded,
              title: l10n.tr('setup_ios_ready_title'),
              body: l10n.tr('setup_ios_ready_subtitle'),
            ),
          ];

    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _HeroIllustration(
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        context.premiumTokens.colors.gold.withValues(
                          alpha: 0.22,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Image.asset(
                  'assets/images/onboarding_capture.webp',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    isAndroid
                        ? Icons.sms_rounded
                        : Icons.keyboard_command_key_rounded,
                    size: 76,
                    color: context.premiumTokens.colors.gold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(
            eyebrow: l10n.tr('onboarding_smart_capture_title'),
            title: isAndroid
                ? l10n.tr('onboarding_android_capture_title')
                : l10n.tr('onboarding_ios_capture_title'),
            body: isAndroid
                ? l10n.tr('onboarding_android_capture_body')
                : l10n.tr('onboarding_ios_capture_body'),
          ),
          const SizedBox(height: AppSpacing.md),
          if (MediaQuery.sizeOf(context).width >= 700)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: features
                  .map(
                    (_FeatureCardData data) => SizedBox(
                      width: (MediaQuery.sizeOf(context).width - 64) / 3,
                      child: _FeatureCard(data: data, family: family),
                    ),
                  )
                  .toList(growable: false),
            )
          else
            Column(
              children: features
                  .map(
                    (_FeatureCardData data) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _FeatureCard(data: data, family: family),
                    ),
                  )
                  .toList(growable: false),
            ),
          const SizedBox(height: AppSpacing.md),
          if (isAndroid)
            Column(
              children: <Widget>[
                AppPrimaryButton(
                  onPressed: () async {
                    await _enableAndroidSmartCapture(context);
                  },
                  label: l10n.tr('onboarding_enable_smart_capture'),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppPrimaryButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AndroidSmartCaptureSetupScreen(),
                      ),
                    );
                  },
                  label: l10n.tr('onboarding_open'),
                ),
              ],
            )
          else
            Column(
              children: <Widget>[
                AppPrimaryButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ShortcutSetupGuideScreen(),
                      ),
                    );
                  },
                  label: l10n.tr('onboarding_open_shortcuts'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.tr('onboarding_skip_for_now'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _enableAndroidSmartCapture(BuildContext context) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.tr('onboarding_enable_smart_capture')),
        content: Text(l10n.tr('onboarding_android_capture_body')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.tr('onboarding_skip')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.tr('onboarding_enable_smart_capture')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final bool granted = await AndroidSmsCaptureService.requestSmsPermission();
    if (!granted || !context.mounted) return;
    final SmartCaptureAlertService alertService = context
        .read<SmartCaptureAlertService>();
    final bool notificationsEnabled = await alertService
        .areAndroidNotificationsEnabled();
    if (!notificationsEnabled) {
      await alertService.requestAndroidNotificationsPermission();
    }
    if (!context.mounted) return;
    await context.read<AppStateController>().setAndroidSmsAutoCaptureEnabled(
      true,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  final String eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          eyebrow.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: tokens.colors.gold,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
        ),
      ],
    );
  }
}

class _BackupPage extends StatelessWidget {
  const _BackupPage({required this.family});

  final String family;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final CloudBackupController cloudController = context
        .watch<CloudBackupController>();
    final bool connected = cloudController.isDriveConnected;

    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _HeroIllustration(
            child: Image.asset(
              'assets/images/onboarding_backup.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.cloud_done_rounded,
                size: 76,
                color: connected
                    ? context.premiumTokens.colors.hero
                    : context.premiumTokens.colors.gold,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            connected
                ? (Localizations.localeOf(context).languageCode == 'ar'
                      ? 'تم ربط Google Drive'
                      : 'Google Drive Connected')
                : l10n.tr('onboarding_backup_title'),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            connected
                ? (Localizations.localeOf(context).languageCode == 'ar'
                      ? 'تم إعداد وتجهيز النسخ الاحتياطي المشفر بنجاح.'
                      : 'Your secure encrypted backups are configured and ready.')
                : l10n.tr('onboarding_backup_body'),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _BadgeCard(label: l10n.tr('onboarding_backup_encrypted')),
              _BadgeCard(label: l10n.tr('onboarding_backup_private')),
              _BadgeCard(label: l10n.tr('onboarding_backup_restore_anytime')),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (connected)
            AppPrimaryButton(
              onPressed: () async {
                final pageController = context
                    .findAncestorStateOfType<_OnboardingFlowState>()
                    ?._controller;
                if (pageController != null) {
                  await pageController.nextPage(
                    duration: AppMotion.pageDuration,
                    curve: AppMotion.curve,
                  );
                }
              },
              label: Localizations.localeOf(context).languageCode == 'ar'
                  ? 'متابعة'
                  : 'Continue',
            )
          else
            AppPrimaryButton(
              onPressed: () async {
                final bool connected =
                    await cloudController.connectGoogleDrive(interactive: true);
                if (connected) {
                  await cloudController.setAutomaticBackupEnabled(true);
                }
              },
              label: l10n.tr('onboarding_connect_google_drive'),
            ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () async {
              final pageController = context
                  .findAncestorStateOfType<_OnboardingFlowState>()
                  ?._controller;
              if (pageController != null) {
                await pageController.nextPage(
                  duration: AppMotion.pageDuration,
                  curve: AppMotion.curve,
                );
              }
            },
            child: Text(
              connected
                  ? (Localizations.localeOf(context).languageCode == 'ar'
                        ? 'التالي'
                        : 'Next')
                  : l10n.tr('onboarding_skip_for_now'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyPage extends StatelessWidget {
  const _ReadyPage({required this.family});

  final String family;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _HeroIllustration(
            child: Image.asset(
              'assets/images/onboarding_ready.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: <Color>[
                      context.premiumTokens.colors.gold,
                      context.premiumTokens.colors.gold.withValues(alpha: 0.6),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.shield_rounded,
                  size: 72,
                  color: context.premiumTokens.colors.hero,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.tr('onboarding_ready_title'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.tr('onboarding_ready_subtitle'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class InitialSetupWizardScreen extends StatefulWidget {
  const InitialSetupWizardScreen({
    super.key,
    required this.onComplete,
    required this.onBack,
  });

  final Future<void> Function() onComplete;
  final VoidCallback onBack;

  @override
  State<InitialSetupWizardScreen> createState() =>
      _InitialSetupWizardScreenState();
}

class _InitialSetupWizardScreenState extends State<InitialSetupWizardScreen> {
  final Set<String> _completed = <String>{};

  Locale _locale(BuildContext context) {
    return Localizations.maybeLocaleOf(context) ??
        WidgetsBinding.instance.platformDispatcher.locale;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppStateController controller = context.watch<AppStateController>();
    final List<_SetupAction> actions = <_SetupAction>[
      _SetupAction(
        id: 'currency',
        label: l10n.tr('onboarding_main_currency'),
        subtitle: CurrencyPresentation.selectorLabel(
          controller.state.mainCurrency.isEmpty
              ? 'EGP'
              : controller.state.mainCurrency,
          isRtl: _locale(context).languageCode.toLowerCase() == 'ar',
        ),
        icon: Icons.payments_rounded,
        onTap: () async {
          await _openCurrencyDialog(context);
        },
      ),
      _SetupAction(
        id: 'theme',
        label: l10n.tr('onboarding_theme'),
        subtitle: _themeLabel(l10n, controller.state.themeMode),
        icon: Icons.palette_rounded,
        onTap: () async {
          await _openThemeDialog(context);
        },
      ),
      _SetupAction(
        id: 'notifications',
        label: l10n.tr('onboarding_notifications'),
        subtitle: l10n.tr('onboarding_open'),
        icon: Icons.notifications_none_rounded,
        onTap: () async {
          await Navigator.of(context).push(NotificationsScreen.route());
        },
      ),
      _SetupAction(
        id: 'biometric',
        label: l10n.tr('onboarding_biometric_lock'),
        subtitle: l10n.tr('onboarding_open'),
        icon: Icons.fingerprint_rounded,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AccountScreen()),
          );
        },
      ),
      _SetupAction(
        id: 'smart-capture',
        label: l10n.tr('onboarding_smart_capture'),
        subtitle: l10n.tr('onboarding_open'),
        icon: Icons.sms_rounded,
        onTap: () async {
          if (defaultTargetPlatform == TargetPlatform.iOS) {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ShortcutSetupGuideScreen(),
              ),
            );
          } else {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AndroidSmartCaptureSetupScreen(),
              ),
            );
          }
        },
      ),
      _SetupAction(
        id: 'backup',
        label: l10n.tr('onboarding_cloud_backup'),
        subtitle: l10n.tr('onboarding_open'),
        icon: Icons.cloud_rounded,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CloudBackupScreen()),
          );
        },
      ),
    ];

    final double progress = _completed.length / actions.length;
    final String progressLabel = l10n.trf(
      'onboarding_setup_progress',
      <String, String>{
        'done': _completed.length.toString(),
        'total': actions.length.toString(),
      },
    );

    return Scaffold(
      backgroundColor: context.premiumTokens.colors.primarySurface,
      body: Stack(
        children: <Widget>[
          const AuthBrandBackdrop(tone: AuthBackdropTone.shared),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveLayout.compactHorizontalPadding(
                      context,
                      wide: 20,
                      compact: 16,
                      veryCompact: 12,
                    ),
                    vertical: AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _OnboardingHeader(
                        title: context.l10n.tr('onboarding_setup_title'),
                        subtitle: context.l10n.tr('onboarding_setup_subtitle'),
                        family: AppTypography.familyFor(_locale(context)),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        progressLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.premiumTokens.colors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Expanded(
                        child: ListView.separated(
                          itemCount: actions.length,
                          separatorBuilder: (BuildContext context, int index) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (BuildContext context, int index) {
                            final _SetupAction action = actions[index];
                            final bool done = _completed.contains(action.id);
                            return PremiumCard(
                              onTap: () async {
                                await action.onTap();
                                if (!mounted) return;
                                setState(() => _completed.add(action.id));
                              },
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: context.premiumTokens.colors.gold
                                          .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.md,
                                      ),
                                    ),
                                    child: Icon(action.icon),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          action.label,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          action.subtitle,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Icon(
                                    done
                                        ? Icons.check_circle_rounded
                                        : Icons.chevron_right_rounded,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: <Widget>[
                          TextButton(
                            onPressed: widget.onBack,
                            child: Text(context.l10n.tr('onboarding_skip')),
                          ),
                          const Spacer(),
                          AppPrimaryButton(
                            onPressed: () async {
                              await widget.onComplete();
                            },
                            label: context.l10n.tr('onboarding_start'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openThemeDialog(BuildContext context) async {
    final AppLocalizations l10n = context.l10n;
    final AppStateController controller = context.read<AppStateController>();
    final String? selected = await showCompactSelectionDialog<String>(
      context: context,
      title: l10n.tr('onboarding_theme'),
      options: <String>['system', 'light', 'dark'],
      optionLabel: (String value) => switch (value) {
        'light' => l10n.tr('theme_light'),
        'dark' => l10n.tr('theme_dark'),
        _ => l10n.tr('theme_system'),
      },
      selectedValueLabel: switch (controller.state.themeMode) {
        'light' => l10n.tr('theme_light'),
        'dark' => l10n.tr('theme_dark'),
        _ => l10n.tr('theme_system'),
      },
    );
    if (selected != null) {
      await controller.updateThemeMode(selected);
    }
  }

  Future<void> _openCurrencyDialog(BuildContext context) async {
    final controller = context.read<AppStateController>();
    final bool isArabic = _locale(context).languageCode.toLowerCase() == 'ar';
    final List<String> currencies = <String>[
      'SAR',
      'EGP',
      'AED',
      'USD',
      ...CurrencyPresentation.marketCurrencyCodes.where(
        (String code) => !<String>{
          'SAR',
          'EGP',
          'AED',
          'USD',
        }.contains(code.trim().toUpperCase()),
      ),
    ];
    final String? selected = await showCompactSelectionDialog<String>(
      context: context,
      title: context.l10n.tr('onboarding_main_currency'),
      options: currencies,
      optionLabel: (String value) =>
          CurrencyPresentation.selectorLabel(value, isRtl: isArabic),
      selectedValueLabel: CurrencyPresentation.selectorLabel(
        controller.state.mainCurrency.isEmpty
            ? 'EGP'
            : controller.state.mainCurrency,
        isRtl: isArabic,
      ),
    );
    if (selected != null) {
      await controller.updateMainCurrency(selected);
      await controller.updateDefaultEntryCurrency(selected);
    }
  }

  String _themeLabel(AppLocalizations l10n, String value) {
    return switch (value) {
      'light' => l10n.tr('theme_light'),
      'dark' => l10n.tr('theme_dark'),
      _ => l10n.tr('theme_system'),
    };
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: child,
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 210),
      decoration: BoxDecoration(
        borderRadius: AppRadii.hero,
        gradient: LinearGradient(
          colors: <Color>[
            tokens.colors.gold.withValues(alpha: 0.22),
            tokens.colors.hero.withValues(alpha: 0.10),
            tokens.colors.surface.withValues(alpha: 0.65),
          ],
        ),
        border: Border.all(color: tokens.colors.border.withValues(alpha: 0.45)),
        boxShadow: tokens.heroShadow,
      ),
      child: Center(child: child),
    );
  }
}

class _BrandVaultIllustration extends StatelessWidget {
  const _BrandVaultIllustration({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final double size = compact ? 80 : 100;
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          PositionedDirectional(
            start: compact ? 20 : 40,
            top: 20,
            child: _MiniCard(icon: Icons.insights_rounded),
          ),
          PositionedDirectional(
            end: compact ? 20 : 40,
            top: 20,
            child: _MiniCard(icon: Icons.cloud_done_rounded),
          ),
          PositionedDirectional(
            start: compact ? 35 : 55,
            bottom: 20,
            child: _MiniCard(icon: Icons.sms_rounded),
          ),
          PositionedDirectional(
            end: compact ? 35 : 55,
            bottom: 20,
            child: _MiniCard(icon: Icons.calculate_rounded),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.colors.gold.withValues(alpha: 0.18),
              border: Border.all(
                color: tokens.colors.gold.withValues(alpha: 0.28),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: tokens.colors.gold.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: size * 0.48,
              color: tokens.colors.hero,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: AppRadii.card,
        color: tokens.colors.surface.withValues(alpha: 0.82),
        border: Border.all(color: tokens.colors.border.withValues(alpha: 0.45)),
      ),
      child: Icon(icon, color: tokens.colors.hero),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.data, required this.family});

  final _FeatureCardData data;
  final String family;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            color: tokens.colors.gold.withValues(alpha: 0.16),
          ),
          child: Icon(data.icon, color: tokens.colors.hero),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          data.title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          data.body,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
        ),
      ],
    );
  }
}

class _FeatureCardData {
  const _FeatureCardData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _IllustrationTile extends StatelessWidget {
  const _IllustrationTile({
    required this.icon,
    required this.title,
    required this.body,
    this.imagePath,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              color: tokens.colors.gold.withValues(alpha: 0.16),
            ),
            clipBehavior: Clip.antiAlias,
            child: imagePath != null
                ? Image.asset(
                    imagePath!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(icon, color: tokens.colors.hero),
                  )
                : Icon(icon, color: tokens.colors.hero),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _OnboardingStatRow extends StatelessWidget {
  const _OnboardingStatRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: children,
    );
  }
}

class _OnboardingStatChip extends StatelessWidget {
  const _OnboardingStatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _OnboardingFooter extends StatelessWidget {
  const _OnboardingFooter({
    required this.index,
    required this.pageCount,
    required this.onBack,
    required this.onSkip,
    required this.onContinue,
    required this.onPrimaryLabel,
    required this.onSecondaryLabel,
    required this.activeFamily,
  });

  final int index;
  final int pageCount;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final VoidCallback? onContinue;
  final String onPrimaryLabel;
  final String? onSecondaryLabel;
  final String activeFamily;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _PageIndicator(index: index, pageCount: pageCount),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            if (onBack != null)
              TextButton(
                onPressed: onBack,
                child: Text(context.l10n.tr('cancel')),
              )
            else
              const SizedBox(width: 8),
            const Spacer(),
            if (onSkip != null)
              TextButton(
                onPressed: onSkip,
                child: Text(
                  onSecondaryLabel ?? context.l10n.tr('onboarding_skip'),
                ),
              ),
            const SizedBox(width: AppSpacing.sm),
            AppPrimaryButton(onPressed: onContinue, label: onPrimaryLabel),
          ],
        ),
      ],
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.index, required this.pageCount});

  final int index;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(pageCount, (int i) {
        final bool active = i == index;
        return AnimatedContainer(
          duration: AppMotion.pageDuration,
          curve: AppMotion.curve,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: active
                ? context.premiumTokens.colors.gold
                : context.premiumTokens.colors.gold.withValues(alpha: 0.22),
          ),
        );
      }),
    );
  }
}

class _SetupAction {
  const _SetupAction({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final Future<void> Function() onTap;
}
