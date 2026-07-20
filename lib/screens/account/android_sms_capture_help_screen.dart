import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/theme/app_spacing.dart';
import '../../services/android_sms_capture_service.dart';
import '../../services/app_state_controller.dart';
import 'smart_capture_setup_wizard_shell.dart';

class AndroidSmsCaptureHelpScreen extends StatefulWidget {
  const AndroidSmsCaptureHelpScreen({super.key});

  @override
  State<AndroidSmsCaptureHelpScreen> createState() =>
      _AndroidSmsCaptureHelpScreenState();
}

class _AndroidSmsCaptureHelpScreenState
    extends State<AndroidSmsCaptureHelpScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motionController;
  int _index = 0;
  bool _smsGranted = false;
  bool _batteryReady = false;
  bool _batteryChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motionController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _index == 1) {
      unawaited(_refreshBatteryStatus());
    }
  }

  Future<void> _bootstrap() async {
    final bool granted = await AndroidSmsCaptureService.hasSmsPermission();
    if (!mounted) return;
    setState(() {
      _smsGranted = granted;
      _index = granted ? 1 : 0;
    });
    if (granted) {
      await _refreshBatteryStatus();
    }
  }

  Future<void> _next() async {
    if (!mounted || _index >= 2) return;
    setState(() => _index += 1);
  }

  Future<void> _requestSmsAccess() async {
    if (_smsGranted) {
      await _next();
      return;
    }
    final bool granted = await AndroidSmsCaptureService.requestSmsPermission();
    if (!mounted) return;
    setState(() => _smsGranted = granted);
    if (granted) {
      await _next();
    }
  }

  Future<void> _refreshBatteryStatus() async {
    if (_batteryChecking) return;
    setState(() => _batteryChecking = true);
    final bool ignored =
        await AndroidSmsCaptureService.isBatteryOptimizationIgnored();
    if (!mounted) return;
    setState(() {
      _batteryChecking = false;
      _batteryReady = ignored;
    });
    if (ignored && _index == 1) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted && _index == 1) {
        await _next();
      }
    }
  }

  Future<void> _openBatterySettings() async {
    await AndroidSmsCaptureService.openBatteryOptimizationSettings();
    if (!mounted) return;
    await _refreshBatteryStatus();
  }

  Future<void> _finish() async {
    await context.read<AppStateController>().setAndroidSmsAutoCaptureEnabled(
      true,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool isFinal = _index == 2;

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
        pageCount: 3,
        heroChild: _AndroidHeroVisual(step: _index),
        skipLabel: l10n.tr('setup_skip'),
        showSkip: false,
        showIndicator: !isFinal,
        heroScale: 1.0,
        heroGlowAlpha: switch (_index) {
          1 => 0.18,
          2 => 0.20,
          _ => 0.16,
        },
        heroRotation: _index == 2 ? -0.035 : 0.0,
        title: switch (_index) {
          0 => l10n.tr('setup_android_sms_title'),
          1 => l10n.tr('setup_android_battery_title'),
          2 => l10n.tr('setup_android_ready_title'),
          _ => l10n.tr('setup_android_sms_title'),
        },
        subtitle: switch (_index) {
          0 => l10n.tr('setup_android_sms_subtitle'),
          1 => l10n.tr('setup_android_battery_subtitle'),
          2 => l10n.tr('setup_android_ready_subtitle'),
          _ => l10n.tr('setup_android_sms_subtitle'),
        },
        body: switch (_index) {
          0 => _AndroidOverviewBody(
            smsLabel: l10n.tr('setup_android_phone'),
            messageLabel: l10n.tr('setup_android_sms'),
            shieldLabel: l10n.tr('setup_android_shield'),
            appLabel: l10n.tr('setup_android_zakah_wealth'),
          ),
          1 => _AndroidBatteryBody(
            batteryReady: _batteryReady,
            batteryChecking: _batteryChecking,
          ),
          2 => PremiumStatusBody(
            title: l10n.tr('setup_android_ready_check_title'),
            subtitle: l10n.tr('setup_android_ready_check_subtitle'),
            checks: <String>[
              l10n.tr('setup_android_check_sms'),
              l10n.tr('setup_android_check_background'),
            ],
          ),
          _ => const SizedBox.shrink(),
        },
        primaryLabel: switch (_index) {
          0 => l10n.tr('setup_android_allow_sms'),
          1 => l10n.tr('setup_android_open_battery'),
          2 => l10n.tr('setup_done'),
          _ => l10n.tr('setup_android_allow_sms'),
        },
        onPrimary: switch (_index) {
          0 => _requestSmsAccess,
          1 => _openBatterySettings,
          2 => _finish,
          _ => _requestSmsAccess,
        },
        showSecondary: false,
        finalPage: isFinal,
        motion: _motionController,
      ),
    );
  }
}

