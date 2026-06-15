import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_radii.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../models/user_profile.dart';
import '../../services/app_state_controller.dart';
import '../../services/auth_controller.dart';
import '../../services/cloud_backup_controller.dart';
import 'login_page.dart';
import '../../screens/app_shell.dart';
import '../../services/backup_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

enum _AuthGateView { signedOut, checking, ready }

class _AuthGateState extends State<AuthGate> {
  AuthController? _authController;
  CloudBackupController? _cloudBackupController;
  UserProfile? _bootstrappedUser;
  _AuthGateView _view = _AuthGateView.signedOut;
  bool _bootstrapInFlight = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AuthController nextAuth = context.read<AuthController>();
    if (!identical(nextAuth, _authController)) {
      final AuthController? previous = _authController;
      if (previous != null) {
        previous.removeListener(_handleAuthChanged);
      }
      _authController = nextAuth;
      nextAuth.addListener(_handleAuthChanged);
      unawaited(_handleAuthChanged());
    }

    try {
      _cloudBackupController = context.read<CloudBackupController>();
    } catch (_) {
      _cloudBackupController = null;
    }
  }

  @override
  void dispose() {
    _authController?.removeListener(_handleAuthChanged);
    super.dispose();
  }

  Future<void> _handleAuthChanged() async {
    final UserProfile? user = _authController?.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _bootstrappedUser = null;
          _view = _AuthGateView.signedOut;
        });
      }
      return;
    }

    if (_bootstrappedUser?.id == user.id && _view != _AuthGateView.signedOut) {
      return;
    }
    if (_bootstrapInFlight) return;

    _bootstrapInFlight = true;
    if (mounted) {
      setState(() {
        _view = _AuthGateView.checking;
      });
    }

    try {
      final AppStateController appStateController = context
          .read<AppStateController>();
      final CloudBackupController? cloudBackupController =
          _cloudBackupController;
      await appStateController.load(userId: user.id);
      await appStateController.attachCurrentUser(
        userId: user.id,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoUrl,
        provider: user.provider,
      );
      await cloudBackupController?.refreshCloudState();

      if (!mounted) return;
      final bool hasBackup = cloudBackupController?.latestBackup != null;
      final bool hasLocalData = BackupService.hasData(
        appStateController.state.toJson(),
      );

      // Never silently overwrite local data during sign-in.
      // If a cloud backup exists, AppShell can surface the explicit restore prompt.
      if (!hasLocalData && !hasBackup) {
        await appStateController.resetForCurrentUser(user);
      }

      setState(() {
        _bootstrappedUser = user;
        _view = _AuthGateView.ready;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _bootstrappedUser = user;
          _view = _AuthGateView.signedOut;
        });
      }
      debugPrint('AuthGate bootstrap failed: $error');
    } finally {
      _bootstrapInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final auth = context.watch<AuthController>();
    final UserProfile? user = auth.currentUser;

    if (auth.isLoading && user == null) {
      return const LoginPage();
    }

    if (user == null || _view == _AuthGateView.signedOut) {
      return const LoginPage();
    }

    if (_view == _AuthGateView.ready) {
      return const AppShell();
    }

    return _AuthCheckingView(tokens: tokens);
  }
}

class _AuthCheckingView extends StatelessWidget {
  const _AuthCheckingView({required this.tokens});

  final PremiumThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tokens.colors.background,
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
                    tokens.colors.background,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.045,
              child: Image.asset(
                'assets/images/hero_pattern_watermark.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _AuthCheckingHero(tokens: tokens),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: AppRadii.card,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              'Authenticating...',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: tokens.colors.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            const _AuthChecklistItem(
                              label: 'Account verified',
                              isDone: true,
                              isActive: false,
                            ),
                            const SizedBox(height: 10),
                            const _AuthChecklistItem(
                              label: 'Checking Cloud Backup...',
                              isDone: false,
                              isActive: true,
                            ),
                            const SizedBox(height: 10),
                            const _AuthChecklistItem(
                              label: 'Loading transactions',
                              isDone: false,
                              isActive: false,
                            ),
                            const SizedBox(height: 10),
                            const _AuthChecklistItem(
                              label: 'Loading assets',
                              isDone: false,
                              isActive: false,
                            ),
                            const SizedBox(height: 10),
                            const _AuthChecklistItem(
                              label: 'Loading plans',
                              isDone: false,
                              isActive: false,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthCheckingHero extends StatelessWidget {
  const _AuthCheckingHero({required this.tokens});

  final PremiumThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.asset(
            'assets/images/app_icon.png',
            width: 98,
            height: 98,
            errorBuilder: (_, _, _) => const SizedBox(width: 98, height: 98),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Zakah Wealth',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: tokens.colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _AuthChecklistItem extends StatelessWidget {
  const _AuthChecklistItem({
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
    final Color accent = isDone ? tokens.colors.emerald : tokens.colors.gold;
    return Row(
      children: <Widget>[
        if (isActive)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: tokens.colors.gold,
            ),
          )
        else
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 18,
            color: accent.withValues(alpha: isDone ? 1 : 0.65),
          ),
        const SizedBox(width: 12),
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
