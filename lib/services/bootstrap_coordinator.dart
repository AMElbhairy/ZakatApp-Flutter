import 'dart:async';

import 'package:flutter/widgets.dart';

import '../features/auth/auth_service.dart';
import '../models/backup_preview.dart';
import '../models/user_profile.dart';
import 'apple_shortcuts_service.dart';
import 'app_state_controller.dart';
import 'auth_controller.dart';
import 'biometric_service.dart';
import 'biometric_auth_result.dart';
import 'backup_service.dart';
import 'backup_restore_service.dart';
import 'bootstrap_cloud_service.dart';
import 'launch_diagnostics.dart';
import 'local_backup_service.dart';
import 'startup_restore_discovery.dart';

enum BootstrapPhase {
  idle,
  authLoading,
  signedOut,
  emailVerification,
  loading,
  restoreGate,
  locked,
  ready,
  failed,
}

enum BootstrapFailureCode {
  none,
  signedOut,
  emailVerification,
  authLoadFailed,
  hydrationFailed,
  restoreFailed,
  staleGeneration,
}

class BootstrapRequest {
  const BootstrapRequest({
    this.retry = false,
    this.launchSource = '',
    this.pendingUri,
    this.processLaunchId = '',
  });

  final bool retry;
  final String launchSource;
  final Uri? pendingUri;
  final String processLaunchId;
}

sealed class BootstrapResult {
  const BootstrapResult({
    required this.phase,
    required this.generation,
    this.reused = false,
    this.pendingUri,
  });

  final BootstrapPhase phase;
  final int generation;
  final bool reused;
  final Uri? pendingUri;
}

final class BootstrapReady extends BootstrapResult {
  const BootstrapReady({
    required super.phase,
    required super.generation,
    required this.requiresUnlock,
    required this.initializedServices,
    super.reused = false,
    super.pendingUri,
  });

  final bool requiresUnlock;
  final bool initializedServices;
}

final class BootstrapSignedOut extends BootstrapResult {
  const BootstrapSignedOut({
    required super.phase,
    required super.generation,
    required this.code,
    super.reused = false,
    super.pendingUri,
  });

  final BootstrapFailureCode code;
}

final class BootstrapEmailVerificationRequired extends BootstrapResult {
  const BootstrapEmailVerificationRequired({
    required super.phase,
    required super.generation,
    required this.user,
    super.reused = false,
    super.pendingUri,
  });

  final UserProfile user;
}

final class BootstrapRestoreGate extends BootstrapResult {
  const BootstrapRestoreGate({
    required super.phase,
    required super.generation,
    required this.discovery,
    super.reused = false,
    super.pendingUri,
  });

  final StartupRestoreDiscoveryResult discovery;
}

final class BootstrapFailed extends BootstrapResult {
  const BootstrapFailed({
    required super.phase,
    required super.generation,
    required this.code,
    this.error,
    super.reused = false,
    super.pendingUri,
  });

  final BootstrapFailureCode code;
  final Object? error;
}

class BootstrapDependencies {
  const BootstrapDependencies({
    required this.authController,
    required this.appStateController,
    this.cloudBackupController,
  });

  final AuthController authController;
  final AppStateController appStateController;
  final BootstrapCloudService? cloudBackupController;
}

enum LockReason {
  coldStartFallback,
  resumeTimeout,
}

class BootstrapCoordinator extends ChangeNotifier {
  BootstrapCoordinator({required BootstrapDependencies dependencies}) : _dependencies = dependencies;

  final BootstrapDependencies _dependencies;
  StreamSubscription<AuthGateState>? _authGateSubscription;
  bool _authGateForwardingEnabled = false;
  bool _authGateSubscriptionAttached = false;
  bool _initialBootstrapComplete = false;
  bool _sessionExpiryHandlingInProgress = false;
  bool _reloadAfterUnlock = false;
  bool _gateBootstrapInProgress = false;
  bool _isDisposed = false;
  int _generation = 0;
  BootstrapResult? _lastResult;
  Future<BootstrapResult>? _inFlight;
  BootstrapPhase _phase = BootstrapPhase.idle;
  StartupRestoreDiscoveryResult? _restoreGateDiscovery;
  UserProfile? _pendingAuthenticatedUser;
  String? _loadingMessage;
  DateTime? _pausedAt;
  DateTime? _lastSuccessfulUnlockAt;

