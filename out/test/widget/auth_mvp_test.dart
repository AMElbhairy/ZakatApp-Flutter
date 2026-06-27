import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/main.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/user_profile.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/auth_controller.dart';
import 'package:zakatapp_flutter/services/backup_key_manager.dart';
import 'package:zakatapp_flutter/services/auth_service.dart';
import 'package:zakatapp_flutter/models/backup_preview.dart';
import 'package:zakatapp_flutter/services/cloud_backup_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/network_status_controller.dart';
import 'package:zakatapp_flutter/services/market_data_api_service.dart';
import 'package:zakatapp_flutter/services/secure_storage_service.dart';
import 'package:zakatapp_flutter/services/startup_restore_discovery.dart';

Future<void> _seedNonEmptyLocalState() async {
  final AppStateRepository repository = AppStateRepository(
    localStorage: const LocalStorageService(),
  );
  final Map<String, dynamic> json = AppStateDefaults.create().toJson();
  json['transactions'] = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'seed-transaction',
      'type': 'income',
      'date': '2026-06-23',
      'amount': 1,
      'currency': 'EGP',
      'category': 'Other Income',
      'description': 'Seed data',
      'createdAt': '2026-06-23T00:00:00Z',
      'rolledOver': false,
    },
  ];
  await repository.saveAppState(AppStateModel.fromJson(json), userId: 'u_1');
}

class _FakeAuthService implements AuthService, AuthGateStateSource {
  _FakeAuthService({this._user});

  final StreamController<AuthGateState> _authStateController =
      StreamController<AuthGateState>.broadcast();

  @override
  Future<bool> ensureSession() async => true;

  UserProfile? _user;

  void emitGateError(String message) {
    _authStateController.add(
      AuthGateState(status: AuthGateStatus.error, message: message),
    );
  }

  @override
  Stream<AuthGateState> get authGateStateChanges => _authStateController.stream;

  @override
  Future<UserProfile?> signIn({
    AuthProvider provider = AuthProvider.google,
  }) async {
    _user = const UserProfile(
      id: 'u_1',
      email: 'user@example.com',
      displayName: 'User One',
      provider: 'google',
      photoUrl: null,
      accessToken: 'token',
    );
    _authStateController.add(
      AuthGateState(status: AuthGateStatus.signedIn, user: _user),
    );
    return _user;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _authStateController.add(
      const AuthGateState(status: AuthGateStatus.signedOut),
    );
  }

  @override
  Future<void> deleteAccount() async {
    _user = null;
    _authStateController.add(
      const AuthGateState(status: AuthGateStatus.signedOut),
    );
  }

  @override
  Future<UserProfile?> restoreSession() async => _user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemorySecureStorageService extends SecureStorageService {
  _MemorySecureStorageService();

  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> loadBackupKey({String? userId}) async {
    return _values['backupKey:${userId ?? 'default'}'];
  }

  @override
  Future<void> saveBackupKey(String keyValue, {String? userId}) async {
    _values['backupKey:${userId ?? 'default'}'] = keyValue;
  }

  @override
  Future<String?> loadBackupPassphrase({String? userId}) async {
    return _values['backupPassphrase:${userId ?? 'default'}'];
  }

  @override
  Future<void> saveBackupPassphrase(String passphrase, {String? userId}) async {
    _values['backupPassphrase:${userId ?? 'default'}'] = passphrase;
  }

  @override
  Future<void> deleteBackupKey({String? userId}) async {
    _values.remove('backupKey:${userId ?? 'default'}');
  }
}

class _FakeMarketDataApiService implements MarketDataApiService {
  @override
  Future<Map<String, double>?> fetchFxRatesToEgp() async {
    return <String, double>{'USD': 50.0, 'SAR': 13.0, 'EGP': 1.0};
  }

  @override
  Future<double?> fetchGold24kPerGramEgp({required double usdToEgp}) async {
    return 3700.0;
  }

