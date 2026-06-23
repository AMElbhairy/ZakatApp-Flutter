import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/backup_preview.dart';
import '../data/local/app_database.dart';
import 'backup_key_manager.dart';
import 'app_state_controller.dart';
import 'auth_controller.dart';
import 'sync/cloud_sync_manager.dart';
import 'sync/cloud_sync_manifest.dart';
import 'sync/google_drive_storage_provider.dart';
import 'sync/snapshot_manager.dart';
import 'sync/sync_encryption_service.dart';
import 'sync/user_cloud_storage_provider.dart';

typedef CloudSyncManagerBuilder = Future<CloudSyncManager?> Function();

class CloudBackupController extends ChangeNotifier with WidgetsBindingObserver {
  CloudBackupController({
    required this.appStateController,
    required this.authController,
    BackupKeyManager? backupKeyManager,
    GoogleSignIn? googleSignIn,
    SnapshotManager? snapshotManager,
    CloudSyncManagerBuilder? cloudSyncManagerBuilder,
    this.debounceDuration = const Duration(seconds: 4),
    this.nowProvider = DateTime.now,
  })  : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: const <String>['profile', 'email'],
            ),
        _snapshotManager = snapshotManager ??
            SnapshotManager(
              encryptionService: SyncEncryptionService(),
            ),
        backupKeyManager =
            backupKeyManager ??
                BackupKeyManager(
                  secureStorageService: appStateController.secureStorageService,
                ),
        _cloudSyncManagerBuilder = cloudSyncManagerBuilder {
    appStateController.addListener(_onSourceChanged);
    authController.addListener(_onSourceChanged);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadSettings());
  }

  final AppStateController appStateController;
  final AuthController authController;
  final BackupKeyManager backupKeyManager;
  final GoogleSignIn _googleSignIn;
  final SnapshotManager _snapshotManager;
  final CloudSyncManagerBuilder? _cloudSyncManagerBuilder;
  final Duration debounceDuration;
  final DateTime Function() nowProvider;

  bool _autoBackupEnabled = false;
  int _minimumIntervalHours = 6;
  DateTime? _lastBackupAt;
  DateTime? _nextEligibleBackupAt;
  String _lastBackupStatus = '';
  String _lastBackupError = '';
  String? _backupPassphrase;
  String? _lastObservedStateStamp;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _pendingAutoBackup = false;
  Timer? _debounceTimer;
  Timer? _eligibleTimer;
  Timer? _retryTimer;
  int _retryCount = 0;
  SnapshotEntry? _latestSnapshot;
  BackupPreview? _latestPreview;
  String _statusMessage = 'Not connected';

  static const List<int> _allowedIntervals = <int>[6, 12];

  bool get isChecking => false;
  bool get isBackingUp => _isBackingUp;
  bool get isRestoring => _isRestoring || appStateController.isRestoringDatabase;
  bool get hasCloudBackup => _lastBackupAt != null || _latestSnapshot != null;
  bool get hasPendingAutoBackup => _pendingAutoBackup || _debounceTimer != null;
  bool get shouldPromptRestore => false;
  BackupPreview? get latestBackup => _latestPreview;
  bool get cloudBackupNewerThanLocal => false;
  bool get backupOwnershipMismatch => false;

  bool get automaticBackupEnabled => _autoBackupEnabled;
  int get minimumIntervalHours => _minimumIntervalHours;
  DateTime? get lastBackupAt => _lastBackupAt;
  DateTime? get nextEligibleBackupAt => _nextEligibleBackupAt;
  String get lastBackupStatus => _lastBackupStatus;
  String get lastBackupError => _lastBackupError;
  String get statusMessage => _statusMessage;
  String get currentStatus =>
      _statusMessage.isNotEmpty ? _statusMessage : 'Cloud Sync: Active';

  Duration get autoBackupDelay => debounceDuration;

  Future<void> refreshCloudState({bool evaluatePrompt = true}) async {
    await _loadSettings();
    await _refreshRemoteState();
    if (evaluatePrompt) {
      _maybeScheduleAutoBackup(reason: 'refresh');
    }
    notifyListeners();
  }

  Future<void> setAutomaticBackupEnabled(bool enabled) async {
    _autoBackupEnabled = enabled;
    await _saveSettings();
    notifyListeners();
    if (enabled) {
      _maybeScheduleAutoBackup(reason: 'setting_enabled');
    } else {
      _cancelTimers();
    }
  }

  Future<void> setMinimumIntervalHours(int hours) async {
    final int normalized = _allowedIntervals.contains(hours) ? hours : 6;
    _minimumIntervalHours = normalized;
    await _saveSettings();
    _recalculateNextEligibleTime();
    notifyListeners();
  }

  void setBackupPassphrase(String passphrase) {
    _backupPassphrase = passphrase.trim();
  }

  Future<void> saveBackupPassphrase(String passphrase) async {
    setBackupPassphrase(passphrase);
    await appStateController.secureStorageService.saveBackupPassphrase(
      passphrase,
      userId: appStateController.state.loadedUserId,
    );
  }

  Future<void> loadBackupPassphrase() async {
    final String? saved = await appStateController.secureStorageService
        .loadBackupPassphrase(userId: appStateController.state.loadedUserId);
    if (saved != null && saved.isNotEmpty) {
      _backupPassphrase = saved;
      notifyListeners();
      return;
    }

    try {
      await backupKeyManager.recoverKeyFromFirestore();
    } on BackupKeyRecoveryException catch (error) {
      _setStatus('Backup key recovery failed', error: error.message);
    }

    final Uint8List? key = await backupKeyManager.getExistingKey();
    if (key != null && key.isNotEmpty) {
      _backupPassphrase = base64UrlEncode(key);
      notifyListeners();
    }
  }

  Future<bool> backupNow({
    bool forceIfCloudNewer = false,
    bool automatic = false,
  }) async {
    if (_isBackingUp) {
      _pendingAutoBackup = _pendingAutoBackup || automatic;
      _setStatus(
        'Backup already running',
        error: automatic ? '' : _lastBackupError,
      );
      return false;
    }

    if (isRestoring) {
      _setStatus('Restore in progress', error: '');
      return false;
    }

    _isBackingUp = true;
    _lastBackupError = '';
    _lastBackupStatus = automatic ? 'Backing up automatically...' : 'Backing up...';
    notifyListeners();

    final CloudSyncManager? manager = await _resolveSyncManager();
    if (manager == null) {
      _isBackingUp = false;
      _setStatus('Google Drive is not connected', error: '');
      return false;
    }

    final UserCloudStorageProvider provider = manager.provider;
    final bool connected = await provider.isConnected();
    if (!connected) {
      _isBackingUp = false;
      _setStatus('Google Drive is not connected', error: '');
      return false;
    }

    final String? passphrase = await _resolvePassphrase();
    if (passphrase == null || passphrase.isEmpty) {
      _isBackingUp = false;
      _setStatus(
        'Backup passphrase is required',
        error: 'Enter and save a cloud backup passphrase first.',
      );
      return false;
    }

    manager.setPassphrase(passphrase);
    final AppDatabase? db = appStateController.database;
    if (db == null) {
      _isBackingUp = false;
      _setStatus('Active database is unavailable', error: '');
      return false;
    }

    try {
      final String localChecksum = await _snapshotManager.calculateDatabaseChecksum(
        db: db,
      );

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String userId = (appStateController.state.loadedUserId?.isNotEmpty ?? false)
          ? appStateController.state.loadedUserId!
          : 'default';

      // 1. database checksum has not changed locally since last successful backup
      final String? cachedChecksum = prefs.getString(_prefsKey('last_successful_checksum', userId));
      if (cachedChecksum != null && cachedChecksum == localChecksum) {
        _lastBackupAt = nowProvider().toUtc();
        _recalculateNextEligibleTime();
        _lastBackupError = '';
        _setStatus('Already backed up');
        await _saveSettings();
        if (!automatic) {
          _retryCount = 0;
          _retryTimer?.cancel();
          _retryTimer = null;
        }
        return true;
      }

      final CloudManifest? manifest = await provider.readManifest();
      if (manifest != null) {
        final CloudSyncManifest cloudManifest = CloudSyncManifest.fromJson(
          manifest.content,
        );
        // 2. backup already exists with identical checksum in history
        final bool existsInHistory = cloudManifest.snapshots.any((s) => s.checksum == localChecksum);
        if (existsInHistory) {
          await prefs.setString(_prefsKey('last_successful_checksum', userId), localChecksum);
          _lastBackupAt = nowProvider().toUtc();
          _recalculateNextEligibleTime();
          _lastBackupError = '';
          _setStatus('Already backed up');
          await _saveSettings();
          if (!automatic) {
            _retryCount = 0;
            _retryTimer?.cancel();
            _retryTimer = null;
          }
          return true;
        }
      }

      // 3. On manifest conflict, preserve all remote snapshot entries, append the local snapshot only if its checksum/path is not already present, then retry with the latest manifest revision
      CloudSyncResult? result;
      int pushAttempt = 0;
      while (pushAttempt < 3) {
        try {
          result = await manager.pushSnapshot(db: db);
          if (result.status == CloudSyncStatus.success) {
            break;
          } else if (result.status == CloudSyncStatus.conflict) {
            pushAttempt++;
            if (pushAttempt < 3) {
              await Future.delayed(Duration(milliseconds: 200 * pushAttempt));
              continue;
            }
          }
          break;
        } catch (e) {
          if (pushAttempt < 2) {
            pushAttempt++;
            await Future.delayed(Duration(milliseconds: 200 * pushAttempt));
            continue;
          }
          rethrow;
        }
      }

      if (result != null && result.status == CloudSyncStatus.success) {
        _retryCount = 0;
        _retryTimer?.cancel();
        _retryTimer = null;

        await prefs.setString(_prefsKey('last_successful_checksum', userId), localChecksum);
        _lastBackupAt = nowProvider().toUtc();
        _lastBackupStatus = 'Backup completed';
        _lastBackupError = '';
        _recalculateNextEligibleTime();
        await _refreshRemoteState(provider: provider);
        await _saveSettings();
        notifyListeners();
        return true;
      }

      final String errMsg = result?.message ?? 'Backup failed';
      _lastBackupError = errMsg;
      _lastBackupStatus = errMsg;
      await _saveSettings();

      // Background exponential backoff retry for failed automatic backups
      if (automatic) {
        _retryCount++;
        final int delaySec = (30 * (1 << (_retryCount - 1))).clamp(30, 3600);
        _retryTimer?.cancel();
        _retryTimer = Timer(Duration(seconds: delaySec), () async {
          _retryTimer = null;
          await backupNow(automatic: true);
        });
      }

      notifyListeners();
      return false;
    } catch (e) {
      _lastBackupError = e.toString();
      _lastBackupStatus = _lastBackupError;
      await _saveSettings();

      if (automatic) {
        _retryCount++;
        final int delaySec = (30 * (1 << (_retryCount - 1))).clamp(30, 3600);
        _retryTimer?.cancel();
        _retryTimer = Timer(Duration(seconds: delaySec), () async {
          _retryTimer = null;
          await backupNow(automatic: true);
        });
      }

      notifyListeners();
      return false;
    } finally {
      _isBackingUp = false;
      _pendingAutoBackup = false;
      notifyListeners();
      if (_eligibleTimer == null && _autoBackupEnabled) {
        _maybeScheduleAutoBackup(reason: 'post_backup');
      }
    }
  }

  Future<BackupPreview?> previewLatestBackup() async {
    final CloudSyncManager? manager = await _resolveSyncManager();
    if (manager == null) {
      _statusMessage = 'Google Drive is not connected';
      notifyListeners();
      return null;
    }

    final UserCloudStorageProvider provider = manager.provider;
    if (!await provider.isConnected()) {
      _statusMessage = 'Google Drive is not connected';
      notifyListeners();
      return null;
    }

    final CloudManifest? manifest = await provider.readManifest();
    if (manifest == null) {
      _latestSnapshot = null;
      _latestPreview = null;
      _statusMessage = 'No cloud backup found';
      notifyListeners();
      return null;
    }

    final CloudSyncManifest cloudManifest = CloudSyncManifest.fromJson(
      manifest.content,
    );
    final SnapshotEntry? snapshot = cloudManifest.snapshots.isNotEmpty
        ? cloudManifest.snapshots.last
        : null;
    _latestSnapshot = snapshot;
    _statusMessage = _lastBackupStatus.isNotEmpty
        ? _lastBackupStatus
        : 'Cloud Sync: Active';

    if (snapshot == null) {
      _latestPreview = null;
      notifyListeners();
      return null;
    }

    _latestPreview = BackupPreview(
      exportedAt: snapshot.createdAt.toIso8601String(),
      schemaOrVersion: 'schemaVersion=${snapshot.databaseSchemaVersion}',
      isLegacy: false,
      sourceType: 'cloud_drive',
      transactionsCount: 0,
      savingsCount: 0,
      investmentsCount: 0,
      recurringTransactionsCount: 0,
      financialPlansCount: 0,
      hasMarketData: false,
      warnings: <String>[
        'Cloud backup sequence #${snapshot.sequence} from ${snapshot.deviceName.isEmpty ? 'Unknown device' : snapshot.deviceName}.',
      ],
      unsupportedFields: const <String>[],
      canRestore: true,
      rawJson: '',
      backupVersion: snapshot.databaseSchemaVersion,
      backupUserId: snapshot.deviceId,
      backupProvider: 'google_drive',
      backupEmail: null,
    );
    notifyListeners();
    return _latestPreview;
  }

  Future<bool> restoreLatestBackup({bool allowOverwrite = true}) async {
    final String? passphrase = await _resolvePassphrase(createIfMissing: false);
    if (passphrase == null || passphrase.isEmpty) {
      _setStatus(
        'Backup passphrase is required',
        error: 'Enter and save a cloud backup passphrase first.',
      );
      return false;
    }

    final CloudSyncManager? manager = await _resolveSyncManager();
    if (manager == null) {
      _setStatus('Google Drive is not connected', error: '');
      return false;
    }

    final UserCloudStorageProvider provider = manager.provider;
    if (!await provider.isConnected()) {
      _setStatus('Google Drive is not connected', error: '');
      return false;
    }

    manager.setPassphrase(passphrase);
    _isRestoring = true;
    _setStatus('Restoring cloud backup...');

    final String targetPath =
        '${Directory.systemTemp.path}/cloud_restore_${DateTime.now().millisecondsSinceEpoch}.sqlite';
    try {
      final CloudSyncResult pullResult = await manager.pullAndRestore(
        targetPath: targetPath,
        localSchemaVersion: appStateController.database?.schemaVersion,
      );
      if (pullResult.status != CloudSyncStatus.success) {
        _setStatus(
          pullResult.message,
          error: pullResult.message,
        );
        return false;
      }

      await appStateController.replaceActiveDatabaseWithRestoredFile(targetPath);
      final File restoredFile = File(targetPath);
      if (await restoredFile.exists()) {
        await restoredFile.delete();
      }

      _setStatus('Restore completed');
      await _refreshRemoteState(provider: provider);
      return true;
    } catch (e) {
      _setStatus('Restore failed', error: e.toString());
      return false;
    } finally {
      _isRestoring = false;
      final File restoredFile = File(targetPath);
      if (await restoredFile.exists()) {
        try {
          await restoredFile.delete();
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  void dismissRestorePrompt() {
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelTimers();
    appStateController.removeListener(_onSourceChanged);
    authController.removeListener(_onSourceChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (! _autoBackupEnabled || isRestoring) {
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _maybeScheduleAutoBackup(reason: 'resumed', onlyIfOverdue: true);
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _maybeScheduleAutoBackup(reason: 'background');
    }
  }

  void _onSourceChanged() {
    final String currentStamp = _currentStateStamp();
    if (currentStamp == _lastObservedStateStamp) {
      return;
    }
    _lastObservedStateStamp = currentStamp;
    if (authController.currentUser == null) {
      _cancelTimers();
      _statusMessage = 'Not connected';
    } else if (_autoBackupEnabled && !isRestoring) {
      _maybeScheduleAutoBackup(reason: 'data_change');
    }
    notifyListeners();
  }

  String _currentStateStamp() {
    final state = appStateController.state;
    return '${state.loadedUserId}|${state.lastModifiedAt}|${state.transactions.length}|${state.savings.length}|${state.investments.length}|${state.pendingTransactions.length}|${state.financialPlans.length}|${state.recurringTransactions.length}';
  }

  void _maybeScheduleAutoBackup({
    required String reason,
    bool onlyIfOverdue = false,
  }) {
    if (!_autoBackupEnabled || isRestoring || _isBackingUp) {
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, () async {
      _debounceTimer = null;
      final bool due = _isBackupOverdue();
      if (onlyIfOverdue && !due) {
        return;
      }
      if (!due) {
        _pendingAutoBackup = true;
        _scheduleEligibleTimer();
        return;
      }
      await backupNow(automatic: true);
    });
    notifyListeners();
  }

  void _scheduleEligibleTimer() {
    _eligibleTimer?.cancel();
    final DateTime? eligibleAt = _nextEligibleBackupAt;
    if (eligibleAt == null) return;
    final Duration remaining = eligibleAt.difference(nowProvider().toUtc());
    if (remaining.isNegative || remaining == Duration.zero) {
      _pendingAutoBackup = true;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounceDuration, () async {
        _debounceTimer = null;
        await backupNow(automatic: true);
      });
      return;
    }
    _eligibleTimer = Timer(remaining, () async {
      _eligibleTimer = null;
      if (_pendingAutoBackup || _autoBackupEnabled) {
        await backupNow(automatic: true);
      }
    });
  }

  bool _isBackupOverdue() {
    final DateTime now = nowProvider().toUtc();
    final DateTime? eligible = _nextEligibleBackupAt;
    if (eligible == null) return true;
    return !now.isBefore(eligible);
  }

  Future<CloudSyncManager?> _resolveSyncManager() async {
    if (_cloudSyncManagerBuilder != null) {
      return _cloudSyncManagerBuilder();
    }

    final String? deviceId = await _getOrCreateDeviceId();
    if (deviceId == null) {
      return null;
    }

    final String deviceName = Platform.isAndroid
        ? 'Android Device'
        : Platform.isIOS
            ? 'iOS Device'
            : 'Desktop Device';

    final UserCloudStorageProvider provider = GoogleDriveStorageProvider(
      googleSignIn: _googleSignIn,
      getAuthHeaders: () async {
        final headers = await _googleSignIn.currentUser?.authHeaders;
        return headers ?? <String, String>{};
      },
      checkConnected: () async {
        try {
          final bool signedIn = await _googleSignIn.isSignedIn();
          if (!signedIn) {
            await _googleSignIn.signInSilently();
          }
          if (_googleSignIn.currentUser == null) {
            return false;
          }
          return await _hasDrivePermissionGranted();
        } catch (_) {
          return false;
        }
      },
      requestConnect: () async => false,
      requestDisconnect: () async {},
      hasGrantedDriveScope: _hasDrivePermissionGranted,
      setGrantedDriveScope: _setDrivePermissionGranted,
    );

    final CloudSyncManager manager = CloudSyncManager(
      provider: provider,
      snapshotManager: _snapshotManager,
      deviceId: deviceId,
      deviceName: deviceName,
      platform: Platform.operatingSystem,
    );
    return manager;
  }

  Future<String?> _getOrCreateDeviceId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('cloud_backup_device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('cloud_backup_device_id', deviceId);
    }
    return deviceId;
  }

  Future<void> _loadSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String userId = (appStateController.state.loadedUserId?.isNotEmpty ?? false)
        ? appStateController.state.loadedUserId!
        : 'default';
    _autoBackupEnabled =
        prefs.getBool(_prefsKey('auto_enabled', userId)) ?? false;
    _minimumIntervalHours =
        prefs.getInt(_prefsKey('interval_hours', userId)) ?? 6;
    final int? lastBackupMs = prefs.getInt(_prefsKey('last_backup_ms', userId));
    final int? nextBackupMs = prefs.getInt(_prefsKey('next_backup_ms', userId));
    _lastBackupAt = lastBackupMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastBackupMs, isUtc: true);
    _nextEligibleBackupAt = nextBackupMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(nextBackupMs, isUtc: true);
    _lastBackupStatus = prefs.getString(_prefsKey('last_status', userId)) ?? '';
    _lastBackupError = prefs.getString(_prefsKey('last_error', userId)) ?? '';
    _statusMessage = _lastBackupStatus.isNotEmpty
        ? _lastBackupStatus
        : (authController.currentUser == null
            ? 'Not connected'
            : 'Cloud Sync: Active');
    final String? savedPassphrase = prefs.getString(
      _prefsKey('passphrase_hint', userId),
    );
    if (savedPassphrase != null && savedPassphrase.isNotEmpty) {
      _backupPassphrase ??= savedPassphrase;
    }
    _lastObservedStateStamp = _currentStateStamp();
  }

  Future<void> _saveSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String userId = (appStateController.state.loadedUserId?.isNotEmpty ?? false)
        ? appStateController.state.loadedUserId!
        : 'default';
    await prefs.setBool(_prefsKey('auto_enabled', userId), _autoBackupEnabled);
    await prefs.setInt(_prefsKey('interval_hours', userId), _minimumIntervalHours);
    if (_lastBackupAt != null) {
      await prefs.setInt(
        _prefsKey('last_backup_ms', userId),
        _lastBackupAt!.millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(_prefsKey('last_backup_ms', userId));
    }
    if (_nextEligibleBackupAt != null) {
      await prefs.setInt(
        _prefsKey('next_backup_ms', userId),
        _nextEligibleBackupAt!.millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(_prefsKey('next_backup_ms', userId));
    }
    await prefs.setString(_prefsKey('last_status', userId), _lastBackupStatus);
    await prefs.setString(_prefsKey('last_error', userId), _lastBackupError);
  }

  String _prefsKey(String suffix, String userId) {
    return 'cloud_backup_${suffix}_$userId';
  }

  String _drivePermissionKey(String userId) {
    return 'cloud_backup_drive_permission_granted_$userId';
  }

  String _currentPermissionUserId() {
    final String loadedUserId = appStateController.state.loadedUserId?.trim() ?? '';
    if (loadedUserId.isNotEmpty) return loadedUserId;
    final String authUserId = authController.currentUser?.id.trim() ?? '';
    if (authUserId.isNotEmpty) return authUserId;
    return 'default';
  }

  Future<bool> _hasDrivePermissionGranted() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_drivePermissionKey(_currentPermissionUserId())) ?? false;
  }

  Future<void> _setDrivePermissionGranted(bool granted) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String key = _drivePermissionKey(_currentPermissionUserId());
    if (granted) {
      await prefs.setBool(key, true);
    } else {
      await prefs.remove(key);
    }
  }

  void _recalculateNextEligibleTime() {
    if (_lastBackupAt == null) {
      _nextEligibleBackupAt = null;
      return;
    }
    _nextEligibleBackupAt = _lastBackupAt!.add(
      Duration(hours: _minimumIntervalHours),
    );
  }

  void _setStatus(String status, {String? error}) {
    _lastBackupStatus = status;
    _statusMessage = status;
    _lastBackupError = error ?? '';
    notifyListeners();
  }

  Future<String?> _resolvePassphrase({bool createIfMissing = true}) async {
    if (_backupPassphrase != null && _backupPassphrase!.isNotEmpty) {
      return _backupPassphrase;
    }
    try {
      await loadBackupPassphrase();
      if (_backupPassphrase != null && _backupPassphrase!.isNotEmpty) {
        return _backupPassphrase;
      }

      if (!createIfMissing) {
        return null;
      }

      final Uint8List key = await backupKeyManager.getOrCreateKey();
      _backupPassphrase = base64UrlEncode(key);
      return _backupPassphrase;
    } on BackupKeyRecoveryException catch (error) {
      _setStatus('Backup key recovery failed', error: error.message);
      return null;
    }
  }

  void _cancelTimers() {
    _debounceTimer?.cancel();
    _eligibleTimer?.cancel();
    _retryTimer?.cancel();
    _debounceTimer = null;
    _eligibleTimer = null;
    _retryTimer = null;
  }

  Future<void> _refreshRemoteState({
    UserCloudStorageProvider? provider,
  }) async {
    try {
      final CloudSyncManager? manager = provider == null
          ? await _resolveSyncManager()
          : null;
      final UserCloudStorageProvider? activeProvider =
          provider ?? manager?.provider;
      if (activeProvider == null || !await activeProvider.isConnected()) {
        _latestSnapshot = null;
        _latestPreview = null;
        if (authController.currentUser == null) {
          _statusMessage = 'Not connected';
        } else {
          _statusMessage = 'Google Drive is not connected';
        }
        return;
      }

      final CloudManifest? manifest = await activeProvider.readManifest();
      if (manifest == null) {
        _latestSnapshot = null;
        _latestPreview = null;
        if (_lastBackupStatus.isEmpty) {
          _statusMessage = 'Cloud Sync: Active';
        }
        return;
      }

      final CloudSyncManifest cloudManifest = CloudSyncManifest.fromJson(
        manifest.content,
      );
      _latestSnapshot = cloudManifest.snapshots.isNotEmpty
          ? cloudManifest.snapshots.last
          : null;

      if (_latestSnapshot != null) {
        _latestPreview = BackupPreview(
          exportedAt: _latestSnapshot!.createdAt.toIso8601String(),
          schemaOrVersion:
              'schemaVersion=${_latestSnapshot!.databaseSchemaVersion}',
          isLegacy: false,
          sourceType: 'cloud_drive',
          transactionsCount: 0,
          savingsCount: 0,
          investmentsCount: 0,
          recurringTransactionsCount: 0,
          financialPlansCount: 0,
          hasMarketData: false,
          warnings: <String>[
            'Cloud backup sequence #${_latestSnapshot!.sequence} from ${_latestSnapshot!.deviceName.isEmpty ? 'Unknown device' : _latestSnapshot!.deviceName}.',
          ],
          unsupportedFields: const <String>[],
          canRestore: true,
          rawJson: '',
          backupVersion: _latestSnapshot!.databaseSchemaVersion,
          backupUserId: _latestSnapshot!.deviceId,
          backupProvider: 'google_drive',
          backupEmail: null,
        );
      } else {
        _latestPreview = null;
      }

      if (_lastBackupStatus.isEmpty || _lastBackupStatus == 'Cloud Sync: Active') {
        _statusMessage = 'Cloud Sync: Active';
      }
    } catch (_) {
      // Best-effort refresh. Existing status is preserved on transient failures.
    }
  }
}
