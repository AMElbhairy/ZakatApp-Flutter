import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme_extensions.dart';

class SmartCaptureSetupWizardScaffold extends StatelessWidget {
  const SmartCaptureSetupWizardScaffold({
    super.key,
    required this.pageIndex,
    required this.pageCount,
    required this.skipLabel,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimary,
    required this.body,
    required this.motion,
    this.heroImagePath,
    this.heroChild,
    this.heroFit = BoxFit.contain,
    this.heroScale = 1.0,
    this.heroRotation = 0.0,
    this.heroGlowAlpha = 0.14,
    this.showSkip = true,
    this.showIndicator = true,
    this.onSkip,
    this.secondaryLabel,
    this.onSecondary,
    this.showSecondary = false,
    this.finalPage = false,
  });

  final int pageIndex;
  final int pageCount;
  final String? heroImagePath;
  final Widget? heroChild;
  final String skipLabel;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final Widget body;
  final Animation<double> motion;
  final BoxFit heroFit;
  final double heroScale;
  final double heroRotation;
  final double heroGlowAlpha;
  final bool showSkip;
  final bool showIndicator;
  final VoidCallback? onSkip;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool showSecondary;
  final bool finalPage;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final double width = MediaQuery.sizeOf(context).width;
    final double height = MediaQuery.sizeOf(context).height;
    final double heroMin = math.min(160.0, height * 0.20);
    final double heroMax = math.max(heroMin, math.min(300.0, height * 0.32));
    final double heroHeight = (height * 0.24).clamp(heroMin, heroMax);
    final EdgeInsets horizontalPadding = EdgeInsets.symmetric(
      horizontal: width < 420 ? AppSpacing.md : AppSpacing.lg,
    );

