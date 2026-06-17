import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme_extensions.dart';

enum AuthBackdropTone { hero, shared }

class _AuthBackdropSpec {
  const _AuthBackdropSpec({
    required this.background,
    required this.backgroundStops,
    required this.textureOpacity,
    required this.glowOpacity,
    required this.vignetteOpacity,
    required this.glowCenter,
    required this.glowRadius,
  });

  final List<Color> background;
  final List<double> backgroundStops;
  final double textureOpacity;
  final double glowOpacity;
  final double vignetteOpacity;
  final AlignmentGeometry glowCenter;
  final double glowRadius;
}

class AuthBrandBackdrop extends StatelessWidget {
  const AuthBrandBackdrop({super.key, this.tone = AuthBackdropTone.shared});

  final AuthBackdropTone tone;

  @override
  Widget build(BuildContext context) {
    final _AuthBackdropSpec spec = _specFor(context);
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: spec.background,
            stops: spec.backgroundStops,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Opacity(
              opacity: spec.textureOpacity,
              child: Image.asset(
                'assets/images/hero_pattern_watermark.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: spec.glowCenter,
                  radius: spec.glowRadius,
                  colors: <Color>[
                    Colors.white.withValues(alpha: spec.glowOpacity),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.18,
                  colors: <Color>[
                    Colors.transparent,
                    Colors.black.withValues(alpha: spec.vignetteOpacity),
                  ],
                  stops: const <double>[0.46, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _AuthBackdropSpec _specFor(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      switch (tone) {
        case AuthBackdropTone.hero:
          return const _AuthBackdropSpec(
            background: <Color>[
              Color(0xFF063B35),
              Color(0xFF075E54),
              Color(0xFF042F2B),
            ],
            backgroundStops: <double>[0, 0.43, 1],
            textureOpacity: 0.07,
            glowOpacity: 0.12,
            vignetteOpacity: 0.38,
            glowCenter: Alignment(-0.08, -0.76),
            glowRadius: 0.9,
          );
        case AuthBackdropTone.shared:
          return const _AuthBackdropSpec(
            background: <Color>[
              Color(0xFF063B35),
              Color(0xFF075E54),
              Color(0xFF042F2B),
            ],
            backgroundStops: <double>[0, 0.42, 1],
            textureOpacity: 0.055,
            glowOpacity: 0.08,
            vignetteOpacity: 0.42,
            glowCenter: Alignment(-0.08, -0.7),
            glowRadius: 0.8,
          );
      }
    }

    switch (tone) {
      case AuthBackdropTone.hero:
        return const _AuthBackdropSpec(
          background: <Color>[
            Color(0xFF0A5A52),
            Color(0xFF0C6B60),
            Color(0xFFF2EFE7),
            Color(0xFFF6F3EA),
          ],
          backgroundStops: <double>[0, 0.26, 0.72, 1],
          textureOpacity: 0.06,
          glowOpacity: 0.1,
          vignetteOpacity: 0.14,
          glowCenter: Alignment(-0.08, -0.74),
          glowRadius: 1.02,
        );
      case AuthBackdropTone.shared:
        return const _AuthBackdropSpec(
          background: <Color>[
            Color(0xFF0A5A52),
            Color(0xFF0C6B60),
            Color(0xFFF3F0E8),
            Color(0xFFF6F3EB),
          ],
          backgroundStops: <double>[0, 0.18, 0.74, 1],
          textureOpacity: 0.04,
          glowOpacity: 0.055,
          vignetteOpacity: 0.12,
          glowCenter: Alignment(-0.1, -0.72),
          glowRadius: 0.92,
        );
    }
  }
}

class AuthBrandShell extends StatelessWidget {
  const AuthBrandShell({
    super.key,
    required this.child,
    this.maxWidth = 460,
    this.tone = AuthBackdropTone.shared,
  });

  final Widget child;
  final double maxWidth;
  final AuthBackdropTone tone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.premiumTokens.colors.background,
      body: Stack(
        children: <Widget>[
          AuthBrandBackdrop(tone: tone),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.logoSize = 76,
    this.centered = true,
    this.compact = false,
    this.framedLogo = true,
  });

  final String title;
  final String subtitle;
  final double logoSize;
  final bool centered;
  final bool compact;
  final bool framedLogo;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final AlignmentGeometry alignment = centered
        ? Alignment.center
        : AlignmentDirectional.centerStart;
    final TextAlign textAlign = centered ? TextAlign.center : TextAlign.start;

    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: alignment,
          child: _BrandLogo(size: logoSize, framed: framedLogo),
        ),
        SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
        Text(
          title,
          textAlign: textAlign,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: tokens.colors.textPrimary,
          ),
        ),
        SizedBox(height: compact ? 2 : AppSpacing.xs),
        Text(
          subtitle,
          textAlign: textAlign,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: tokens.colors.textPrimary,
            height: 1.18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class AuthBrandBodyCard extends StatelessWidget {
  const AuthBrandBodyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tokens.colors.surface.withValues(alpha: dark ? 0.72 : 0.64),
        borderRadius: AppRadii.card,
        border: Border.all(
          color: tokens.colors.divider.withValues(alpha: dark ? 0.52 : 0.38),
        ),
        boxShadow: tokens.softShadow,
      ),
      child: child,
    );
  }
}

class AuthBrandPrimaryButton extends StatelessWidget {
  const AuthBrandPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.backgroundColor,
    this.foregroundColor,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final Color resolvedBackground = backgroundColor ?? tokens.colors.gold;
    final Color resolvedForeground = foregroundColor ?? tokens.colors.emerald;

