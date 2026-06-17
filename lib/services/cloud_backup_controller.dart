import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/backup_preview.dart';
import '../models/user_profile.dart';
import 'app_state_controller.dart';
import 'auth_controller.dart';
import 'backup_restore_service.dart';
import 'backup_service.dart';
import 'google_drive_service.dart';

class CloudBackupController extends ChangeNotifier with WidgetsBindingObserver {
  CloudBackupController({
    required this.appStateController,
    required this.authController,
    GoogleDriveService? googleDriveService,
    BackupRestoreService? backupRestoreService,
    Duration? autoBackupDelay,
    this._appVersion = '1.0.0+1',
  }) : _googleDriveService = googleDriveService ?? GoogleDriveService(),
       _backupRestoreService =
           backupRestoreService ??
           BackupRestoreService(controller: appStateController),
       _autoBackupDelay = autoBackupDelay ?? const Duration(minutes: 3) {
    appStateController.addListener(_onAppStateChanged);
    authController.addListener(_onAuthChanged);
    WidgetsBinding.instance.addObserver(this);
    _onAuthChanged();
  }

  final AppStateController appStateController;
  final AuthController authController;
  final GoogleDriveService _googleDriveService;
  final BackupRestoreService _backupRestoreService;
  final Duration _autoBackupDelay;
  final String _appVersion;

  Timer? _autoBackupTimer;
  bool _suppressNextAutoBackup = false;
  bool _isChecking = false;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _pendingRestorePrompt = false;
  bool _hasPendingAutoBackup = false;
  bool _cloudBackupNewerThanLocal = false;
  bool _backupOwnershipMismatch = false;
  String? _lastObservedStateHash;
  String? _lastSignedInUserId;
  Future<void>? _refreshCloudStateInFlight;
  String _statusMessage = '';
  String _lastError = '';
  DriveBackupFile? _latestBackup;

  bool get isChecking => _isChecking;
  bool get isBackingUp => _isBackingUp;
  bool get isRestoring => _isRestoring;
  bool get hasCloudBackup => _latestBackup != null;
  bool get hasPendingAutoBackup => _hasPendingAutoBackup;
  bool get shouldPromptRestore => _pendingRestorePrompt;
  bool get cloudBackupNewerThanLocal => _cloudBackupNewerThanLocal;
  bool get backupOwnershipMismatch => _backupOwnershipMismatch;
  String get statusMessage => _statusMessage;
  String get lastError => _lastError;
  DriveBackupFile? get latestBackup => _latestBackup;
  Duration get autoBackupDelay => _autoBackupDelay;

  Future<void> refreshCloudState({bool evaluatePrompt = true}) async {
    if (_accessToken == null || _accessToken!.isEmpty) {
      _latestBackup = null;
      _pendingRestorePrompt = false;
      _cloudBackupNewerThanLocal = false;
      _backupOwnershipMismatch = false;
      _statusMessage = '';
      notifyListeners();
      return;
    }
    if (_refreshCloudStateInFlight != null) {
      await _refreshCloudStateInFlight;
      if (evaluatePrompt) {
        _pendingRestorePrompt = _shouldPromptRestoreAfterSignIn(_latestBackup);
        notifyListeners();
      }
      return;
    }

    final Future<void> refreshFuture = _performRefreshCloudState(
      evaluatePrompt: evaluatePrompt,
    );
    _refreshCloudStateInFlight = refreshFuture;
    await refreshFuture;
  }

  Future<void> _performRefreshCloudState({required bool evaluatePrompt}) async {
    _isChecking = true;
    _statusMessage = 'Checking cloud backup...';
    notifyListeners();
    try {
      if (!await authController.ensureSession()) {
        debugPrint(
          'CloudBackupController.refreshCloudState: ensureSession failed',
        );
        _statusMessage = 'Session expired. Please sign in again.';
        return;
      }
      final String? accessToken = _accessToken;
      if (accessToken == null) return;

      _latestBackup = await _googleDriveService.fetchLatestBackup(accessToken);
      _backupOwnershipMismatch =
          _latestBackup != null && !_isBackupOwnedByCurrentUser(_latestBackup);
      _cloudBackupNewerThanLocal = _isCloudNewerThanLocal(_latestBackup);
      if (_latestBackup == null) {
        _statusMessage = 'No cloud backup found.';
      } else if (_backupOwnershipMismatch) {
        _statusMessage = 'This backup belongs to another account.';
      } else if (_cloudBackupNewerThanLocal) {
        _statusMessage = 'Cloud backup available and newer than local data.';
      } else {
        _statusMessage = 'Cloud backup available.';
      }
      if (evaluatePrompt) {
        _pendingRestorePrompt = _shouldPromptRestoreAfterSignIn(_latestBackup);
      }
    } catch (error) {
      _lastError = error.toString();
      _statusMessage = 'Failed to check cloud backup.';
    } finally {
      _isChecking = false;
      _refreshCloudStateInFlight = null;
      notifyListeners();
    }
  }

