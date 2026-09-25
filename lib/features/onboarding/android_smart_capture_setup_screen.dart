import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme_extensions.dart';
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
    final tokens = context.premiumTokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color descColor = isDark ? tokens.colors.textSecondary : const Color(0xFF4A5D5A);
    final bool showSettings = _smsKnown && !_smsGranted;

    return PopScope<void>(
      canPop: true,
      child: AuthBrandShell(
        maxWidth: 560,
        tone: AuthBackdropTone.shared,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AuthBrandHeader(
                title: l10n.tr('onboarding_capture_title'),
                subtitle: l10n.tr('onboarding_capture_android_body'),
                centered: true,
                compact: false,
                logoSize: 76,
              ),
              const SizedBox(height: 32),
              
              _StatusPill(label: _statusLabel(l10n), tokens: tokens),
              const SizedBox(height: 24),
              
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: tokens.colors.card,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: tokens.colors.divider),
                  boxShadow: tokens.softShadow,
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      backgroundColor: tokens.colors.gold.withValues(alpha: 0.15),
                      radius: 28,
                      child: Icon(
                        Icons.settings_suggest_outlined,
                        color: tokens.colors.gold,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _batteryKnown && !_batteryIgnored && _smsGranted
                          ? l10n.tr('setup_android_battery_retry')
                          : l10n.tr('setup_android_battery_subtitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: descColor,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              FilledButton(
                key: const ValueKey<String>('smart-capture-primary'),
                onPressed: _busy ? null : () => unawaited(_handlePrimaryAction()),
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.colors.gold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
                child: Text(
                  _primaryLabel(l10n),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(height: 12),
              
              OutlinedButton(
                key: const ValueKey<String>('smart-capture-not-now'),
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tokens.colors.gold),
                  foregroundColor: tokens.colors.gold,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
                child: Text(
                  l10n.tr('onboarding_not_now'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              if (showSettings) ...<Widget>[
                const SizedBox(height: 16),
                TextButton(
                  key: const ValueKey<String>('smart-capture-open-settings'),
                  onPressed: () => unawaited(_openAppSettings()),
                  style: TextButton.styleFrom(
                    foregroundColor: tokens.colors.textPrimary.withValues(alpha: 0.6),
                  ),
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
  const _StatusPill({required this.label, required this.tokens});

  final String label;
  final PremiumThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.gold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: tokens.colors.gold.withValues(alpha: 0.3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: tokens.colors.gold,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
