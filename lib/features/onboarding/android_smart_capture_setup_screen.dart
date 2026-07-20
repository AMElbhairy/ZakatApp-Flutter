import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/auth/auth_brand_ui.dart';
import '../../services/android_sms_capture_service.dart';
import '../../services/app_state_controller.dart';

class AndroidSmartCaptureSetupScreen extends StatefulWidget {
  const AndroidSmartCaptureSetupScreen({super.key});

  @override
  State<AndroidSmartCaptureSetupScreen> createState() =>
      _AndroidSmartCaptureSetupScreenState();
}

class _AndroidSmartCaptureSetupScreenState
    extends State<AndroidSmartCaptureSetupScreen>
    with WidgetsBindingObserver {
  bool _smsGranted = false;
  bool _smsKnown = false;
  bool _batteryIgnored = false;
  bool _batteryKnown = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshStatus());
    }
  }

  Future<void> _refreshStatus() async {
    if (!AndroidSmsCaptureService.isSupported) return;
    final bool smsGranted = await AndroidSmsCaptureService.hasSmsPermission();
    final bool batteryIgnored =
        await AndroidSmsCaptureService.isBatteryOptimizationIgnored();
    if (!mounted) return;
    setState(() {
      _smsGranted = smsGranted;
      _smsKnown = true;
      _batteryIgnored = batteryIgnored;
      _batteryKnown = true;
      _busy = false;
    });
  }

  bool get _isReady => _smsGranted && _batteryIgnored;

  Future<void> _requestSmsPermission() async {
    if (_busy || !AndroidSmsCaptureService.isSupported) return;
    setState(() => _busy = true);
    final bool granted = await AndroidSmsCaptureService.requestSmsPermission();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _smsGranted = granted;
      _smsKnown = true;
    });
    await _refreshStatus();
    if (_isReady) {
      await _complete();
    }
  }

  Future<void> _openBatterySettings() async {
    if (_busy || !AndroidSmsCaptureService.isSupported) return;
    setState(() => _busy = true);
    await AndroidSmsCaptureService.openBatteryOptimizationSettings();
    if (!mounted) return;
    setState(() => _busy = false);
    await _refreshStatus();
  }

  Future<void> _openAppSettings() async {
    await AndroidSmsCaptureService.openAppSettings();
    if (!mounted) return;
    await _refreshStatus();
  }

  Future<void> _complete() async {
    if (!_isReady || _busy) return;
    setState(() => _busy = true);
    await context.read<AppStateController>().setAndroidSmsAutoCaptureEnabled(
      true,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop(true);
  }

  String _statusLabel(AppLocalizations l10n) {
    if (!_smsKnown) {
      return l10n.tr('onboarding_capture_status_not_enabled');
    }
    if (!_smsGranted) {
      return l10n.tr('onboarding_capture_status_denied');
    }
    return _batteryIgnored
        ? l10n.tr('onboarding_capture_status_enabled')
        : l10n.tr('onboarding_capture_status_not_enabled');
  }

  String _primaryLabel(AppLocalizations l10n) {
    if (!_smsGranted) {
      return l10n.tr('onboarding_capture_enable_sms');
    }
    if (!_batteryIgnored) {
      return l10n.tr('setup_android_open_battery');
    }
    return l10n.tr('setup_done');
  }

  Future<void> _handlePrimaryAction() async {
    if (!_smsGranted) {
      await _requestSmsPermission();
      return;
    }
    if (!_batteryIgnored) {
      await _openBatterySettings();
      return;
    }
    await _complete();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool showSettings = _smsKnown && !_smsGranted;

    return PopScope<void>(
      canPop: true,
      child: AuthBrandShell(
        maxWidth: 560,
        tone: AuthBackdropTone.shared,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AuthBrandHeader(
                title: l10n.tr('onboarding_capture_title'),
                subtitle: l10n.tr('onboarding_capture_android_body'),
                centered: true,
                compact: true,
                logoSize: 72,
              ),
              const SizedBox(height: AppSpacing.lg),
              _StatusPill(label: _statusLabel(l10n), colorScheme: colorScheme),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _batteryKnown && !_batteryIgnored && _smsGranted
                    ? l10n.tr('setup_android_battery_retry')
                    : l10n.tr('setup_android_battery_subtitle'),
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                key: const ValueKey<String>('smart-capture-primary'),
                onPressed: _busy
                    ? null
                    : () => unawaited(_handlePrimaryAction()),
                child: Text(_primaryLabel(l10n)),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                key: const ValueKey<String>('smart-capture-not-now'),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.tr('onboarding_not_now')),
              ),
              if (showSettings) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  key: const ValueKey<String>('smart-capture-open-settings'),
                  onPressed: () => unawaited(_openAppSettings()),
                  child: Text(l10n.tr('onboarding_open_settings')),
                ),
              ],
            ],
          ),
        ),
      ),
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
          color: colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.26),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
