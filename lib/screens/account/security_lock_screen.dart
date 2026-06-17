import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../services/biometric_service.dart';
import '../../features/auth/auth_brand_ui.dart';

class SecurityLockScreen extends StatefulWidget {
  const SecurityLockScreen({super.key, required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  State<SecurityLockScreen> createState() => _SecurityLockScreenState();
}

class _SecurityLockScreenState extends State<SecurityLockScreen> {
  String _biometricLabel = 'Face ID';
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricType();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _loadBiometricType() async {
    final String label = await BiometricService.getBiometricTypeLabel();
    if (!mounted) return;
    setState(() {
      _biometricLabel = label;
    });
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    final bool success = await BiometricService.authenticate(
      reason: 'Unlock Zakah Wealth',
      isSensitiveAction: true,
    );
    if (!mounted) return;
    setState(() => _authenticating = false);
    if (success) widget.onUnlock();
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
                  onPressed: _authenticate,
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
