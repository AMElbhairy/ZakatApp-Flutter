import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'core/i18n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_brand_ui.dart';
import 'features/auth/auth_loading_screen.dart';
import 'features/auth/login_page.dart';
import 'features/auth/restore_gate_screen.dart';
import 'models/user_profile.dart';
import 'repositories/app_state_repository.dart';
import 'screens/account/security_lock_screen.dart';
import 'screens/app_shell.dart';
import 'services/app_state_controller.dart';
import 'services/apple_shortcuts_service.dart';
import 'services/auth_controller.dart';
import 'services/auth_service.dart';
import 'services/cloud_backup_controller.dart';
import 'services/google_drive_service.dart';
import 'services/google_sheets_service.dart';
import 'services/local_storage_service.dart';
import 'services/sync_controller.dart';

void main() {
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository = AppStateRepository(
    localStorage: localStorage,
  );
  runApp(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppPrivacyOverlayController>(
          create: (_) => AppPrivacyOverlayController(),
        ),
        ChangeNotifierProvider<AppStateController>(
          create: (_) => AppStateController(repository: repository),
        ),
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(
            authService: CombinedAuthService(),
            localStorage: localStorage,
          ),
        ),
        ChangeNotifierProvider<CloudBackupController>(
          create: (BuildContext ctx) => CloudBackupController(
            appStateController: ctx.read<AppStateController>(),
            authController: ctx.read<AuthController>(),
            googleDriveService: GoogleDriveService(),
          ),
        ),
        ChangeNotifierProvider<SyncController>(
          create: (BuildContext ctx) => SyncController(
            appStateController: ctx.read<AppStateController>(),
            authController: ctx.read<AuthController>(),
            googleSheetsService: GoogleSheetsService(),
          ),
        ),
      ],
      child: const ZakatApp(),
    ),
  );
}

class ZakatApp extends StatelessWidget {
  const ZakatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStateController appStateController = context
        .watch<AppStateController>();
    final String languageCode = appStateController.state.languagePreference;
    final String themeModeRaw = appStateController.state.themeMode;
    final ThemeMode themeMode = switch (themeModeRaw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final Locale locale = languageCode == 'ar'
        ? const Locale('ar')
        : const Locale('en');
    return MaterialApp(
      title: 'Zakah Wealth',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (BuildContext context, Widget? child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Stack(
            children: <Widget>[
              if (child case final Widget builtChild) builtChild,
              Consumer<AppPrivacyOverlayController>(
                builder:
                    (
                      BuildContext context,
                      AppPrivacyOverlayController controller,
                      Widget? _,
                    ) {
                      if (!controller.visible) return const SizedBox.shrink();
                      return const AuthPrivacyOverlay();
                    },
              ),
            ],
          ),
        );
      },
      home: const _AppBootstrapper(),
    );
  }
}

enum _BootstrapPhase {
  authLoading,
  signedOut,
  loading,
  restoreGate,
  locked,
  ready,
}

class _AppBootstrapper extends StatefulWidget {
  const _AppBootstrapper();