  @override
  Future<double?> fetchSilverPerGramEgp({required double usdToEgp}) async {
    return 40.0;
  }
}

class _DelayedMarketDataApiService implements MarketDataApiService {
  final Completer<void> _fxGate = Completer<void>();

  void releaseFx() {
    if (!_fxGate.isCompleted) {
      _fxGate.complete();
    }
  }

  @override
  Future<Map<String, double>?> fetchFxRatesToEgp() async {
    await _fxGate.future;
    return <String, double>{'USD': 50.0, 'SAR': 13.0, 'EGP': 1.0};
  }

  @override
  Future<double?> fetchGold24kPerGramEgp({required double usdToEgp}) async {
    return 3700.0;
  }

  @override
  Future<double?> fetchSilverPerGramEgp({required double usdToEgp}) async {
    return 40.0;
  }
}

class _ThrowingMarketDataApiService implements MarketDataApiService {
  @override
  Future<Map<String, double>?> fetchFxRatesToEgp() async {
    throw StateError('network unavailable');
  }

  @override
  Future<double?> fetchGold24kPerGramEgp({required double usdToEgp}) async {
    throw StateError('network unavailable');
  }

  @override
  Future<double?> fetchSilverPerGramEgp({required double usdToEgp}) async {
    throw StateError('network unavailable');
  }
}

class _DelayedCloudBackupController extends CloudBackupController {
  _DelayedCloudBackupController({
    required super.appStateController,
    required super.authController,
    required super.backupKeyManager,
  });

  final Completer<void> _refreshGate = Completer<void>();
  bool refreshCalled = false;

  void releaseRefresh() {
    if (!_refreshGate.isCompleted) {
      _refreshGate.complete();
    }
  }

  @override
  Future<void> refreshCloudState({bool evaluatePrompt = true}) async {
    refreshCalled = true;
    await _refreshGate.future;
  }

  @override
  Future<StartupRestoreDiscoveryResult> discoverStartupRestore({
    required bool localHasData,
  }) async {
    return const StartupRestoreDiscoveryResult(
      status: StartupRestoreDiscoveryStatus.none,
      message: 'No cloud backup found',
    );
  }
}

class _StartupRestoreCloudBackupController extends CloudBackupController {
  _StartupRestoreCloudBackupController({
    required super.appStateController,
    required super.authController,
    required super.backupKeyManager,
    this.discoveryStatus = StartupRestoreDiscoveryStatus.restorePrompt,
    this.discoveryMessage = 'Cloud backup found. Restore your latest backup?',
    this.restoreSucceeds = true,
  }) : super(debounceDuration: const Duration(milliseconds: 20));

  final StartupRestoreDiscoveryStatus discoveryStatus;
  final String discoveryMessage;
  final bool restoreSucceeds;

  int restoreCalls = 0;
  int openBackupSyncCalls = 0;
  int startupDiscoveryCalls = 0;

  @override
  Future<void> refreshCloudState({bool evaluatePrompt = true}) async {}

  @override
  Future<StartupRestoreDiscoveryResult> discoverStartupRestore({
    required bool localHasData,
  }) async {
    startupDiscoveryCalls += 1;
    if (discoveryStatus == StartupRestoreDiscoveryStatus.restorePrompt) {
      return StartupRestoreDiscoveryResult(
        status: discoveryStatus,
        message: discoveryMessage,
        preview: const BackupPreview(
          exportedAt: '2026-06-23T00:00:00Z',
          schemaOrVersion: 'schemaVersion=3',
          isLegacy: false,
          sourceType: 'flutter',
          transactionsCount: 1,
          savingsCount: 0,
          investmentsCount: 0,
          recurringTransactionsCount: 0,
          financialPlansCount: 0,
          hasMarketData: false,
          warnings: <String>[],
          unsupportedFields: <String>[],
          canRestore: true,
          rawJson: '{}',
          backupVersion: 3,
          backupUserId: 'u_1',
          backupProvider: 'google_drive',
          backupEmail: 'user@example.com',
        ),
      );
    }
    return StartupRestoreDiscoveryResult(
      status: discoveryStatus,
      message: discoveryMessage,
      error: discoveryMessage,
    );
  }

