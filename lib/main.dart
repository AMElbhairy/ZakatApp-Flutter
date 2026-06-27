import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'core/i18n/app_localizations.dart';
import 'core/theme/app_colors.dart';
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
import 'services/backup_key_manager.dart';
import 'services/backup_service.dart';
import 'services/first_run_cleanup_service.dart';
import 'services/google_sign_in_factory.dart';
import 'services/google_sheets_service.dart';
import 'services/local_storage_service.dart';
import 'services/network_status_controller.dart';
import 'services/smart_capture_alert_service.dart';
import 'services/sync_controller.dart';
import 'services/startup_restore_discovery.dart';

final bool _showLegacyAuthUi = kDebugMode && !ZakatApp.isTesting;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final GoogleSignIn googleSignIn = createAppGoogleSignIn();

  if (!ZakatApp.isTesting) {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await FirstRunCleanupService(
        firebaseAuth: FirebaseAuth.instance,
        googleSignIn: googleSignIn,
        clearSecureStorage: () async {
          const FlutterSecureStorage secureStorage = FlutterSecureStorage();
          await secureStorage.deleteAll();
        },
      ).runIfNeeded(prefs);
    } catch (e) {
      debugPrint('Error in first run detection/cleanup: $e');
    }
  }

  const LocalStorageService localStorage = LocalStorageService();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final SmartCaptureAlertService smartCaptureAlertService = kIsWeb
      ? const NoopSmartCaptureAlertService()
      : PlatformSmartCaptureAlertService();
  smartCaptureAlertService.attachNavigatorKey(navigatorKey);
  try {
    await smartCaptureAlertService.initialize();
  } catch (error, stackTrace) {
    debugPrint('Smart capture alert init skipped: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  final localDatabase = localDatabaseProvider();
  final AppStateRepository repository = AppStateRepository(
    localStorage: localStorage,
  );
  runApp(
    MultiProvider(
      providers: <SingleChildWidget>[
        Provider<GoogleSignIn>.value(value: googleSignIn),
        Provider<SmartCaptureAlertService>.value(
          value: smartCaptureAlertService,
        ),
        ChangeNotifierProvider<AppPrivacyOverlayController>(
          create: (_) => AppPrivacyOverlayController(),
        ),
        ChangeNotifierProvider<AppStateController>(
          create: (_) => AppStateController(
            repository: repository,
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
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(
            authService: FirebaseAuthService(googleSignIn: googleSignIn),
            localStorage: localStorage,
          ),
        ),
        Provider<BackupKeyManager>(
          create: (BuildContext ctx) => BackupKeyManager(
            secureStorageService: ctx
                .read<AppStateController>()
                .secureStorageService,
          ),
        ),
        ChangeNotifierProvider<CloudBackupController>(
          create: (BuildContext ctx) => CloudBackupController(
            appStateController: ctx.read<AppStateController>(),
            authController: ctx.read<AuthController>(),
            backupKeyManager: ctx.read<BackupKeyManager>(),
            googleSignIn: ctx.read<GoogleSignIn>(),
          ),
        ),
        ChangeNotifierProvider<NetworkStatusController>(
          create: (_) {
            final NetworkStatusController controller =
                NetworkStatusController();
            unawaited(controller.start());
            return controller;
          },
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

  static final bool isTesting =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  @override
  Widget build(BuildContext context) {
    final GlobalKey<NavigatorState> key =
        navigatorKey ?? GlobalKey<NavigatorState>();
    if (_hasAppPrivacyOverlayController(context)) {
      return _NetworkStatusScope(child: _ZakatAppContent(navigatorKey: key));
    }
    return ChangeNotifierProvider<AppPrivacyOverlayController>(
      create: (_) => AppPrivacyOverlayController(),
      child: _NetworkStatusScope(child: _ZakatAppContent(navigatorKey: key)),
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

bool _hasNetworkStatusController(BuildContext context) {
  try {
    context.read<NetworkStatusController>();
    return true;
  } catch (_) {
    return false;
  }
}

class _NetworkStatusScope extends StatefulWidget {
  const _NetworkStatusScope({required this.child});

  final Widget child;

  @override
  State<_NetworkStatusScope> createState() => _NetworkStatusScopeState();
}

class _NetworkStatusScopeState extends State<_NetworkStatusScope> {
  NetworkStatusController? _controller;
  bool _usesExternalController = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool hasExternalController = _hasNetworkStatusController(context);
    if (hasExternalController == _usesExternalController) {
      return;
    }

    _usesExternalController = hasExternalController;
    if (_usesExternalController) {
      _controller?.dispose();
      _controller = null;
    } else if (!ZakatApp.isTesting && _controller == null) {
      _controller = NetworkStatusController();
      unawaited(_controller!.start());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_usesExternalController) {
      return widget.child;
    }
    if (ZakatApp.isTesting) {
      return widget.child;
    }
    final NetworkStatusController controller = _controller ??=
        NetworkStatusController();
    if (!_controller!.isOffline && !_controller!.isChecking) {
      unawaited(_controller!.start());
    }
    return ChangeNotifierProvider<NetworkStatusController>.value(
      value: controller,
      child: widget.child,
    );
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
      theme: AppTheme.lightForLocale(locale: locale),
      darkTheme: AppTheme.darkForLocale(locale: locale),
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
              const _OfflineStatusBannerOverlay(),
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

class _OfflineStatusBannerOverlay extends StatelessWidget {
  const _OfflineStatusBannerOverlay();

  @override
  Widget build(BuildContext context) {
    final bool hasController = _hasNetworkStatusController(context);
    if (!hasController) return const SizedBox.shrink();

    final bool isOffline = context.watch<NetworkStatusController>().isOffline;
    if (!isOffline) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final Color surface = theme.colorScheme.surface;
    final Color onSurface = theme.colorScheme.onSurface;
    final Color accent = theme.colorScheme.tertiary;

    return IgnorePointer(
      ignoring: true,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: surface.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: AppColors.black12,
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.cloud_off_rounded, color: accent, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              'Working offline',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Google Drive sync will resume when you are online. Market prices may be outdated.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: onSurface.withValues(alpha: 0.78),
                                height: 1.3,
                              ),
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
        ),
      ),
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
  int _shellInitialIndex = 2;
  StartupRestoreDiscoveryResult? _restoreGateDiscovery;
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

  T? _maybeRead<T>() {
    try {
      return context.read<T>();
    } catch (_) {
      return null;
    }
  }

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
    final CloudBackupController? cloudBackupController =
        _maybeRead<CloudBackupController>();

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

    final bool localHasData = BackupService.hasData(
      appStateController.state.toJson(),
    );
    final StartupRestoreDiscoveryResult discovery = localHasData ||
            cloudBackupController == null
        ? const StartupRestoreDiscoveryResult(
            status: StartupRestoreDiscoveryStatus.none,
            message: 'Local data exists',
          )
        : await cloudBackupController.discoverStartupRestore(
            localHasData: false,
          );
    _restoreGateDiscovery = discovery;

    if (!localHasData &&
        discovery.status == StartupRestoreDiscoveryStatus.restorePrompt) {
      await _autoRestoreStartupBackup(discovery);
      return;
    }

    if (discovery.shouldShowGate) {
      setState(() {
        _loadingEntries = false;
        _loadingMarketData = false;
        _loadingAssets = false;
        _loadingPlans = false;
        _checkingCloudBackup = false;
        _loadingMessage = discovery.message;
        _phase = _BootstrapPhase.restoreGate;
      });
      _initialBootstrapComplete = true;
      return;
    }

    if (cloudBackupController != null) {
      unawaited(() async {
        try {
          await cloudBackupController.refreshCloudState(
            evaluatePrompt: false,
          );
        } catch (error, stackTrace) {
          debugPrint('Cloud backup bootstrap refresh failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }());
    }

    if (!appStateController.enableBackgroundSync &&
        !appStateController.enableMarketAutoRefresh) {
      setState(() {
        _loadingEntries = false;
        _loadingMarketData = false;
        _loadingAssets = false;
        _loadingPlans = false;
        _checkingCloudBackup = false;
        _phase = _BootstrapPhase.ready;
      });
      _initialBootstrapComplete = true;
      return;
    }

    setState(() {
      _loadingEntries = false;
      _loadingMarketData = false;
      _loadingAssets = false;
      _loadingPlans = false;
      _checkingCloudBackup = false;
      _phase = appStateController.state.biometricLockEnabled
          ? _BootstrapPhase.locked
          : _BootstrapPhase.ready;
    });
    _initialBootstrapComplete = true;

    unawaited(
      _finishBootstrapBackgroundTasks(
        user: user,
        appStateController: appStateController,
      ),
    );
  }

  Future<void> _autoRestoreStartupBackup(
    StartupRestoreDiscoveryResult discovery,
  ) async {
    final CloudBackupController? cloudBackupController =
        _maybeRead<CloudBackupController>();
    if (cloudBackupController == null) {
      await _enterShellAfterRestore();
      return;
    }
    setState(() {
      _phase = _BootstrapPhase.loading;
      _loadingEntries = false;
      _loadingAssets = false;
      _loadingMarketData = false;
      _loadingPlans = false;
      _checkingCloudBackup = false;
      _loadingMessage = 'Restoring latest cloud backup...';
      _restoreGateDiscovery = discovery;
    });

    final bool ok = await cloudBackupController.restoreLatestBackup();
    if (!mounted) return;
    if (!ok) {
      final String error = cloudBackupController.statusMessage.isNotEmpty
          ? cloudBackupController.statusMessage
          : 'Restore failed';
      setState(() {
        _loadingMessage = error;
        _phase = _BootstrapPhase.restoreGate;
        _restoreGateDiscovery = discovery.copyWith(error: error);
      });
      _initialBootstrapComplete = true;
      return;
    }

    await _enterShellAfterRestore();
  }

  Future<void> _finishBootstrapBackgroundTasks({
    required UserProfile user,
    required AppStateController appStateController,
  }) async {
    final CloudBackupController? cloudBackupController =
        _maybeRead<CloudBackupController>();
    cloudBackupController?.completeStartupRestoreDiscovery();

    if (appStateController.enableBackgroundSync) {
      try {
        if (cloudBackupController != null) {
          unawaited(cloudBackupController.refreshCloudState());
        }
      } catch (error, stackTrace) {
        debugPrint('Cloud backup bootstrap refresh failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    if (appStateController.enableMarketAutoRefresh) {
      try {
        unawaited(appStateController.startMarketAutoRefresh());
      } catch (error, stackTrace) {
        debugPrint('Market refresh bootstrap failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    if (!mounted) return;
    AppleShortcutsService.initialize(appStateController);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
  }

  Future<void> _handleAuthGateState(AuthGateState state) async {
    if (!mounted) return;
    if (!_initialBootstrapComplete) {
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
        await context.read<AppStateController>().resetForSignedOutUser();
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
          _restoreGateDiscovery = null;
        });
        context.read<AppPrivacyOverlayController>().hide();
        return;
      case AuthGateStatus.error:
        if (_authController?.currentUser != null) {
          setState(() {
            _loadingMessage = state.message;
          });
          return;
        }
        await context.read<AppStateController>().resetForSignedOutUser();
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
          _restoreGateDiscovery = null;
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
    _maybeRead<CloudBackupController>()?.completeStartupRestoreDiscovery();
    await context.read<AppStateController>().resetForSignedOutUser();
    if (!mounted) return;
    setState(() {
      _phase = _BootstrapPhase.signedOut;
      _pausedAt = null;
      _accountVerified = false;
      _checkingCloudBackup = false;
      _loadingEntries = false;
      _loadingAssets = false;
      _loadingPlans = false;
      _restoreGateDiscovery = null;
    });
    _initialBootstrapComplete = true;
    context.read<AppPrivacyOverlayController>().hide();
  }

  bool _requiresEmailVerification(UserProfile user) {
    return user.provider == 'email' && !user.emailVerified;
  }

  Future<void> _routeToEmailVerification(UserProfile user) async {
    if (!mounted) return;
    _maybeRead<CloudBackupController>()?.completeStartupRestoreDiscovery();
    await context.read<AppStateController>().resetForSignedOutUser();
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
      _restoreGateDiscovery = null;
    });
    _initialBootstrapComplete = true;
    context.read<AppPrivacyOverlayController>().hide();
  }

  Future<void> _showSessionExpiredIntervention() async {
    if (!mounted) return;
    const Color deepEmerald = AppColors.brandForest;
    const Color surface = AppColors.sharedContainer;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
        backgroundColor: AppColors.transparent,
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
                    color: AppColors.black12,
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
                    color: AppColors.brandForest.withValues(alpha: 0.20),
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
        unawaited(
          appStateController.processDueRecurringTransactions(reason: 'resume'),
        );
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
      _phase = _BootstrapPhase.loading;
      _loadingEntries = false;
      _loadingAssets = false;
      _loadingMarketData = false;
      _loadingPlans = false;
      _loadingMessage = 'Unlocking secure session...';
    });
    unawaited(_finishUnlockTransition());
  }

  Future<void> _finishUnlockTransition() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    final AppStateController appStateController = context
        .read<AppStateController>();
    if (appStateController.enableMarketAutoRefresh) {
      setState(() {
        _loadingMarketData = true;
      });
      try {
        await appStateController.startMarketAutoRefresh();
      } finally {
        if (mounted) {
          setState(() {
            _loadingMarketData = false;
          });
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _loadingMessage = null;
      _phase = _BootstrapPhase.ready;
    });
  }

  Future<void> _enterShellAfterRestore() async {
    if (!mounted) return;
    final AppStateController appStateController = context
        .read<AppStateController>();
    final CloudBackupController? cloudBackupController =
        _maybeRead<CloudBackupController>();
    final UserProfile? user = context.read<AuthController>().currentUser;
    if (user == null) {
      setState(() => _phase = _BootstrapPhase.signedOut);
      return;
    }
    cloudBackupController?.completeStartupRestoreDiscovery();
    if (cloudBackupController != null) {
      await cloudBackupController.refreshCloudState(evaluatePrompt: false);
    }
    if (!mounted) return;
    if (appStateController.state.biometricLockEnabled) {
      setState(() {
        _phase = _BootstrapPhase.locked;
        _loadingMessage = null;
        _restoreGateDiscovery = null;
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
        _shellInitialIndex = 2;
        _restoreGateDiscovery = null;
      });
    }
    _initialBootstrapComplete = true;
  }

  Future<void> _restoreBackup() async {
    final CloudBackupController? cloudBackupController =
        _maybeRead<CloudBackupController>();
    if (cloudBackupController == null) {
      await _enterShellAfterRestore();
      return;
    }
    setState(() {
      _phase = _BootstrapPhase.loading;
      _loadingEntries = false;
      _loadingAssets = false;
      _loadingMarketData = false;
      _loadingPlans = false;
      _checkingCloudBackup = false;
      _loadingMessage = 'Restoring cloud backup...';
    });
    final bool ok = await cloudBackupController.restoreLatestBackup();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _loadingMessage = cloudBackupController.statusMessage;
        _phase = _BootstrapPhase.restoreGate;
      });
      return;
    }
    await _enterShellAfterRestore();
  }

  Future<void> _startFresh() async {
    final AppStateController appStateController = context
        .read<AppStateController>();
    final AuthController authController = context.read<AuthController>();
    final CloudBackupController? cloudBackupController =
        _maybeRead<CloudBackupController>();
    final UserProfile? user = authController.currentUser;
    if (user == null) {
      setState(() => _phase = _BootstrapPhase.signedOut);
      return;
    }
    final bool shouldLock = appStateController.state.biometricLockEnabled;
    cloudBackupController?.completeStartupRestoreDiscovery();
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
      _shellInitialIndex = 2;
      _restoreGateDiscovery = null;
    });
    if (cloudBackupController != null) {
      unawaited(cloudBackupController.refreshCloudState(evaluatePrompt: false));
    }
  }

  Future<void> _openBackupSync() async {
    final AppStateController appStateController = context
        .read<AppStateController>();
    final AuthController authController = context.read<AuthController>();
    final CloudBackupController? cloudBackupController =
        _maybeRead<CloudBackupController>();
    final UserProfile? user = authController.currentUser;
    if (user == null) {
      setState(() => _phase = _BootstrapPhase.signedOut);
      return;
    }
    cloudBackupController?.completeStartupRestoreDiscovery();
    setState(() {
      _loadingMarketData = false;
      _shellInitialIndex = 4;
      _phase = appStateController.state.biometricLockEnabled
          ? _BootstrapPhase.locked
          : _BootstrapPhase.ready;
      _restoreGateDiscovery = null;
    });
    if (cloudBackupController != null) {
      unawaited(cloudBackupController.refreshCloudState(evaluatePrompt: false));
    }
    if (!appStateController.state.biometricLockEnabled) {
      await appStateController.startMarketAutoRefresh();
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
        isLoadingMarketData: _loadingMarketData,
        isLoadingPlans: _loadingPlans,
        statusMessage: _loadingMessage,
      ),
      _BootstrapPhase.signedOut => LoginPage(
        showLegacyAuthUi: _showLegacyAuthUi,
      ),
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
      _BootstrapPhase.restoreGate => _maybeRead<CloudBackupController>() ==
              null
          ? const SizedBox.shrink()
          : RestoreGateScreen(
              cloudBackupController:
                  _maybeRead<CloudBackupController>()!,
              discovery:
                  _restoreGateDiscovery ??
                  const StartupRestoreDiscoveryResult(
                    status: StartupRestoreDiscoveryStatus.none,
                    message: 'No cloud backup found',
                  ),
              onRestore: _restoreBackup,
              onStartFresh: _startFresh,
              onOpenBackupSync: _openBackupSync,
            ),
      _BootstrapPhase.locked => SecurityLockScreen(onUnlock: _handleUnlock),
      _BootstrapPhase.ready => AppShell(initialIndex: _shellInitialIndex),
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