    return Scaffold(
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
                painter: _SmartCapturePatternPainter(
                  color: tokens.colors.onHero.withValues(alpha: 0.018),
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
                            final double maxWidth = math.min(
                              constraints.maxWidth,
                              440,
                            );
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
                                    if (showSkip)
                                      Align(
                                        alignment:
                                            AlignmentDirectional.centerEnd,
                                        child: TextButton(
                                          onPressed: onSkip,
                                          style: TextButton.styleFrom(
                                            foregroundColor: tokens
                                                .colors
                                                .onHero
                                                .withValues(alpha: 0.92),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.xs,
                                              vertical: 0,
                                            ),
                                            textStyle: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: tokens.colors.onHero
                                                      .withValues(alpha: 0.92),
                                                ),
                                          ),
                                          child: Text(skipLabel),
                                        ),
                                      )
                                    else
                                      const SizedBox(height: 20),
                                    SizedBox(
                                      height: heroHeight,
                                      child: _SmartCaptureHeroStage(
                                        imagePath: heroImagePath,
                                        heroChild: heroChild,
                                        animationDuration:
                                            _SmartCaptureSetupWizardState
                                                .imageDuration,
                                        motion: motion,
                                        pageIndex: pageIndex,
                                        scale: heroScale,
                                        fit: heroFit,
                                        rotation: heroRotation,
                                        glowAlpha: heroGlowAlpha,
                                      ),
                                    ),
                                    Center(
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: maxWidth,
                                        ),
                                        child: Transform.translate(
                                          offset: const Offset(0, -24),
                                          child: AnimatedSwitcher(
                                            duration:
                                                _SmartCaptureSetupWizardState
                                                    .transitionDuration,
                                            switchInCurve: Curves.easeOutCubic,
                                            switchOutCurve: Curves.easeInCubic,
                                            transitionBuilder:
                                                (
                                                  Widget child,
                                                  Animation<double> animation,
                                                ) {
                                                  final Animation<Offset>
                                                  offset = Tween<Offset>(
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
                                              key: ValueKey<int>(pageIndex),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: <Widget>[
                                                  Text(
                                                    title,
                                                    textAlign: TextAlign.center,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .headlineMedium
                                                        ?.copyWith(
                                                          color: tokens
                                                              .colors
                                                              .onHero,
                                                          fontSize: 34,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          letterSpacing: -0.4,
                                                          height: 1.02,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    subtitle,
                                                    textAlign: TextAlign.center,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyLarge
                                                        ?.copyWith(
                                                          color: tokens
                                                              .colors
                                                              .onHero
                                                              .withValues(
                                                                alpha: 0.75,
                                                              ),
                                                          height: 1.45,
                                                        ),
                                                  ),
                                                  if (showIndicator) ...<Widget>[
                                                    const SizedBox(
                                                      height: AppSpacing.xs,
                                                    ),
                                                    _SmartCapturePageDots(
                                                      index: pageIndex,
                                                      pageCount: pageCount,
                                                    ),
                                                  ],
                                                  const SizedBox(
                                                    height: AppSpacing.xs,
                                                  ),
                                                  body,
                                                ],
                                              ),
                                            ),
                                          ),
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
                  _SmartCaptureFooterActions(
                    primaryLabel: primaryLabel,
                    onPrimary: onPrimary,
                    showSecondary: showSecondary,
                    onSecondary: onSecondary,
                    secondaryLabel: secondaryLabel,
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

class _SmartCaptureSetupWizardState {
  static const Duration transitionDuration = Duration(milliseconds: 250);
  static const Duration imageDuration = Duration(milliseconds: 250);
}

class _SmartCaptureHeroStage extends StatelessWidget {
  const _SmartCaptureHeroStage({
    required this.imagePath,
    required this.heroChild,
    required this.animationDuration,
    required this.motion,
    required this.pageIndex,
    required this.scale,
    required this.fit,
    required this.rotation,
    required this.glowAlpha,
  });

  final String? imagePath;
  final Widget? heroChild;
  final Duration animationDuration;
  final Animation<double> motion;
  final int pageIndex;
  final double scale;
  final BoxFit fit;
  final double rotation;
  final double glowAlpha;

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
        final double pageScale = pageIndex == 7
            ? 1.0 + math.sin(t * math.pi * 2) * 0.015
            : 1.0;
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
                  child:
                      heroChild ??
                      (imagePath == null
                          ? const SizedBox.shrink()
                          : Image.asset(
                              imagePath!,
                              fit: fit,
                              alignment: Alignment.center,
                            )),
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

class PremiumDeviceFrame extends StatelessWidget {
  const PremiumDeviceFrame({
    super.key,
    required this.screenshotPath,
    required this.highlight,
    required this.caption,
    this.borderRadius = 34,
  });

  final String screenshotPath;
  final PremiumHighlightSpec highlight;
  final String caption;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = math.min(constraints.maxWidth, 340);
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: AspectRatio(
              aspectRatio: 0.495,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius + 6),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      tokens.colors.onHero.withValues(alpha: 0.08),
                      tokens.colors.onHero.withValues(alpha: 0.02),
                    ],
                  ),
                  border: Border.all(color: tokens.colors.onHeroBorder),
                  boxShadow: tokens.heroShadow,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        Image.asset(
                          screenshotPath,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  tokens.colors.onHero.withValues(alpha: 0.05),
                                  AppColors.transparent,
                                  AppColors.backgroundHeroDark.withValues(
                                    alpha: 0.22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(20, 22, 20, 22),
                            child: Stack(
                              children: <Widget>[
                                Positioned(
                                  left: rtl ? null : highlight.rect.left,
                                  right: rtl ? highlight.rect.left : null,
                                  top: highlight.rect.top,
                                  width: highlight.rect.width,
                                  height: highlight.rect.height,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: tokens.colors.selected,
                                        width: 2,
                                      ),
                                      color: tokens.colors.selected.withValues(
                                        alpha: 0.06,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: rtl ? null : highlight.arrowOffset.dx,
                                  right: rtl ? highlight.arrowOffset.dx : null,
                                  top: highlight.arrowOffset.dy,
                                  child: Icon(
                                    highlight.arrowIcon,
                                    color: tokens.colors.selected,
                                    size: 26,
                                  ),
                                ),
                                Positioned(
                                  left: rtl ? null : highlight.captionOffset.dx,
                                  right: rtl
                                      ? highlight.captionOffset.dx
                                      : null,
                                  top: highlight.captionOffset.dy,
                                  child: _CaptionPill(caption: caption),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class PremiumHighlightSpec {
  const PremiumHighlightSpec({
    required this.rect,
    required this.captionOffset,
    required this.arrowOffset,
    this.arrowIcon = Icons.arrow_downward_rounded,
  });

  final Rect rect;
  final Offset captionOffset;
  final Offset arrowOffset;
  final IconData arrowIcon;
}

class PremiumChecklist extends StatelessWidget {
  const PremiumChecklist({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: items
          .map(
            (String item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _ChecklistLine(text: item),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ChecklistLine extends StatelessWidget {
  const _ChecklistLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          Icons.check_circle_rounded,
          size: 20,
          color: tokens.colors.success,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: tokens.colors.onHero.withValues(alpha: 0.84),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class PremiumFlowDiagram extends StatelessWidget {
  const PremiumFlowDiagram({super.key, required this.steps});

  final List<PremiumFlowStep> steps;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: steps
          .map(
            (PremiumFlowStep step) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.x2l),
                      color: tokens.colors.onHero.withValues(alpha: 0.05),
                      border: Border.all(color: tokens.colors.onHeroBorder),
                    ),
                    child: Text(
                      step.label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: tokens.colors.onHero,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (step.hasArrow) ...<Widget>[
                    const SizedBox(height: 8),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: tokens.colors.selected,
                      size: 26,
                    ),
                  ],
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class PremiumFlowStep {
  const PremiumFlowStep({required this.label, this.hasArrow = true});

  final String label;
  final bool hasArrow;
}

class PremiumStatusBody extends StatelessWidget {
  const PremiumStatusBody({
    super.key,
    required this.title,
    required this.subtitle,
    required this.checks,
  });

  final String title;
  final String subtitle;
  final List<String> checks;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: context.premiumTokens.colors.onHero.withValues(alpha: 0.90),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.premiumTokens.colors.onHero.withValues(alpha: 0.74),
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        PremiumChecklist(items: checks),
      ],
    );
  }
}

class _SmartCapturePageDots extends StatelessWidget {
  const _SmartCapturePageDots({required this.index, required this.pageCount});

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
          duration: _SmartCaptureSetupWizardState.transitionDuration,
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

class _SmartCaptureFooterActions extends StatelessWidget {
  const _SmartCaptureFooterActions({
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
          _SmartCapturePrimaryButton(onPressed: onPrimary, label: primaryLabel),
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

class _SmartCapturePrimaryButton extends StatelessWidget {
  const _SmartCapturePrimaryButton({
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

class _CaptionPill extends StatelessWidget {
  const _CaptionPill({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.background.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: tokens.colors.selected.withValues(alpha: 0.52),
        ),
        boxShadow: tokens.softShadow,
      ),
      child: Text(
        caption,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: tokens.colors.selected,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SmartCapturePatternPainter extends CustomPainter {
  const _SmartCapturePatternPainter({required this.color});

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
  bool shouldRepaint(covariant _SmartCapturePatternPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

extension on double {
  int floorEven() {
    final int value = floor();
    return value.isEven ? value : value - 1;
  }
}