  @override
  Future<BackupPreview?> previewLatestBackup() async {
    if (discoveryStatus != StartupRestoreDiscoveryStatus.restorePrompt) {
      return null;
    }
    return const BackupPreview(
      exportedAt: '2026-06-23T00:00:00Z',
      schemaOrVersion: 'schemaVersion=3',
      isLegacy: false,
      sourceType: 'flutter',
      transactionsCount: 1,
      savingsCount: 0,
      investmentsCount: 0,
      recurringTransactionsCount: 0,
      financialPlansCount: 0,
      hasMarketData: false,
      warnings: <String>[],
      unsupportedFields: <String>[],
      canRestore: true,
      rawJson: '{}',
      backupVersion: 3,
      backupUserId: 'u_1',
      backupProvider: 'google_drive',
      backupEmail: 'user@example.com',
    );
  }

  @override
  Future<bool> restoreLatestBackup({bool allowOverwrite = true}) async {
    restoreCalls += 1;
    return restoreSucceeds;
  }

  @override
  String get statusMessage =>
      restoreSucceeds ? super.statusMessage : 'Restore failed';

  @override
  String get lastBackupStatus =>
      restoreSucceeds ? super.lastBackupStatus : 'Restore failed';

  @override
  String get lastBackupError =>
      restoreSucceeds ? super.lastBackupError : 'Restore failed';

  @override
  Future<void> completeStartupRestoreDiscovery() async {}
}

class _FailingStartupRestoreCloudBackupController
    extends _StartupRestoreCloudBackupController {
  _FailingStartupRestoreCloudBackupController({
    required super.appStateController,
    required super.authController,
    required super.backupKeyManager,
  }) : super(restoreSucceeds: false);

  @override
  Future<bool> restoreLatestBackup({bool allowOverwrite = true}) async {
    restoreCalls += 1;
    return false;
  }
}

class _IdleCloudBackupController extends CloudBackupController {
  _IdleCloudBackupController({
    required super.appStateController,
    required super.authController,
    required super.backupKeyManager,
  }) : super(debounceDuration: const Duration(milliseconds: 20));

  @override
  Future<void> refreshCloudState({bool evaluatePrompt = true}) async {}

  @override
  Future<StartupRestoreDiscoveryResult> discoverStartupRestore({
    required bool localHasData,
  }) async {
    return const StartupRestoreDiscoveryResult(
      status: StartupRestoreDiscoveryStatus.none,
      message: 'No cloud backup found',
    );
  }
}

class _FakeNetworkStatusController extends NetworkStatusController {
  _FakeNetworkStatusController([this._offline = false]);

  bool _offline;

  set offline(bool value) {
    if (_offline == value) return;
    _offline = value;
    notifyListeners();
  }

  @override
  bool get isOffline => _offline;

  @override
  bool get isChecking => false;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> start() async {}
}

class _TestAppStateController extends AppStateController {
  _TestAppStateController({
    required super.repository,
    required super.marketDataApiService,
    required super.enableBackgroundSync,
    required super.enableMarketAutoRefresh,
  });

