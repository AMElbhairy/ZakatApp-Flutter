import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/i18n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'repositories/app_state_repository.dart';
import 'services/app_state_controller.dart';
import 'services/auth_controller.dart';
import 'services/auth_service.dart';
import 'services/apple_shortcuts_service.dart';
import 'services/cloud_backup_controller.dart';
import 'services/google_drive_service.dart';
import 'services/google_sheets_service.dart';
import 'services/sync_controller.dart';
import 'services/local_storage_service.dart';
import 'screens/account/app_initialization_screen.dart';
import 'screens/account/security_lock_screen.dart';
import 'features/auth/auth_gate.dart';

void main() {
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository = AppStateRepository(
    localStorage: localStorage,
  );
  runApp(
    MultiProvider(
      providers: [
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
      title: 'ZakatApp',
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
          child: child,
        );
      },
      home: const _AppBootstrapper(),
    );
  }
}

class _AppBootstrapper extends StatefulWidget {
  const _AppBootstrapper();

  @override
  State<_AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<_AppBootstrapper>
    with WidgetsBindingObserver {
  String _phase = 'initializing'; // initializing -> locked -> ready
  DateTime? _pausedTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final appState = context.read<AppStateController>().state;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_pausedTime == null && _phase == 'ready') {
        _pausedTime = DateTime.now();
      }
    } else if (state == AppLifecycleState.resumed) {
      unawaited(context.read<AppStateController>().load());
      if (_pausedTime != null &&
          appState.biometricLockEnabled &&
          _phase == 'ready') {
        final secondsPaused = DateTime.now().difference(_pausedTime!).inSeconds;
        final delaySeconds = switch (appState.biometricAutoLockDelay) {
          'immediate' => 0,
          '30_seconds' => 30,
          '5_minutes' => 300,
          _ => 60, // 1_minute default
        };

        if (secondsPaused >= delaySeconds) {
          setState(() {
            _phase = 'locked';
          });
        }
      }
      _pausedTime = null;
    }
  }

  void _onInitializationComplete() {
    final appStateController = context.read<AppStateController>();
    final authController = context.read<AuthController>();
    AppleShortcutsService.initialize(appStateController);
    setState(() {
      _phase =
          authController.isSignedIn &&
              appStateController.state.biometricLockEnabled
          ? 'locked'
          : 'ready';
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      'initializing' => AppInitializationScreen(
        onComplete: _onInitializationComplete,
      ),
      'locked' => SecurityLockScreen(
        onUnlock: () {
          setState(() {
            _phase = 'ready';
          });
        },
      ),
      _ => const AuthGate(),
    };
  }
}