  Future<bool> backupNow({
    bool forceIfCloudNewer = false,
    bool automatic = false,
  }) async {
    if (_accessToken == null || _accessToken!.isEmpty) {
      _statusMessage = 'Sign in to use Google Drive backup.';
      notifyListeners();
      return false;
    }
    final UserProfile? currentUser = authController.currentUser;
    if (currentUser == null || currentUser.id.trim().isEmpty) {
      _statusMessage = 'Sign in to use Google Drive backup.';
      notifyListeners();
      return false;
    }
    if (automatic &&
        !BackupService.hasData(appStateController.state.toJson())) {
      return false;
    }
    if (_isBackingUp || _isRestoring) return false;

    if (_latestBackup != null &&
        _isCloudNewerThanLocal(_latestBackup) &&
        !forceIfCloudNewer) {
      _statusMessage =
          'Cloud backup is newer than local data. Restore or confirm overwrite.';
      notifyListeners();
      return false;
    }

    _isBackingUp = true;
    _lastError = '';
    _statusMessage = automatic
        ? 'Auto backup in progress...'
        : 'Backup in progress...';
    notifyListeners();

    try {
      if (!await authController.ensureSession()) {
        debugPrint('CloudBackupController.backupNow: ensureSession failed');
        _statusMessage = 'Session expired. Please sign in again.';
        return false;
      }
      final String? accessToken = _accessToken;
      if (accessToken == null) return false;

      final DateTime now = DateTime.now().toUtc();
      final DateTime createdAt = _latestBackup?.backupCreatedAt ?? now;
      final Map<String, dynamic> appState = appStateController.state.toJson();
      final String payload = BackupService.exportBackup(
        appState,
        userId: currentUser.id,
        provider: currentUser.provider,
        email: currentUser.email,
        cloudBackupMetadata: <String, dynamic>{
          'createdAt': createdAt.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'devicePlatform': defaultTargetPlatform.name,
          'appVersion': _appVersion,
        },
      );
      final DriveBackupFile? uploaded = await _googleDriveService.uploadBackup(
        jsonString: payload,
        accessToken: accessToken,
      );
      if (uploaded == null) {
        _statusMessage = 'Cloud backup failed.';
        _lastError = 'upload_failed';
        return false;
      }

      _latestBackup = uploaded;
      _backupOwnershipMismatch = false;
      _hasPendingAutoBackup = false;
      _autoBackupTimer?.cancel();
      _cloudBackupNewerThanLocal = false;
      _statusMessage = automatic
          ? 'Auto backup complete.'
          : 'Cloud backup completed.';
      return true;
    } catch (error) {
      _lastError = error.toString();
      _statusMessage = 'Cloud backup failed.';
      return false;
    } finally {
      _isBackingUp = false;
      notifyListeners();
    }
  }

  Future<BackupPreview?> previewLatestBackup() async {
    final DriveBackupFile? latest = _latestBackup;
    if (latest == null || _accessToken == null || _accessToken!.isEmpty) {
      debugPrint(
        'CloudBackupController.previewLatestBackup: latest=$latest, accessToken=$_accessToken',
      );
      return null;
    }
    if (!await authController.ensureSession()) return null;
    final String? accessToken = _accessToken;
    if (accessToken == null) return null;

    final String? rawJson =
        latest.rawJson ??
        await _googleDriveService.downloadBackupContent(
          accessToken: accessToken,
          fileId: latest.id,
        );
    if (rawJson == null) return null;
    return BackupService.parseBackupPreview(rawJson);
  }