  // New fields
  bool _lockScreenAutoPrompt = false;
  bool _biometricPromptInProgress = false;
  LockReason? _lockReason;
  BootstrapRequest? _pendingBootstrapRequest;
  Uri? _pendingUri;
  Future<BootstrapResult>? _protectedBootstrapFuture;
  String? _protectedBootstrapUserId;
  int? _protectedBootstrapGeneration;

  bool get biometricPromptInProgress => _biometricPromptInProgress;

  void _setBiometricPromptInProgress(bool value) {
    if (_biometricPromptInProgress == value) {
      return;
    }
    _biometricPromptInProgress = value;
    notifyListeners();
  }

  BootstrapPhase get phase => _phase;
  StartupRestoreDiscoveryResult? get restoreGateDiscovery =>
      _restoreGateDiscovery;
  String? get loadingMessage => _loadingMessage;
  BootstrapResult? get lastResult => _lastResult;
  UserProfile? get pendingAuthenticatedUser => _pendingAuthenticatedUser;
  bool get requiresUnlock => _phase == BootstrapPhase.locked;
  bool get hasInitialBootstrapComplete => _initialBootstrapComplete;

  bool get lockScreenAutoPrompt => _lockScreenAutoPrompt;

  void _attachAuthGateSubscription() {
    if (_authGateSubscriptionAttached) return;
    _authGateSubscriptionAttached = true;
    final AuthController authController = _dependencies.authController;
    _authGateSubscription = authController.authGateStateChanges.listen(
      (AuthGateState state) {
        if (_isDisposed || !_authGateForwardingEnabled) return;
        unawaited(handleAuthGateState(state));
      },
    );
  }

  BootstrapRequest _normalizeRequest(BootstrapRequest request) {
    return request;
  }

  bool _isCurrentGeneration(int generation) => generation == _generation;

  void _setPhase(BootstrapPhase next, {String? loadingMessage}) {
    if (_phase == next && _loadingMessage == loadingMessage) return;
    _phase = next;
    _loadingMessage = loadingMessage;
    notifyListeners();
  }

  void _setRestoreGateDiscovery(StartupRestoreDiscoveryResult? discovery) {
    _restoreGateDiscovery = discovery;
    notifyListeners();
  }

  BootstrapResult _staleResult(int generation, BootstrapRequest request) {
    return BootstrapFailed(
      phase: _phase,
      generation: generation,
      code: BootstrapFailureCode.staleGeneration,
      reused: true,
      pendingUri: request.pendingUri,
    );
  }

  Future<BootstrapResult> start({bool retry = false}) {
    final BootstrapRequest request = _normalizeRequest(
      BootstrapRequest(retry: retry),
    );
    if (!retry && _lastResult is BootstrapReady) {
      return Future<BootstrapResult>.value(_lastResult);
    }
    if (_inFlight != null && !retry) {
      return _inFlight!;
    }

    if (retry) {
      _generation += 1;
      _lastResult = null;
      _reloadAfterUnlock = false;
      _pendingAuthenticatedUser = null;
      _pendingBootstrapRequest = null;
      _pendingUri = null;
      _lockReason = null;
      _lockScreenAutoPrompt = false;
      BiometricService.lockSensitiveSession();
      _restoreGateDiscovery = null;
      _loadingMessage = null;
      _phase = BootstrapPhase.authLoading;
      _protectedBootstrapFuture = null;
      _protectedBootstrapUserId = null;
      _protectedBootstrapGeneration = null;
      notifyListeners();
    }

    final int generation = _generation;
    final Completer<BootstrapResult> completer = Completer<BootstrapResult>();
    _inFlight = completer.future;
    _authGateForwardingEnabled = true;
    _attachAuthGateSubscription();

    unawaited(
      LaunchDiagnostics.record(
        'bootstrap_start',
        metadata: <String, dynamic>{
          'generation': generation,
          'retry': retry,
          'launchSource': request.launchSource,
          'processLaunchId': request.processLaunchId,
        },
      ),
    );

    () async {
      try {
        final BootstrapResult result = await _startInternal(
          generation: generation,
          request: request,
        );
        if (!_isCurrentGeneration(generation)) {
          completer.complete(_staleResult(generation, request));
          return;
        }
        _lastResult = result;
        completer.complete(result);
      } catch (error, stackTrace) {
        debugPrint('BootstrapCoordinator.start failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        final BootstrapFailed result = BootstrapFailed(
          phase: BootstrapPhase.failed,
          generation: generation,
          code: BootstrapFailureCode.authLoadFailed,
          error: error,
          pendingUri: request.pendingUri,
        );
        if (_isCurrentGeneration(generation)) {
          _phase = BootstrapPhase.failed;
          _loadingMessage = error.toString();
          _lastResult = result;
          notifyListeners();
        }
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      } finally {
        if (identical(_inFlight, completer.future)) {
          _inFlight = null;
        }
      }
    }();

    return completer.future;
  }