  @override
  Future<void> startMarketAutoRefresh({bool refreshImmediately = true}) async {
    if (refreshImmediately) {
      await refreshMarketData(force: true);
    }
  }
}

Widget _buildApp({
  AuthService? authService,
  MarketDataApiService? marketDataApiService,
  BackupKeyManager? backupKeyManager,
  CloudBackupController? cloudBackupController,
  CloudBackupController Function(
    AppStateController appStateController,
    AuthController authController,
    BackupKeyManager backupKeyManager,
  )?
  cloudBackupControllerBuilder,
  NetworkStatusController? networkStatusController,
  bool enableBackgroundSync = true,
  bool enableMarketAutoRefresh = true,
}) {
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository = AppStateRepository(
    localStorage: localStorage,
  );
  final BackupKeyManager resolvedBackupKeyManager =
      backupKeyManager ??
      BackupKeyManager(
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'u_1', email: 'user@example.com'),
        ),
        firestore: FakeFirebaseFirestore(),
        secureStorageService: _MemorySecureStorageService(),
      );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppPrivacyOverlayController>(
        create: (_) => AppPrivacyOverlayController(),
      ),
      ChangeNotifierProvider<AppStateController>(
        create: (_) => _TestAppStateController(
          repository: repository,
          marketDataApiService:
              marketDataApiService ?? _FakeMarketDataApiService(),
          enableBackgroundSync: enableBackgroundSync,
          enableMarketAutoRefresh: enableMarketAutoRefresh,
        ),
      ),
      ChangeNotifierProvider<AuthController>(
        create: (_) => AuthController(
          authService: authService ?? _FakeAuthService(),
          localStorage: localStorage,
        ),
      ),
      if (cloudBackupController != null)
        ChangeNotifierProvider<CloudBackupController>.value(
          value: cloudBackupController,
        )
      else if (cloudBackupControllerBuilder != null)
        ChangeNotifierProvider<CloudBackupController>(
          create: (BuildContext ctx) => cloudBackupControllerBuilder(
            ctx.read<AppStateController>(),
            ctx.read<AuthController>(),
            resolvedBackupKeyManager,
          ),
        )
      else
        ChangeNotifierProvider<CloudBackupController>(
          create: (BuildContext ctx) => _IdleCloudBackupController(
            appStateController: ctx.read<AppStateController>(),
            authController: ctx.read<AuthController>(),
            backupKeyManager: resolvedBackupKeyManager,
          ),
        ),
      if (networkStatusController != null)
        ChangeNotifierProvider<NetworkStatusController>.value(
          value: networkStatusController,
        ),
    ],
    child: const ZakatApp(),
  );
}

