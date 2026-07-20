import 'dart:math' as math;
import 'dart:io' show Platform;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/utils/currency_presentation.dart';
import '../../core/widgets/compact_selection_dialog.dart';
import '../../screens/account/shortcut_setup_guide_screen.dart';
import 'android_smart_capture_setup_screen.dart';
import '../../services/app_state_controller.dart';
import '../../services/cloud_backup_controller.dart';

class PremiumOnboardingPresentation extends StatefulWidget {
  const PremiumOnboardingPresentation({
    super.key,
    required this.onFinishOnboarding,
  });

  final VoidCallback onFinishOnboarding;

  @override
  State<PremiumOnboardingPresentation> createState() =>
      _PremiumOnboardingPresentationState();
}

class _PremiumOnboardingPresentationState
    extends State<PremiumOnboardingPresentation>
    with SingleTickerProviderStateMixin {
  static const Duration _transitionDuration = Duration(milliseconds: 250);
  static const Duration _imageDuration = Duration(milliseconds: 250);
  static const Duration _motionDuration = Duration(seconds: 12);

  int _index = 0;
  late final AnimationController _motionController;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: _motionDuration,
    );
    final bool isTesting =
        !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTesting) {
      _motionController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  Locale _locale(BuildContext context) {
    return Localizations.maybeLocaleOf(context) ??
        WidgetsBinding.instance.platformDispatcher.locale;
  }

  bool get _isFinalPage => _index == 6;

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  Future<void> _goToPage(int target) async {
    if (!mounted || target == _index) return;
    setState(() => _index = target);
  }

  Future<void> _next() async {
    if (_index >= 6) return;
    await _goToPage(_index + 1);
  }

  Future<void> _skipToDone() async {
    widget.onFinishOnboarding();
  }

  Future<void> _completeFlow() async {
    widget.onFinishOnboarding();
  }

  bool _isArabic(BuildContext context) =>
      _locale(context).languageCode.toLowerCase() == 'ar';

  Future<void> _openMoreCurrencies(BuildContext context) async {
    final AppStateController controller = context.read<AppStateController>();
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
    if (selected == null) return;
    await controller.updateMainCurrency(selected);
    await controller.updateDefaultEntryCurrency(selected);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _chooseQuickCurrency(String code) async {
    final AppStateController controller = context.read<AppStateController>();
    await controller.updateMainCurrency(code);
    await controller.updateDefaultEntryCurrency(code);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _chooseLanguage(String languageCode) async {
    final AppStateController controller = context.read<AppStateController>();
    await controller.updateLanguagePreference(languageCode);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openSmartCaptureSetup() async {
    if (_isAndroid) {
      final bool? completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const AndroidSmartCaptureSetupScreen(),
        ),
      );
      if (completed == true && mounted) {
        await _next();
      }
      return;
    }

    final bool? completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ShortcutSetupGuideScreen()),
    );
    if (completed == true && mounted) {
      await _next();
    }
  }

  Future<void> _connectGoogleDrive() async {
    final CloudBackupController cloudController = context
        .read<CloudBackupController>();
    final bool connected = await cloudController.connectGoogleDrive(
      interactive: true,
    );
    if (!mounted || !connected) return;
    await cloudController.setAutomaticBackupEnabled(true);
    await _next();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppStateController appState = context.watch<AppStateController>();
    final bool isArabic = _isArabic(context);
    final String currentLanguage = appState.state.languagePreference == 'ar'
        ? 'ar'
        : 'en';
    final String currentCurrency = appState.state.mainCurrency.isEmpty
        ? 'EGP'
        : appState.state.mainCurrency;
    final double width = MediaQuery.sizeOf(context).width;
    final double height = MediaQuery.sizeOf(context).height;
    final double heroMin = math.min(180.0, height * 0.28);
    final double heroMax = math.max(heroMin, math.min(360.0, height * 0.42));
    final double heroHeight = (height * 0.32).clamp(heroMin, heroMax);
    final EdgeInsets horizontalPadding = EdgeInsets.symmetric(
      horizontal: width < 420 ? AppSpacing.md : AppSpacing.lg,
    );

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) {
        if (didPop) return;
        if (_index > 0) {
          unawaited(_goToPage(_index - 1));
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundHeroDark,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      AppColors.backgroundHeroDark,
                      AppColors.backgroundDark.withValues(alpha: 0.96),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _IslamicPatternPainter(
                    color: context.premiumTokens.colors.onHero.withValues(
                      alpha: 0.010,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: horizontalPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                              return SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      if (!_isFinalPage)
                                        Align(
                                          alignment:
                                              AlignmentDirectional.centerEnd,
                                          child: TextButton(
                                            onPressed: _skipToDone,
                                            style: TextButton.styleFrom(
                                              foregroundColor: context
                                                  .premiumTokens
                                                  .colors
                                                  .onHero
                                                  .withValues(alpha: 0.92),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: AppSpacing.xs,
                                                    vertical: 0,
                                                  ),
                                              textStyle: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: context
                                                        .premiumTokens
                                                        .colors
                                                        .onHero
                                                        .withValues(
                                                          alpha: 0.92,
                                                        ),
                                                  ),
                                            ),
                                            child: Text(
                                              l10n.tr('onboarding_skip'),
                                            ),
                                          ),
                                        )
                                      else
                                        const SizedBox(height: 20),
                                      SizedBox(
                                        height: heroHeight,
                                        child: _HeroStage(
                                          imagePath: _imageForIndex(),
                                          imageFit: _imageFitForIndex(),
                                          fallbackIcon: _fallbackIconForIndex(),
                                          animationDuration: _imageDuration,
                                          motion: _motionController,
                                          pageIndex: _index,
                                          scale: _heroScaleForIndex(),
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      AnimatedSwitcher(
                                        duration: _transitionDuration,
                                        switchInCurve: Curves.easeOutCubic,
                                        switchOutCurve: Curves.easeInCubic,
                                        transitionBuilder:
                                            (
                                              Widget child,
                                              Animation<double> animation,
                                            ) {
                                              final Animation<Offset> offset =
                                                  Tween<Offset>(
                                                    begin: const Offset(
                                                      0,
                                                      0.02,
                                                    ),
                                                    end: Offset.zero,
                                                  ).animate(animation);
                                              return FadeTransition(
                                                opacity: animation,
                                                child: SlideTransition(
                                                  position: offset,
                                                  child: child,
                                                ),
                                              );
                                            },
                                        child: KeyedSubtree(
                                          key: ValueKey<int>(_index),
                                          child: _buildContent(
                                            context,
                                            l10n: l10n,
                                            currentLanguage: currentLanguage,
                                            currentCurrency: currentCurrency,
                                            isArabic: isArabic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Transform.translate(
                      offset: _index == 2 ? const Offset(0, -12) : Offset.zero,
                      child: _FooterActions(
                        primaryLabel: _primaryLabel(l10n),
                        onPrimary: _primaryAction(),
                        onSecondary: _index == 5
                            ? () => unawaited(_next())
                            : null,
                        secondaryLabel: _index == 5
                            ? l10n.tr('onboarding_skip_for_now')
                            : null,
                        showSecondary: _index == 5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required AppLocalizations l10n,
    required String currentLanguage,
    required String currentCurrency,
    required bool isArabic,
  }) {
    final ThemeData theme = Theme.of(context);
    final _OnboardingPageKey pageKey = _pageKeyForIndex(_index);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = math.min(constraints.maxWidth, 440);
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  _titleForIndex(l10n),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: context.premiumTokens.colors.onHero,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _subtitleForIndex(l10n),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: context.premiumTokens.colors.onHero.withValues(
                      alpha: 0.72,
                    ),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (pageKey == _OnboardingPageKey.welcome) ...<Widget>[
                  _CompactFeatureRow(
                    items: <_FeatureListItem>[
                      _FeatureListItem(
                        icon: Icons.savings_rounded,
                        label: l10n.tr('onboarding_track_wealth_title'),
                      ),
                      _FeatureListItem(
                        icon: Icons.calculate_rounded,
                        label: l10n.tr('onboarding_calculate_zakat_title'),
                      ),
                      _FeatureListItem(
                        icon: Icons.lock_rounded,
                        label: l10n.tr('onboarding_secure_backup_title'),
                      ),
                    ],
                  ),
                ],
                if (pageKey == _OnboardingPageKey.language) ...<Widget>[
                  _SimpleChoiceRow(
                    selectedValue: currentLanguage,
                    choices: <_SimpleChoiceData>[
                      _SimpleChoiceData(
                        value: 'en',
                        label: isArabic ? 'English' : l10n.tr('english'),
                      ),
                      _SimpleChoiceData(
                        value: 'ar',
                        label: isArabic ? 'العربية' : l10n.tr('arabic'),
                      ),
                    ],
                    onSelect: _chooseLanguage,
                  ),
                ],
                if (pageKey == _OnboardingPageKey.currency) ...<Widget>[
                  _CompactCurrencyGrid(
                    currentCurrency: currentCurrency,
                    onSelect: _chooseQuickCurrency,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: AlignmentDirectional.center,
                    child: TextButton(
                      onPressed: () => _openMoreCurrencies(context),
                      style: TextButton.styleFrom(
                        foregroundColor: context.premiumTokens.colors.selected,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 0,
                        ),
                      ),
                      child: Text(
                        isArabic ? 'المزيد...' : 'More...',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
                if (pageKey == _OnboardingPageKey.features) ...<Widget>[
                  _ChecklistPanel(
                    items: <String>[
                      l10n.tr('onboarding_track_wealth_body'),
                      l10n.tr('onboarding_calculate_zakat_body'),
                      l10n.tr('onboarding_secure_backup_body'),
                    ],
                  ),
                ],
                if (pageKey == _OnboardingPageKey.capture) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _ChecklistPanel(
                    items: <String>[
                      _isAndroid
                          ? l10n.tr('onboarding_android_capture_line_1')
                          : l10n.tr('setup_ios_enable_title'),
                      isArabic
                          ? 'لا يتم رفع الرسائل من جهازك'
                          : 'Messages never leave your device.',
                      isArabic
                          ? 'كل عملية تحتاج موافقتك'
                          : 'Every transaction requires your approval.',
                    ],
                  ),
                ],
                if (pageKey == _OnboardingPageKey.backup) ...<Widget>[
                  _ChecklistPanel(
                    items: <String>[
                      l10n.tr('onboarding_backup_encrypted'),
                      l10n.tr('onboarding_backup_private'),
                      l10n.tr('onboarding_backup_restore_anytime'),
                    ],
                  ),
                ],
                if (pageKey == _OnboardingPageKey.ready) ...<Widget>[
                  _ChecklistPanel(
                    items: <String>[
                      isArabic ? 'تم إعداد اللغة' : 'Language set',
                      isArabic ? 'تم إعداد العملة' : 'Currency selected',
                      isArabic
                          ? 'تم تجهيز Smart Capture'
                          : 'Smart Capture ready',
                      isArabic ? 'النسخ الاحتياطي جاهز' : 'Backup ready',
                    ],
                  ),
                ],
                if (!_isFinalPage) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  _PageDots(index: _index, pageCount: 7),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _titleForIndex(AppLocalizations l10n) {
    switch (_pageKeyForIndex(_index)) {
      case _OnboardingPageKey.welcome:
        return l10n.tr('onboarding_welcome_title');
      case _OnboardingPageKey.language:
        return l10n.tr('onboarding_language_title');
      case _OnboardingPageKey.currency:
        return l10n.tr('onboarding_currency_title');
      case _OnboardingPageKey.features:
        return l10n.tr('onboarding_features_title');
      case _OnboardingPageKey.capture:
        return _isAndroid
            ? l10n.tr('onboarding_android_capture_title')
            : l10n.tr('onboarding_ios_capture_title');
      case _OnboardingPageKey.backup:
        return l10n.tr('onboarding_backup_title');
      case _OnboardingPageKey.ready:
        return l10n.tr('onboarding_ready_title');
    }
  }

  String _subtitleForIndex(AppLocalizations l10n) {
    final bool isArabic = _isArabic(context);
    switch (_pageKeyForIndex(_index)) {
      case _OnboardingPageKey.welcome:
        return isArabic
            ? 'أدر ثروتك في مكان آمن واحد.'
            : 'Manage your wealth in one secure place.';
      case _OnboardingPageKey.language:
        return isArabic
            ? 'اختر اللغة التي تناسبك.'
            : 'Choose the language you prefer.';
      case _OnboardingPageKey.currency:
        return isArabic
            ? 'اختر العملة الأساسية لحساباتك.'
            : 'Choose the main currency for your finances.';
      case _OnboardingPageKey.features:
        return isArabic
            ? 'كل ما تحتاجه للثروة والزكاة.'
            : 'Everything you need for wealth and zakat.';
      case _OnboardingPageKey.capture:
        return isArabic
            ? 'التقاط ذكي وآمن لرسائل البنك.'
            : 'Private, review-first bank message capture.';
      case _OnboardingPageKey.backup:
        return isArabic
            ? 'نسخ احتياطي مشفر وجاهز عند الحاجة.'
            : 'Encrypted backup, ready whenever you need it.';
      case _OnboardingPageKey.ready:
        return isArabic
            ? 'كل شيء جاهز للبدء.'
            : 'Everything is set. You can start now.';
    }
  }

  String _primaryLabel(AppLocalizations l10n) {
    switch (_pageKeyForIndex(_index)) {
      case _OnboardingPageKey.capture:
        return _isAndroid
            ? l10n.tr('onboarding_enable_smart_capture')
            : l10n.tr('onboarding_open_shortcuts');
      case _OnboardingPageKey.backup:
        return l10n.tr('onboarding_connect_google_drive');
      case _OnboardingPageKey.ready:
        return l10n.tr('onboarding_start');
      case _OnboardingPageKey.welcome:
      case _OnboardingPageKey.language:
      case _OnboardingPageKey.currency:
      case _OnboardingPageKey.features:
        return l10n.tr('onboarding_continue');
    }
  }

  VoidCallback _primaryAction() {
    switch (_pageKeyForIndex(_index)) {
      case _OnboardingPageKey.welcome:
      case _OnboardingPageKey.language:
      case _OnboardingPageKey.currency:
      case _OnboardingPageKey.features:
        return () => unawaited(_next());
      case _OnboardingPageKey.capture:
        return () => unawaited(_openSmartCaptureSetup());
      case _OnboardingPageKey.backup:
        return () => unawaited(_connectGoogleDrive());
      case _OnboardingPageKey.ready:
        return () => unawaited(_completeFlow());
    }
  }

  String _imageForIndex() {
    switch (_pageKeyForIndex(_index)) {
      case _OnboardingPageKey.welcome:
        return 'assets/images/onboarding_vault.jpeg';
      case _OnboardingPageKey.language:
        return 'assets/images/onboarding_language.webp';
      case _OnboardingPageKey.currency:
        return 'assets/images/onboarding_currency.webp';
      case _OnboardingPageKey.features:
        return 'assets/images/onboarding_features.webp';
      case _OnboardingPageKey.capture:
        return 'assets/images/onboarding_capture.webp';
      case _OnboardingPageKey.backup:
        return 'assets/images/onboarding_backup.webp';
      case _OnboardingPageKey.ready:
        return 'assets/images/onboarding_ready.jpeg';
    }
  }

  double _heroScaleForIndex() {
    switch (_pageKeyForIndex(_index)) {
      case _OnboardingPageKey.welcome:
        return 0.98;
      case _OnboardingPageKey.language:
        return 0.95;
      case _OnboardingPageKey.currency:
        return 0.92;
      case _OnboardingPageKey.features:
        return 0.90;
      case _OnboardingPageKey.capture:
        return 0.95;
      case _OnboardingPageKey.backup:
        return 0.92;
      case _OnboardingPageKey.ready:
        return 1.0;
    }
  }

  BoxFit _imageFitForIndex() {
    return BoxFit.contain;
  }

  IconData _fallbackIconForIndex() {
    switch (_pageKeyForIndex(_index)) {
      case _OnboardingPageKey.welcome:
        return Icons.account_balance_wallet_rounded;
      case _OnboardingPageKey.language:
        return Icons.language_rounded;
      case _OnboardingPageKey.currency:
        return Icons.payments_rounded;
      case _OnboardingPageKey.features:
        return Icons.tune_rounded;
      case _OnboardingPageKey.capture:
        return _isAndroid ? Icons.sms_rounded : Icons.shortcut_rounded;
      case _OnboardingPageKey.backup:
        return Icons.cloud_done_rounded;
      case _OnboardingPageKey.ready:
        return Icons.verified_rounded;
    }
  }

  _OnboardingPageKey _pageKeyForIndex(int index) {
    switch (index) {
      case 0:
        return _OnboardingPageKey.welcome;
      case 1:
        return _OnboardingPageKey.language;
      case 2:
        return _OnboardingPageKey.currency;
      case 3:
        return _OnboardingPageKey.features;
      case 4:
        return _OnboardingPageKey.capture;
      case 5:
        return _OnboardingPageKey.backup;
      case 6:
        return _OnboardingPageKey.ready;
      default:
        return _OnboardingPageKey.welcome;
    }
  }
}

enum _OnboardingPageKey {
  welcome,
  language,
  currency,
  features,
  capture,
  backup,
  ready,
}

class _HeroStage extends StatelessWidget {
  const _HeroStage({
    required this.imagePath,
    required this.imageFit,
    required this.fallbackIcon,
    required this.animationDuration,
    required this.motion,
    required this.pageIndex,
    required this.scale,
  });

  final String imagePath;
  final BoxFit imageFit;
  final IconData fallbackIcon;
  final Duration animationDuration;
  final Animation<double> motion;
  final int pageIndex;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return AnimatedBuilder(
      animation: motion,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeInOutSine.transform(motion.value);
        final double floatY = math.sin(t * math.pi * 2) * 4.0;
        final double floatX = math.cos(t * math.pi * 2) * 1.5;
        final double pulse = 1.0 + (math.sin(t * math.pi * 2) * 0.008);
        final double pageScale = pageIndex == 6
            ? 1.0 + math.sin(t * math.pi * 2) * 0.015
            : 1.0;
        final double rotation = switch (pageIndex) {
          0 => math.sin(t * math.pi * 2) * 0.010,
          6 => -0.038 + math.sin(t * math.pi * 2) * 0.006,
          _ => 0.0,
        };
        final double glowAlpha = switch (pageIndex) {
          1 => 0.18,
          3 => 0.17,
          5 => 0.16,
          6 => 0.18,
          _ => 0.14,
        };
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.2),
                      radius: 0.9,
                      colors: <Color>[
                        tokens.colors.selected.withValues(alpha: glowAlpha),
                        AppColors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: animationDuration,
                  curve: Curves.easeOutCubic,
                  builder: (BuildContext context, double value, Widget? child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(floatX, floatY + 12 * (1 - value)),
                        child: Transform.rotate(
                          angle: rotation,
                          child: Transform.scale(
                            scale: scale * pulse * pageScale,
                            child: ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: <Color>[
                                    Colors.transparent,
                                    Colors.white,
                                    Colors.white,
                                    Colors.transparent,
                                  ],
                                  stops: <double>[0.0, 0.10, 0.88, 1.0],
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.dstIn,
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: Image.asset(
                    imagePath,
                    fit: imageFit,
                    alignment: Alignment.center,
                    errorBuilder:
                        (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
                          return Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadii.xl),
                              color: AppColors.transparent,
                            ),
                            child: Icon(
                              fallbackIcon,
                              size: pageIndex == 6 ? 92 : 72,
                              color: tokens.colors.onHero,
                            ),
                          );
                        },
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 126,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          AppColors.transparent,
                          AppColors.backgroundHeroDark.withValues(alpha: 0.56),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FooterActions extends StatelessWidget {
  const _FooterActions({
    required this.primaryLabel,
    required this.onPrimary,
    required this.showSecondary,
    this.onSecondary,
    this.secondaryLabel,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final bool showSecondary;
  final VoidCallback? onSecondary;
  final String? secondaryLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _OnboardingPrimaryButton(onPressed: onPrimary, label: primaryLabel),
          if (showSecondary &&
              onSecondary != null &&
              secondaryLabel != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: AlignmentDirectional.center,
              child: TextButton(
                onPressed: onSecondary,
                style: TextButton.styleFrom(
                  foregroundColor: tokens.colors.onHero,
                  textStyle: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                child: Text(secondaryLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.index, required this.pageCount});

  final int index;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(pageCount, (int i) {
        final bool active = i == index;
        return AnimatedContainer(
          duration: _PremiumOnboardingPresentationState._transitionDuration,
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: active
                ? tokens.colors.selected
                : tokens.colors.selected.withValues(alpha: 0.28),
          ),
        );
      }),
    );
  }
}

class _ChecklistPanel extends StatelessWidget {
  const _ChecklistPanel({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF10231E).withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: tokens.colors.onHeroBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items
            .map(
              (String item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: tokens.colors.selected,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        item,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tokens.colors.onHero.withValues(alpha: 0.84),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _FeatureListItem {
  const _FeatureListItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _CompactFeatureRow extends StatelessWidget {
  const _CompactFeatureRow({required this.items});

  final List<_FeatureListItem> items;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: items
          .map(
            (_FeatureListItem item) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF10231E).withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: tokens.colors.onHeroBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(item.icon, size: 16, color: tokens.colors.selected),
                  const SizedBox(width: 6),
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: tokens.colors.onHero,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _SimpleChoiceData {
  const _SimpleChoiceData({required this.value, required this.label});

  final String value;
  final String label;
}

class _SimpleChoiceRow extends StatelessWidget {
  const _SimpleChoiceRow({
    required this.selectedValue,
    required this.choices,
    required this.onSelect,
  });

  final String selectedValue;
  final List<_SimpleChoiceData> choices;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: choices
          .map(
            (_SimpleChoiceData choice) => Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  end: choice == choices.first ? AppSpacing.sm : 0,
                ),
                child: _ChoiceButton(
                  label: choice.label,
                  icon: '',
                  selected: selectedValue == choice.value,
                  showLeading: false,
                  onTap: () => onSelect(choice.value),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _CompactCurrencyGrid extends StatelessWidget {
  const _CompactCurrencyGrid({
    required this.currentCurrency,
    required this.onSelect,
  });

  final String currentCurrency;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final List<String> codes = <String>['SAR', 'EGP', 'USD', 'AED'];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: codes
          .map(
            (String code) => SizedBox(
              width: 92,
              child: _ChoiceButton(
                label: code,
                icon: _flagForCurrency(code),
                selected: currentCurrency.toUpperCase() == code.toUpperCase(),
                compact: true,
                onTap: () => onSelect(code),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.showLeading = true,
    this.compact = false,
  });

  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;
  final bool showLeading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final Color selectedBackground = tokens.colors.selected;
    final Color selectedForeground = Theme.of(context).colorScheme.onSecondary;
    final Color unselectedForeground = tokens.colors.onHero;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.x2l),
          child: AnimatedContainer(
            duration: _PremiumOnboardingPresentationState._transitionDuration,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? selectedBackground
                  : const Color(0xFF10231E).withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(AppRadii.x2l),
              border: Border.all(
                color: selected
                    ? selectedBackground
                    : tokens.colors.onHeroBorder,
              ),
              boxShadow: selected ? tokens.floatingShadow : const <BoxShadow>[],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (showLeading) ...<Widget>[
                  Text(
                    icon,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected
                          ? selectedForeground
                          : unselectedForeground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: selected
                          ? selectedForeground
                          : unselectedForeground,
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 16 : null,
                    ),
                  ),
                ),
                if (selected) ...<Widget>[
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: selectedForeground,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IslamicPatternPainter extends CustomPainter {
  const _IslamicPatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;
    final Paint fill = Paint()
      ..color = color.withValues(alpha: 0.005)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    const double step = 88;
    for (double y = -step; y < size.height + step; y += step) {
      for (double x = -step; x < size.width + step; x += step) {
        final Offset center = Offset(x + (y / step).floorEven() * 12, y);
        _drawMotif(canvas, center, paint, fill);
      }
    }
  }

  void _drawMotif(Canvas canvas, Offset center, Paint paint, Paint fill) {
    const double radius = 22;
    final Path diamond = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius, center.dy)
      ..close();
    canvas.drawPath(diamond, paint);

    final Path star = Path();
    for (int i = 0; i < 8; i++) {
      final double angle = (math.pi / 4) * i;
      final Offset point =
          center +
          Offset(
            math.cos(angle) * radius * 0.95,
            math.sin(angle) * radius * 0.95,
          );
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(star, fill);

    canvas.drawLine(
      Offset(center.dx - radius * 1.1, center.dy),
      Offset(center.dx + radius * 1.1, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 1.1),
      Offset(center.dx, center.dy + radius * 1.1),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _IslamicPatternPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

extension on double {
  int floorEven() {
    final int value = floor();
    return value.isEven ? value : value - 1;
  }
}

String _flagForCurrency(String code) {
  switch (code.toUpperCase()) {
    case 'SAR':
      return '🇸🇦';
    case 'EGP':
      return '🇪🇬';
    case 'AED':
      return '🇦🇪';
    case 'USD':
      return '🇺🇸';
    default:
      return '•';
  }
}

class _OnboardingPrimaryButton extends StatelessWidget {
  const _OnboardingPrimaryButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return SafeArea(
      top: false,
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadii.x2l),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    tokens.colors.selected.withValues(alpha: 1.0),
                    tokens.colors.selected.withValues(alpha: 0.92),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadii.x2l),
                boxShadow: tokens.floatingShadow,
                border: Border.all(
                  color: tokens.colors.onHero.withValues(alpha: 0.10),
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
