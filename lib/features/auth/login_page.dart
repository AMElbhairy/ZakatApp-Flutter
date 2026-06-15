import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_radii.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../services/auth_controller.dart';
import 'auth_service.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final auth = context.watch<AuthController>();
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;
    final bool isLoading = auth.isLoading;

    return Scaffold(
      backgroundColor: tokens.colors.background,
      body: Stack(
        children: <Widget>[
          const _AuthBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: math.max(0, constraints.maxHeight - 28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const SizedBox(height: 4),
                        const _AuthHero(),
                        const SizedBox(height: 12),
                        const _GoldAccentDivider(),
                        const SizedBox(height: 12),
                        _TrustCard(tokens: tokens),
                        const SizedBox(height: 12),
                        _AuthActionButton(
                          key: const Key('googleSignInButton'),
                          label: 'Continue with Google',
                          icon: const GoogleBrandMark(),
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF111111),
                          borderColor: const Color(0xFFE5E7EB),
                          isLoading: isLoading,
                          onPressed: () => context
                              .read<AuthController>()
                              .signIn(provider: AuthProvider.google),
                        ),
                        const SizedBox(height: 10),
                        _AuthActionButton(
                          key: const Key('appleSignInButton'),
                          label: 'Continue with Apple',
                          icon: const Icon(Icons.apple, size: 22),
                          backgroundColor: tokens.colors.surface,
                          foregroundColor: tokens.colors.textPrimary,
                          borderColor: tokens.colors.divider,
                          isLoading: isLoading,
                          onPressed: defaultTargetPlatform == TargetPlatform.iOS
                              ? () => context.read<AuthController>().signIn(
                                  provider: AuthProvider.apple,
                                )
                              : null,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Already backed up? Sign in with the same account to restore your data automatically.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: tokens.colors.textSecondary,
                                height: 1.25,
                              ),
                        ),
                        if (defaultTargetPlatform != TargetPlatform.iOS)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Apple Sign In is available on iPhone and iPad.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: tokens.colors.textSecondary,
                                  ),
                            ),
                          ),
                        if (auth.error != null) ...<Widget>[
                          const SizedBox(height: 10),
                          Text(
                            auth.error!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: tokens.colors.danger),
                          ),
                        ],
                        if (isRtl) const SizedBox(height: 6),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop();

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              const Color(0xFF073A31),
              const Color(0xFF021815),
              tokens.colors.background,
            ],
          ),
        ),
        child: Opacity(
          opacity: 0.035,
          child: Image.asset(
            'assets/images/hero_pattern_watermark.png',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero();

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.transparent,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/app_icon.png',
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(width: 72, height: 72),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Zakah Wealth',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: tokens.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Track Wealth.\nCalculate Zakat.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: tokens.colors.textPrimary,
            height: 1.12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            'Secure wealth tracking with automatic cloud backup, zakat calculations and cross-device sync.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.colors.textSecondary,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _GoldAccentDivider extends StatelessWidget {
  const _GoldAccentDivider();

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Divider(color: tokens.colors.divider.withValues(alpha: 0.5));
  }
}

class _TrustCard extends StatelessWidget {
  const _TrustCard({required this.tokens});

  final PremiumThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final List<(IconData, String)> items = <(IconData, String)>[
      (Icons.check_circle_rounded, 'Automatic Backup'),
      (Icons.check_circle_rounded, 'Restore on Any Device'),
      (Icons.check_circle_rounded, 'Sign in with Google or Apple'),
      (Icons.check_circle_rounded, 'Private by Design'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: AppRadii.card,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Your data stays protected and available across all your devices.',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: tokens.colors.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: <Widget>[
                  Icon(item.$1, size: 17, color: tokens.colors.emerald),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.$2,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.colors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthActionButton extends StatelessWidget {
  const _AuthActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.isLoading,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: borderColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        icon: isLoading
            ? SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: tokens.colors.gold,
                ),
              )
            : SizedBox(height: 22, width: 22, child: Center(child: icon)),
        label: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: foregroundColor,
          ),
        ),
      ),
    );
  }
}

class GoogleBrandMark extends StatelessWidget {
  const GoogleBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/google-logo.png',
      width: 22,
      height: 22,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const SizedBox(width: 22, height: 22),
    );
  }
}
