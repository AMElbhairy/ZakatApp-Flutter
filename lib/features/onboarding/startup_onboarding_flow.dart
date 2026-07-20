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
    final bool isAndroid = _isAndroidPlatform(context);
    final bool isIOS = _isIOSPlatform(context);
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
          Text(
            _titleForStep(l10n),
            textAlign: TextAlign.start,
            style: textTheme.headlineSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _subtitleForStep(context, l10n),
            textAlign: TextAlign.start,
            style: textTheme.titleMedium?.copyWith(
              color: textColor.withValues(alpha: 0.82),
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        _buildBody(context, l10n, textTheme),
        const SizedBox(height: AppSpacing.xl),
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
    final TargetPlatform platform = Theme.of(context).platform;
    final bool isAndroid = platform == TargetPlatform.android;
    final bool isIOS = platform == TargetPlatform.iOS;
    final CloudBackupController? cloudBackupController =
        _maybeCloudBackupController(context);

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
          Row(
            children: <Widget>[
              if (canGoBack)
                TextButton(
                  onPressed: () => unawaited(_back()),
                  child: Text(l10n.tr('onboarding_back')),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () => unawaited(_next()),
                child: Text(continueLabel),
              ),
            ],
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
            FilledButton(
              key: const ValueKey<String>('onboarding-capture-continue'),
              onPressed: () => unawaited(_next()),
              child: Text(l10n.tr('onboarding_continue')),
            )
          else if (showAndroidStatus) ...<Widget>[
            FilledButton(
              key: const ValueKey<String>('onboarding-capture-enable'),
              onPressed: _androidSmsRequestInFlight
                  ? null
                  : () => unawaited(_enableAndroidSmsCapture()),
              child: Text(l10n.tr('onboarding_capture_enable_sms')),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              key: const ValueKey<String>('onboarding-capture-not-now'),
              onPressed: () => unawaited(_next()),
              child: Text(l10n.tr('onboarding_not_now')),
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
            FilledButton(
              key: const ValueKey<String>('onboarding-capture-shortcuts'),
              onPressed: () => unawaited(_openShortcutsGuide()),
              child: Text(l10n.tr('onboarding_open_shortcuts')),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              key: const ValueKey<String>('onboarding-capture-not-now'),
              onPressed: () => unawaited(_next()),
              child: Text(l10n.tr('onboarding_not_now')),
            ),
          ] else ...<Widget>[
            FilledButton(
              key: const ValueKey<String>('onboarding-capture-not-now'),
              onPressed: () => unawaited(_next()),
              child: Text(l10n.tr('onboarding_not_now')),
            ),
          ],
          if (canGoBack) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () => unawaited(_back()),
              child: Text(l10n.tr('onboarding_back')),
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
            FilledButton(
              key: const ValueKey<String>('onboarding-security-continue'),
              onPressed: () => unawaited(_next()),
              child: Text(l10n.tr('onboarding_continue')),
            )
          else ...<Widget>[
            FilledButton(
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
              child: Text(l10n.tr('onboarding_security_enable')),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              key: const ValueKey<String>('onboarding-security-not-now'),
              onPressed: () => unawaited(_next()),
              child: Text(l10n.tr('onboarding_security_not_now')),
            ),
          ],
          if (canGoBack) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () => unawaited(_back()),
              child: Text(l10n.tr('onboarding_back')),
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
          FilledButton(
            key: const ValueKey<String>('onboarding-backup-primary'),
            onPressed: connected
                ? () => unawaited(_next())
                : () async {
                    final bool connected = await _connectGoogleDrive();
                    if (connected && mounted) {
                      await _next();
                    }
                  },
            child: Text(
              connected
                  ? l10n.tr('onboarding_continue')
                  : l10n.tr('onboarding_connect_google_drive'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const ValueKey<String>('onboarding-backup-not-now'),
            onPressed: () => unawaited(_next()),
            child: Text(l10n.tr('onboarding_skip_for_now')),
          ),
          if (canGoBack) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () => unawaited(_back()),
              child: Text(l10n.tr('onboarding_back')),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton(
          key: ValueKey<String>(
            isFinal ? 'onboarding-start' : 'onboarding-continue',
          ),
          onPressed:
              isFinal ? () => unawaited(_complete()) : () => unawaited(_next()),
          child: Text(
            isFinal ? l10n.tr('onboarding_start') : l10n.tr('onboarding_continue'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: canGoBack ? () => unawaited(_back()) : null,
          child: Text(l10n.tr('onboarding_back')),
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
    return Text(lines.join('\n\n'), style: style, textAlign: TextAlign.start);
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
    final bool englishSelected = selectedLanguage != 'ar';
    final List<Widget> options = arabicSelected
        ? <Widget>[
            _LanguageChoiceButton(
              key: const ValueKey<String>('onboarding-language-ar'),
              label: arabicLabel,
              subtitle: arabicSubtitle,
              selected: true,
              onPressed: () => unawaited(onSelectLanguage('ar')),
            ),
            const SizedBox(height: AppSpacing.sm),
            _LanguageChoiceButton(
              key: const ValueKey<String>('onboarding-language-en'),
              label: englishLabel,
              subtitle: englishSubtitle,
              selected: false,
              onPressed: () => unawaited(onSelectLanguage('en')),
            ),
          ]
        : <Widget>[
            _LanguageChoiceButton(
              key: const ValueKey<String>('onboarding-language-en'),
              label: englishLabel,
              subtitle: englishSubtitle,
              selected: true,
              onPressed: () => unawaited(onSelectLanguage('en')),
            ),
            const SizedBox(height: AppSpacing.sm),
            _LanguageChoiceButton(
              key: const ValueKey<String>('onboarding-language-ar'),
              label: arabicLabel,
              subtitle: arabicSubtitle,
              selected: false,
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
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (selected) ...<Widget>[
                  const Icon(Icons.check_rounded, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(label),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary.withValues(
                  alpha: selected ? 0.88 : 0.72,
                ),
              ),
            ),
          ],
        ),
      ],
    );
    return selected
        ? FilledButton(onPressed: onPressed, child: content)
        : FilledButton.tonal(onPressed: onPressed, child: content);
  }
}

class _CaptureStep extends StatelessWidget {
  const _CaptureStep();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _SecurityStep extends StatelessWidget {
  const _SecurityStep();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _StatusPill(label: encryptedLabel, colorScheme: colorScheme),
            _StatusPill(label: privateLabel, colorScheme: colorScheme),
            _StatusPill(label: restoreLabel, colorScheme: colorScheme),
          ],
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
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
          borderRadius: AppRadii.pill,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