  Future<bool> restoreLatestBackup({bool allowOverwrite = true}) async {
    final DriveBackupFile? latest = _latestBackup;
    if (latest == null || _accessToken == null || _accessToken!.isEmpty) {
      debugPrint(
        'CloudBackupController.restoreLatestBackup: latest=$latest, accessToken=$_accessToken',
      );
      _statusMessage = 'No cloud backup found.';
      notifyListeners();
      return false;
    }
    if (_backupOwnershipMismatch) {
      _statusMessage = 'This backup belongs to another account.';
      notifyListeners();
      return false;
    }
    if (_isRestoring || _isBackingUp) {
      debugPrint(
        'CloudBackupController.restoreLatestBackup: blocked isRestoring=$_isRestoring, isBackingUp=$_isBackingUp',
      );
      return false;
    }

    _isRestoring = true;
    _lastError = '';
    _statusMessage = 'Restore in progress...';
    notifyListeners();
    try {
      if (!await authController.ensureSession()) {
        debugPrint(
          'CloudBackupController.restoreLatestBackup: ensureSession failed',
        );
        _statusMessage = 'Session expired. Please sign in again.';
        return false;
      }
      final String? accessToken = _accessToken;
      if (accessToken == null) return false;

      final String? rawJson =
          latest.rawJson ??
          await _googleDriveService.downloadBackupContent(
            accessToken: accessToken,
            fileId: latest.id,
          );
      if (rawJson == null) {
        _statusMessage = 'No cloud backup found.';
        return false;
      }
      _suppressNextAutoBackup = true;
      await _backupRestoreService.restoreReplace(
        rawJson,
        allowWhenLocalDataExists: allowOverwrite,
        expectedUserId: authController.currentUser?.id,
      );
      final String? currentUserId = authController.currentUser?.id;
      if (currentUserId != null && currentUserId.trim().isNotEmpty) {
        await appStateController.clearRestorePromptDismissedForCurrentUser(
          userId: currentUserId,
        );
      }
      _pendingRestorePrompt = false;
      _hasPendingAutoBackup = false;
      _autoBackupTimer?.cancel();
      _cloudBackupNewerThanLocal = false;
      _backupOwnershipMismatch = false;
      _statusMessage = 'Cloud restore completed.';
      _lastObservedStateHash = _stateHash(appStateController.state.toJson());
      return true;
    } catch (error) {
      _lastError = error.toString();
      _statusMessage = 'Cloud restore failed.';
      return false;
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  void dismissRestorePrompt() {
    if (!_pendingRestorePrompt) return;
    _pendingRestorePrompt = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _autoBackupTimer?.cancel();
    appStateController.removeListener(_onAppStateChanged);
    authController.removeListener(_onAuthChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (_suppressNextAutoBackup) {
      _suppressNextAutoBackup = false;
      return;
    }
    if (_accessToken == null || _isRestoring) return;
    final Map<String, dynamic> stateJson = appStateController.state.toJson();
    if (!BackupService.hasData(stateJson)) return;
    final String hash = _stateHash(stateJson);
    if (hash == _lastObservedStateHash) return;
    _lastObservedStateHash = hash;
    _hasPendingAutoBackup = true;
    _autoBackupTimer?.cancel();
    _autoBackupTimer = Timer(_autoBackupDelay, () {
      unawaited(backupNow(automatic: true));
    });
    notifyListeners();
  }

  void _onAuthChanged() {
    final String? currentUserId = authController.currentUser?.id;
    if (currentUserId == _lastSignedInUserId) return;
    _lastSignedInUserId = currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) {
      _autoBackupTimer?.cancel();
      _hasPendingAutoBackup = false;
      _latestBackup = null;
      _pendingRestorePrompt = false;
      _cloudBackupNewerThanLocal = false;
      _statusMessage = '';
      notifyListeners();
      return;
    }
    unawaited(refreshCloudState(evaluatePrompt: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_hasPendingAutoBackup) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _autoBackupTimer?.cancel();
      unawaited(backupNow(automatic: true));
    }
  }

  bool _shouldPromptRestoreAfterSignIn(DriveBackupFile? latest) {
    if (latest == null) return false;
    if (_backupOwnershipMismatch) return false;
    if (BackupService.hasData(appStateController.state.toJson())) return false;
    final String? dismissedUserId =
        appStateController.state.restorePromptDismissedUserId;
    final String? currentUserId = authController.currentUser?.id;
    if (dismissedUserId != null &&
        currentUserId != null &&
        dismissedUserId == currentUserId) {
      return false;
    }
    return true;
  }

  bool _isCloudNewerThanLocal(DriveBackupFile? latest) {
    if (latest == null) return false;
    final DateTime? cloudUpdatedAt = latest.effectiveUpdatedAt;
    final String localRaw = appStateController.state.lastModifiedAt.trim();
    final DateTime? localUpdatedAt = localRaw.isEmpty
        ? null
        : DateTime.tryParse(localRaw)?.toUtc();
    if (cloudUpdatedAt == null) return false;
    if (localUpdatedAt == null) return true;
    return cloudUpdatedAt.isAfter(localUpdatedAt);
  }

  String _stateHash(Map<String, dynamic> json) => jsonEncode(json);

  String? get _accessToken => authController.currentUser?.accessToken;

  bool _isBackupOwnedByCurrentUser(DriveBackupFile? latest) {
    final UserProfile? currentUser = authController.currentUser;
    if (latest == null || currentUser == null) return false;
    final String ownerId = (latest.userId ?? '').trim();
    return ownerId.isEmpty || ownerId == currentUser.id;
  }
}