  Future<BootstrapResult> _startInternal({
    required int generation,
    required BootstrapRequest request,
  }) async {
    final AuthController authController = _dependencies.authController;
    final AppStateController appStateController = _dependencies.appStateController;

    _setPhase(BootstrapPhase.authLoading);
    await authController.load();
    if (!_isCurrentGeneration(generation)) {
      return _staleResult(generation, request);
    }

    final UserProfile? user = authController.currentUser;
    if (user == null) {
      await _routeToSignedOut();
      return BootstrapSignedOut(
        phase: BootstrapPhase.signedOut,
        generation: generation,
        code: BootstrapFailureCode.signedOut,
        pendingUri: request.pendingUri,
      );
    }
    if (_requiresEmailVerification(user)) {
      await _routeToEmailVerification(user);
      return BootstrapEmailVerificationRequired(
        phase: BootstrapPhase.emailVerification,
        generation: generation,
        user: user,
        pendingUri: request.pendingUri,
      );
    }

    _pendingUri = request.pendingUri;

    final bool biometricEnabled = await appStateController.isBiometricLockEnabledForBootstrap(
      userId: user.id,
    );
    if (!_isCurrentGeneration(generation)) {
      return _staleResult(generation, request);
    }

    if (biometricEnabled) {
      _setPhase(BootstrapPhase.loading);
      
      _setBiometricPromptInProgress(true);
      late final BiometricAuthResult authResult;
      try {
        authResult = await BiometricService.authenticateWithResult(
          reason: 'Unlock Zakah Wealth',
          purpose: BiometricAuthPurpose.appUnlock,
          biometricOnly: true,
        );
      } finally {
        _setBiometricPromptInProgress(false);
      }

      if (!_isCurrentGeneration(generation)) {
        return _staleResult(generation, request);
      }

      if (authResult != BiometricAuthResult.success) {
        _pendingAuthenticatedUser = user;
        _pendingBootstrapRequest = request;
        _lockReason = LockReason.coldStartFallback;
        _lockScreenAutoPrompt = false;
        _setPhase(BootstrapPhase.locked);
        _initialBootstrapComplete = true;
        final BootstrapReady lockedResult = BootstrapReady(
          phase: BootstrapPhase.locked,
          generation: generation,
          requiresUnlock: true,
          initializedServices: false,
          pendingUri: request.pendingUri,
        );
        _lastResult = lockedResult;
        return lockedResult;
      }
    }

    return _ensureProtectedStateLoaded(
      user: user,
      request: request,
      generation: generation,
    );
  }

  Future<BootstrapResult> _ensureProtectedStateLoaded({
    required UserProfile user,
    required BootstrapRequest request,
    required int generation,
  }) {
    final existing = _protectedBootstrapFuture;
    if (existing != null &&
        _protectedBootstrapUserId == user.id &&
        _protectedBootstrapGeneration == generation) {
      return existing;
    }
    final future = _loadProtectedStateAndComplete(
      user: user,
      request: request,
      generation: generation,
    );
    _protectedBootstrapFuture = future;
    _protectedBootstrapUserId = user.id;
    _protectedBootstrapGeneration = generation;
    return future.whenComplete(() {
      if (identical(_protectedBootstrapFuture, future)) {
        _protectedBootstrapFuture = null;
        _protectedBootstrapUserId = null;
        _protectedBootstrapGeneration = null;
      }
    });
  }

