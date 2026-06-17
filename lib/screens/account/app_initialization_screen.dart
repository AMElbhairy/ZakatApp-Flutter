import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../../services/app_state_controller.dart';
import '../../services/auth_controller.dart';

class AppInitializationScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const AppInitializationScreen({super.key, required this.onComplete});

  @override
  State<AppInitializationScreen> createState() =>
      _AppInitializationScreenState();
}

class _AppInitializationScreenState extends State<AppInitializationScreen> {
  bool _loadingAssets = false;
  bool _loadingTransactions = false;
  bool _restoringSession = false;
  bool _preparingProjections = false;
  bool _timeoutReached = false;
  bool _localDataLoaded = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _startInitialization();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _startInitialization() async {
    final stopwatch = Stopwatch()..start();

    // Start 5 second timeout timer
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _timeoutReached = true;
        });
      }
    });

    try {
      final appStateController = context.read<AppStateController>();
      final authController = context.read<AuthController>();

      // Step 1: Restoring session
      setState(() => _restoringSession = true);
      final int t0 = stopwatch.elapsedMilliseconds;
      await authController.load();
      final int t1 = stopwatch.elapsedMilliseconds;
      debugPrint('[Profile] Restore authentication session took ${t1 - t0}ms');
      setState(() => _restoringSession = false);

      // Step 2: Loading app state for the resolved user namespace
      setState(() => _loadingAssets = true);
      final int t2 = stopwatch.elapsedMilliseconds;
      await appStateController.load(
        userId: authController.currentUser?.id,
      );
      final int t3 = stopwatch.elapsedMilliseconds;
      debugPrint('[Profile] Load AppState took ${t3 - t2}ms');
      setState(() {
        _loadingAssets = false;
        _localDataLoaded = true;
      });

      // Step 3: Loading transactions & savings
      setState(() => _loadingTransactions = true);
      final int t4 = stopwatch.elapsedMilliseconds;
      // Already hydrated in appStateController.load(), wait 100ms to simulate/yield UI thread
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final int t5 = stopwatch.elapsedMilliseconds;
      debugPrint('[Profile] Load savings & transactions took ${t5 - t4}ms');
      setState(() => _loadingTransactions = false);

      // Step 4: Preparing projections
      setState(() => _preparingProjections = true);
      final int t6 = stopwatch.elapsedMilliseconds;
      // Simulate yielding UI thread for projections preparation
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final int t7 = stopwatch.elapsedMilliseconds;
      debugPrint(
        '[Profile] Build dashboard state & projections took ${t7 - t6}ms',
      );
      setState(() => _preparingProjections = false);

      _timeoutTimer?.cancel();
      debugPrint(
        '[Profile] Total app initialization took ${stopwatch.elapsedMilliseconds}ms',
      );

      // Trigger background tasks non-blocking
      unawaited(appStateController.startMarketAutoRefresh());

      if (mounted) {
        widget.onComplete();
      }
    } catch (e, stack) {
      debugPrint('[Profile] App initialization failed: $e\n$stack');
      _timeoutTimer?.cancel();
      if (mounted) {
        widget.onComplete(); // Fallback to complete anyway
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Deep Green background matching brand palette
    const deepGreen = Color(0xFF01332B);
    const goldColor = Color(0xFFD4AF37);

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
                    const Color(0xFF073A31),
                    const Color(0xFF021815),
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
                      color: Colors.transparent,
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
                  const Text(
                    'Zakah Wealth',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Preparing your wealth dashboard...',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildChecklistItem('Loading assets', _loadingAssets),
                        const SizedBox(height: 12),
                        _buildChecklistItem(
                          'Loading transactions',
                          _loadingTransactions,
                        ),
                        const SizedBox(height: 12),
                        _buildChecklistItem(
                          'Restoring session',
                          _restoringSession,
                        ),
                        const SizedBox(height: 12),
                        _buildChecklistItem(
                          'Preparing projections',
                          _preparingProjections,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (_timeoutReached) ...[
                    const Text(
                      'Still preparing your data...',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    if (_localDataLoaded)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: widget.onComplete,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: goldColor,
                            foregroundColor: deepGreen,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Continue Offline',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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

  Widget _buildChecklistItem(String label, bool isActive) {
    return Row(
      children: [
        isActive
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                  strokeWidth: 1.5,
                ),
              )
            : const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFFD4AF37),
                size: 18,
              ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