  @override
  State<_AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<_AppBootstrapper>
    with WidgetsBindingObserver {
  _BootstrapPhase _phase = _BootstrapPhase.authLoading;
  DateTime? _pausedAt;
  bool _accountVerified = false;
  bool _checkingCloudBackup = false;
  bool _loadingEntries = false;
  bool _loadingAssets = false;
  bool _loadingPlans = false;
  String? _loadingMessage;
  AuthController? _authController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AuthController nextAuth = context.read<AuthController>();
    if (!identical(nextAuth, _authController)) {
      _authController?.removeListener(_handleAuthChanged);
      _authController = nextAuth;
      nextAuth.addListener(_handleAuthChanged);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authController?.removeListener(_handleAuthChanged);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final AuthController authController = context.read<AuthController>();
    context.read<AppPrivacyOverlayController>().hide();

    try {
      setState(() {
        _phase = _BootstrapPhase.authLoading;
        _loadingMessage = null;
      });

      await authController.load();
      if (!mounted) return;

      final UserProfile? user = authController.currentUser;
      if (user == null) {
        context.read<AppPrivacyOverlayController>().hide();
        setState(() {
          _phase = _BootstrapPhase.signedOut;
          _accountVerified = false;
          _checkingCloudBackup = false;
          _loadingEntries = false;
          _loadingAssets = false;
          _loadingPlans = false;
        });
        return;
      }
      await _bootstrapAuthenticatedUser(user);
    } catch (error, stackTrace) {
      debugPrint('App bootstrap failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      context.read<AppPrivacyOverlayController>().hide();
      setState(() {
        _phase = _BootstrapPhase.signedOut;
        _accountVerified = false;
        _checkingCloudBackup = false;
        _loadingEntries = false;
        _loadingAssets = false;
        _loadingPlans = false;
      });
    }
  }

  Future<void> _bootstrapAuthenticatedUser(UserProfile user) async {
    final AppStateController appStateController = context
        .read<AppStateController>();
    final CloudBackupController cloudBackupController = context
        .read<CloudBackupController>();

    setState(() {
      _phase = _BootstrapPhase.loading;
      _accountVerified = true;
      _checkingCloudBackup = false;
      _loadingEntries = true;
      _loadingAssets = false;
      _loadingPlans = false;
      _loadingMessage = null;
    });

    await appStateController.loadAuthenticated(user.id);
    if (!mounted) return;

    await appStateController.attachCurrentUser(
      userId: user.id,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoUrl,
      provider: user.provider,
    );
    if (!mounted) return;

    setState(() {
      _loadingEntries = false;
      _loadingAssets = true;
      _checkingCloudBackup = true;
    });

    await cloudBackupController.refreshCloudState();
    if (!mounted) return;

    setState(() {
      _checkingCloudBackup = false;
      _loadingAssets = false;
      _loadingPlans = true;
    });

    AppleShortcutsService.initialize(appStateController);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    setState(() {
      _loadingPlans = false;
    });

    final bool shouldRestore =
        cloudBackupController.shouldPromptRestore &&
        cloudBackupController.latestBackup != null &&
        appStateController.state.restorePromptDismissedUserId != user.id;

    if (shouldRestore) {
      setState(() {
        _phase = _BootstrapPhase.restoreGate;
      });
    } else if (appStateController.state.biometricLockEnabled) {
      setState(() {
        _phase = _BootstrapPhase.locked;
      });
    } else {
      setState(() {
        _phase = _BootstrapPhase.ready;
      });
      unawaited(appStateController.startMarketAutoRefresh());
    }
  }

  Future<void> _handleAuthChanged() async {
    final UserProfile? user = _authController?.currentUser;
    if (!mounted) return;
    if (user == null) {
      setState(() {
        _phase = _BootstrapPhase.signedOut;
        _pausedAt = null;
        _accountVerified = false;
        _checkingCloudBackup = false;
        _loadingEntries = false;
        _loadingAssets = false;
        _loadingPlans = false;
      });
      context.read<AppPrivacyOverlayController>().hide();
      return;
    }

    if (_phase == _BootstrapPhase.authLoading) {
      return;
    }

    if (_phase == _BootstrapPhase.signedOut) {
      await _bootstrapAuthenticatedUser(user);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final AuthController? authController = _authController;
    final AppStateController appStateController = context
        .read<AppStateController>();
    final bool shouldProtect =
        authController?.currentUser != null &&
        (appStateController.state.biometricLockEnabled ||
            appStateController.state.biometricHideWealthEnabled);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_pausedAt == null &&
          shouldProtect &&
          _phase != _BootstrapPhase.locked) {
        _pausedAt = DateTime.now();
        if (mounted) {
          context.read<AppPrivacyOverlayController>().show();
        }
      }
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final DateTime? pausedAt = _pausedAt;
      _pausedAt = null;
      if (!mounted) return;
      context.read<AppPrivacyOverlayController>().hide();

      if (pausedAt != null &&
          authController?.currentUser != null &&
          appStateController.state.biometricLockEnabled &&
          _phase == _BootstrapPhase.ready) {
        final int secondsPaused = DateTime.now().difference(pausedAt).inSeconds;
        final int delaySeconds =
            switch (appStateController.state.biometricAutoLockDelay) {
              'immediate' => 0,
              '30_seconds' => 30,
              '5_minutes' => 300,
              _ => 60,
            };
        if (secondsPaused >= delaySeconds) {
          setState(() {
            _phase = _BootstrapPhase.locked;
          });
        }
      }
    }
  }

  void _handleUnlock() {
    if (!mounted) return;
    context.read<AppPrivacyOverlayController>().hide();
    setState(() {
      _phase = _BootstrapPhase.ready;
    });
  }

  Future<void> _enterShellAfterRestore() async {
    if (!mounted) return;
    final AppStateController appStateController = context
        .read<AppStateController>();
    final CloudBackupController cloudBackupController = context
        .read<CloudBackupController>();
    final UserProfile? user = context.read<AuthController>().currentUser;
    if (user == null) {
      setState(() => _phase = _BootstrapPhase.signedOut);
      return;
    }
    await cloudBackupController.refreshCloudState(evaluatePrompt: false);
    if (!mounted) return;
    if (appStateController.state.biometricLockEnabled) {
      setState(() {
        _phase = _BootstrapPhase.locked;
      });
    } else {
      setState(() {
        _phase = _BootstrapPhase.ready;
      });
      unawaited(appStateController.startMarketAutoRefresh());
    }
  }

  Future<void> _restoreBackup() async {
    final CloudBackupController cloudBackupController = context
        .read<CloudBackupController>();
    final bool ok = await cloudBackupController.restoreLatestBackup();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _loadingMessage = cloudBackupController.statusMessage;
      });
      return;
    }
    await _enterShellAfterRestore();
  }

  Future<void> _startFresh() async {
    final AppStateController appStateController = context
        .read<AppStateController>();
    final AuthController authController = context.read<AuthController>();
    final UserProfile? user = authController.currentUser;
    if (user == null) {
      setState(() => _phase = _BootstrapPhase.signedOut);
      return;
    }
    final bool shouldLock = appStateController.state.biometricLockEnabled;
    await appStateController.markRestorePromptDismissedForCurrentUser(
      userId: user.id,
    );
    if (!mounted) return;
    setState(() {
      _phase = shouldLock ? _BootstrapPhase.locked : _BootstrapPhase.ready;
    });
    if (!shouldLock) {
      unawaited(appStateController.startMarketAutoRefresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (_phase) {
      _BootstrapPhase.authLoading => AuthLoadingScreen(
        isAccountVerified: _accountVerified,
        isCheckingCloudBackup: _checkingCloudBackup,
        isLoadingEntries: _loadingEntries,
        isLoadingAssets: _loadingAssets,
        isLoadingPlans: _loadingPlans,
        statusMessage: _loadingMessage,
      ),
      _BootstrapPhase.signedOut => const LoginPage(),
      _BootstrapPhase.loading => AuthLoadingScreen(
        isAccountVerified: _accountVerified,
        isCheckingCloudBackup: _checkingCloudBackup,
        isLoadingEntries: _loadingEntries,
        isLoadingAssets: _loadingAssets,
        isLoadingPlans: _loadingPlans,
        statusMessage: _loadingMessage,
      ),
      _BootstrapPhase.restoreGate => RestoreGateScreen(
        cloudBackupController: context.watch<CloudBackupController>(),
        onRestore: _restoreBackup,
        onStartFresh: _startFresh,
      ),
      _BootstrapPhase.locked => SecurityLockScreen(onUnlock: _handleUnlock),
      _BootstrapPhase.ready => const AppShell(),
    };

    return body;
  }
}

class AppPrivacyOverlayController extends ChangeNotifier {
  bool _visible = false;

  bool get visible => _visible;

  void show() {
    if (_visible) return;
    _visible = true;
    notifyListeners();
  }

  void hide() {
    if (!_visible) return;
    _visible = false;
    notifyListeners();
  }
}