  Future<BootstrapResult> _loadProtectedStateAndComplete({
    required UserProfile user,
    required BootstrapRequest request,
    required int generation,
  }) async {
    final AppStateController appStateController = _dependencies.appStateController;
    final BootstrapCloudService? cloudBackupController =
        _dependencies.cloudBackupController;

    final DateTime loadingStartedAt = DateTime.now();
    _setPhase(BootstrapPhase.loading);

    Future<void> enforceMinLoadingTime() async {
      final Duration elapsed = DateTime.now().difference(loadingStartedAt);
      const Duration minimumDuration = Duration(milliseconds: 1200); // 1.2 seconds min display time
      if (elapsed < minimumDuration) {
        await Future.delayed(minimumDuration - elapsed);
      }
    }

    await appStateController.loadAuthenticated(user.id);
    if (!_isCurrentGeneration(generation)) {
      return _staleResult(generation, request);
    }

    await appStateController.attachCurrentUser(
      userId: user.id,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoUrl,
      provider: user.provider,
    );
    if (!_isCurrentGeneration(generation)) {
      return _staleResult(generation, request);
    }

    if (appStateController.hasHydrationFailure ||
        !appStateController.isHydrationReady) {
      _setPhase(BootstrapPhase.failed, loadingMessage: _loadingMessage);
      final BootstrapFailed failed = BootstrapFailed(
        phase: BootstrapPhase.failed,
        generation: generation,
        code: BootstrapFailureCode.hydrationFailed,
        error: appStateController.hasHydrationFailure
            ? StateError('Hydration failed')
            : StateError('Hydration not ready'),
        pendingUri: _pendingUri,
      );
      _lastResult = failed;
      return failed;
    }

    final bool localHasData = BackupService.hasData(
      appStateController.state.toJson(),
    );
    final StartupRestoreDiscoveryResult discovery = await _discoverStartupRestore(
      localHasData: localHasData,
    );
    _restoreGateDiscovery = discovery;
    if (!localHasData &&
        discovery.status == StartupRestoreDiscoveryStatus.restorePrompt) {
      final bool restored = await _autoRestoreStartupBackup(
        discovery,
        generation: generation,
        request: request,
      );
      if (!restored) {
        return BootstrapFailed(
          phase: BootstrapPhase.restoreGate,
          generation: generation,
          code: BootstrapFailureCode.restoreFailed,
          error: cloudBackupController?.statusMessage,
          pendingUri: _pendingUri,
        );
      }
      _pendingAuthenticatedUser = null;
      _pendingBootstrapRequest = null;
      _initialBootstrapComplete = true;
      await enforceMinLoadingTime();
      if (!_isCurrentGeneration(generation)) {
        return _staleResult(generation, request);
      }
      _setPhase(BootstrapPhase.ready);
      final Uri? pendingUri = _pendingUri;
      _pendingUri = null;
      final BootstrapReady ready = BootstrapReady(
        phase: BootstrapPhase.ready,
        generation: generation,
        requiresUnlock: false,
        initializedServices: true,
        pendingUri: pendingUri,
      );
      _lastResult = ready;
      return ready;
    }

    if (discovery.shouldShowGate) {
      _setPhase(BootstrapPhase.restoreGate);
      final BootstrapRestoreGate gateResult = BootstrapRestoreGate(
        phase: BootstrapPhase.restoreGate,
        generation: generation,
        discovery: discovery,
        pendingUri: _pendingUri,
      );
      _lastResult = gateResult;
      return gateResult;
    }

    if (!appStateController.enableBackgroundSync &&
        !appStateController.enableMarketAutoRefresh) {
      _pendingAuthenticatedUser = null;
      _pendingBootstrapRequest = null;
      _initialBootstrapComplete = true;
      unawaited(_finishBootstrapBackgroundTasks(generation: generation));
      await enforceMinLoadingTime();
      if (!_isCurrentGeneration(generation)) {
        return _staleResult(generation, request);
      }
      _setPhase(BootstrapPhase.ready);
      final Uri? pendingUri = _pendingUri;
      _pendingUri = null;
      final BootstrapReady ready = BootstrapReady(
        phase: BootstrapPhase.ready,
        generation: generation,
        requiresUnlock: false,
        initializedServices: true,
        pendingUri: pendingUri,
      );
      _lastResult = ready;
      return ready;
    }

    _pendingAuthenticatedUser = null;
    _pendingBootstrapRequest = null;
    _initialBootstrapComplete = true;
    unawaited(_finishBootstrapBackgroundTasks(generation: generation));

    await enforceMinLoadingTime();
    if (!_isCurrentGeneration(generation)) {
      return _staleResult(generation, request);
    }
    _setPhase(BootstrapPhase.ready);
    final Uri? pendingUri = _pendingUri;
    _pendingUri = null;
    final BootstrapReady ready = BootstrapReady(
      phase: BootstrapPhase.ready,
      generation: generation,
      requiresUnlock: false,
      initializedServices: true,
      pendingUri: pendingUri,
    );
    _lastResult = ready;
    return ready;
  }