class _AndroidOverviewBody extends StatelessWidget {
  const _AndroidOverviewBody({
    required this.smsLabel,
    required this.messageLabel,
    required this.shieldLabel,
    required this.appLabel,
  });

  final String smsLabel;
  final String messageLabel;
  final String shieldLabel;
  final String appLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PremiumChecklist(
          items: <String>[smsLabel, messageLabel, shieldLabel, appLabel],
        ),
      ],
    );
  }
}

class _AndroidBatteryBody extends StatelessWidget {
  const _AndroidBatteryBody({
    required this.batteryReady,
    required this.batteryChecking,
  });

  final bool batteryReady;
  final bool batteryChecking;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _ActionCard(
          icon: Icons.battery_saver_rounded,
          title: l10n.tr('setup_android_battery_title'),
          subtitle: l10n.tr('setup_android_battery_caption'),
          accent: context.premiumTokens.colors.selected,
        ),
        const SizedBox(height: AppSpacing.sm),
        PremiumFlowDiagram(
          steps: <PremiumFlowStep>[
            PremiumFlowStep(label: l10n.tr('setup_android_open_battery')),
            PremiumFlowStep(label: l10n.tr('setup_android_battery_caption')),
            PremiumFlowStep(
              label: l10n.tr('setup_android_battery_ready'),
              hasArrow: false,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (batteryChecking)
          Text(
            l10n.tr('setup_android_checking'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.premiumTokens.colors.onHero.withValues(
                alpha: 0.74,
              ),
            ),
          )
        else if (batteryReady)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: context.premiumTokens.colors.success,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                l10n.tr('setup_android_battery_ready'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.premiumTokens.colors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          )
        else
          Text(
            l10n.tr('setup_android_battery_retry'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.premiumTokens.colors.onHero.withValues(
                alpha: 0.74,
              ),
            ),
          ),
      ],
    );
  }
}

class _AndroidHeroVisual extends StatelessWidget {
  const _AndroidHeroVisual({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final IconData icon = switch (step) {
      0 => Icons.sms_rounded,
      1 => Icons.battery_saver_rounded,
      _ => Icons.verified_user_rounded,
    };
    final String badge = switch (step) {
      0 => 'SMS',
      1 => 'Battery',
      _ => 'Ready',
    };

    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _MiniPhoneCard(
            icon: icon,
            lines: <String>[
              badge,
              step == 0
                  ? 'Allow access'
                  : step == 1
                  ? 'Keep running'
                  : 'Capture active',
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Icons.arrow_forward_rounded,
            color: tokens.colors.selected,
            size: 26,
          ),
          const SizedBox(width: AppSpacing.sm),
          _SignalBadge(
            icon: step == 2 ? Icons.check_rounded : icon,
            label: badge,
          ),
        ],
      ),
    );
  }
}

class _MiniPhoneCard extends StatelessWidget {
  const _MiniPhoneCard({required this.icon, required this.lines});

  final IconData icon;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Container(
      width: 120,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: tokens.colors.onHero.withValues(alpha: 0.06),
        border: Border.all(color: tokens.colors.onHeroBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, color: tokens.colors.selected),
          const SizedBox(height: AppSpacing.xs),
          ...lines.map(
            (String line) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                line,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: tokens.colors.onHero,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalBadge extends StatelessWidget {
  const _SignalBadge({required this.icon, required this.label});

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
        color: tokens.colors.selected.withValues(alpha: 0.12),
        border: Border.all(color: tokens.colors.selected.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: tokens.colors.selected),
          const SizedBox(height: 4),
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

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: accent.withValues(alpha: 0.14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: tokens.colors.onHero,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.colors.onHero.withValues(alpha: 0.76),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
