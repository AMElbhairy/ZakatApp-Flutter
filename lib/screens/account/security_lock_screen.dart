import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../services/biometric_service.dart';
import '../../features/auth/auth_brand_ui.dart';

class SecurityLockScreen extends StatefulWidget {
  const SecurityLockScreen({
    super.key,
    required this.onUnlock,
    required this.autoPrompt,
  });

  final Future<void> Function() onUnlock;
  final bool autoPrompt;

  @override
  State<SecurityLockScreen> createState() => _SecurityLockScreenState();
}

class _SecurityLockScreenState extends State<SecurityLockScreen>
    with WidgetsBindingObserver {
  String _biometricLabel = 'Face ID';
  bool _authenticating = false;
  bool _autoPromptScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBiometricType();
    _scheduleAutoAuthenticate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadBiometricType() async {
    final String label = await BiometricService.getBiometricTypeLabel();
    if (!mounted) return;
    setState(() {
      _biometricLabel = label;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleAutoAuthenticate(force: true);
    }
  }

  void _scheduleAutoAuthenticate({bool force = false}) {
    if (!mounted) return;
    if (_autoPromptScheduled || _authenticating) return;
    if (!force && !widget.autoPrompt) return;
    _autoPromptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _autoPromptScheduled = false;
      await _authenticate();
    });
  }

  Future<void> _authenticate() async {
    if (_authenticating) {
      return;
    }
    setState(() {
      _authenticating = true;
    });
    try {
      await widget.onUnlock();
    } finally {
      if (mounted) {
        setState(() {
          _authenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color secondaryTextColor = dark
        ? tokens.colors.textSecondary
        : tokens.colors.hero;
    final AppLocalizations l10n = context.l10n;
    return AuthBrandShell(
      tone: AuthBackdropTone.shared,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          AuthBrandHeader(
            title: l10n.tr('brand_title'),
            subtitle: l10n.tr('lock_title'),
            logoSize: 68,
            compact: true,
            framedLogo: false,
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthBrandBodyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  l10n.tr('lock_message'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: secondaryTextColor,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AuthBrandPrimaryButton(
                  label: l10n.tr('unlock'),
                  leading: const Icon(Icons.lock_open_rounded, size: 20),
                  onPressed: () => _authenticate(),
                  isLoading: _authenticating,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n
                      .tr('use_biometric_or_passcode')
                      .replaceAll('{biometric}', _biometricLabel),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: secondaryTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
