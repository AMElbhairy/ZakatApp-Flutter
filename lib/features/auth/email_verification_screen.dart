import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/widgets/app_ui.dart';
import '../../services/auth_controller.dart';
import 'auth_brand_ui.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.onVerified,
  });

  final String email;
  final Future<void> Function() onVerified;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  static const int _resendCooldownSeconds = 60;

  Timer? _cooldownTimer;
  int _secondsUntilResend = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final tokens = context.premiumTokens;
    final bool resendDisabled = auth.isLoading || _secondsUntilResend > 0;
    final String resendLabel = _secondsUntilResend > 0
        ? context.l10n.trf('resend_verification_email_in', {
            'seconds': _secondsUntilResend.toString(),
          })
        : context.l10n.tr('resend_verification_email');

    return AuthBrandShell(
      tone: AuthBackdropTone.shared,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          AuthBrandHeader(
            title: context.l10n.tr('brand_title'),
            subtitle: context.l10n.tr('verify_email_title'),
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
                  context.l10n.trf('verify_email_message', {
                    'email': widget.email,
                  }),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.colors.textPrimary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AuthBrandPrimaryButton(
                  label: context.l10n.tr('refresh_verification_status'),
                  isLoading: auth.isLoading,
                  leading: const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: () async {
                    final bool verified = await context
                        .read<AuthController>()
                        .refreshEmailVerificationStatus();
                    if (!context.mounted) return;
                    if (verified) {
                      await widget.onVerified();
                      return;
                    }
                    if (auth.error == null) {
                      showTopSnackBar(
                        context,
                        context.l10n.tr('verify_email_still_pending'),
                        kind: AppToastKind.info,
                      );
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                AuthBrandSecondaryButton(
                  label: resendLabel,
                  foregroundColor: tokens.colors.textPrimary,
                  leading: const Icon(Icons.mark_email_read_outlined, size: 20),
                  onPressed: resendDisabled
                      ? null
                      : () => _resendEmail(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: auth.isLoading
                      ? null
                      : () => context.read<AuthController>().signOut(),
                  child: Text(context.l10n.tr('sign_out_anyway')),
                ),
                if (auth.error != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    auth.error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.colors.danger,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resendEmail(BuildContext context) async {
    try {
      await context.read<AuthController>().sendEmailVerification();
    } catch (_) {}
    if (!context.mounted) return;

    final String? error = context.read<AuthController>().error;
    if (error == null) {
      _startCooldown();
      showTopSnackBar(
        context,
        '${context.l10n.tr('verification_email_sent')} ${context.l10n.tr('verification_email_delivery_hint')}',
        kind: AppToastKind.success,
      );
      return;
    }

    if (error.contains('Too many attempts')) {
      _startCooldown();
      showTopSnackBar(
        context,
        context.l10n.tr('verification_email_rate_limited'),
        kind: AppToastKind.warning,
      );
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() {
      _secondsUntilResend = _resendCooldownSeconds;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted || _secondsUntilResend <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _secondsUntilResend = 0;
          });
        }
        return;
      }
      setState(() {
        _secondsUntilResend -= 1;
      });
    });
  }
}