  Future<bool> _autoRestoreStartupBackup(
    StartupRestoreDiscoveryResult discovery, {
    required int generation,
    required BootstrapRequest request,
  }) async {
    if (discovery.isLocalBackup) {
      return _autoRestoreLocalBackup(
        discovery,
        generation: generation,
      );
    }
    final BootstrapCloudService? cloudBackupController =
        _dependencies.cloudBackupController;
    if (cloudBackupController == null) {
      await _enterShellAfterRestore(
        generation: generation,
      );
      return true;
    }
    _setPhase(BootstrapPhase.loading, loadingMessage: discovery.message);
    final bool ok = await cloudBackupController.restoreLatestBackup();
    if (!_isCurrentGeneration(generation)) {
      return false;
    }
    if (!ok) {
      _setPhase(BootstrapPhase.restoreGate, loadingMessage: cloudBackupController.statusMessage);
      _setRestoreGateDiscovery(discovery.copyWith(
        error: cloudBackupController.statusMessage,
      ));
      return false;
    }
    await _enterShellAfterRestore(
      generation: generation,
    );
    return true;
  }

  Future<bool> _autoRestoreLocalBackup(
    StartupRestoreDiscoveryResult discovery, {
    required int generation,
  }) async {
    final BackupPreview? preview = discovery.preview;
    if (preview == null || preview.rawJson.trim().isEmpty) {
      _setPhase(BootstrapPhase.restoreGate, loadingMessage: discovery.message);
      _setRestoreGateDiscovery(
        discovery.copyWith(error: 'Local backup preview is missing.'),
      );
      return false;
    }

    _setPhase(BootstrapPhase.loading, loadingMessage: discovery.message);
    try {
      final BackupRestoreService restoreService = BackupRestoreService(
        controller: _dependencies.appStateController,
      );
      final String startupUserId = _startupUserId();
      await restoreService.restoreReplace(
        preview.rawJson,
        allowWhenLocalDataExists: true,
        expectedUserId: startupUserId.isEmpty ? null : startupUserId,
      );
      if (!_isCurrentGeneration(generation)) {
        return false;
      }
      await _enterShellAfterRestore(
        generation: generation,
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint('Local backup auto-restore failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setPhase(BootstrapPhase.restoreGate, loadingMessage: discovery.message);
      _setRestoreGateDiscovery(discovery.copyWith(error: error.toString()));
      return false;
    }
  }

  Future<StartupRestoreDiscoveryResult> _discoverStartupRestore({
    required bool localHasData,
  }) async {
    final AppStateController appStateController = _dependencies.appStateController;
    final BootstrapCloudService? cloudBackupController =
        _dependencies.cloudBackupController;
    final LocalBackupService? localBackupService =
        appStateController.localBackupService;
    final String currentUserId = _startupUserId();

    if (localHasData) {
      return const StartupRestoreDiscoveryResult(
        status: StartupRestoreDiscoveryStatus.none,
        message: '',
      );
    }

    if (cloudBackupController == null) {
      if (localBackupService == null) {
        return const StartupRestoreDiscoveryResult(
          status: StartupRestoreDiscoveryStatus.none,
          message: '',
        );
      }
      return localBackupService.discoverStartupRestore(
        userId: currentUserId,
        localHasData: localHasData,
      );
    }

    final StartupRestoreDiscoveryResult cloudDiscovery =
        await cloudBackupController.discoverStartupRestore(
          localHasData: false,
        );
    if (cloudDiscovery.status == StartupRestoreDiscoveryStatus.restorePrompt ||
        cloudDiscovery.status == StartupRestoreDiscoveryStatus.dismissed) {
      return cloudDiscovery;
    }

    if (localBackupService == null || currentUserId.trim().isEmpty) {
      return cloudDiscovery;
    }

    final StartupRestoreDiscoveryResult localDiscovery =
        await localBackupService.discoverStartupRestore(
          userId: currentUserId,
          localHasData: localHasData,
        );
    if (localDiscovery.status == StartupRestoreDiscoveryStatus.restorePrompt) {
      return localDiscovery;
    }

    return cloudDiscovery;
  }

  Future<void> _finishBootstrapBackgroundTasks({
    required int generation,
  }) async {
    final AppStateController appStateController = _dependencies.appStateController;
    final BootstrapCloudService? cloudBackupController =
        _dependencies.cloudBackupController;
    cloudBackupController?.completeStartupRestoreDiscovery();

    try {
      if (cloudBackupController != null) {
        unawaited(cloudBackupController.activateAfterBootstrap());
      }
    } catch (error, stackTrace) {
      debugPrint('Cloud backup bootstrap refresh failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (appStateController.enableMarketAutoRefresh) {
      try {
        unawaited(appStateController.startMarketAutoRefresh());
      } catch (error, stackTrace) {
        debugPrint('Market refresh bootstrap failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    if (_isDisposed || !_isCurrentGeneration(generation)) return;
    AppleShortcutsService.initialize(appStateController);
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  Future<void> handleAuthGateState(AuthGateState state) async {
    if (_isDisposed) return;
    switch (state.status) {
      case AuthGateStatus.checking:
        if (_phase == BootstrapPhase.signedOut) {
          _setPhase(BootstrapPhase.authLoading);
        }
        return;
      case AuthGateStatus.signedOut:
        if (_dependencies.authController.currentUser != null) {
          return;
        }
        await _routeToSignedOut();
        return;
      case AuthGateStatus.error:
        if (_dependencies.authController.currentUser != null) {
          _loadingMessage = state.message;
          notifyListeners();
          return;
        }
        await _routeToSignedOut();
        return;
      case AuthGateStatus.tokenExpired:
        if (_sessionExpiryHandlingInProgress) return;
        _sessionExpiryHandlingInProgress = true;
        try {
          await _routeToSignedOut();
        } finally {
          _sessionExpiryHandlingInProgress = false;
        }
        return;
      case AuthGateStatus.signedIn:
        final UserProfile? user = state.user ?? _dependencies.authController.currentUser;
        if (user == null) return;
        if (_requiresEmailVerification(user)) {
          await _routeToEmailVerification(user);
          return;
        }
        if (_inFlight != null) {
          return;
        }
        if (_gateBootstrapInProgress) return;
        if (!(_phase == BootstrapPhase.signedOut ||
            _phase == BootstrapPhase.authLoading)) {
          return;
        }
        _gateBootstrapInProgress = true;
        try {
          await start(retry: true);
        } finally {
          _gateBootstrapInProgress = false;
        }
        return;
    }
  }

  Future<void> handleLifecycleState(AppLifecycleState state) async {
    if (_biometricPromptInProgress) {
      return;
    }

    final AppStateController appStateController = _dependencies.appStateController;
    final AuthController authController = _dependencies.authController;
    final bool shouldProtect =
        authController.currentUser != null &&
        (appStateController.state.biometricLockEnabled ||
            appStateController.state.biometricHideWealthEnabled);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_pausedAt == null &&
          _initialBootstrapComplete &&
          _phase == BootstrapPhase.ready &&
          shouldProtect &&
          _phase != BootstrapPhase.locked) {
        _pausedAt = DateTime.now();
      }
      return;
    }

    if (state != AppLifecycleState.resumed) {
      return;
    }

    final DateTime? pausedAt = _pausedAt;
    _pausedAt = null;
    final bool justUnlocked =
        _lastSuccessfulUnlockAt != null &&
        DateTime.now().difference(_lastSuccessfulUnlockAt!) <
            Duration.zero;
    final bool shouldReloadAfterLongInactive =
        pausedAt != null &&
        DateTime.now().difference(pausedAt) >=
            const Duration(minutes: 5);
    final bool shouldLock =
        pausedAt != null &&
        authController.currentUser != null &&
        appStateController.state.biometricLockEnabled &&
        _phase == BootstrapPhase.ready &&
        !justUnlocked &&
        DateTime.now().difference(pausedAt).inSeconds >=
            _autoLockDelaySeconds(appStateController.state.biometricAutoLockDelay);

    if (authController.currentUser != null &&
        (_phase == BootstrapPhase.ready || _phase == BootstrapPhase.locked)) {
      final BootstrapCloudService? cloudBackupController =
          _dependencies.cloudBackupController;
      if (cloudBackupController != null) {
        unawaited(cloudBackupController.onLifecycleResume());
      }
      unawaited(appStateController.startMarketAutoRefresh());
      unawaited(
        appStateController.processDueRecurringTransactions(reason: 'resume'),
      );
    }

    if (shouldReloadAfterLongInactive) {
      if (shouldLock) {
        _reloadAfterUnlock = true;
      } else {
        unawaited(_refreshAfterLongInactive());
      }
    }

    if (shouldLock) {
      _lockReason = LockReason.resumeTimeout;
      _lockScreenAutoPrompt = true;
      _setPhase(BootstrapPhase.locked);
    }
  }

  Future<void> handleUnlock() async {
    if (_biometricPromptInProgress) {
      return;
    }
    final LockReason? lockReason = _lockReason;
    if (lockReason == null) {
      return;
    }

    _setBiometricPromptInProgress(true);
    late final BiometricAuthResult result;
    try {
      result = await BiometricService.authenticateWithResult(
        reason: 'Unlock Zakah Wealth',
        purpose: BiometricAuthPurpose.appUnlock,
        biometricOnly: true,
      );
    } finally {
      _setBiometricPromptInProgress(false);
    }

    if (result != BiometricAuthResult.success) {
      _lockScreenAutoPrompt = false;
      notifyListeners();
      return;
    }

    _lockScreenAutoPrompt = false;
    if (lockReason == LockReason.resumeTimeout) {
      _lockReason = null;
      _lastSuccessfulUnlockAt = DateTime.now();
      if (_reloadAfterUnlock) {
        _reloadAfterUnlock = false;
        _setPhase(BootstrapPhase.loading, loadingMessage: 'Refreshing data...');
        try {
          await _refreshAfterLongInactive();
        } finally {
          _setPhase(BootstrapPhase.ready);
        }
      } else {
        _setPhase(BootstrapPhase.ready);
      }
      return;
    }

    final UserProfile? user = _pendingAuthenticatedUser;
    final BootstrapRequest? request = _pendingBootstrapRequest;
    if (user == null || request == null) {
      await start(retry: true);
      return;
    }

    await _ensureProtectedStateLoaded(
      user: user,
      request: request,
      generation: _generation,
    );
  }

  Future<void> restoreBackup() async {
    final StartupRestoreDiscoveryResult? discovery = _restoreGateDiscovery;
    if (discovery != null && discovery.isLocalBackup) {
      await _restoreLocalBackup(discovery);
      return;
    }
    final BootstrapCloudService? cloudBackupController =
        _dependencies.cloudBackupController;
    if (cloudBackupController == null) {
      await _enterShellAfterRestore(
        generation: _generation,
      );
      return;
    }
    _setPhase(BootstrapPhase.loading, loadingMessage: 'restoring_cloud_backup');
    final bool ok = await cloudBackupController.restoreLatestBackup();
    if (!ok) {
      _setPhase(BootstrapPhase.restoreGate, loadingMessage: cloudBackupController.statusMessage);
      return;
    }
    await _enterShellAfterRestore(
      generation: _generation,
    );
  }

  Future<void> _restoreLocalBackup(
    StartupRestoreDiscoveryResult discovery,
  ) async {
    final BackupPreview? preview = discovery.preview;
    if (preview == null || preview.rawJson.trim().isEmpty) {
      _setPhase(BootstrapPhase.restoreGate, loadingMessage: discovery.message);
      _setRestoreGateDiscovery(
        discovery.copyWith(error: 'Local backup preview is missing.'),
      );
      return;
    }

    _setPhase(BootstrapPhase.loading, loadingMessage: discovery.message);
    try {
      final BackupRestoreService restoreService = BackupRestoreService(
        controller: _dependencies.appStateController,
      );
      final String startupUserId = _startupUserId();
      await restoreService.restoreReplace(
        preview.rawJson,
        allowWhenLocalDataExists: true,
        expectedUserId: startupUserId.isEmpty ? null : startupUserId,
      );
      await _enterShellAfterRestore(
        generation: _generation,
      );
    } catch (error, stackTrace) {
      debugPrint('Local backup restore failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setPhase(BootstrapPhase.restoreGate, loadingMessage: discovery.message);
      _setRestoreGateDiscovery(discovery.copyWith(error: error.toString()));
    }
  }

  Future<void> startFresh() async {
    final AppStateController appStateController = _dependencies.appStateController;
    final AuthController authController = _dependencies.authController;
    final BootstrapCloudService? cloudBackupController =
        _dependencies.cloudBackupController;
    final UserProfile? user = authController.currentUser;
    if (user == null) {
      _setPhase(BootstrapPhase.signedOut);
      return;
    }
    final bool shouldLock = appStateController.state.biometricLockEnabled;
    cloudBackupController?.completeStartupRestoreDiscovery();
    await appStateController.markRestorePromptDismissedForCurrentUser(
      userId: user.id,
    );
    if (!shouldLock) {
      await appStateController.startMarketAutoRefresh();
    }
    if (shouldLock) {
      _lockReason = LockReason.resumeTimeout;
      _lockScreenAutoPrompt = true;
      _setPhase(BootstrapPhase.locked);
    } else {
      _setPhase(BootstrapPhase.ready);
    }
    if (cloudBackupController != null) {
      unawaited(cloudBackupController.activateAfterBootstrap());
    }
  }

  Future<void> openBackupSync() async {
    final AppStateController appStateController = _dependencies.appStateController;
    final AuthController authController = _dependencies.authController;
    final BootstrapCloudService? cloudBackupController =
        _dependencies.cloudBackupController;
    final UserProfile? user = authController.currentUser;
    if (user == null) {
      _setPhase(BootstrapPhase.signedOut);
      return;
    }
    cloudBackupController?.completeStartupRestoreDiscovery();
    _lockReason = appStateController.state.biometricLockEnabled ? LockReason.resumeTimeout : null;
    _lockScreenAutoPrompt = appStateController.state.biometricLockEnabled;
    _setPhase(
      appStateController.state.biometricLockEnabled
          ? BootstrapPhase.locked
          : BootstrapPhase.ready,
    );
    if (cloudBackupController != null) {
      unawaited(cloudBackupController.activateAfterBootstrap());
    }
    if (!appStateController.state.biometricLockEnabled) {
      await appStateController.startMarketAutoRefresh();
    }
  }

  Future<void> _refreshAfterLongInactive() async {
    final AppStateController appStateController = _dependencies.appStateController;
    final UserProfile? user = _dependencies.authController.currentUser;
    if (user == null) {
      return;
    }
    try {
      await appStateController.loadAuthenticated(user.id);
      if (!appStateController.enableMarketAutoRefresh) {
        return;
      }
      await appStateController.startMarketAutoRefresh();
    } catch (error, stackTrace) {
      debugPrint('Long-inactive reload failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return;
    }
  }

  String _startupUserId() {
    final String authUserId = _dependencies.authController.currentUser?.id.trim() ?? '';
    if (authUserId.isNotEmpty) {
      return authUserId;
    }
    return _dependencies.appStateController.state.userId?.trim() ?? '';
  }

  static int _autoLockDelaySeconds(String delay) {
    return switch (delay) {
      'immediate' => 0,
      '30_seconds' => 30,
      '5_minutes' => 300,
      _ => 60,
    };
  }

  Future<void> _enterShellAfterRestore({
    required int generation,
  }) async {
    if (!_isCurrentGeneration(generation)) {
      return;
    }
    final AppStateController appStateController = _dependencies.appStateController;
    final BootstrapCloudService? cloudBackupController =
        _dependencies.cloudBackupController;
    final UserProfile? user = _dependencies.authController.currentUser;
    if (user == null) {
      _setPhase(BootstrapPhase.signedOut);
      return;
    }
    cloudBackupController?.completeStartupRestoreDiscovery();
    if (appStateController.state.biometricLockEnabled) {
      _lockReason = LockReason.resumeTimeout;
      _lockScreenAutoPrompt = true;
      _setPhase(BootstrapPhase.locked);
    } else {
      _setPhase(BootstrapPhase.ready);
      await appStateController.startMarketAutoRefresh();
    }
    if (cloudBackupController != null) {
      await cloudBackupController.activateAfterBootstrap();
    }
    _initialBootstrapComplete = true;
  }

  Future<void> _routeToSignedOut() async {
    final AppStateController appStateController = _dependencies.appStateController;
    final BootstrapCloudService? cloudBackupController =
        _dependencies.cloudBackupController;
    cloudBackupController?.completeStartupRestoreDiscovery();
    await appStateController.resetForSignedOutUser();
    _setPhase(BootstrapPhase.signedOut);
    _pausedAt = null;
    _pendingAuthenticatedUser = null;
    _pendingBootstrapRequest = null;
    _pendingUri = null;
    _lockReason = null;
    _lockScreenAutoPrompt = false;
    BiometricService.lockSensitiveSession();
    _protectedBootstrapFuture = null;
    _protectedBootstrapUserId = null;
    _protectedBootstrapGeneration = null;
    _initialBootstrapComplete = true;
  }

  bool _requiresEmailVerification(UserProfile user) {
    return user.provider == 'email' && !user.emailVerified;
  }

  Future<void> _routeToEmailVerification(UserProfile user) async {
    final AppStateController appStateController = _dependencies.appStateController;
    final BootstrapCloudService? cloudBackupController =
        _dependencies.cloudBackupController;
    cloudBackupController?.completeStartupRestoreDiscovery();
    await appStateController.resetForSignedOutUser();
    _setPhase(BootstrapPhase.emailVerification);
    _pausedAt = null;
    _pendingAuthenticatedUser = null;
    _pendingBootstrapRequest = null;
    _pendingUri = null;
    _lockReason = null;
    _lockScreenAutoPrompt = false;
    BiometricService.lockSensitiveSession();
    _protectedBootstrapFuture = null;
    _protectedBootstrapUserId = null;
    _protectedBootstrapGeneration = null;
    _initialBootstrapComplete = true;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _authGateSubscription?.cancel();
    super.dispose();
  }
}