    return SizedBox(
      height: 54,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: resolvedBackground,
          foregroundColor: resolvedForeground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: tokens.colors.gold.withValues(alpha: 0.30)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: resolvedForeground,
                ),
              )
            : leading ?? const SizedBox(width: 18, height: 18),
        label: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: resolvedForeground,
          ),
        ),
      ),
    );
  }
}

class AuthBrandSecondaryButton extends StatelessWidget {
  const AuthBrandSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.foregroundColor,
    this.leading,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color foregroundColor;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          side: BorderSide(
            color: tokens.colors.divider.withValues(alpha: 0.82),
          ),
          backgroundColor: tokens.colors.surface.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
        icon: leading ?? const SizedBox(width: 18, height: 18),
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

class AuthChecklistItem extends StatelessWidget {
  const AuthChecklistItem({
    super.key,
    required this.label,
    required this.isDone,
    required this.isActive,
  });

  final String label;
  final bool isDone;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final Widget leading = isActive
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: tokens.colors.gold,
            ),
          )
        : Icon(
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: isDone ? tokens.colors.gold : tokens.colors.textSecondary,
            size: 18,
          );

    return Row(
      children: <Widget>[
        leading,
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.colors.textPrimary,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class AuthStatChip extends StatelessWidget {
  const AuthStatChip({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.background.withValues(alpha: 0.34),
        borderRadius: AppRadii.pill,
        border: Border.all(
          color: tokens.colors.divider.withValues(alpha: 0.72),
        ),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: tokens.colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class AuthPrivacyOverlay extends StatelessWidget {
  const AuthPrivacyOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final AppLocalizations l10n = context.l10n;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const AuthBrandBackdrop(tone: AuthBackdropTone.shared),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _BrandLogo(size: 58, framed: false),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.tr('protected_by_app_lock'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: tokens.colors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.tr('biometric_lock_enabled'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: dark
                              ? tokens.colors.textSecondary
                              : tokens.colors.hero,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.size, this.framed = true});

  final double size;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    if (!framed) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          'assets/images/app_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
        ),
      );
    }

    final tokens = context.premiumTokens;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(math.max(18, size * 0.24)),
        color: tokens.colors.surface.withValues(alpha: 0.22),
        border: Border.all(
          color: tokens.colors.gold.withValues(alpha: 0.28),
          width: 1.0,
        ),
        boxShadow: tokens.heroShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
      ),
    );
  }
}
