import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../services/auth_controller.dart';
import 'auth_brand_ui.dart';
import 'auth_service.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color secondaryTextColor = dark
        ? tokens.colors.textSecondary
        : tokens.colors.hero;
    final auth = context.watch<AuthController>();
    final AppLocalizations l10n = context.l10n;
    final bool isLoading = auth.isLoading;
    final bool showAppleSignIn =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    return AuthBrandShell(
      tone: AuthBackdropTone.hero,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, constraints.maxHeight - 16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  AuthBrandHeader(
                    title: l10n.tr('brand_title'),
                    subtitle: l10n.tr('brand_tagline'),
                    logoSize: 84,
                    framedLogo: false,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.tr('brand_trust_message'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: secondaryTextColor,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AuthBrandBodyCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          l10n.tr('login_intro'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: tokens.colors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AuthBrandPrimaryButton(
                          key: const Key('googleSignInButton'),
                          label: l10n.tr('continue_with_google'),
                          leading: const _GoogleBrandMark(),
                          isLoading: isLoading,
                          onPressed: () => context
                              .read<AuthController>()
                              .signIn(provider: AuthProvider.google),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AuthBrandSecondaryButton(
                          key: const Key('appleSignInButton'),
                          label: l10n.tr('continue_with_apple'),
                          leading: const Icon(Icons.apple, size: 20),
                          foregroundColor: tokens.colors.textPrimary,
                          onPressed: showAppleSignIn
                              ? () => context.read<AuthController>().signIn(
                                  provider: AuthProvider.apple,
                                )
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          l10n.tr('login_note'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: secondaryTextColor,
                                height: 1.4,
                              ),
                        ),
                        if (!showAppleSignIn) ...<Widget>[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.tr('apple_signin_unavailable'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: secondaryTextColor),
                          ),
                        ],
                        if (auth.error != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            auth.error!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: tokens.colors.danger),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GoogleBrandMark extends StatelessWidget {
  const _GoogleBrandMark();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/google-logo.png',
      width: 20,
      height: 20,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const SizedBox(width: 20, height: 20),
    );
  }
}
