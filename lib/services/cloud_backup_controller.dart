import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/backup_preview.dart';
import 'app_state_controller.dart';
import 'auth_controller.dart';
import 'backup_restore_service.dart';
import 'backup_service.dart';
import 'google_drive_service.dart';

class CloudBackupController extends ChangeNotifier {
  CloudBackupController({
    required this.appStateController,
    required this.authController,
    GoogleDriveService? googleDriveService,
    BackupRestoreService? backupRestoreService,
    Duration? autoBackupDelay,
    this._appVersion = '1.0.0+1',
  })  : _googleDriveService = googleDriveService ?? GoogleDriveService(),
        _backupRestoreService =
            backupRestoreService ?? BackupRestoreService(controller: appStateController),
        _autoBackupDelay = autoBackupDelay ?? const Duration(seconds: 4) {
    appStateController.addListener(_onAppStateChanged);
    authController.addListener(_onAuthChanged);
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
  bool _cloudBackupNewerThanLocal = false;
  String? _lastObservedStateHash;
  String? _lastSignedInUserId;
  String _statusMessage = '';
  String _lastError = '';
  DriveBackupFile? _latestBackup;

  bool get isChecking => _isChecking;
  bool get isBackingUp => _isBackingUp;
  bool get isRestoring => _isRestoring;
  bool get hasCloudBackup => _latestBackup != null;
  bool get shouldPromptRestore => _pendingRestorePrompt;
  bool get cloudBackupNewerThanLocal => _cloudBackupNewerThanLocal;
  String get statusMessage => _statusMessage;
  String get lastError => _lastError;
  DriveBackupFile? get latestBackup => _latestBackup;

  Future<void> refreshCloudState({bool evaluatePrompt = true}) async {
    final String? accessToken = _accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      _latestBackup = null;
      _pendingRestorePrompt = false;
      _cloudBackupNewerThanLocal = false;
      _statusMessage = '';
      notifyListeners();
      return;
    }
    if (_isChecking) return;
    _isChecking = true;
    notifyListeners();
    try {
      _latestBackup = await _googleDriveService.fetchLatestBackup(accessToken);
      _cloudBackupNewerThanLocal = _isCloudNewerThanLocal(_latestBackup);
      if (_latestBackup == null) {
        _statusMessage = 'No cloud backup found.';
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
      notifyListeners();
    }
  }

  Future<bool> backupNow({bool forceIfCloudNewer = false, bool automatic = false}) async {
    final String? accessToken = _accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      _statusMessage = 'Sign in to use Google Drive backup.';
      notifyListeners();
      return false;
    }
    if (automatic && !BackupService.hasData(appStateController.state.toJson())) {
      return false;
    }
    if (_isBackingUp || _isRestoring) return false;

    if (_latestBackup != null &&
        _isCloudNewerThanLocal(_latestBackup) &&
        !forceIfCloudNewer) {
      _statusMessage = 'Cloud backup is newer than local data. Restore or confirm overwrite.';
      notifyListeners();
      return false;
    }

    _isBackingUp = true;
    _lastError = '';
    _statusMessage = automatic ? 'Auto backup in progress...' : 'Backup in progress...';
    notifyListeners();

    try {
      final DateTime now = DateTime.now().toUtc();
      final DateTime createdAt = _latestBackup?.backupCreatedAt ?? now;
      final Map<String, dynamic> appState = appStateController.state.toJson();
      final String payload = BackupService.exportBackup(
        appState,
        cloudBackupMetadata: <String, dynamic>{
          'backupVersion': 1,
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
      _cloudBackupNewerThanLocal = false;
      _statusMessage = automatic ? 'Auto backup complete.' : 'Cloud backup completed.';
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
    final String? accessToken = _accessToken;
    if (latest == null || accessToken == null || accessToken.isEmpty) {
      return null;
    }
    final String? rawJson = latest.rawJson ??
        await _googleDriveService.downloadBackupContent(
          accessToken: accessToken,
          fileId: latest.id,
        );
    if (rawJson == null) return null;
    return BackupService.parseBackupPreview(rawJson);
  }

  Future<bool> restoreLatestBackup({bool allowOverwrite = true}) async {
    final DriveBackupFile? latest = _latestBackup;
    final String? accessToken = _accessToken;
    if (latest == null || accessToken == null || accessToken.isEmpty) {
      _statusMessage = 'No cloud backup found.';
      notifyListeners();
      return false;
    }
    if (_isRestoring || _isBackingUp) return false;

    _isRestoring = true;
    _lastError = '';
    _statusMessage = 'Restore in progress...';
    notifyListeners();
    try {
      final String? rawJson = latest.rawJson ??
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
      );
      _pendingRestorePrompt = false;
      _cloudBackupNewerThanLocal = false;
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
    _autoBackupTimer?.cancel();
    _autoBackupTimer = Timer(_autoBackupDelay, () {
      unawaited(backupNow(automatic: true));
    });
  }

  void _onAuthChanged() {
    final String? currentUserId = authController.currentUser?.id;
    if (currentUserId == _lastSignedInUserId) return;
    _lastSignedInUserId = currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) {
      _autoBackupTimer?.cancel();
      _latestBackup = null;
      _pendingRestorePrompt = false;
      _cloudBackupNewerThanLocal = false;
      _statusMessage = '';
      notifyListeners();
      return;
    }
    unawaited(refreshCloudState(evaluatePrompt: true));
  }

  bool _shouldPromptRestoreAfterSignIn(DriveBackupFile? latest) {
    if (latest == null) return false;
    if (BackupService.hasData(appStateController.state.toJson())) return false;
    return true;
  }

  bool _isCloudNewerThanLocal(DriveBackupFile? latest) {
    if (latest == null) return false;
    final DateTime? cloudUpdatedAt = latest.effectiveUpdatedAt;
    final String localRaw = appStateController.state.lastModifiedAt.trim();
    final DateTime? localUpdatedAt = localRaw.isEmpty ? null : DateTime.tryParse(localRaw)?.toUtc();
    if (cloudUpdatedAt == null) return false;
    if (localUpdatedAt == null) return true;
    return cloudUpdatedAt.isAfter(localUpdatedAt);
  }

  String _stateHash(Map<String, dynamic> json) => jsonEncode(json);

  String? get _accessToken => authController.currentUser?.accessToken;
}
