import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:zakatapp_flutter/services/biometric_auth_result.dart';

import 'package:zakatapp_flutter/models/user_profile.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/auth_controller.dart';
import 'package:zakatapp_flutter/services/bootstrap_cloud_service.dart';
import 'package:zakatapp_flutter/services/bootstrap_coordinator.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/features/auth/auth_service.dart';
import 'package:zakatapp_flutter/services/startup_restore_discovery.dart';

const MethodChannel _homeWidgetChannel = MethodChannel('home_widget');
const MethodChannel _homeWidgetUpdatesChannel = MethodChannel('home_widget/updates');
const MethodChannel _widgetRefreshChannel = MethodChannel('com.zakahwealth.widgets');
const MethodChannel _smartCaptureChannel = MethodChannel('com.zakahwealth.smartcapture');
const MethodChannel _smartCaptureNativeChannel = MethodChannel(
  'com.zakahwealth.smartcapture.native',
);

class _FakeAuthService implements AuthService, AuthGateStateSource {
  _FakeAuthService(this._restoredUser, {this.restoreDelay = Duration.zero});

  final UserProfile? _restoredUser;
  final Duration restoreDelay;
  final StreamController<AuthGateState> _gateController =
      StreamController<AuthGateState>.broadcast();

  int restoreSessionCalls = 0;

  @override
  Stream<AuthGateState> get authGateStateChanges => _gateController.stream;

  @override
  Future<UserProfile?> restoreSession() async {
    restoreSessionCalls += 1;
    if (restoreDelay > Duration.zero) {
      await Future<void>.delayed(restoreDelay);
    }
    return _restoredUser;
  }

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<bool> ensureSession() async => true;

  @override
  Future<UserProfile?> createAccountWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async =>
      null;

  @override
  Future<UserProfile?> reloadCurrentUser() async => _restoredUser;

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<UserProfile?> signIn({AuthProvider provider = AuthProvider.google}) async =>
      _restoredUser;

  @override
  Future<UserProfile?> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      _restoredUser;

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> isCurrentUserEmailVerified() async => true;

  void dispose() {
    _gateController.close();
  }
}

class _RecordingAppStateController extends AppStateController {
  _RecordingAppStateController({
    required super.repository,
    this.firstLoadGate,
    super.enableBackgroundSync = false,
    super.enableMarketAutoRefresh = false,
  });

  final Completer<void>? firstLoadGate;
  bool biometricLockEnabledForBootstrap = false;
  int loadAuthenticatedCalls = 0;
  int attachCurrentUserCalls = 0;
  int marketRefreshCalls = 0;
  int recurringCalls = 0;

  @override
  Future<void> loadAuthenticated(String userId) async {
    loadAuthenticatedCalls += 1;
    if (loadAuthenticatedCalls == 1 && firstLoadGate != null) {
      await firstLoadGate!.future;
    }
    await super.loadAuthenticated(userId);
  }

  @override
  Future<bool> isBiometricLockEnabledForBootstrap({
    required String userId,
  }) async {
    return biometricLockEnabledForBootstrap;
  }

  @override
  Future<void> attachCurrentUser({
    required String userId,
    required String email,
    required String displayName,
    String? photoUrl,
    required String provider,
  }) async {
    attachCurrentUserCalls += 1;
    await super.attachCurrentUser(
      userId: userId,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      provider: provider,
    );
  }

  @override
  Future<void> startMarketAutoRefresh({bool refreshImmediately = true}) async {
    marketRefreshCalls += 1;
  }

  @override
  Future<int> processDueRecurringTransactions({
    DateTime? now,
    String reason = 'load',
  }) async {
    recurringCalls += 1;
    return 0;
  }
}

class _RecordingBootstrapCloudService implements BootstrapCloudService {
  int discoverCalls = 0;
  int activateCalls = 0;
  int resumeCalls = 0;
  int restoreCalls = 0;
  int completeDiscoveryCalls = 0;
  String statusMessageText = '';

  @override
  Future<StartupRestoreDiscoveryResult> discoverStartupRestore({
    required bool localHasData,
  }) async {
    discoverCalls += 1;
    return const StartupRestoreDiscoveryResult(
      status: StartupRestoreDiscoveryStatus.none,
      message: '',
    );
  }

  @override
  Future<void> activateAfterBootstrap() async {
    activateCalls += 1;
  }

  @override
  Future<void> onLifecycleResume() async {
    resumeCalls += 1;
  }

  @override
  Future<bool> restoreLatestBackup({bool allowOverwrite = true}) async {
    restoreCalls += 1;
    return true;
  }