void main() {
  testWidgets('signed-out state renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('googleSignInButton')), findsOneWidget);
    expect(find.byKey(const Key('appleSignInButton')), findsNothing);
    expect(find.byKey(const Key('emailField')), findsNothing);
    expect(find.byKey(const Key('passwordField')), findsNothing);
    expect(find.byKey(const Key('emailAuthButton')), findsNothing);
    expect(find.byKey(const Key('premiumBottomNav')), findsNothing);
  });

  testWidgets('cached session loads app offline', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final UserProfile cachedUser = const UserProfile(
      id: 'u_1',
      email: 'user@example.com',
      displayName: 'User One',
      provider: 'google',
      accessToken: 'token',
    );

    await tester.pumpWidget(
      _buildApp(
        authService: _FakeAuthService(user: cachedUser),
        networkStatusController: _FakeNetworkStatusController(true),
        enableBackgroundSync: false,
        enableMarketAutoRefresh: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Working offline'), findsOneWidget);
    expect(find.byKey(const Key('googleSignInButton')), findsNothing);
  });

  testWidgets('fresh empty install auto-restores the newest cloud backup', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final UserProfile cachedUser = const UserProfile(
      id: 'u_1',
      email: 'user@example.com',
      displayName: 'User One',
      provider: 'google',
      accessToken: 'token',
    );
    late _StartupRestoreCloudBackupController cloudController;

    await tester.pumpWidget(
      _buildApp(
        authService: _FakeAuthService(user: cachedUser),
        cloudBackupControllerBuilder:
            (
              AppStateController appStateController,
              AuthController authController,
              BackupKeyManager backupKeyManager,
            ) {
              cloudController = _StartupRestoreCloudBackupController(
                appStateController: appStateController,
                authController: authController,
                backupKeyManager: backupKeyManager,
              );
              return cloudController;
            },
        enableBackgroundSync: false,
        enableMarketAutoRefresh: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(cloudController.startupDiscoveryCalls, equals(1));
    expect(cloudController.restoreCalls, equals(1));
    expect(find.byKey(const Key('premiumBottomNav')), findsOneWidget);
    expect(find.text('Restore Backup'), findsNothing);
  });

  testWidgets(
    'non-empty local database does not auto-restore newer cloud backup',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await _seedNonEmptyLocalState();
      final UserProfile cachedUser = const UserProfile(
        id: 'u_1',
        email: 'user@example.com',
        displayName: 'User One',
        provider: 'google',
        accessToken: 'token',
      );
      late _StartupRestoreCloudBackupController cloudController;

      await tester.pumpWidget(
        _buildApp(
          authService: _FakeAuthService(user: cachedUser),
          cloudBackupControllerBuilder:
              (
                AppStateController appStateController,
                AuthController authController,
                BackupKeyManager backupKeyManager,
              ) {
                cloudController = _StartupRestoreCloudBackupController(
                  appStateController: appStateController,
                  authController: authController,
                  backupKeyManager: backupKeyManager,
                );
                return cloudController;
              },
          enableBackgroundSync: false,
          enableMarketAutoRefresh: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(cloudController.startupDiscoveryCalls, equals(0));
      expect(cloudController.restoreCalls, equals(0));
      expect(find.byKey(const Key('premiumBottomNav')), findsOneWidget);
      expect(find.text('Restore Backup'), findsNothing);
    },
  );

  testWidgets(
    'fresh local install with missing Drive permission offers Backup & Sync',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final UserProfile cachedUser = const UserProfile(
        id: 'u_1',
        email: 'user@example.com',
        displayName: 'User One',
        provider: 'google',
        accessToken: 'token',
      );
      late _StartupRestoreCloudBackupController cloudController;

      await tester.pumpWidget(
        _buildApp(
          authService: _FakeAuthService(user: cachedUser),
          cloudBackupControllerBuilder:
              (
                AppStateController appStateController,
                AuthController authController,
                BackupKeyManager backupKeyManager,
              ) {
                cloudController = _StartupRestoreCloudBackupController(
                  appStateController: appStateController,
                  authController: authController,
                  backupKeyManager: backupKeyManager,
                  discoveryStatus:
                      StartupRestoreDiscoveryStatus.drivePermissionRequired,
                  discoveryMessage:
                      'A backup may exist. Connect Google Drive to check.',
                );
                return cloudController;
              },
          enableBackgroundSync: false,
          enableMarketAutoRefresh: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A backup may exist'), findsOneWidget);
      expect(find.text('Open Backup & Sync'), findsOneWidget);

      await tester.tap(find.text('Open Backup & Sync'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('premiumBottomNav')), findsOneWidget);
    },
  );

  testWidgets(
    'fresh local install with missing backup key shows recovery error',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final UserProfile cachedUser = const UserProfile(
        id: 'u_1',
        email: 'user@example.com',
        displayName: 'User One',
        provider: 'google',
        accessToken: 'token',
      );

      await tester.pumpWidget(
        _buildApp(
          authService: _FakeAuthService(user: cachedUser),
          cloudBackupControllerBuilder:
              (
                AppStateController appStateController,
                AuthController authController,
                BackupKeyManager backupKeyManager,
              ) {
                return _StartupRestoreCloudBackupController(
                  appStateController: appStateController,
                  authController: authController,
                  backupKeyManager: backupKeyManager,
                  discoveryStatus:
                      StartupRestoreDiscoveryStatus.keyRecoveryRequired,
                  discoveryMessage:
                      BackupKeyRecoveryException.recoveryUnavailableMessage,
                );
              },
          enableBackgroundSync: false,
          enableMarketAutoRefresh: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Backup key recovery required'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);
    },
  );

  testWidgets(
    'auto-restore failure leaves empty database intact and shows error',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final UserProfile cachedUser = const UserProfile(
        id: 'u_1',
        email: 'user@example.com',
        displayName: 'User One',
        provider: 'google',
        accessToken: 'token',
      );
      late _StartupRestoreCloudBackupController cloudController;

      await tester.pumpWidget(
        _buildApp(
          authService: _FakeAuthService(user: cachedUser),
          cloudBackupControllerBuilder:
              (
                AppStateController appStateController,
                AuthController authController,
                BackupKeyManager backupKeyManager,
              ) {
                cloudController = _FailingStartupRestoreCloudBackupController(
                  appStateController: appStateController,
                  authController: authController,
                  backupKeyManager: backupKeyManager,
                );
                return cloudController;
              },
          enableBackgroundSync: false,
          enableMarketAutoRefresh: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(cloudController.startupDiscoveryCalls, equals(1));
      expect(cloudController.restoreCalls, equals(1));
      expect(find.byKey(const Key('premiumBottomNav')), findsNothing);
      expect(find.textContaining('Restore failed'), findsOneWidget);
    },
  );

  testWidgets(
    'late auth stream errors do not force login when a cached session exists',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final _FakeAuthService authService = _FakeAuthService(
        user: const UserProfile(
          id: 'u_1',
          email: 'user@example.com',
          displayName: 'User One',
          provider: 'google',
          accessToken: 'token',
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          authService: authService,
          enableBackgroundSync: false,
          enableMarketAutoRefresh: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('premiumBottomNav')), findsOneWidget);

      authService.emitGateError('network unavailable');
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('googleSignInButton')), findsNothing);
    },
  );

  testWidgets(
    'market data failures do not force login when a cached session exists',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final _FakeAuthService authService = _FakeAuthService(
        user: const UserProfile(
          id: 'u_1',
          email: 'user@example.com',
          displayName: 'User One',
          provider: 'google',
          accessToken: 'token',
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          authService: authService,
          marketDataApiService: _ThrowingMarketDataApiService(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('googleSignInButton')), findsNothing);
    },
  );

  testWidgets('fake sign-in updates UI', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp(authService: _FakeAuthService()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('googleSignInButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('googleSignInButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('premiumBottomNav')), findsOneWidget);
  });

  testWidgets('fake sign-out clears UI', skip: true, (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp(authService: _FakeAuthService()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('googleSignInButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('googleSignInButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Account').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('googleSignOutButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('googleSignInButton')), findsOneWidget);
    expect(find.byKey(const Key('premiumBottomNav')), findsNothing);
  });

  testWidgets(
    'sign in waits for market refresh before showing dashboard',
    skip: true,
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final _DelayedMarketDataApiService marketService =
          _DelayedMarketDataApiService();

      await tester.pumpWidget(
        _buildApp(
          authService: _FakeAuthService(),
          marketDataApiService: marketService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('googleSignInButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('googleSignInButton')));
      await tester.pump();

      expect(find.byKey(const Key('loadingMarketDataStep')), findsOneWidget);
      expect(find.byKey(const Key('premiumBottomNav')), findsNothing);

      marketService.releaseFx();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('premiumBottomNav')), findsOneWidget);
    },
  );

  testWidgets('email session does not wait on cloud backup refresh', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _DelayedCloudBackupController? delayedCloudBackupController;

    await tester.pumpWidget(
      _buildApp(
        authService: _FakeAuthService(
          user: const UserProfile(
            id: 'u_1',
            email: 'user@example.com',
            displayName: 'User One',
            provider: 'email',
            emailVerified: true,
            accessToken: 'token',
          ),
        ),
        enableMarketAutoRefresh: false,
        cloudBackupControllerBuilder:
            (
              AppStateController appStateController,
              AuthController authController,
              BackupKeyManager backupKeyManager,
            ) {
              final controller = _DelayedCloudBackupController(
                appStateController: appStateController,
                authController: authController,
                backupKeyManager: backupKeyManager,
              );
              // Keep a reference so the test can release the gate later.
              delayedCloudBackupController = controller;
              return controller;
            },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('premiumBottomNav')), findsOneWidget);
    expect(delayedCloudBackupController, isNotNull);
    expect(delayedCloudBackupController!.refreshCalled, isTrue);

    delayedCloudBackupController!.releaseRefresh();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('premiumBottomNav')), findsOneWidget);
  });

  testWidgets('startup works without auth', skip: true, (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp(authService: _FakeAuthService()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('googleSignInButton')), findsOneWidget);
  });
}
