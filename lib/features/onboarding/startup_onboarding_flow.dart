import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../auth/auth_brand_ui.dart';
import 'android_smart_capture_setup_screen.dart';
import '../../screens/account/shortcut_setup_guide_screen.dart';
import '../../services/android_sms_capture_service.dart';
import '../../services/app_state_controller.dart';
import '../../services/cloud_backup_controller.dart';
import '../../services/biometric_service.dart';

class StartupOnboardingFlow extends StatefulWidget {
  const StartupOnboardingFlow({
    super.key,
    required this.preferences,
    required this.onComplete,
  });

  final SharedPreferences preferences;
  final Future<void> Function() onComplete;

  @override
  State<StartupOnboardingFlow> createState() => _StartupOnboardingFlowState();
}

class _StartupOnboardingFlowState extends State<StartupOnboardingFlow> {
  static const int _pageCount = 7;

  late int _index;
  bool _androidSmsGranted = false;
  bool _androidSmsKnown = false;
  bool _androidSmsRequestInFlight = false;
  bool _iosShortcutConfigured = false;
  bool _biometricAvailable = false;
  bool _biometricKnown = false;

  @override
  void initState() {
    super.initState();
    _index = _storedIndex.clamp(0, _pageCount - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refreshPlatformState());
    });
    unawaited(_persistIndex());
  }

  int get _storedIndex =>
      widget.preferences.getInt(StorageKeys.onboardingStepKey) ?? 0;

  Future<void> _persistIndex() async {
    await widget.preferences.setInt(StorageKeys.onboardingStepKey, _index);
  }

  Future<void> _clearProgress() async {
    await widget.preferences.remove(StorageKeys.onboardingStepKey);
  }

  bool _isAndroidPlatform(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.android;

  bool _isIOSPlatform(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.iOS;

  Future<void> _refreshPlatformState() async {
    if (Theme.of(context).platform == TargetPlatform.android) {
      final bool granted = await AndroidSmsCaptureService.hasSmsPermission();
      if (!mounted) return;
      setState(() {
        _androidSmsGranted = granted;
        _androidSmsKnown = true;
      });
    }
  }

  Future<void> _refreshBiometricSupport() async {
    final bool available = await BiometricService.canAuthenticate();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricKnown = true;
    });
  }

  Future<void> _goTo(int next) async {
    final int clamped = next.clamp(0, _pageCount - 1);
    if (clamped == _index) return;
    setState(() => _index = clamped);
    await _persistIndex();
    if (clamped == 3) {
      unawaited(_refreshPlatformState());
    } else if (clamped == 4) {
      unawaited(_refreshBiometricSupport());
    }
  }

  Future<void> _next() => _goTo(_index + 1);

  Future<void> _back() => _goTo(_index - 1);

  Future<void> _complete() async {
    await widget.onComplete();
    if (!mounted) return;
    await _clearProgress();
  }

  Future<bool> _connectGoogleDrive() async {
    try {
      final CloudBackupController cloudController =
          context.read<CloudBackupController>();
      final bool connected = await cloudController.connectGoogleDrive(
        interactive: true,
      );
      if (!mounted) return false;
      if (connected) {
        await cloudController.setAutomaticBackupEnabled(true);
      }
      return connected;
    } catch (_) {
      return false;
    }
  }

  Future<void> _selectLanguage(String languageCode) async {
    _index = 1;
    await _persistIndex();
    if (!mounted) return;
    await context.read<AppStateController>().updateLanguagePreference(
      languageCode,
    );
  }

  Future<void> _enableAndroidSmsCapture() async {
    if (!_isAndroidPlatform(context) || _androidSmsRequestInFlight) return;
    setState(() => _androidSmsRequestInFlight = true);
    final bool? completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const AndroidSmartCaptureSetupScreen(),
      ),
    );
    if (!mounted) return;
    final bool granted =
        completed == true || await AndroidSmsCaptureService.hasSmsPermission();
    setState(() {
      _androidSmsGranted = granted;
      _androidSmsKnown = true;
      _androidSmsRequestInFlight = false;
    });
  }

  Future<void> _openAndroidSettings() async {
    await AndroidSmsCaptureService.openAppSettings();
  }

  Future<void> _openShortcutsGuide() async {
    if (!_isIOSPlatform(context)) return;
    final bool? configured = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ShortcutSetupGuideScreen()),
    );
    if (!mounted) return;
    setState(() {
      _iosShortcutConfigured = configured == true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool isCompact = MediaQuery.sizeOf(context).width < 420;
    final bool hasStoredLanguagePreference = widget.preferences.containsKey(
      'language_preference',
    );
    final String selectedLanguage = hasStoredLanguagePreference
        ? context.watch<AppStateController>().state.languagePreference
        : WidgetsBinding.instance.platformDispatcher.locale.languageCode
                  .toLowerCase() ==
              'ar'
        ? 'ar'
        : 'en';

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) {
        if (didPop) return;
        if (_index > 0) {
          unawaited(_back());
        }
      },
      child: AuthBrandShell(
        maxWidth: 520,
        tone: AuthBackdropTone.shared,
        child: SingleChildScrollView(
          child: _buildStep(
            context: context,
            l10n: l10n,
            compact: isCompact,
            selectedLanguage: selectedLanguage,
            key: ValueKey<int>(_index),
          ),
        ),
      ),
    );
  }

  Widget _buildStep({
    required BuildContext context,
    required AppLocalizations l10n,
    required bool compact,
    required String selectedLanguage,
    required Key key,
  }) {
    final tokens = context.premiumTokens;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color textColor = tokens.colors.textPrimary;
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_index == 0)
          AuthBrandHeader(
            title: l10n.tr('brand_title'),
            subtitle: l10n.tr('onboarding_choose_language'),
            compact: compact,
            logoSize: compact ? 70 : 76,
          )
        else ...<Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_index + 1} / $_pageCount',
                style: TextStyle(
                  color: tokens.colors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              GestureDetector(
                onTap: () => unawaited(_complete()),
                child: Text(
                  isArabic ? 'تخطي' : 'Skip',
                  style: TextStyle(
                    color: tokens.colors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_index + 1) / _pageCount,
            backgroundColor: tokens.colors.divider,
            valueColor: AlwaysStoppedAnimation<Color>(tokens.colors.gold),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: 36),
          Text(
            _titleForStep(l10n),
            textAlign: TextAlign.start,
            style: textTheme.headlineSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _subtitleForStep(context, l10n),
            textAlign: TextAlign.start,
            style: textTheme.titleMedium?.copyWith(
              color: textColor.withValues(alpha: 0.82),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 32),
        ],
        _buildBody(context, l10n, textTheme),
        const SizedBox(height: 40),
        _buildActions(context, l10n, selectedLanguage),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    TextTheme textTheme,
  ) {
    final Color muted = context.premiumTokens.colors.textPrimary.withValues(
      alpha: 0.74,
    );

    switch (_index) {
      case 0:
        return _LanguageStep(
          englishLabel: l10n.tr('english'),
          englishSubtitle: l10n.tr('onboarding_language_english_subtitle'),
          arabicLabel: l10n.tr('arabic'),
          arabicSubtitle: l10n.tr('onboarding_language_arabic_subtitle'),
          selectedLanguage: context
              .watch<AppStateController>()
              .state
              .languagePreference,
          onSelectLanguage: _selectLanguage,
        );
      case 1:
        return _TextBlock(
          lines: <String>[l10n.tr('onboarding_welcome_body')],
          style: textTheme.titleMedium?.copyWith(color: muted, height: 1.4),
        );
      case 2:
        return _TextBlock(
          lines: <String>[l10n.tr('onboarding_privacy_body')],
          style: textTheme.titleMedium?.copyWith(color: muted, height: 1.45),
        );
      case 3:
        return const _CaptureStep();
      case 4:
        return const _SecurityStep();
      case 5:
        return _BackupStep(
          encryptedLabel: l10n.tr('onboarding_backup_encrypted'),
          privateLabel: l10n.tr('onboarding_backup_private'),
          restoreLabel: l10n.tr('onboarding_backup_restore_anytime'),
        );
      case 6:
        return _TextBlock(
          lines: <String>[l10n.tr('onboarding_ready_body')],
          style: textTheme.titleMedium?.copyWith(color: muted, height: 1.45),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPrimaryButton({required VoidCallback? onPressed, required String label, Key? key}) {
    final tokens = context.premiumTokens;
    return FilledButton(
      key: key,
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: tokens.colors.gold,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _buildSecondaryButton({required VoidCallback? onPressed, required String label, Key? key}) {
    final tokens = context.premiumTokens;
    return OutlinedButton(
      key: key,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: tokens.colors.gold),
        foregroundColor: tokens.colors.gold,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _buildBackButton({required VoidCallback onPressed, required String label}) {
    final tokens = context.premiumTokens;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: tokens.colors.textPrimary.withValues(alpha: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.arrow_back, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    AppLocalizations l10n,
    String selectedLanguage,
  ) {
    final bool isFinal = _index == _pageCount - 1;
    final bool canGoBack = _index > 0;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TargetPlatform platform = Theme.of(context).platform;
    final bool isAndroid = platform == TargetPlatform.android;
    final bool isIOS = platform == TargetPlatform.iOS;

    if (_index == 0) {
      final String continueLabel = selectedLanguage == 'ar'
          ? l10n.tr('onboarding_continue_in_arabic')
          : l10n.tr('onboarding_continue_in_english');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildPrimaryButton(
            onPressed: () => unawaited(_next()),
            label: continueLabel,
          ),
        ],
      );
    }

    if (_index == 3) {
      final bool showAndroidStatus = isAndroid;
      final bool showIosStatus = isIOS;
      final bool isEnabled = isAndroid ? _androidSmsGranted : _iosShortcutConfigured;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (showAndroidStatus)
            _StatusPill(
              label: _androidSmsGranted
                  ? l10n.tr('onboarding_capture_status_enabled')
                  : _androidSmsKnown
                  ? l10n.tr('onboarding_capture_status_denied')
                  : l10n.tr('onboarding_capture_status_not_enabled'),
              colorScheme: colorScheme,
            )
          else if (showIosStatus)
            _StatusPill(
              label: _iosShortcutConfigured
                  ? l10n.tr('onboarding_capture_status_enabled')
                  : l10n.tr('onboarding_capture_status_not_enabled'),
              colorScheme: colorScheme,
            )
          else
            _StatusPill(
              label: l10n.tr('onboarding_capture_status_unavailable'),
              colorScheme: colorScheme,
            ),
          const SizedBox(height: AppSpacing.lg),
          if (isEnabled)
            _buildPrimaryButton(
              key: const ValueKey<String>('onboarding-capture-continue'),
              onPressed: () => unawaited(_next()),
              label: l10n.tr('onboarding_continue'),
            )
          else if (showAndroidStatus) ...<Widget>[
            _buildPrimaryButton(
              key: const ValueKey<String>('onboarding-capture-enable'),
              onPressed: _androidSmsRequestInFlight
                  ? null
                  : () => unawaited(_enableAndroidSmsCapture()),
              label: l10n.tr('onboarding_capture_enable_sms'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildSecondaryButton(
              key: const ValueKey<String>('onboarding-capture-not-now'),
              onPressed: () => unawaited(_next()),
              label: l10n.tr('onboarding_not_now'),
            ),
            if (_androidSmsKnown && !_androidSmsGranted) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                key: const ValueKey<String>('onboarding-capture-settings'),
                onPressed: () => unawaited(_openAndroidSettings()),
                child: Text(l10n.tr('onboarding_open_settings')),
              ),
            ],
          ] else if (showIosStatus) ...<Widget>[
            _buildPrimaryButton(
              key: const ValueKey<String>('onboarding-capture-shortcuts'),
              onPressed: () => unawaited(_openShortcutsGuide()),
              label: l10n.tr('onboarding_open_shortcuts'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildSecondaryButton(
              key: const ValueKey<String>('onboarding-capture-not-now'),
              onPressed: () => unawaited(_next()),
              label: l10n.tr('onboarding_not_now'),
            ),
          ] else ...<Widget>[
            _buildPrimaryButton(
              key: const ValueKey<String>('onboarding-capture-not-now'),
              onPressed: () => unawaited(_next()),
              label: l10n.tr('onboarding_not_now'),
            ),
          ],
          if (canGoBack) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _buildBackButton(
              onPressed: () => unawaited(_back()),
              label: l10n.tr('onboarding_back'),
            ),
          ],
        ],
      );
    }

    if (_index == 4) {
      final bool biometricEnabled =
          context.watch<AppStateController>().state.biometricLockEnabled;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _StatusPill(
            label: biometricEnabled
                ? l10n.tr('onboarding_capture_status_enabled')
                : _biometricKnown
                ? (_biometricAvailable
                      ? l10n.tr('onboarding_security_status_available')
                      : l10n.tr('onboarding_security_unavailable'))
                : l10n.tr('onboarding_security_status_checking'),
            colorScheme: colorScheme,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (biometricEnabled || (_biometricKnown && !_biometricAvailable))
            _buildPrimaryButton(
              key: const ValueKey<String>('onboarding-security-continue'),
              onPressed: () => unawaited(_next()),
              label: l10n.tr('onboarding_continue'),
            )
          else ...<Widget>[
            _buildPrimaryButton(
              key: const ValueKey<String>('onboarding-security-enable'),
              onPressed: () async {
                if (!_biometricKnown) {
                  await _refreshBiometricSupport();
                }
                if (_biometricAvailable) {
                  await context
                      .read<AppStateController>()
                      .updateBiometricLockEnabled(true);
                }
              },
              label: l10n.tr('onboarding_security_enable'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildSecondaryButton(
              key: const ValueKey<String>('onboarding-security-not-now'),
              onPressed: () => unawaited(_next()),
              label: l10n.tr('onboarding_security_not_now'),
            ),
          ],
          if (canGoBack) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _buildBackButton(
              onPressed: () => unawaited(_back()),
              label: l10n.tr('onboarding_back'),
            ),
          ],
        ],
      );
    }

    if (_index == 5) {
      final bool connected =
          _maybeCloudBackupController(context)?.isDriveConnected == true;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _StatusPill(
            label: connected
                ? l10n.tr('onboarding_capture_status_enabled')
                : l10n.tr('onboarding_capture_status_not_enabled'),
            colorScheme: colorScheme,
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildPrimaryButton(
            key: const ValueKey<String>('onboarding-backup-primary'),
            onPressed: connected
                ? () => unawaited(_next())
                : () async {
                    final bool connected = await _connectGoogleDrive();
                    if (connected && mounted) {
                      await _next();
                    }
                  },
            label: connected
                ? l10n.tr('onboarding_continue')
                : l10n.tr('onboarding_connect_google_drive'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSecondaryButton(
            key: const ValueKey<String>('onboarding-backup-not-now'),
            onPressed: () => unawaited(_next()),
            label: l10n.tr('onboarding_skip_for_now'),
          ),
          if (canGoBack) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _buildBackButton(
              onPressed: () => unawaited(_back()),
              label: l10n.tr('onboarding_back'),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildPrimaryButton(
          key: ValueKey<String>(
            isFinal ? 'onboarding-start' : 'onboarding-continue',
          ),
          onPressed:
              isFinal ? () => unawaited(_complete()) : () => unawaited(_next()),
          label: isFinal ? l10n.tr('onboarding_start') : l10n.tr('onboarding_continue'),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (canGoBack)
          _buildBackButton(
            onPressed: () => unawaited(_back()),
            label: l10n.tr('onboarding_back'),
          ),
      ],
    );
  }

  String _titleForStep(AppLocalizations l10n) {
    return switch (_index) {
      1 => l10n.tr('onboarding_welcome_title'),
      2 => l10n.tr('onboarding_privacy_title'),
      3 =>
        Theme.of(context).platform == TargetPlatform.android
            ? l10n.tr('setup_android_sms_title')
            : l10n.tr('onboarding_capture_title'),
      4 => l10n.tr('onboarding_security_title'),
      5 => l10n.tr('onboarding_backup_title'),
      6 => l10n.tr('onboarding_ready_title'),
      _ => l10n.tr('brand_title'),
    };
  }

  String _subtitleForStep(BuildContext context, AppLocalizations l10n) {
    return switch (_index) {
      1 => l10n.tr('onboarding_welcome_subtitle'),
      2 => l10n.tr('onboarding_privacy_subtitle'),
      3 =>
        Theme.of(context).platform == TargetPlatform.android
            ? l10n.tr('setup_android_sms_subtitle')
            : l10n.tr('onboarding_capture_ios_body'),
      4 => l10n.tr('onboarding_security_body'),
      5 => l10n.tr('onboarding_backup_body'),
      6 => l10n.tr('onboarding_ready_subtitle'),
      _ => l10n.tr('onboarding_choose_language'),
    };
  }

  CloudBackupController? _maybeCloudBackupController(BuildContext context) {
    try {
      return context.watch<CloudBackupController>();
    } catch (_) {
      return null;
    }
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.lines, required this.style});

  final List<String> lines;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bodyColor = isDark ? tokens.colors.textSecondary : const Color(0xFF4A5D5A);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: tokens.colors.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: tokens.colors.divider),
        boxShadow: tokens.softShadow,
      ),
      child: Text(
        lines.join('\n\n'),
        style: style?.copyWith(color: bodyColor, fontSize: 14, height: 1.55) ??
            TextStyle(color: bodyColor, fontSize: 14, height: 1.55),
        textAlign: TextAlign.start,
      ),
    );
  }
}

class _LanguageStep extends StatelessWidget {
  const _LanguageStep({
    required this.englishLabel,
    required this.englishSubtitle,
    required this.arabicLabel,
    required this.arabicSubtitle,
    required this.selectedLanguage,
    required this.onSelectLanguage,
  });

  final String englishLabel;
  final String englishSubtitle;
  final String arabicLabel;
  final String arabicSubtitle;
  final String selectedLanguage;
  final Future<void> Function(String languageCode) onSelectLanguage;

  @override
  Widget build(BuildContext context) {
    final bool arabicSelected = selectedLanguage == 'ar';
    final List<Widget> options = arabicSelected
        ? <Widget>[
            _LanguageChoiceButton(
              key: const ValueKey<String>('onboarding-language-ar'),
              label: arabicLabel,
              subtitle: arabicSubtitle,
              selected: true,
              flag: '🇸🇦',
              onPressed: () => unawaited(onSelectLanguage('ar')),
            ),
            const SizedBox(height: AppSpacing.sm),
            _LanguageChoiceButton(
              key: const ValueKey<String>('onboarding-language-en'),
              label: englishLabel,
              subtitle: englishSubtitle,
              selected: false,
              flag: '🇬🇧',
              onPressed: () => unawaited(onSelectLanguage('en')),
            ),
          ]
        : <Widget>[
            _LanguageChoiceButton(
              key: const ValueKey<String>('onboarding-language-en'),
              label: englishLabel,
              subtitle: englishSubtitle,
              selected: true,
              flag: '🇬🇧',
              onPressed: () => unawaited(onSelectLanguage('en')),
            ),
            const SizedBox(height: AppSpacing.sm),
            _LanguageChoiceButton(
              key: const ValueKey<String>('onboarding-language-ar'),
              label: arabicLabel,
              subtitle: arabicSubtitle,
              selected: false,
              flag: '🇸🇦',
              onPressed: () => unawaited(onSelectLanguage('ar')),
            ),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: options,
    );
  }
}

class _LanguageChoiceButton extends StatelessWidget {
  const _LanguageChoiceButton({
    super.key,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onPressed,
    required this.flag,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onPressed;
  final String flag;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: tokens.colors.card,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: selected ? tokens.colors.gold : tokens.colors.divider,
            width: selected ? 2.0 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: tokens.colors.gold.withValues(alpha: 0.25),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(
              flag,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: tokens.colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? tokens.colors.textSecondary : const Color(0xFF4A5D5A),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? tokens.colors.gold : Colors.transparent,
                border: Border.all(
                  color: selected ? tokens.colors.gold : tokens.colors.divider,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureStep extends StatelessWidget {
  const _CaptureStep();

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color descColor = isDark ? tokens.colors.textSecondary : const Color(0xFF4A5D5A);
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final bool isAndroid = Theme.of(context).platform == TargetPlatform.android;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: tokens.colors.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: tokens.colors.divider),
        boxShadow: tokens.softShadow,
      ),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: tokens.colors.gold.withValues(alpha: 0.15),
            radius: 36,
            child: Icon(
              isAndroid ? Icons.message_outlined : Icons.bolt_outlined,
              color: tokens.colors.gold,
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isArabic
                ? (isAndroid ? 'الالتقاط الذكي للرسائل' : 'مزامنة اختصارات سيري')
                : (isAndroid ? 'Smart SMS Capture' : 'Siri Shortcuts Sync'),
            style: TextStyle(
              color: tokens.colors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            tokens: tokens,
            descColor: descColor,
            icon: Icons.lock_outline,
            text: isArabic
                ? (isAndroid
                    ? 'تتم معالجة جميع الرسائل محلياً بالكامل على هاتفك. لا يتم رفع أي بيانات شخصية إلى خوادم خارجية.'
                    : 'أتمتة المعاملات على نظام iOS باستخدام الاختصارات المدمجة. معالجة محلية خاصة وآمنة.')
                : (isAndroid
                    ? 'All SMS messages are processed locally on your phone. No personal data ever uploads to external servers.'
                    : 'Automate transactions on iOS using native Shortcuts. Fully private and locally processed.'),
          ),
          const Divider(height: 24),
          _buildDetailRow(
            tokens: tokens,
            descColor: descColor,
            icon: Icons.filter_list_off_outlined,
            text: isArabic
                ? (isAndroid
                    ? 'تجاهل الرسائل الشخصية تماماً، ورموز التحقق الثنائي (OTP). يقرأ فقط رسائل تنبيهات المعاملات البنكية.'
                    : 'يعمل تلقائياً عند استلام رسائل المعاملات البنكية. يقرأ البيانات المطابقة فقط.')
                : (isAndroid
                    ? 'Strictly ignores personal messages, verification codes, and OTPs. Reads only transaction SMS alerts.'
                    : 'Triggers automatically when you receive bank SMS alerts. Only reads matching structures.'),
          ),
          const Divider(height: 24),
          _buildDetailRow(
            tokens: tokens,
            descColor: descColor,
            icon: Icons.check_circle_outline,
            text: isArabic
                ? 'يقوم بصياغة مسودات معلقة آمنة لتتمكن من مراجعتها والموافقة عليها يدوياً قبل الدخول في حسابات الزكاة.'
                : 'Creates safe pending transaction drafts for your manual review and approval before Zakat calculation.',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required PremiumThemeTokens tokens,
    required Color descColor,
    required IconData icon,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: tokens.colors.gold),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: descColor,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _SecurityStep extends StatelessWidget {
  const _SecurityStep();

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color descColor = isDark ? tokens.colors.textSecondary : const Color(0xFF4A5D5A);
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final stateController = context.watch<AppStateController>();
    final bool biometricEnabled = stateController.state.biometricLockEnabled;

    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tokens.colors.gold.withValues(alpha: 0.15),
            border: Border.all(color: tokens.colors.gold, width: 2.0),
          ),
          child: Icon(
            Icons.fingerprint_rounded,
            color: tokens.colors.gold,
            size: 54,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: tokens.colors.card,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: tokens.colors.divider),
            boxShadow: tokens.softShadow,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: tokens.colors.gold.withValues(alpha: 0.10),
                    radius: 18,
                    child: Icon(Icons.security_outlined, color: tokens.colors.gold, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'تفعيل الحماية البيومترية' : 'Setup Biometrics',
                          style: TextStyle(
                            color: tokens.colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isArabic ? 'استخدم بصمة الإصبع أو الوجه لتسجيل الدخول الآمن' : 'Use Face ID or Fingerprint for secure login',
                          style: TextStyle(
                            color: descColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: biometricEnabled,
                    activeTrackColor: tokens.colors.gold,
                    onChanged: (bool value) async {
                      await stateController.updateBiometricLockEnabled(value);
                    },
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: tokens.colors.gold.withValues(alpha: 0.10),
                    radius: 18,
                    child: Icon(Icons.password_outlined, color: tokens.colors.gold, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'رمز مرور الجهاز الاحتياطي' : 'Fallback Device Lock',
                          style: TextStyle(
                            color: tokens.colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isArabic ? 'استخدام رمز مرور قفل الشاشة كبديل لحماية حسابك' : 'Use system screen lock PIN/Pattern as fallback',
                          style: TextStyle(
                            color: descColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: biometricEnabled,
                    activeTrackColor: tokens.colors.gold,
                    onChanged: (bool value) async {
                      await stateController.updateBiometricLockEnabled(value);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isArabic 
              ? 'الخصوصية أولاً: بياناتك المالية مشفرة وآمنة تماماً على هذا الجهاز.' 
              : 'Privacy First: Your financial records are encrypted and secured locally.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: descColor,
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _BackupStep extends StatelessWidget {
  const _BackupStep({
    required this.encryptedLabel,
    required this.privateLabel,
    required this.restoreLabel,
  });

  final String encryptedLabel;
  final String privateLabel;
  final String restoreLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color descColor = isDark ? tokens.colors.textSecondary : const Color(0xFF4A5D5A);
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: tokens.colors.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: tokens.colors.divider),
        boxShadow: tokens.softShadow,
      ),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: tokens.colors.gold.withValues(alpha: 0.15),
            radius: 36,
            child: Icon(
              Icons.cloud_upload_outlined,
              color: tokens.colors.gold,
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'النسخ الاحتياطي السحابي' : 'Cloud Backup Sync',
            style: TextStyle(
              color: tokens.colors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          _buildItem(tokens, descColor, Icons.lock_outline, encryptedLabel),
          const Divider(height: 24),
          _buildItem(tokens, descColor, Icons.privacy_tip_outlined, privateLabel),
          const Divider(height: 24),
          _buildItem(tokens, descColor, Icons.settings_backup_restore_outlined, restoreLabel),
        ],
      ),
    );
  }

  Widget _buildItem(PremiumThemeTokens tokens, Color descColor, IconData icon, String label) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: tokens.colors.gold.withValues(alpha: 0.10),
          radius: 16,
          child: Icon(icon, color: tokens.colors.gold, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: descColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.colorScheme});

  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Align(
      alignment: Alignment.center,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: tokens.colors.gold.withValues(alpha: 0.3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC5A059),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
