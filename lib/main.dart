// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'core/i18n/app_localizations.dart';
import 'core/privacy/app_privacy.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_brand_ui.dart';
import 'features/auth/email_verification_screen.dart';
import 'features/auth/auth_loading_screen.dart';
import 'features/auth/login_page.dart';
import 'features/auth/restore_gate_screen.dart';
import 'features/onboarding/onboarding_gate.dart';
import 'firebase_options.dart';
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
import 'screens/account/notifications_screen.dart';
import 'screens/dashboard/obligations_list_screen.dart';
import 'services/app_state_controller.dart';
import 'services/collection_hydration_evidence.dart';
import 'services/bootstrap_coordinator.dart';
import 'services/auth_controller.dart';
import 'services/auth_service.dart';
import 'services/biometric_service.dart';
import 'services/cloud_backup_controller.dart';
import 'services/backup_key_manager.dart';
import 'services/launch_diagnostics.dart';
import 'services/first_run_cleanup_service.dart';
import 'services/google_sign_in_factory.dart';
import 'services/google_sheets_service.dart';
import 'services/local_storage_service.dart';
import 'services/network_status_controller.dart';
import 'services/smart_capture_alert_service.dart';
import 'services/sync_controller.dart';
import 'services/startup_restore_discovery.dart';
import 'services/widget_data_service.dart';

final bool _showLegacyAuthUi = true;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  LaunchDiagnostics.setLaunchSource('app_icon');
  unawaited(
    LaunchDiagnostics.record(
      'process_entry',
      metadata: <String, dynamic>{'processState': 'cold_start'},
    ),
  );
  final GoogleSignIn googleSignIn = createAppGoogleSignIn();
  final GoogleSignIn backupGoogleSignIn = createAppGoogleSignIn(
    extraScopes: const <String>[
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  );
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  unawaited(WidgetDataService.initialize());

  if (!ZakatApp.isTesting) {
    try {
      await FirstRunCleanupService(
        firebaseAuth: FirebaseAuth.instance,
        googleSignIn: googleSignIn,
        clearSecureStorage: () async {
          const FlutterSecureStorage secureStorage = FlutterSecureStorage();
          await secureStorage.deleteAll();
        },
        clearAppStorage: () async {
          await prefs.clear();
          await WidgetDataService.clearAll();
          await AppDatabase.deleteAllDatabaseFiles();
        },
      ).runIfNeeded(prefs);
    } catch (e) {
      debugPrint('Error in first run detection/cleanup: $e');
    }
  }

  const LocalStorageService localStorage = LocalStorageService();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final String startupLanguage =
      prefs.getString('language_preference')?.trim().toLowerCase() == 'ar'
      ? 'ar'
      : 'en';
  final SmartCaptureAlertService smartCaptureAlertService = kIsWeb
      ? const NoopSmartCaptureAlertService()
      : PlatformSmartCaptureAlertService();
  smartCaptureAlertService.attachNavigatorKey(navigatorKey);
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
            googleSignIn: backupGoogleSignIn,
          ),
        ),
        ChangeNotifierProvider<BootstrapCoordinator>(
          create: (BuildContext ctx) => BootstrapCoordinator(
            dependencies: BootstrapDependencies(
              authController: ctx.read<AuthController>(),
              appStateController: ctx.read<AppStateController>(),
              cloudBackupController: ctx.read<CloudBackupController>(),
            ),
          ),
        ),
        ChangeNotifierProvider<NetworkStatusController>(
          create: (_) {
            final NetworkStatusController controller =
                NetworkStatusController();
            unawaited(
              controller.start(initialDelay: const Duration(milliseconds: 850)),
            );
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
      child: ZakatApp(
        navigatorKey: navigatorKey,
        preferences: prefs,
        startupLanguage: startupLanguage,
      ),
    ),
  );

  unawaited(_initializeSmartCaptureAlertService(smartCaptureAlertService));
}

