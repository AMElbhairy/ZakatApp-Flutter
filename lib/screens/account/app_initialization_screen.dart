import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../services/bootstrap_coordinator.dart';

class AppInitializationScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const AppInitializationScreen({super.key, required this.onComplete});

  @override
  State<AppInitializationScreen> createState() =>
      _AppInitializationScreenState();
}

class _AppInitializationScreenState extends State<AppInitializationScreen> {
  BootstrapCoordinator? _coordinator;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final BootstrapCoordinator nextCoordinator = context.read<
        BootstrapCoordinator>();
    if (!identical(nextCoordinator, _coordinator)) {
      _coordinator?.removeListener(_onBootstrapChanged);
      _coordinator = nextCoordinator;
      _coordinator?.addListener(_onBootstrapChanged);
    }
    _onBootstrapChanged();
  }

  @override
  void dispose() {
    _coordinator?.removeListener(_onBootstrapChanged);
    super.dispose();
  }

  void _onBootstrapChanged() {
    if (!mounted) return;
    final BootstrapCoordinator? coordinator = _coordinator;
    if (coordinator?.phase == BootstrapPhase.ready) {
      widget.onComplete();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final BootstrapCoordinator coordinator = context.watch<BootstrapCoordinator>();
    final String family = AppTypography.familyFor(Localizations.localeOf(context));
    final AppLocalizations l10n = context.l10n;
    const Color deepGreen = AppColors.backgroundHero;
    const Color goldColor = AppColors.gold;
    final String statusMessage = switch (coordinator.phase) {
      BootstrapPhase.failed => l10n.tr('startup_still_preparing_data'),
      BootstrapPhase.ready => l10n.tr('startup_preparing_dashboard'),
      _ => l10n.tr('startup_preparing_dashboard'),
    };

    return Scaffold(
      backgroundColor: deepGreen,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    AppColors.brandTeal.withValues(alpha: 1),
                    AppColors.backgroundHeroDark,
                    deepGreen,
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
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 32.0,
                vertical: 24.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.transparent,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox(width: 72, height: 72);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Zakah Wealth',
                    style: AppTypography.pageTitle(
                      color: AppColors.white,
                      family: family,
                      fallbackFamily: AppTypography.englishFamily,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    statusMessage,
                    textAlign: TextAlign.center,
                    style: AppTypography.body(
                      color: AppColors.white70,
                      family: family,
                      fallbackFamily: AppTypography.englishFamily,
                    ),
                  ),
                  const Spacer(),
                  if (coordinator.phase == BootstrapPhase.failed) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => coordinator.start(retry: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: goldColor,
                          foregroundColor: deepGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Retry',
                          style: AppTypography.button(
                            color: deepGreen,
                            family: family,
                            fallbackFamily: AppTypography.englishFamily,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(goldColor),
                        strokeWidth: 2,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
