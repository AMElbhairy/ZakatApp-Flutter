import 'package:flutter/material.dart';
import '../../services/biometric_service.dart';

class SecurityLockScreen extends StatefulWidget {
  final VoidCallback onUnlock;

  const SecurityLockScreen({super.key, required this.onUnlock});

  @override
  State<SecurityLockScreen> createState() => _SecurityLockScreenState();
}

class _SecurityLockScreenState extends State<SecurityLockScreen> {
  String _biometricLabel = 'Biometrics';
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricType();
    // Auto-authenticate on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _loadBiometricType() async {
    final label = await BiometricService.getBiometricTypeLabel();
    if (mounted) {
      setState(() {
        _biometricLabel = label;
      });
    }
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);

    final success = await BiometricService.authenticate(
      reason: 'Unlock Zakah Wealth to access your dashboard securely',
    );

    if (mounted) {
      setState(() => _authenticating = false);
      if (success) {
        widget.onUnlock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const deepGreen = Color(0xFF01332B);
    const goldColor = Color(0xFFD4AF37);

    return Scaffold(
      backgroundColor: deepGreen,
      body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  // App Logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      width: 88,
                      height: 88,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(width: 88, height: 88);
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Zakah Wealth',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your financial data is protected.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const Spacer(),
                  // Gold CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _authenticate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: goldColor,
                        foregroundColor: deepGreen,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Unlock',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Use $_biometricLabel / Passcode',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
    );
  }
}