  @override
  void completeStartupRestoreDiscovery() {
    completeDiscoveryCalls += 1;
  }

  @override
  String get statusMessage => statusMessageText;
}

BootstrapCoordinator _buildCoordinator({
  required _RecordingAppStateController appStateController,
  required AuthController authController,
  BootstrapCloudService? cloudBackupService,
}) {
  return BootstrapCoordinator(
    dependencies: BootstrapDependencies(
      authController: authController,
      appStateController: appStateController,
      cloudBackupController: cloudBackupService,
    ),
  );
}

dynamic _mockBiometricReturnVal = true;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    _mockBiometricReturnVal = true;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/local_auth'), (MethodCall call) async {
      if (call.method == 'authenticate') {
        if (_mockBiometricReturnVal is Exception) {
          throw _mockBiometricReturnVal;
        }
        return _mockBiometricReturnVal;
      }
      if (call.method == 'getAvailableBiometrics') {
        return <String>['fingerprint', 'face'];
      }
      if (call.method == 'isDeviceSupported') {
        return true;
      }
      if (call.method == 'checkBiometrics') {
        return true;
      }
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_homeWidgetChannel, (MethodCall call) async {
      switch (call.method) {
        case 'setAppGroupId':
        case 'saveWidgetData':
        case 'updateWidget':
          return true;
        case 'getWidgetData':
          return null;
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      _homeWidgetUpdatesChannel,
      (MethodCall call) async {
        if (call.method == 'reloadAllTimelines') {
          return null;
        }
        return null;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      _widgetRefreshChannel,
      (MethodCall call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_smartCaptureChannel, (MethodCall call) async {
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      _smartCaptureNativeChannel,
      (MethodCall call) async {
        switch (call.method) {
          case 'markShortcutServiceReady':
            return true;
          case 'getPendingShortcutMessages':
            return <dynamic>[];
        }
        return null;
      },
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/local_auth'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_homeWidgetChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_homeWidgetUpdatesChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_widgetRefreshChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_smartCaptureChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_smartCaptureNativeChannel, null);
  });

  Future<void> flushMicrotasks() async {
    await Future<void>.delayed(Duration.zero);
  }

  test('coordinator start runs without a widget tree', () async {
    final _FakeAuthService fakeAuth = _FakeAuthService(
      const UserProfile(
        id: 'user-1',
        email: 'user@example.com',
        displayName: 'User',
        provider: 'google',
        emailVerified: true,
      ),
    );
    final AuthController authController = AuthController(
      authService: fakeAuth,
      localStorage: const LocalStorageService(),
    );
    final _RecordingAppStateController appStateController =
        _RecordingAppStateController(
      repository: AppStateRepository(localStorage: const LocalStorageService()),
    );
    final _RecordingBootstrapCloudService cloudBackupService =
        _RecordingBootstrapCloudService();
    final BootstrapCoordinator coordinator = _buildCoordinator(
      appStateController: appStateController,
      authController: authController,
      cloudBackupService: cloudBackupService,
    );
    int readyCount = 0;
    coordinator.addListener(() {
      if (coordinator.phase == BootstrapPhase.ready) {
        readyCount += 1;
      }
    });

    final BootstrapResult result = await coordinator.start();
    await flushMicrotasks();

    expect(result, isA<BootstrapReady>());
    expect(coordinator.phase, BootstrapPhase.ready);
    expect(readyCount, 1);
    expect(appStateController.loadAuthenticatedCalls, 1);
    expect(appStateController.attachCurrentUserCalls, 1);
    expect(appStateController.recurringCalls, 1);
    expect(cloudBackupService.activateCalls, 1);
    expect(cloudBackupService.resumeCalls, 0);
    fakeAuth.dispose();
  });

  test('single-flight start returns the same in-flight future', () async {
    final Completer<void> loadGate = Completer<void>();
    final _FakeAuthService fakeAuth = _FakeAuthService(
      const UserProfile(
        id: 'user-2',
        email: 'user2@example.com',
        displayName: 'User Two',
        provider: 'google',
        emailVerified: true,
      ),
      restoreDelay: const Duration(milliseconds: 1),
    );
    final AuthController authController = AuthController(
      authService: fakeAuth,
      localStorage: const LocalStorageService(),
    );
    final _RecordingAppStateController appStateController =
        _RecordingAppStateController(
      repository: AppStateRepository(localStorage: const LocalStorageService()),
      firstLoadGate: loadGate,
      enableBackgroundSync: true,
      enableMarketAutoRefresh: true,
    );
    final _RecordingBootstrapCloudService cloudBackupService =
        _RecordingBootstrapCloudService();
    final BootstrapCoordinator coordinator = _buildCoordinator(
      appStateController: appStateController,
      authController: authController,
      cloudBackupService: cloudBackupService,
    );

    final Future<BootstrapResult> first = coordinator.start();
    final Future<BootstrapResult> second = coordinator.start();

    expect(identical(first, second), isTrue);

    loadGate.complete();
    await first;
    await flushMicrotasks();

    expect(appStateController.loadAuthenticatedCalls, 1);
    expect(cloudBackupService.activateCalls, 1);
    fakeAuth.dispose();
  });

  test('cached success does not rehydrate or reactivate', () async {
    final _FakeAuthService fakeAuth = _FakeAuthService(
      const UserProfile(
        id: 'user-3',
        email: 'user3@example.com',
        displayName: 'User Three',
        provider: 'google',
        emailVerified: true,
      ),
    );
    final AuthController authController = AuthController(
      authService: fakeAuth,
      localStorage: const LocalStorageService(),
    );
    final _RecordingAppStateController appStateController =
        _RecordingAppStateController(
      repository: AppStateRepository(localStorage: const LocalStorageService()),
    );
    final _RecordingBootstrapCloudService cloudBackupService =
        _RecordingBootstrapCloudService();
    final BootstrapCoordinator coordinator = _buildCoordinator(
      appStateController: appStateController,
      authController: authController,
      cloudBackupService: cloudBackupService,
    );

    await coordinator.start();
    await flushMicrotasks();
    final int firstLoadCount = appStateController.loadAuthenticatedCalls;
    final int firstAttachCount = appStateController.attachCurrentUserCalls;

    await coordinator.start();
    await flushMicrotasks();

    expect(appStateController.loadAuthenticatedCalls, firstLoadCount);
    expect(appStateController.attachCurrentUserCalls, firstAttachCount);
    expect(cloudBackupService.activateCalls, 1);
    fakeAuth.dispose();
  });

  test('stale retry cannot publish over the newer generation', () async {
    final Completer<void> firstGate = Completer<void>();
    final _FakeAuthService fakeAuth = _FakeAuthService(
      const UserProfile(
        id: 'user-4',
        email: 'user4@example.com',
        displayName: 'User Four',
        provider: 'google',
        emailVerified: true,
      ),
    );
    final AuthController authController = AuthController(
      authService: fakeAuth,
      localStorage: const LocalStorageService(),
    );
    final _RecordingAppStateController appStateController =
        _RecordingAppStateController(
      repository: AppStateRepository(localStorage: const LocalStorageService()),
      firstLoadGate: firstGate,
    );
    final _RecordingBootstrapCloudService cloudBackupService =
        _RecordingBootstrapCloudService();
    final BootstrapCoordinator coordinator = _buildCoordinator(
      appStateController: appStateController,
      authController: authController,
      cloudBackupService: cloudBackupService,
    );

    final Future<BootstrapResult> firstAttempt = coordinator.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final Future<BootstrapResult> retryAttempt = coordinator.start(retry: true);
    firstGate.complete();

    final BootstrapResult retryResult = await retryAttempt;
    final BootstrapResult staleResult = await firstAttempt;
    await flushMicrotasks();

    expect(retryResult, isA<BootstrapReady>());
    expect(staleResult.reused, isTrue);
    expect(coordinator.phase, BootstrapPhase.ready);
    expect(appStateController.loadAuthenticatedCalls, 2);
    expect(cloudBackupService.activateCalls, 1);
    fakeAuth.dispose();
  });

  test('unlock resumes a biometric-locked startup without re-locking', () async {
    _mockBiometricReturnVal = false; // Mock failure first so it locks
    final _FakeAuthService fakeAuth = _FakeAuthService(
      const UserProfile(
        id: 'user-5',
        email: 'user5@example.com',
        displayName: 'User Five',
        provider: 'google',
        emailVerified: true,
      ),
    );
    final AuthController authController = AuthController(
      authService: fakeAuth,
      localStorage: const LocalStorageService(),
    );
    final _RecordingAppStateController appStateController =
        _RecordingAppStateController(
      repository: AppStateRepository(localStorage: const LocalStorageService()),
    )..biometricLockEnabledForBootstrap = true;
    final _RecordingBootstrapCloudService cloudBackupService =
        _RecordingBootstrapCloudService();
    final BootstrapCoordinator coordinator = _buildCoordinator(
      appStateController: appStateController,
      authController: authController,
      cloudBackupService: cloudBackupService,
    );

    final BootstrapResult initialResult = await coordinator.start();
    await flushMicrotasks();

    expect(initialResult, isA<BootstrapReady>());
    expect((initialResult as BootstrapReady).requiresUnlock, isTrue);
    expect(coordinator.phase, BootstrapPhase.locked);
    expect(appStateController.loadAuthenticatedCalls, 0);

    _mockBiometricReturnVal = true; // Succeed on unlock
    await coordinator.handleUnlock();
    await flushMicrotasks();

    expect(coordinator.phase, BootstrapPhase.ready);
    expect(appStateController.loadAuthenticatedCalls, 1);
    expect(appStateController.attachCurrentUserCalls, 1);
    expect(cloudBackupService.activateCalls, 1);
    fakeAuth.dispose();
  });

  test('Cold start + biometric success -> protected load called once -> ready', () async {
    _mockBiometricReturnVal = true;
    final _FakeAuthService fakeAuth = _FakeAuthService(
      const UserProfile(
        id: 'test-user-success',
        email: 'success@example.com',
        displayName: 'Test',
        provider: 'google',
        emailVerified: true,
      ),
    );
    final AuthController authController = AuthController(
      authService: fakeAuth,
      localStorage: const LocalStorageService(),
    );
    final _RecordingAppStateController appStateController = _RecordingAppStateController(
      repository: AppStateRepository(localStorage: const LocalStorageService()),
    )..biometricLockEnabledForBootstrap = true;
    final BootstrapCoordinator coordinator = _buildCoordinator(
      appStateController: appStateController,
      authController: authController,
    );

    final BootstrapResult result = await coordinator.start();
    await flushMicrotasks();

    expect(result, isA<BootstrapReady>());
    expect(coordinator.phase, BootstrapPhase.ready);
    expect(appStateController.loadAuthenticatedCalls, 1);
    fakeAuth.dispose();
  });

  test('Cold start + cancellation -> locked -> initializedServices false -> autoPrompt false', () async {
    _mockBiometricReturnVal = const LocalAuthException(
      code: LocalAuthExceptionCode.userCanceled,
      details: 'User cancelled',
    );
    final _FakeAuthService fakeAuth = _FakeAuthService(
      const UserProfile(
        id: 'test-user-cancel',
        email: 'cancel@example.com',
        displayName: 'Test',
        provider: 'google',
        emailVerified: true,
      ),
    );
    final AuthController authController = AuthController(
      authService: fakeAuth,
      localStorage: const LocalStorageService(),
    );
    final _RecordingAppStateController appStateController = _RecordingAppStateController(
      repository: AppStateRepository(localStorage: const LocalStorageService()),
    )..biometricLockEnabledForBootstrap = true;
    final BootstrapCoordinator coordinator = _buildCoordinator(
      appStateController: appStateController,
      authController: authController,
    );

    final BootstrapResult result = await coordinator.start();
    await flushMicrotasks();

    expect(result, isA<BootstrapReady>());
    expect((result as BootstrapReady).requiresUnlock, isTrue);
    expect(result.initializedServices, isFalse);
    expect(coordinator.phase, BootstrapPhase.locked);
    expect(coordinator.lockScreenAutoPrompt, isFalse);
    expect(appStateController.loadAuthenticatedCalls, 0);
    fakeAuth.dispose();
  });

  test('Resume timeout -> locked -> initializedServices true -> autoPrompt true', () async {
    _mockBiometricReturnVal = true;
    final _FakeAuthService fakeAuth = _FakeAuthService(
      const UserProfile(
        id: 'test-user-resume',
        email: 'resume@example.com',
        displayName: 'Test',
        provider: 'google',
        emailVerified: true,
      ),
    );
    final AuthController authController = AuthController(
      authService: fakeAuth,
      localStorage: const LocalStorageService(),
    );
    final _RecordingAppStateController appStateController = _RecordingAppStateController(
      repository: AppStateRepository(localStorage: const LocalStorageService()),
    )..biometricLockEnabledForBootstrap = true;
    final BootstrapCoordinator coordinator = _buildCoordinator(
      appStateController: appStateController,
      authController: authController,
    );

    // Initial boot without biometrics (start it as already hydrated / logged in)
    appStateController.biometricLockEnabledForBootstrap = false;
    await coordinator.start();
    await flushMicrotasks();
    expect(coordinator.phase, BootstrapPhase.ready);
    expect(appStateController.loadAuthenticatedCalls, 1);

    // Turn biometrics back on, update delay to immediate, enable lock, and trigger resume lock
    appStateController.biometricLockEnabledForBootstrap = true;
    await appStateController.updateBiometricAutoLockDelay('immediate');
    await appStateController.updateBiometricLockEnabled(true);
    
    // Simulate backgrounding
    await coordinator.handleLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    // Simulate resume lock (shouldLock is true)
    await coordinator.handleLifecycleState(AppLifecycleState.resumed);
    await flushMicrotasks();

    expect(coordinator.phase, BootstrapPhase.locked);
    expect(coordinator.lockScreenAutoPrompt, isTrue);
    
    // Manual/auto unlock retry
    await coordinator.handleUnlock();
    await flushMicrotasks();

    expect(coordinator.phase, BootstrapPhase.ready);
    // Should NOT reload/rehydrate state on resume unlock
    expect(appStateController.loadAuthenticatedCalls, 1);

    fakeAuth.dispose();
  });

  test('Stale generation after biometric success -> no protected load or ready transition', () async {
    _mockBiometricReturnVal = true;
    final _FakeAuthService fakeAuth = _FakeAuthService(
      const UserProfile(
        id: 'test-user-stale',
        email: 'stale@example.com',
        displayName: 'Test',
        provider: 'google',
        emailVerified: true,
      ),
    );
    final AuthController authController = AuthController(
      authService: fakeAuth,
      localStorage: const LocalStorageService(),
    );
    final _RecordingAppStateController appStateController = _RecordingAppStateController(
      repository: AppStateRepository(localStorage: const LocalStorageService()),
    )..biometricLockEnabledForBootstrap = true;
    final BootstrapCoordinator coordinator = _buildCoordinator(
      appStateController: appStateController,
      authController: authController,
    );

    final Future<BootstrapResult> future = coordinator.start();
    // Restart to bump generation
    coordinator.start(retry: true);
    
    final result = await future;
    expect(result.reused, isTrue);
    expect(coordinator.phase, isNot(BootstrapPhase.ready));
    fakeAuth.dispose();
  });

  test('biometricPromptInProgress changes notifies listeners', () async {
    _mockBiometricReturnVal = true;
    final _FakeAuthService fakeAuth = _FakeAuthService(
      const UserProfile(
        id: 'test-user-biometric-notify',
        email: 'biometric-notify@example.com',
        displayName: 'Test',
        provider: 'google',
        emailVerified: true,
      ),
    );
    final AuthController authController = AuthController(
      authService: fakeAuth,
      localStorage: const LocalStorageService(),
    );
    final _RecordingAppStateController appStateController = _RecordingAppStateController(
      repository: AppStateRepository(localStorage: const LocalStorageService()),
    )..biometricLockEnabledForBootstrap = true;
    final BootstrapCoordinator coordinator = _buildCoordinator(
      appStateController: appStateController,
      authController: authController,
    );

    // Bootstrap app to ready phase (we start with biometric lock disabled on boot so it completes)
    appStateController.biometricLockEnabledForBootstrap = false;
    await coordinator.start();
    await flushMicrotasks();
    expect(coordinator.phase, BootstrapPhase.ready);

    // Enable biometric lock for lock/unlock
    appStateController.biometricLockEnabledForBootstrap = true;
    await appStateController.updateBiometricLockEnabled(true);
    await appStateController.updateBiometricAutoLockDelay('immediate');

    // Simulate backgrounding & resume to lock the screen
    await coordinator.handleLifecycleState(AppLifecycleState.paused);
    await coordinator.handleLifecycleState(AppLifecycleState.resumed);
    await flushMicrotasks();
    expect(coordinator.phase, BootstrapPhase.locked);

    // Listen to notifications
    int notificationCount = 0;
    bool lastPromptInProgress = false;
    coordinator.addListener(() {
      notificationCount++;
      lastPromptInProgress = coordinator.biometricPromptInProgress;
    });

    // Start manual unlock, which triggers biometric prompt
    final Future<void> unlockFuture = coordinator.handleUnlock();
    
    // In-progress flag should immediately be true and trigger a notification
    expect(coordinator.biometricPromptInProgress, isTrue);
    expect(notificationCount, greaterThanOrEqualTo(1));
    expect(lastPromptInProgress, isTrue);

    // Wait for the prompt to finish
    await unlockFuture;
    await flushMicrotasks();

    // In-progress flag should be false and trigger a notification
    expect(coordinator.biometricPromptInProgress, isFalse);
    expect(lastPromptInProgress, isFalse);

    fakeAuth.dispose();
  });
}
