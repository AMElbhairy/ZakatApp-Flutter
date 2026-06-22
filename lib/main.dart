import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'core/i18n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_brand_ui.dart';
import 'features/auth/email_verification_screen.dart';
import 'features/auth/auth_loading_screen.dart';
import 'features/auth/login_page.dart';
import 'features/auth/restore_gate_screen.dart';
import 'firebase_options.dart';
import 'models/user_profile.dart';
import 'data/local/app_database.dart';
import 'data/local/daos/migration_state_dao.dart';
import 'data/local/local_store_providers.dart';
import 'data/repositories/local_financial_operations_repository.dart';
import 'data/repositories/local_savings_repository.dart';
import 'data/repositories/local_sync_repository.dart';
import 'data/repositories/local_transactions_repository.dart';
import 'repositories/app_state_repository.dart';
import 'screens/account/security_lock_screen.dart';
import 'screens/app_shell.dart';
import 'services/app_state_controller.dart';
import 'services/apple_shortcuts_service.dart';
import 'services/auth_controller.dart';
import 'services/auth_service.dart';
import 'services/cloud_backup_controller.dart';
import 'services/firestore_sync_manager.dart';
import 'services/google_sheets_service.dart';
import 'services/local_storage_service.dart';
import 'services/smart_capture_alert_service.dart';
import 'data/sync/local_sync_pipeline.dart';
import 'services/sync_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!ZakatApp.isTesting) {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool hasRunBefore = prefs.getBool('has_run_before') ?? false;
      if (!hasRunBefore) {
        try {
          await FirebaseAuth.instance.signOut();
        } catch (e) {
          debugPrint('Error signing out of FirebaseAuth on first run: $e');
        }
        try {
          const FlutterSecureStorage secureStorage = FlutterSecureStorage();
          await secureStorage.deleteAll();
        } catch (e) {
          debugPrint('Error clearing secure storage on first run: $e');
        }
        await prefs.setBool('has_run_before', true);
      }
    } catch (e) {
      debugPrint('Error in first run detection/cleanup: $e');
    }
  }

  const LocalStorageService localStorage = LocalStorageService();
  final FirestoreSyncManager firestoreSyncManager = FirestoreSyncManager();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final SmartCaptureAlertService smartCaptureAlertService = kIsWeb
      ? const NoopSmartCaptureAlertService()
      : PlatformSmartCaptureAlertService();
  smartCaptureAlertService.attachNavigatorKey(navigatorKey);
  await smartCaptureAlertService.initialize();
  final localDatabase = localDatabaseProvider();
  final AppStateRepository repository = AppStateRepository(
    localStorage: localStorage,
  );
  runApp(
    MultiProvider(
      providers: <SingleChildWidget>[
        Provider<SmartCaptureAlertService>.value(
          value: smartCaptureAlertService,
        ),
        ChangeNotifierProvider<AppPrivacyOverlayController>(
          create: (_) => AppPrivacyOverlayController(),
        ),
        ChangeNotifierProvider<AppStateController>(
          create: (_) => AppStateController(
            repository: repository,
            firestoreSyncManager: firestoreSyncManager,
            database: localDatabase,
            ownsDatabase: true,
            smartCaptureAlertService: smartCaptureAlertService,
          ),
        ),
        ProxyProvider<AppStateController, AppDatabase>(
          update: (_, controller, _) => controller.database!,
        ),
        ProxyProvider<AppDatabase, MigrationStateDao>(
          update: (_, db, _) => migrationStateProvider(db),
        ),
        ProxyProvider<AppStateController, LocalTransactionsRepository>(
          update: (_, controller, _) =>
              controller.localTransactionsRepository
                  as LocalTransactionsRepository,
        ),
        ProxyProvider<AppStateController, LocalSavingsRepository>(
          update: (_, controller, _) =>
              controller.localSavingsRepository as LocalSavingsRepository,
        ),
        ProxyProvider<AppStateController, LocalFinancialOperationsRepository>(
          update: (_, controller, _) =>
              controller.localFinancialOperationsRepository
                  as LocalFinancialOperationsRepository,
        ),
        ProxyProvider<AppDatabase, LocalSyncRepository>(
          update: (_, AppDatabase db, _) => localSyncRepositoryProvider(db),
        ),
        ProxyProvider<AppStateController, UseSqliteLocalStoreProvider>(
          update: (_, controller, _) => controller.useSqliteLocalStoreProvider!,
        ),
        ProxyProvider<AppStateController, LocalSyncPipeline>(
          update: (_, controller, _) => controller.localSyncPipeline!,
        ),
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(
            authService: FirebaseAuthService(),
            localStorage: localStorage,
          ),
        ),
        Provider<FirestoreSyncManager>.value(value: firestoreSyncManager),
        ChangeNotifierProvider<CloudBackupController>(
          create: (BuildContext ctx) => CloudBackupController(
            appStateController: ctx.read<AppStateController>(),
            authController: ctx.read<AuthController>(),
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
      child: ZakatApp(navigatorKey: navigatorKey),
    ),
  );
}

class ZakatApp extends StatelessWidget {
  const ZakatApp({super.key, this.navigatorKey});

  final GlobalKey<NavigatorState>? navigatorKey;

  static final bool isTesting = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  @override
  Widget build(BuildContext context) {
    final GlobalKey<NavigatorState> key = navigatorKey ?? GlobalKey<NavigatorState>();
    if (_hasAppPrivacyOverlayController(context)) {
      return _ZakatAppContent(navigatorKey: key);
    }
    return ChangeNotifierProvider<AppPrivacyOverlayController>(
      create: (_) => AppPrivacyOverlayController(),
      child: _ZakatAppContent(navigatorKey: key),
    );
  }
}

bool _hasAppPrivacyOverlayController(BuildContext context) {
  try {
    context.read<AppPrivacyOverlayController>();
    return true;
  } catch (_) {
    return false;
  }
}

class _ZakatAppContent extends StatelessWidget {
  const _ZakatAppContent({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

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
      navigatorKey: navigatorKey,
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
  emailVerification,
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
  bool _loadingMarketData = false;
  bool _loadingPlans = false;
  String? _loadingMessage;
  AuthController? _authController;
  StreamSubscription<AuthGateState>? _authGateSubscription;
  bool _gateBootstrapInProgress = false;
  bool _sessionExpiryHandlingInProgress = false;
  bool _initialBootstrapComplete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_bootstrap());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AuthController nextAuth = context.read<AuthController>();
    if (!identical(nextAuth, _authController)) {
      _authGateSubscription?.cancel();
      _authController = nextAuth;
      _authGateSubscription = nextAuth.authGateStateChanges.listen((
        AuthGateState state,
      ) {
        unawaited(_handleAuthGateState(state));
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authGateSubscription?.cancel();
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
        await _routeToSignedOut();
        return;
      }
      if (_requiresEmailVerification(user)) {
        await _routeToEmailVerification(user);
        return;
      }
      await _bootstrapAuthenticatedUser(user);
    } catch (error, stackTrace) {
      debugPrint('App bootstrap failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _routeToSignedOut();
    }
  }

  Future<void> _bootstrapAuthenticatedUser(UserProfile user) async {
    _initialBootstrapComplete = false;
    final AppStateController appStateController = context
        .read<AppStateController>();

    setState(() {
      _phase = _BootstrapPhase.loading;
      _accountVerified = true;
      _checkingCloudBackup = false;
      _loadingEntries = true;
      _loadingAssets = false;
      _loadingMarketData = false;
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

    if (!appStateController.enableBackgroundSync &&
        !appStateController.enableMarketAutoRefresh) {
      setState(() {
        _loadingEntries = false;
        _loadingAssets = false;
        _checkingCloudBackup = false;
        _loadingMarketData = false;
        _loadingPlans = false;
        _phase = _BootstrapPhase.ready;
      });
      _initialBootstrapComplete = true;
      return;
    }

    setState(() {
      _loadingEntries = false;
      _loadingAssets = true;
      _checkingCloudBackup = true;
      _loadingMarketData = false;
    });

    await appStateController.startLiveFirestoreSync(userId: user.id);
    if (!mounted) return;

    final CloudBackupController cloudBackupController = context
        .read<CloudBackupController>();
    await cloudBackupController.refreshCloudState();
    if (!mounted) return;

    setState(() {
      _checkingCloudBackup = false;
      _loadingAssets = false;
      _loadingMarketData = true;
      _loadingPlans = false;
    });

    await appStateController.startMarketAutoRefresh();
    if (!mounted) return;

    setState(() {
      _loadingMarketData = false;
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
    _initialBootstrapComplete = true;
  }

  Future<void> _handleAuthGateState(AuthGateState state) async {
    if (!mounted) return;
    if (!_initialBootstrapComplete) {
      debugPrint('[BootstrapDebug] ignoring stream auth state ${state.status} because initial bootstrap is not complete');
      return;
    }
    switch (state.status) {
      case AuthGateStatus.checking:
        if (_phase == _BootstrapPhase.signedOut) {
          setState(() {
            _phase = _BootstrapPhase.authLoading;
            _loadingMessage = null;
          });
        }
        return;
      case AuthGateStatus.signedOut:
      case AuthGateStatus.error:
        await context.read<AppStateController>().stopLiveFirestoreSync();
        if (!mounted) return;
        if (_phase == _BootstrapPhase.signedOut) return;
        setState(() {
          _phase = _BootstrapPhase.signedOut;
          _pausedAt = null;
          _accountVerified = false;
          _checkingCloudBackup = false;
          _loadingEntries = false;
          _loadingAssets = false;
          _loadingMarketData = false;
          _loadingPlans = false;
          _loadingMessage = state.message;
        });
        context.read<AppPrivacyOverlayController>().hide();
        return;
      case AuthGateStatus.tokenExpired:
        if (_sessionExpiryHandlingInProgress) return;
        _sessionExpiryHandlingInProgress = true;
        try {
          await _showSessionExpiredIntervention();
          if (!mounted) return;
          await _authController?.signOut();
          if (!mounted) return;
          await _routeToSignedOut();
        } finally {
          _sessionExpiryHandlingInProgress = false;
        }
        return;
      case AuthGateStatus.signedIn:
        final UserProfile? user = state.user ?? _authController?.currentUser;
        if (user == null) return;
        if (_requiresEmailVerification(user)) {
          await _routeToEmailVerification(user);
          return;
        }
        if (_gateBootstrapInProgress) return;
        if (!(_phase == _BootstrapPhase.signedOut ||
            _phase == _BootstrapPhase.authLoading)) {
          return;
        }
        _gateBootstrapInProgress = true;
        try {
          await _bootstrapAuthenticatedUser(user);
        } finally {
          _gateBootstrapInProgress = false;
        }
        return;
    }
  }

  Future<void> _routeToSignedOut() async {
    if (!mounted) return;
    await context.read<AppStateController>().stopLiveFirestoreSync();
    if (!mounted) return;
    setState(() {
      _phase = _BootstrapPhase.signedOut;
      _pausedAt = null;
      _accountVerified = false;
      _checkingCloudBackup = false;
      _loadingEntries = false;
      _loadingAssets = false;
      _loadingPlans = false;
    });
    _initialBootstrapComplete = true;
    context.read<AppPrivacyOverlayController>().hide();
  }

  bool _requiresEmailVerification(UserProfile user) {
    return user.provider == 'email' && !user.emailVerified;
  }

  Future<void> _routeToEmailVerification(UserProfile user) async {
    if (!mounted) return;
    await context.read<AppStateController>().stopLiveFirestoreSync();
    if (!mounted) return;
    setState(() {
      _phase = _BootstrapPhase.emailVerification;
      _pausedAt = null;
      _accountVerified = false;
      _checkingCloudBackup = false;
      _loadingEntries = false;
      _loadingAssets = false;
      _loadingMarketData = false;
      _loadingPlans = false;
      _loadingMessage = null;
    });
    _initialBootstrapComplete = true;
    context.read<AppPrivacyOverlayController>().hide();
  }

  Future<void> _showSessionExpiredIntervention() async {
    if (!mounted) return;
    const Color deepEmerald = Color(0xFF042F2B);
    const Color surface = Color(0xFFF7F5EF);

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bottomSheetContext) {
        final ThemeData theme = Theme.of(bottomSheetContext);
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  height: 4,
                  width: 42,
                  decoration: BoxDecoration(
                    color: const Color(0x33042F2B),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Session verification required',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: deepEmerald,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your secure session has expired. Please verify your identity to continue.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: deepEmerald.withValues(alpha: 0.86),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: deepEmerald,
                      foregroundColor: surface,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.of(bottomSheetContext).pop(),
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

      if (authController?.currentUser != null &&
          (_phase == _BootstrapPhase.ready ||
              _phase == _BootstrapPhase.locked)) {
        unawaited(appStateController.startMarketAutoRefresh());
        unawaited(appStateController.triggerSyncPipeline(reason: 'app_resume'));
      }

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
        _loadingMarketData = true;
      });
      await appStateController.startMarketAutoRefresh();
      if (!mounted) return;
      setState(() {
        _loadingMarketData = false;
        _phase = _BootstrapPhase.ready;
      });
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
    if (!shouldLock) {
      setState(() {
        _loadingMarketData = true;
      });
      await appStateController.startMarketAutoRefresh();
      if (!mounted) return;
    }
    setState(() {
      _loadingMarketData = false;
      _phase = shouldLock ? _BootstrapPhase.locked : _BootstrapPhase.ready;
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[BootstrapDebug] building with phase=$_phase');
    final Widget body = switch (_phase) {
      _BootstrapPhase.authLoading => AuthLoadingScreen(
        isAccountVerified: _accountVerified,
        isCheckingCloudBackup: _checkingCloudBackup,
        isLoadingEntries: _loadingEntries,
        isLoadingAssets: _loadingAssets,
        isLoadingMarketData: _loadingMarketData,
        isLoadingPlans: _loadingPlans,
        statusMessage: _loadingMessage,
      ),
      _BootstrapPhase.signedOut => const LoginPage(),
      _BootstrapPhase.emailVerification => EmailVerificationScreen(
        email: context.watch<AuthController>().currentUser?.email ?? '',
        onVerified: () async {
          final UserProfile? user = context.read<AuthController>().currentUser;
          if (user == null || _requiresEmailVerification(user)) {
            return;
          }
          await _bootstrapAuthenticatedUser(user);
        },
      ),
      _BootstrapPhase.loading => AuthLoadingScreen(
        isAccountVerified: _accountVerified,
        isCheckingCloudBackup: _checkingCloudBackup,
        isLoadingEntries: _loadingEntries,
        isLoadingAssets: _loadingAssets,
        isLoadingMarketData: _loadingMarketData,
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
