import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../services/apple_shortcuts_service.dart';
import 'smart_capture_setup_wizard_shell.dart';

class ShortcutSetupGuideScreen extends StatefulWidget {
  const ShortcutSetupGuideScreen({super.key});

  @override
  State<ShortcutSetupGuideScreen> createState() =>
      _ShortcutSetupGuideScreenState();
}

class _ShortcutSetupGuideScreenState extends State<ShortcutSetupGuideScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController;
  int _index = 0;
  static const int _pageCount = 5;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (!mounted || _index >= _pageCount - 1) return;
    setState(() => _index += 1);
  }

  Future<void> _finish() async {
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _openShortcutsInstaller() async {
    await AppleShortcutsService.openShortcutsApp();
    if (!mounted) return;
    await _next();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool isFinal = _index == _pageCount - 1;

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) {
        if (didPop) return;
        if (_index > 0) {
          setState(() => _index -= 1);
        }
      },
      child: SmartCaptureSetupWizardScaffold(
        pageIndex: _index,
        pageCount: _pageCount,
        heroChild: _IosHeroVisual(step: _index),
        skipLabel: l10n.tr('setup_skip'),
        showSkip: false,
        showIndicator: !isFinal,
        heroScale: 1.0,
        heroGlowAlpha: switch (_index) {
          4 => 0.20,
          1 => 0.17,
          2 => 0.17,
          3 => 0.17,
          _ => 0.16,
        },
        heroRotation: _index == 4 ? -0.04 : 0.0,
        title: switch (_index) {
          0 => l10n.tr('setup_ios_enable_title'),
          1 => l10n.tr('setup_ios_install_title'),
          2 => l10n.tr('setup_ios_create_automation_title'),
          3 => l10n.tr('setup_ios_auto_title'),
          4 => l10n.tr('setup_ios_ready_title'),
          _ => l10n.tr('setup_ios_enable_title'),
        },
        subtitle: switch (_index) {
          0 => l10n.tr('setup_ios_enable_subtitle'),
          1 => l10n.tr('setup_ios_install_subtitle'),
          2 => l10n.tr('setup_ios_create_automation_subtitle'),
          3 => l10n.tr('setup_ios_auto_subtitle'),
          4 => l10n.tr('setup_ios_ready_subtitle'),
          _ => l10n.tr('setup_ios_enable_subtitle'),
        },
        body: switch (_index) {
          0 => _IosOverviewBody(
            title: l10n.tr('setup_ios_enable_title'),
            subtitle: l10n.tr('setup_ios_enable_subtitle'),
            items: <String>[
              l10n.tr('setup_ios_install_title'),
              l10n.tr('setup_ios_create_automation_title'),
              l10n.tr('setup_ios_auto_title'),
              l10n.tr('setup_ios_ready_title'),
            ],
          ),
          1 => _GuideStepBody(
            headline: l10n.tr('setup_ios_add_shortcut_caption'),
            items: <String>[
              l10n.tr('setup_ios_install_title'),
              l10n.tr('setup_ios_add_shortcut_primary'),
            ],
            visual: const _MiniShortcutBoard(
              leadingIcon: Icons.shortcut_rounded,
              title: 'Zakah Wealth',
              tag: 'Shortcut',
            ),
          ),
          2 => _GuideStepBody(
            headline: l10n.tr('setup_ios_automation_caption'),
            items: <String>[
              l10n.tr('setup_ios_trigger_title'),
              l10n.tr('setup_ios_log_title'),
              l10n.tr('setup_ios_connect_title'),
            ],
            visual: const _MiniShortcutBoard(
              leadingIcon: Icons.bolt_rounded,
              title: 'When Message Arrives',
              tag: 'Automation',
            ),
          ),
          3 => _GuideStepBody(
            headline: l10n.tr('setup_ios_run_caption'),
            items: <String>[
              l10n.tr('setup_ios_message_caption'),
              l10n.tr('setup_ios_input_caption'),
              l10n.tr('setup_ios_run_caption'),
            ],
            visual: const _MiniShortcutBoard(
              leadingIcon: Icons.play_circle_fill_rounded,
              title: 'Run Immediately',
              tag: 'Auto',
            ),
          ),
          4 => PremiumStatusBody(
            title: l10n.tr('setup_ios_ready_check_title'),
            subtitle: l10n.tr('setup_ios_ready_check_subtitle'),
            checks: <String>[
              l10n.tr('setup_ios_check_shortcut'),
              l10n.tr('setup_ios_check_automation'),
              l10n.tr('setup_ios_check_capture'),
            ],
          ),
          _ => const SizedBox.shrink(),
        },
        primaryLabel: switch (_index) {
          0 => l10n.tr('setup_continue'),
          1 => l10n.tr('setup_ios_add_shortcut_primary'),
          2 => l10n.tr('setup_ios_open_shortcuts'),
          3 => l10n.tr('setup_ios_open_shortcuts'),
          4 => l10n.tr('setup_done'),
          _ => l10n.tr('setup_continue'),
        },
        onPrimary: switch (_index) {
          0 => _next,
          1 => _openShortcutsInstaller,
          2 => _openShortcutsInstaller,
          3 => _openShortcutsInstaller,
          4 => _finish,
          _ => _next,
        },
        showSecondary: false,
        finalPage: isFinal,
        motion: _motionController,
      ),
    );
  }
}

class _GuideStepBody extends StatelessWidget {
  const _GuideStepBody({
    required this.headline,
    required this.items,
    required this.visual,
  });

  final String headline;
  final List<String> items;
  final Widget visual;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        visual,
        const SizedBox(height: 16),
        Text(
          headline,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: tokens.colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        PremiumChecklist(items: items),
      ],
    );
  }
}

class _IosOverviewBody extends StatelessWidget {
  const _IosOverviewBody({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PremiumChecklist(items: items),
      ],
    );
  }
}

class _IosHeroVisual extends StatelessWidget {
  const _IosHeroVisual({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final List<Widget> chips = <Widget>[
      _HeroChip(icon: Icons.shortcut_rounded, label: 'Shortcut'),
      _HeroChip(icon: Icons.bolt_rounded, label: 'Automation'),
      _HeroChip(icon: Icons.check_circle_rounded, label: 'Capture'),
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: chips,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Step ${step + 1}',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: tokens.colors.selected,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MiniShortcutBoard extends StatelessWidget {
  const _MiniShortcutBoard({
    required this.leadingIcon,
    required this.title,
    required this.tag,
  });

  final IconData leadingIcon;
  final String title;
  final String tag;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: tokens.colors.onHero.withValues(alpha: 0.05),
        border: Border.all(color: tokens.colors.onHeroBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: tokens.colors.selected.withValues(alpha: 0.14),
                ),
                child: Icon(leadingIcon, color: tokens.colors.selected),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: tokens.colors.onHero,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _TagPill(label: tag),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const _MockLine(widthFactor: 0.9),
          const SizedBox(height: 8),
          const _MockLine(widthFactor: 0.7),
          const SizedBox(height: 8),
          const _MockLine(widthFactor: 0.82),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: tokens.colors.onHero.withValues(alpha: 0.05),
        border: Border.all(color: tokens.colors.onHeroBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: tokens.colors.selected),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: tokens.colors.onHero,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: tokens.colors.selected.withValues(alpha: 0.16),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tokens.colors.selected,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MockLine extends StatelessWidget {
  const _MockLine({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: tokens.colors.onHero.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}