Future<void> _initializeSmartCaptureAlertService(
  SmartCaptureAlertService smartCaptureAlertService,
) async {
  try {
    await smartCaptureAlertService.initialize();
  } catch (error, stackTrace) {
    debugPrint('Smart capture alert init skipped: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class ZakatApp extends StatelessWidget {
  const ZakatApp({
    super.key,
    this.navigatorKey,
    required this.preferences,
    this.startupLanguage,
  });

  final GlobalKey<NavigatorState>? navigatorKey;
  final SharedPreferences preferences;
  final String? startupLanguage;

  static final bool isTesting =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  @override
  Widget build(BuildContext context) {
    final GlobalKey<NavigatorState> key =
        navigatorKey ?? GlobalKey<NavigatorState>();
    return _NetworkStatusScope(
      child: _ZakatAppContent(
        navigatorKey: key,
        preferences: preferences,
        startupLanguage: startupLanguage ?? 'en',
      ),
    );
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

class _NetworkStatusScopeState extends State<_NetworkStatusScope>
    with WidgetsBindingObserver {
  NetworkStatusController? _controller;
  bool _usesExternalController = false;
  bool _ownsController = false;
  bool _startupProbeScheduled = false;
  Timer? _startupProbeTimer;
  Timer? _resumeProbeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool hasExternalController = _hasNetworkStatusController(context);
    if (hasExternalController == _usesExternalController) {
      return;
    }

    _usesExternalController = hasExternalController;
    if (_usesExternalController) {
      if (_ownsController) {
        _controller?.dispose();
      }
      _controller = context.read<NetworkStatusController>();
      _ownsController = false;
    } else if (!ZakatApp.isTesting && _controller == null) {
      _controller = NetworkStatusController();
      _ownsController = true;
      _scheduleStartupProbe(_controller!);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _startupProbeTimer?.cancel();
    _resumeProbeTimer?.cancel();
    if (_ownsController) {
      _controller?.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      final NetworkStatusController? controller = _controller;
      if (controller != null) {
        _resumeProbeTimer?.cancel();
        _resumeProbeTimer = Timer(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          unawaited(controller.refresh());
        });
      }
    }
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
    if (!_startupProbeScheduled) {
      _scheduleStartupProbe(controller);
    }
    return ChangeNotifierProvider<NetworkStatusController>.value(
      value: controller,
      child: widget.child,
    );
  }

  void _scheduleStartupProbe(NetworkStatusController controller) {
    if (_startupProbeScheduled || ZakatApp.isTesting) return;
    _startupProbeScheduled = true;
    _startupProbeTimer?.cancel();
    _startupProbeTimer = Timer(const Duration(milliseconds: 850), () {
      if (!mounted) return;
      unawaited(
        controller.start(initialDelay: const Duration(milliseconds: 0)),
      );
    });
  }
}

class _ZakatAppContent extends StatefulWidget {
  const _ZakatAppContent({
    required this.navigatorKey,
    required this.preferences,
    required this.startupLanguage,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final SharedPreferences preferences;
  final String startupLanguage;

  @override
  State<_ZakatAppContent> createState() => _ZakatAppContentState();
}

class _ZakatAppContentState extends State<_ZakatAppContent> {
  final AppLinks _appLinks = AppLinks();
  final ValueNotifier<bool> _navigationReadyNotifier = ValueNotifier<bool>(
    false,
  );
  final GlobalKey<_AppBootstrapperState> _bootstrapperKey =
      GlobalKey<_AppBootstrapperState>();
  String? _lastAppliedLanguage;
  String? _pendingLanguageRestartTarget;
  int _languageRestartGeneration = 0;
  bool _languageRestartScheduled = false;
  StreamSubscription<Uri>? _uriSubscription;
  String? _lastHandledLink;
  Uri? _pendingIncomingUri;
  Timer? _pendingIncomingUriTimer;
  late final PrivacyRouteObserver _privacyRouteObserver;

  @override
  void initState() {
    super.initState();
    _privacyRouteObserver = PrivacyRouteObserver((
      ScreenPrivacyClassification? privacy,
    ) {
      _bootstrapperKey.currentState?.setRoutePrivacyOverride(privacy);
    });
    unawaited(_handleInitialLink());
    _uriSubscription = _appLinks.uriLinkStream.listen(
      _handleIncomingUri,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('App link stream error: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  @override
  void dispose() {
    _pendingIncomingUriTimer?.cancel();
    _uriSubscription?.cancel();
    _navigationReadyNotifier.dispose();
    super.dispose();
  }

  Future<void> _handleInitialLink() async {
    try {
      final Uri? uri = await _appLinks.getInitialLink();
      if (uri != null) {
        LaunchDiagnostics.setLaunchSource(_launchSourceFromUri(uri));
        unawaited(
          LaunchDiagnostics.record(
            'initial_uri_received',
            metadata: <String, dynamic>{'uri': uri.toString()},
          ),
        );
        _handleIncomingUri(uri);
      }
    } catch (error, stackTrace) {
      debugPrint('Initial app link error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _handleIncomingUri(Uri uri) {
    final String serialized = uri.toString();
    if (serialized == _lastHandledLink) {
      return;
    }
    LaunchDiagnostics.setLaunchSource(_launchSourceFromUri(uri));
    unawaited(
      LaunchDiagnostics.record(
        'incoming_uri',
        metadata: <String, dynamic>{'uri': serialized},
      ),
    );
    _lastHandledLink = serialized;
    _pendingIncomingUri = uri;
    _schedulePendingIncomingUriDispatch();
  }

  void _schedulePendingIncomingUriDispatch() {
    _pendingIncomingUriTimer?.cancel();
    if (!mounted || _pendingIncomingUri == null) {
      return;
    }
    _pendingIncomingUriTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      final Uri pending = _pendingIncomingUri!;
      final AuthController authController = context.read<AuthController>();
      final AppStateController appStateController = context
          .read<AppStateController>();
      final bool requiresBiometricLock =
          authController.currentUser != null &&
          appStateController.state.biometricLockEnabled;
      if (!_navigationReadyNotifier.value ||
          (requiresBiometricLock &&
              !BiometricService.isSensitiveSessionUnlocked)) {
        _schedulePendingIncomingUriDispatch();
        return;
      }

      _pendingIncomingUri = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _navigateForUri(pending);
      });
    });
  }

  void _navigateForUri(Uri uri) {
    final NavigatorState? navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;

    final String host = uri.host.trim().toLowerCase();
    final String firstPath = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.first.trim().toLowerCase()
        : '';
    final String normalizedPath = uri.path.trim().toLowerCase();
    final String filter = (uri.queryParameters['filter'] ?? '')
        .trim()
        .toLowerCase();

    if (host == 'widget' ||
        firstPath == 'widget' ||
        normalizedPath.contains('/widget')) {
      navigator.popUntil((Route<dynamic> route) => route.isFirst);
      return;
    }

    if (host == 'smart-capture' ||
        firstPath == 'smart-capture' ||
        normalizedPath.contains('smart-capture')) {
      navigator.push(
        NotificationsScreen.route(
          initialStatus: CaptureInboxStatusFilter.pending,
        ),
      );
      return;
    }

    if (host == 'obligations' ||
        firstPath == 'obligations' ||
        normalizedPath.contains('obligations')) {
      navigator.push(
        MaterialPageRoute<void>(
          settings: const AppPrivacyRouteSettings(
            privacy: ScreenPrivacyClassification.sensitive,
          ),
          builder: (_) => ObligationsListScreen(
            filterMode: switch (filter) {
              'next_month' => 'next_month',
              'total' => 'total',
              _ => 'this_month',
            },
          ),
        ),
      );
      return;
    }

    if (host == 'dashboard' ||
        firstPath == 'dashboard' ||
        host == 'zakah-status' ||
        normalizedPath.contains('dashboard')) {
      navigator.popUntil((Route<dynamic> route) => route.isFirst);
    }
  }

  String _launchSourceFromUri(Uri uri) {
    final String host = uri.host.trim().toLowerCase();
    final String firstPath = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.first.trim().toLowerCase()
        : '';
    if (host != 'widget' && firstPath != 'widget') {
      return 'deep_link';
    }
    final String family =
        uri.queryParameters['family']?.trim().toLowerCase() ?? '';
    return switch (family) {
      'small' => 'widget_small',
      'medium' => 'widget_medium',
      'large' => 'widget_large',
      _ => 'widget_unknown',
    };
  }

  void _scheduleLanguageRestart(String preferredLanguage, bool canRestart) {
    if (_lastAppliedLanguage == null) {
      _lastAppliedLanguage = preferredLanguage;
      return;
    }
    if (_lastAppliedLanguage == preferredLanguage) {
      _pendingLanguageRestartTarget = null;
      return;
    }
    _pendingLanguageRestartTarget = preferredLanguage;
    if (!canRestart) return;
    if (_languageRestartScheduled) return;
    _languageRestartScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _languageRestartScheduled = false;
      if (!mounted) return;
      if (_pendingLanguageRestartTarget != preferredLanguage) return;
      setState(() {
        _lastAppliedLanguage = preferredLanguage;
        _pendingLanguageRestartTarget = null;
        _languageRestartGeneration += 1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppStateController appStateController = context
        .watch<AppStateController>();
    final String themeModeRaw = appStateController.state.themeMode;
    final bool hasPersistedLanguagePreference = widget.preferences.containsKey(
      'language_preference',
    );
    final String persistedLanguageCode =
        hasPersistedLanguagePreference &&
            widget.preferences
                    .getString('language_preference')
                    ?.trim()
                    .toLowerCase() ==
                'ar'
        ? 'ar'
        : 'en';
    final String preferredLanguage =
        appStateController.hydrationPhase != AppHydrationPhase.ready
            ? widget.startupLanguage
            : hasPersistedLanguagePreference
                ? persistedLanguageCode
                : appStateController.state.languagePreference == 'ar'
                    ? 'ar'
                    : 'en';
    _scheduleLanguageRestart(
      preferredLanguage,
      appStateController.hydrationPhase == AppHydrationPhase.ready,
    );
    final Locale locale = preferredLanguage == 'ar'
        ? const Locale('ar')
        : const Locale('en');
    final ThemeMode themeMode = switch (themeModeRaw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return MaterialApp(
      key: ValueKey<String>(
        'zakat-app-$preferredLanguage-$_languageRestartGeneration',
      ),
      navigatorKey: widget.navigatorKey,
      navigatorObservers: <NavigatorObserver>[_privacyRouteObserver],
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
        final double width = MediaQuery.sizeOf(context).width;
        final bool isSmallScreen = width < 430;
        final Widget builtChild = child ?? const SizedBox.shrink();

        final Widget responsiveChild = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(isSmallScreen ? 0.9 : 1.0),
          ),
          child: builtChild,
        );

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Stack(
            children: <Widget>[
              responsiveChild,
              const _OfflineStatusBannerOverlay(),
              Consumer<AppPrivacyOverlayController>(
                builder:
                    (
                      BuildContext context,
                      AppPrivacyOverlayController controller,
                      Widget? _,
                    ) {
                      if (!controller.visible) return const SizedBox.shrink();
                      return const Positioned.fill(
                        child: AbsorbPointer(
                          absorbing: true,
                          child: AuthPrivacyOverlay(
                            key: Key('appPrivacyOverlay'),
                          ),
                        ),
                      );
                    },
              ),
            ],
          ),
        );
      },
      home: _AppBootstrapper(
        key: _bootstrapperKey,
        preferences: widget.preferences,
        navigationReadyNotifier: _navigationReadyNotifier,
      ),
    );
  }
}

class _OfflineStatusBannerOverlay extends StatefulWidget {
  const _OfflineStatusBannerOverlay();

  @override
  State<_OfflineStatusBannerOverlay> createState() =>
      _OfflineStatusBannerOverlayState();
}

class _OfflineStatusBannerOverlayState
    extends State<_OfflineStatusBannerOverlay> {
  bool _dismissedWhileOffline = false;
  bool _lastOffline = false;

  @override
  Widget build(BuildContext context) {
    final bool hasController = _hasNetworkStatusController(context);
    if (!hasController) return const SizedBox.shrink();

    final bool isOffline = context.watch<NetworkStatusController>().isOffline;
    if (_lastOffline && !isOffline && _dismissedWhileOffline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _dismissedWhileOffline = false;
          });
        }
      });
    }
    _lastOffline = isOffline;

    if (!isOffline) return const SizedBox.shrink();
    if (_dismissedWhileOffline) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final Color surface = theme.colorScheme.surface;
    final Color onSurface = theme.colorScheme.onSurface;
    final Color accent = theme.colorScheme.tertiary;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: Dismissible(
            key: const ValueKey<String>('offline-status-banner'),
            direction: DismissDirection.horizontal,
            onDismissed: (_) {
              setState(() {
                _dismissedWhileOffline = true;
              });
            },
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
  const _AppBootstrapper({
    super.key,
    required this.preferences,
    required this.navigationReadyNotifier,
  });

  final SharedPreferences preferences;
  final ValueNotifier<bool> navigationReadyNotifier;

  @override
  State<_AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<_AppBootstrapper>
    with WidgetsBindingObserver {
  _BootstrapPhase _phase = _BootstrapPhase.authLoading;
  int _shellIndex = 2;
  StartupRestoreDiscoveryResult? _restoreGateDiscovery;
  bool _accountVerified = false;
  bool _checkingCloudBackup = false;
  bool _loadingEntries = false;
  bool _loadingAssets = false;
  bool _loadingMarketData = false;
  bool _loadingPlans = false;
  String? _loadingMessage;
  BootstrapCoordinator? _bootstrapCoordinator;
  AppLifecycleState _lastLifecycleState = AppLifecycleState.resumed;
  bool _privacyOverlayArmed = false;
  bool _privacyArmScheduled = false;
  ScreenPrivacyClassification _baseVisibleScreenPrivacy =
      ScreenPrivacyClassification.nonSensitive;
  ScreenPrivacyClassification? _routePrivacyOverride;

  ScreenPrivacyClassification get _visibleScreenPrivacy =>
      _routePrivacyOverride ?? _baseVisibleScreenPrivacy;

  T? _maybeRead<T>() {
    try {
      return context.read<T>();
    } catch (_) {
      return null;
    }
  }

  void _setNavigationReady(bool ready) {
    widget.navigationReadyNotifier.value = ready;
  }

  AppPrivacyOverlayController? _privacyOverlayController() {
    try {
      return context.read<AppPrivacyOverlayController>();
    } catch (_) {
      return null;
    }
  }

  bool _shouldShowPrivacyOverlay() {
    final coordinator = _bootstrapCoordinator;
    if (coordinator == null) {
      return false;
    }
    if (!_privacyOverlayArmed) {
      return false;
    }
    if (_visibleScreenPrivacy != ScreenPrivacyClassification.sensitive) {
      return false;
    }
    if (coordinator.phase != BootstrapPhase.ready) {
      return false;
    }
    if (coordinator.biometricPromptInProgress) {
      return false;
    }
    return _lastLifecycleState != AppLifecycleState.resumed;
  }

  void _refreshPrivacyOverlay() {
    final AppPrivacyOverlayController? controller = _privacyOverlayController();
    if (controller == null) return;
    final bool visible = _shouldShowPrivacyOverlay();
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _privacyOverlayController()?.setVisible(_shouldShowPrivacyOverlay());
      });
      return;
    }
    controller.setVisible(visible);
  }

  void _resetPrivacyOverlayArming() {
    _privacyOverlayArmed = false;
    _privacyArmScheduled = false;
  }

  void _setBaseVisibleScreenPrivacy(ScreenPrivacyClassification privacy) {
    if (_baseVisibleScreenPrivacy == privacy) return;
    _baseVisibleScreenPrivacy = privacy;
    _refreshPrivacyOverlay();
    _tryArmPrivacyOverlay();
  }

  void setRoutePrivacyOverride(ScreenPrivacyClassification? privacy) {
    if (_routePrivacyOverride == privacy) return;
    _routePrivacyOverride = privacy;
    _refreshPrivacyOverlay();
    _tryArmPrivacyOverlay();
  }

  void _tryArmPrivacyOverlay() {
    final BootstrapCoordinator? coordinator = _bootstrapCoordinator;
    if (_privacyOverlayArmed ||
        _privacyArmScheduled ||
        coordinator == null ||
        coordinator.phase != BootstrapPhase.ready ||
        coordinator.biometricPromptInProgress ||
        _lastLifecycleState != AppLifecycleState.resumed ||
        _visibleScreenPrivacy != ScreenPrivacyClassification.sensitive) {
      return;
    }
    _privacyArmScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _privacyArmScheduled = false;
      if (!mounted) return;
      final BootstrapCoordinator? currentCoordinator = _bootstrapCoordinator;
      if (currentCoordinator?.phase == BootstrapPhase.ready &&
          !(currentCoordinator?.biometricPromptInProgress ?? true) &&
          _lastLifecycleState == AppLifecycleState.resumed &&
          _visibleScreenPrivacy == ScreenPrivacyClassification.sensitive) {
        _privacyOverlayArmed = true;
        _refreshPrivacyOverlay();
      }
    });
  }

  BootstrapCoordinator? _listenedCoordinator;

  void _attachBootstrapCoordinator(BootstrapCoordinator? coordinator) {
    if (identical(_listenedCoordinator, coordinator)) {
      return;
    }
    _listenedCoordinator?.removeListener(_handleCoordinatorChanged);
    _listenedCoordinator = coordinator;
    _listenedCoordinator?.addListener(_handleCoordinatorChanged);
    _bootstrapCoordinator = coordinator;
    _syncFromBootstrapCoordinator();
    _refreshPrivacyOverlay();
  }

  void _handleCoordinatorChanged() {
    _syncFromBootstrapCoordinator();
    _refreshPrivacyOverlay();
  }

  void _syncFromBootstrapCoordinator() {
    if (!mounted) return;
    final BootstrapCoordinator? coordinator = _bootstrapCoordinator;
    if (coordinator == null) return;
    if (coordinator.phase != BootstrapPhase.ready) {
      _resetPrivacyOverlayArming();
      _refreshPrivacyOverlay();
    }
    setState(() {
      _phase = switch (coordinator.phase) {
        BootstrapPhase.authLoading => _BootstrapPhase.authLoading,
        BootstrapPhase.signedOut => _BootstrapPhase.signedOut,
        BootstrapPhase.emailVerification => _BootstrapPhase.emailVerification,
        BootstrapPhase.loading => _BootstrapPhase.loading,
        BootstrapPhase.restoreGate => _BootstrapPhase.restoreGate,
        BootstrapPhase.locked => _BootstrapPhase.locked,
        BootstrapPhase.ready => _BootstrapPhase.ready,
        BootstrapPhase.failed => _BootstrapPhase.signedOut,
        BootstrapPhase.idle => _BootstrapPhase.authLoading,
      };
      _restoreGateDiscovery = coordinator.restoreGateDiscovery;
      _loadingMessage = coordinator.loadingMessage;
      _accountVerified =
          coordinator.phase != BootstrapPhase.signedOut &&
          coordinator.phase != BootstrapPhase.emailVerification &&
          coordinator.phase != BootstrapPhase.idle;
      _checkingCloudBackup =
          coordinator.phase == BootstrapPhase.loading ||
          coordinator.phase == BootstrapPhase.restoreGate;
      _loadingEntries =
          coordinator.phase == BootstrapPhase.authLoading ||
          coordinator.phase == BootstrapPhase.loading;
      _loadingAssets = coordinator.phase == BootstrapPhase.loading;
      _loadingMarketData = coordinator.phase == BootstrapPhase.loading;
      _loadingPlans = coordinator.phase == BootstrapPhase.loading;
    });
    _setNavigationReady(coordinator.phase == BootstrapPhase.ready);
    if (coordinator.phase == BootstrapPhase.ready) {
      _tryArmPrivacyOverlay();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _baseVisibleScreenPrivacy = _privacyForTab(_shellIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final BootstrapCoordinator? coordinator =
          _maybeRead<BootstrapCoordinator>();
      if (coordinator != null) {
        unawaited(coordinator.start());
      }
    });
  }

  AppPrivacyOverlayController? _listenedPrivacyController;

  void _attachPrivacyController(AppPrivacyOverlayController? controller) {
    if (identical(_listenedPrivacyController, controller)) {
      return;
    }
    _listenedPrivacyController?.removeListener(_refreshPrivacyOverlay);
    _listenedPrivacyController = controller;
    _listenedPrivacyController?.addListener(_refreshPrivacyOverlay);
    _refreshPrivacyOverlay();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final BootstrapCoordinator? nextBootstrapCoordinator =
        _maybeRead<BootstrapCoordinator>();
    _attachBootstrapCoordinator(nextBootstrapCoordinator);
    final AppPrivacyOverlayController? nextPrivacyController =
        _maybeRead<AppPrivacyOverlayController>();
    _attachPrivacyController(nextPrivacyController);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _listenedCoordinator?.removeListener(_handleCoordinatorChanged);
    _listenedPrivacyController?.removeListener(_refreshPrivacyOverlay);
    super.dispose();
  }

  Future<void> _restoreBackup() async {
    final BootstrapCoordinator? coordinator = _bootstrapCoordinator;
    if (coordinator != null) {
      await coordinator.restoreBackup();
    }
  }

  Future<void> _startFresh() async {
    final BootstrapCoordinator? coordinator = _bootstrapCoordinator;
    if (coordinator != null) {
      await coordinator.startFresh();
    }
  }

  Future<void> _openBackupSync() async {
    final BootstrapCoordinator? coordinator = _bootstrapCoordinator;
    if (coordinator != null) {
      await coordinator.openBackupSync();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _lastLifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      _privacyOverlayController()?.setVisible(false);
    }
    final BootstrapCoordinator? coordinator = _bootstrapCoordinator;
    if (coordinator != null) {
      unawaited(coordinator.handleLifecycleState(state));
    }
    if (state == AppLifecycleState.resumed) {
      _tryArmPrivacyOverlay();
    } else {
      _refreshPrivacyOverlay();
    }
  }

  Future<void> _handleUnlock() async {
    final BootstrapCoordinator? coordinator = _bootstrapCoordinator;
    if (coordinator != null) {
      await coordinator.handleUnlock();
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
          final BootstrapCoordinator? coordinator =
              _maybeRead<BootstrapCoordinator>();
          if (coordinator != null) {
            await coordinator.start(retry: true);
          }
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
      _BootstrapPhase.restoreGate =>
        RestoreGateScreen(
          cloudBackupController: _maybeRead<CloudBackupController>(),
          discovery:
              _restoreGateDiscovery ??
              StartupRestoreDiscoveryResult(
                status: StartupRestoreDiscoveryStatus.none,
                message: context.l10n.tr('no_cloud_backup_found'),
              ),
          onRestore: _restoreBackup,
          onStartFresh: _startFresh,
          onOpenBackupSync: _openBackupSync,
        ),
      _BootstrapPhase.locked => SecurityLockScreen(
        onUnlock: _handleUnlock,
        autoPrompt: _bootstrapCoordinator?.lockScreenAutoPrompt ?? false,
      ),

      _BootstrapPhase.ready => OnboardingGate(
        preferences: widget.preferences,
        skipInTests: ZakatApp.isTesting,
        child: AppShell(
          initialIndex: _shellIndex,
          onIndexChanged: (int index) {
            _shellIndex = index;
            _setBaseVisibleScreenPrivacy(_privacyForTab(index));
          },
        ),
      ),
    };

    return body;
  }

  ScreenPrivacyClassification _privacyForTab(int index) {
    if (index >= 0 && index <= 3) {
      return ScreenPrivacyClassification.sensitive;
    }
    return ScreenPrivacyClassification.nonSensitive;
  }
}

class AppPrivacyOverlayController extends ChangeNotifier {
  bool _visible = false;
  int _sensitiveCount = 0;

  bool get visible => _visible;
  bool get sensitiveContentVisible => _sensitiveCount > 0;

  void setVisible(bool visible) {
    if (_visible == visible) return;
    _visible = visible;
    notifyListeners();
  }

  void incrementSensitiveCount() {
    _sensitiveCount++;
    notifyListeners();
  }

  void decrementSensitiveCount() {
    if (_sensitiveCount > 0) {
      _sensitiveCount--;
    }
    notifyListeners();
  }

  void forceOff() {
    _sensitiveCount = 0;
    _visible = false;
    notifyListeners();
  }
}
