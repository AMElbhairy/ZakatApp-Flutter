import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/backup_preview.dart';
import '../data/local/app_database.dart';
import '../data/local/daos/sync_metadata_dao.dart';
import '../data/local/daos/sync_queue_dao.dart';
import 'backup_key_manager.dart';
import 'app_state_controller.dart';
import 'auth_controller.dart';
import 'backup_service.dart';
import 'sync/cloud_sync_manager.dart';
import 'sync/cloud_sync_manifest.dart';
import 'sync/google_drive_operation_sync_manager.dart';
import 'sync/google_drive_storage_provider.dart';
import 'sync/snapshot_manager.dart';
import 'sync/sync_encryption_service.dart';
import 'sync/user_cloud_storage_provider.dart';
import 'google_sign_in_factory.dart';
import 'startup_restore_discovery.dart';

typedef CloudSyncManagerBuilder = Future<CloudSyncManager?> Function();
typedef GoogleDriveOperationSyncManagerBuilder =
    Future<GoogleDriveOperationSyncManager?> Function();

const bool enableGoogleDriveOperationSync = false;

class CloudBackupController extends ChangeNotifier with WidgetsBindingObserver {
  CloudBackupController({
    required this.appStateController,
    required this.authController,
    BackupKeyManager? backupKeyManager,
    GoogleSignIn? googleSignIn,
    SnapshotManager? snapshotManager,
    this._cloudSyncManagerBuilder,
    this._operationSyncManagerBuilder,
    this.enableOperationSync = enableGoogleDriveOperationSync,
    this.debounceDuration = const Duration(seconds: 4),
    this.nowProvider = DateTime.now,
  }) : _googleSignIn = googleSignIn ?? createAppGoogleSignIn(),
       _snapshotManager =
           snapshotManager ??
           SnapshotManager(encryptionService: SyncEncryptionService()),
       backupKeyManager =
           backupKeyManager ??
           BackupKeyManager(
             secureStorageService: appStateController.secureStorageService,
           ) {
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
  final GoogleDriveOperationSyncManagerBuilder? _operationSyncManagerBuilder;
  final bool enableOperationSync;
  final Duration debounceDuration;
  final DateTime Function() nowProvider;

  bool _autoBackupEnabled = true;
  int _minimumIntervalHours = 3;
  DateTime? _lastBackupAt;
  DateTime? _nextEligibleBackupAt;
  String _lastBackupStatus = '';
  String _lastBackupError = '';
  String? _backupPassphrase;
  String? _backupPassphraseUserId;
  String? _lastObservedStateStamp;
  String? _lastOperationSyncAt;
  String _lastOperationSyncError = '';
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _isOperationSyncing = false;
  bool _pendingAutoBackup = false;
  bool _suppressOperationSyncAfterRestore = false;
  bool _startupRestoreDiscoveryActive = false;
  bool _isDriveConnected = false;
  Timer? _debounceTimer;
  Timer? _eligibleTimer;
  Timer? _retryTimer;
  Timer? _operationSyncTimer;
  int _retryCount = 0;
  SnapshotEntry? _latestSnapshot;
  BackupPreview? _latestPreview;
  String _statusMessage = 'Refreshing backup status...';

  static const List<int> _allowedIntervals = <int>[3, 6, 12];

  bool get isChecking => false;
  bool get isBackingUp => _isBackingUp;
  bool get isRestoring =>
      _isRestoring || appStateController.isRestoringDatabase;
  bool get hasCloudBackup => _lastBackupAt != null || _latestSnapshot != null;
  bool get hasPendingAutoBackup => _pendingAutoBackup || _debounceTimer != null;
  bool get shouldPromptRestore {
    final bool hasRemoteBackup = _latestSnapshot != null;
    if (!hasRemoteBackup) return false;
    return !BackupService.hasData(appStateController.state.toJson());
  }

  BackupPreview? get latestBackup => _latestPreview;
  bool get cloudBackupNewerThanLocal => false;
  bool get backupOwnershipMismatch => false;
  bool get isOperationSyncEnabled => enableOperationSync;
  bool get isOperationSyncing => _isOperationSyncing;
  bool get isDriveConnected => _isDriveConnected;
  String get operationSyncModeLabel => enableOperationSync ? 'On' : 'Off';
  String get operationSyncStatusMessage {
    if (!enableOperationSync) {
      return 'Cloud Sync: Disabled';
    }
    if (_isOperationSyncing) return 'Cloud Sync: Syncing...';
    if (_suppressOperationSyncAfterRestore) {
      return 'Cloud Sync: Waiting for confirmation after restore';
    }
    return 'Cloud Sync: On';
  }

  String? get lastOperationSyncAt => _lastOperationSyncAt;
  String get lastOperationSyncError => _lastOperationSyncError;
  Future<int> pendingOperationCount() async {
    final AppDatabase? db = appStateController.database;
    if (db == null) return 0;
    return SyncQueueDao(db).countQueued();
  }

  bool get automaticBackupEnabled => _autoBackupEnabled;
  int get minimumIntervalHours => _minimumIntervalHours;
  DateTime? get lastBackupAt => _lastBackupAt;
  DateTime? get nextEligibleBackupAt => _nextEligibleBackupAt;
  String get lastBackupStatus => _lastBackupStatus;
  String get lastBackupError => _lastBackupError;
  String get statusMessage => _statusMessage;
  String get currentStatus => _statusMessage.isNotEmpty
      ? _statusMessage
      : (_isDriveConnected
            ? 'Cloud Sync: Active'
            : 'Refreshing backup status...');

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
    final int normalized = _allowedIntervals.contains(hours) ? hours : 3;
    _minimumIntervalHours = normalized;
    await _saveSettings();
    _recalculateNextEligibleTime();
    notifyListeners();
  }

  void setBackupPassphrase(String passphrase) {
    _backupPassphrase = passphrase.trim();
    _backupPassphraseUserId = _currentUserId();
  }

  Future<void> saveBackupPassphrase(String passphrase) async {
    setBackupPassphrase(passphrase);
    await appStateController.secureStorageService.saveBackupPassphrase(
      passphrase,
      userId: _currentUserId(),
    );
  }

  Future<void> loadBackupPassphrase() async {
    final String currentUserId = _currentUserId();
    if (_backupPassphraseUserId != currentUserId) {
      _backupPassphrase = null;
      _backupPassphraseUserId = null;
    }

    try {
      final String? repaired = await _loadPassphraseFromBackupKeyManager(
        currentUserId: currentUserId,
        preferRecovery: true,
      );
      if (repaired != null && repaired.isNotEmpty) {
        _backupPassphrase = repaired;
        _backupPassphraseUserId = currentUserId;
        notifyListeners();
        return;
      }
    } on BackupKeyRecoveryException catch (error) {
      _setStatus('Backup key recovery failed', error: error.message);
    }

    _backupPassphrase = null;
    _backupPassphraseUserId = null;
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
    _lastBackupStatus = automatic
        ? 'Backing up automatically...'
        : 'Backing up...';
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
    _isDriveConnected = true;

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
      final String localChecksum = await _snapshotManager
          .calculateDatabaseChecksum(db: db);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String userId =
          (appStateController.state.loadedUserId?.isNotEmpty ?? false)
          ? appStateController.state.loadedUserId!
          : 'default';

      final CloudManifest? manifest = await provider.readManifest();
      final Set<String> availableSnapshotPaths = manifest == null
          ? <String>{}
          : <String>{
              for (final CloudFileInfo file in await provider.listFiles(
                'snapshots/',
              ))
                file.path,
            };
      final String? cachedChecksum = prefs.getString(
        _prefsKey('last_successful_checksum', userId),
      );
      final bool cachedBackupStillExists =
          manifest != null &&
          manifest.content['snapshots'] is List &&
          CloudSyncManifest.fromJson(manifest.content).snapshots.any(
            (s) =>
                s.checksum == localChecksum &&
                availableSnapshotPaths.contains(s.path),
          );
      if (cachedChecksum != null &&
          cachedChecksum == localChecksum &&
          cachedBackupStillExists) {
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

      if (manifest != null) {
        final CloudSyncManifest cloudManifest = CloudSyncManifest.fromJson(
          manifest.content,
        );
        // 2. backup already exists with identical checksum in history
        final bool existsInHistory = cloudManifest.snapshots.any(
          (s) =>
              s.checksum == localChecksum &&
              availableSnapshotPaths.contains(s.path),
        );
        if (existsInHistory) {
          await prefs.setString(
            _prefsKey('last_successful_checksum', userId),
            localChecksum,
          );
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

        await prefs.setString(
          _prefsKey('last_successful_checksum', userId),
          localChecksum,
        );
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

  Future<bool> syncOperationsNow({bool automatic = false}) async {
    if (!enableOperationSync) {
      _lastOperationSyncError = '';
      return false;
    }
    if (_isOperationSyncing) {
      return false;
    }
    if (isRestoring || appStateController.isRestoringDatabase) {
      _lastOperationSyncError = 'Restore in progress';
      await _saveSettings();
      notifyListeners();
      return false;
    }

    final GoogleDriveOperationSyncManager? manager =
        await _resolveOperationSyncManager();
    if (manager == null) {
      _lastOperationSyncError = 'Google Drive is not connected';
      await _saveSettings();
      notifyListeners();
      return false;
    }

    final String? passphrase = await _resolvePassphrase();
    if (passphrase == null || passphrase.isEmpty) {
      _lastOperationSyncError =
          'Enter and save a cloud backup passphrase first.';
      await _saveSettings();
      notifyListeners();
      return false;
    }

    _isOperationSyncing = true;
    _lastOperationSyncError = '';
    notifyListeners();
    try {
      OperationSyncResult result = await manager.syncNow(
        passphrase: passphrase,
      );
      if (result.status == GoogleDriveOperationSyncStatus.error &&
          _isMacAuthError(result.message)) {
        final String? repaired = await _repairBackupPassphraseFromFirestore();
        if (repaired != null && repaired.isNotEmpty && repaired != passphrase) {
          result = await manager.syncNow(passphrase: repaired);
        }
      }
      final bool succeeded =
          result.status != GoogleDriveOperationSyncStatus.error;
      if (succeeded) {
        _lastOperationSyncAt = nowProvider().toUtc().toIso8601String();
      }
      _lastOperationSyncError = succeeded ? '' : result.message;
      if (_suppressOperationSyncAfterRestore) {
        _suppressOperationSyncAfterRestore = false;
      }
      await _saveSettings();
      notifyListeners();
      return result.status != GoogleDriveOperationSyncStatus.error;
    } on crypto.SecretBoxAuthenticationError {
      _invalidateOperationSyncPassphrase();
      _lastOperationSyncError =
          'Backup passphrase is out of date. Reconnect or restore again.';
      await _saveSettings();
      notifyListeners();
      return false;
    } catch (error) {
      if (_isMacAuthError(error)) {
        _invalidateOperationSyncPassphrase();
        _lastOperationSyncError =
            'Backup passphrase is out of date. Reconnect or restore again.';
        await _saveSettings();
        notifyListeners();
        return false;
      }
      _lastOperationSyncError = error.toString();
      await _saveSettings();
      notifyListeners();
      return false;
    } finally {
      _isOperationSyncing = false;
      notifyListeners();
    }
  }

  void beginStartupRestoreDiscovery() {
    _startupRestoreDiscoveryActive = true;
    _debounceTimer?.cancel();
    _eligibleTimer?.cancel();
    _retryTimer?.cancel();
    _debounceTimer = null;
    _eligibleTimer = null;
    _retryTimer = null;
    _pendingAutoBackup = false;
  }

  void completeStartupRestoreDiscovery() {
    _startupRestoreDiscoveryActive = false;
  }

  Future<StartupRestoreDiscoveryResult> discoverStartupRestore({
    required bool localHasData,
  }) async {
    if (localHasData) {
      _latestSnapshot = null;
      _latestPreview = null;
      completeStartupRestoreDiscovery();
      return const StartupRestoreDiscoveryResult(
        status: StartupRestoreDiscoveryStatus.none,
        message: 'Local data exists',
      );
    }

    final String currentUserId = _currentUserId();
    final String? dismissedUserId =
        appStateController.state.restorePromptDismissedUserId;
    if (dismissedUserId != null && dismissedUserId == currentUserId) {
      _latestSnapshot = null;
      _latestPreview = null;
      completeStartupRestoreDiscovery();
      return const StartupRestoreDiscoveryResult(
        status: StartupRestoreDiscoveryStatus.dismissed,
        message: 'Restore prompt dismissed',
      );
    }

    beginStartupRestoreDiscovery();
    try {
      final CloudSyncManager? manager = await _resolveSyncManager();
      if (manager == null) {
        _latestSnapshot = null;
        _latestPreview = null;
        completeStartupRestoreDiscovery();
        return const StartupRestoreDiscoveryResult(
          status: StartupRestoreDiscoveryStatus.drivePermissionRequired,
          message: 'A backup may exist. Connect Google Drive to check.',
        );
      }

      final UserCloudStorageProvider provider = manager.provider;
      if (!await provider.isConnected()) {
        _latestSnapshot = null;
        _latestPreview = null;
        completeStartupRestoreDiscovery();
        return const StartupRestoreDiscoveryResult(
          status: StartupRestoreDiscoveryStatus.drivePermissionRequired,
          message: 'A backup may exist. Connect Google Drive to check.',
        );
      }

      final CloudManifest? manifestInfo = await provider.readManifest();
      if (manifestInfo == null) {
        _latestSnapshot = null;
        _latestPreview = null;
        completeStartupRestoreDiscovery();
        return const StartupRestoreDiscoveryResult(
          status: StartupRestoreDiscoveryStatus.none,
          message: 'No cloud backup found',
        );
      }

      final CloudSyncManifest cloudManifest = CloudSyncManifest.fromJson(
        manifestInfo.content,
      );
      final SnapshotEntry? snapshot = await _latestAvailableSnapshot(
        provider,
        cloudManifest,
      );
      if (snapshot == null) {
        _latestSnapshot = null;
        _latestPreview = null;
        completeStartupRestoreDiscovery();
        return const StartupRestoreDiscoveryResult(
          status: StartupRestoreDiscoveryStatus.none,
          message: 'No available snapshots registered in manifest.',
        );
      }

      final String? passphrase = await _loadPassphraseFromBackupKeyManager(
        currentUserId: currentUserId,
        preferRecovery: true,
      );
      if (passphrase == null || passphrase.isEmpty) {
        _latestSnapshot = null;
        _latestPreview = null;
        completeStartupRestoreDiscovery();
        return const StartupRestoreDiscoveryResult(
          status: StartupRestoreDiscoveryStatus.keyRecoveryRequired,
          message: BackupKeyRecoveryException.recoveryUnavailableMessage,
          error: BackupKeyRecoveryException.recoveryUnavailableMessage,
        );
      }

      _latestSnapshot = snapshot;
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
      _statusMessage = 'Cloud backup found';
      notifyListeners();
      return StartupRestoreDiscoveryResult(
        status: StartupRestoreDiscoveryStatus.restorePrompt,
        message: 'Cloud backup found. Restore your latest backup?',
        preview: _latestPreview,
      );
    } on BackupKeyRecoveryException catch (error) {
      _latestSnapshot = null;
      _latestPreview = null;
      completeStartupRestoreDiscovery();
      _setStatus('Backup key recovery failed', error: error.message);
      return StartupRestoreDiscoveryResult(
        status: StartupRestoreDiscoveryStatus.keyRecoveryRequired,
        message: error.message,
        error: error.message,
      );
    } catch (error) {
      _latestSnapshot = null;
      _latestPreview = null;
      completeStartupRestoreDiscovery();
      return StartupRestoreDiscoveryResult(
        status: StartupRestoreDiscoveryStatus.none,
        message: error.toString(),
        error: error.toString(),
      );
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
    final SnapshotEntry? snapshot = await _latestAvailableSnapshot(
      provider,
      cloudManifest,
    );
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
        _setStatus(pullResult.message, error: pullResult.message);
        return false;
      }

      await appStateController.replaceActiveDatabaseWithRestoredFile(
        targetPath,
      );
      _suppressOperationSyncAfterRestore = true;
      final File restoredFile = File(targetPath);
      if (await restoredFile.exists()) {
        await restoredFile.delete();
      }

      _setStatus('Restore completed');
      await _refreshRemoteState(provider: provider);
      completeStartupRestoreDiscovery();
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

  Future<void> deleteCloudBackupData() async {
    final CloudSyncManager? manager = await _resolveSyncManager();
    if (manager == null) {
      throw StateError('Google Drive is not connected');
    }

    final UserCloudStorageProvider provider = manager.provider;
    if (!await provider.isConnected()) {
      throw StateError('Google Drive is not connected');
    }

    final List<CloudFileInfo> files = await provider.listFiles('');
    for (final CloudFileInfo file in files) {
      final String path = file.path.trim();
      if (path.isEmpty) continue;
      try {
        await provider.deleteFile(path);
      } catch (_) {
        // Best-effort cleanup continues so account deletion removes as much remote data as possible.
      }
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
    if (!_autoBackupEnabled || isRestoring || _startupRestoreDiscoveryActive) {
      if (!appStateController.isRestoringDatabase) {
        if (state == AppLifecycleState.resumed) {
          _maybeScheduleOperationSync(reason: 'resumed');
        }
      }
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _maybeScheduleAutoBackup(reason: 'resumed', onlyIfOverdue: true);
      if (!_suppressOperationSyncAfterRestore &&
          !appStateController.isRestoringDatabase) {
        _maybeScheduleOperationSync(reason: 'resumed');
      }
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
      _statusMessage = 'Refreshing backup status...';
    } else {
      if (_autoBackupEnabled &&
          !isRestoring &&
          !_startupRestoreDiscoveryActive) {
        _maybeScheduleAutoBackup(reason: 'data_change');
      }
      if (!_suppressOperationSyncAfterRestore &&
          !isRestoring &&
          !appStateController.isRestoringDatabase) {
        _maybeScheduleOperationSync(reason: 'data_change');
      }
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
    if (reason.isEmpty) {
      return;
    }
    if (!_autoBackupEnabled ||
        isRestoring ||
        _isBackingUp ||
        _startupRestoreDiscoveryActive) {
      return;
    }
    final bool hasLocalData = BackupService.hasData(
      appStateController.state.toJson(),
    );
    if (_isDriveConnected &&
        _lastBackupAt == null &&
        hasLocalData &&
        !onlyIfOverdue) {
      unawaited(backupNow(automatic: true));
      notifyListeners();
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

  void _maybeScheduleOperationSync({required String reason}) {
    if (reason.isEmpty) {
      return;
    }
    if (!enableOperationSync) {
      return;
    }
    if (_suppressOperationSyncAfterRestore ||
        isRestoring ||
        _isOperationSyncing) {
      return;
    }
    _operationSyncTimer?.cancel();
    _operationSyncTimer = Timer(debounceDuration, () async {
      _operationSyncTimer = null;
      await syncOperationsNow(automatic: true);
    });
    notifyListeners();
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
          return _googleSignIn.currentUser != null;
        } catch (_) {
          return false;
        }
      },
      requestConnect: () async => false,
      requestDisconnect: () async {},
      hasGrantedDriveScope: _hasDrivePermissionGranted,
      setGrantedDriveScope: _setDrivePermissionGranted,
      namespacePrefix: _currentUserId(),
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

  Future<GoogleDriveOperationSyncManager?>
  _resolveOperationSyncManager() async {
    if (!enableOperationSync) {
      return null;
    }
    if (_operationSyncManagerBuilder != null) {
      return _operationSyncManagerBuilder();
    }

    final AppDatabase? db = appStateController.database;
    if (db == null) {
      return null;
    }

    final CloudSyncManager? backupManager = await _resolveSyncManager();
    final UserCloudStorageProvider? provider = backupManager?.provider;
    if (provider == null) {
      return null;
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

    return GoogleDriveOperationSyncManager(
      provider: provider,
      encryptionService: SyncEncryptionService(),
      syncQueueDao: SyncQueueDao(db),
      syncMetadataDao: SyncMetadataDao(db),
      controller: appStateController,
      deviceId: deviceId,
      deviceName: deviceName,
      appVersion: String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0'),
    );
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
    final String userId =
        (appStateController.state.loadedUserId?.isNotEmpty ?? false)
        ? appStateController.state.loadedUserId!
        : 'default';
    _autoBackupEnabled =
        prefs.getBool(_prefsKey('auto_enabled', userId)) ?? true;
    _minimumIntervalHours =
        prefs.getInt(_prefsKey('interval_hours', userId)) ?? 3;
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
    _lastOperationSyncAt = prefs.getString(
      _prefsKey('last_operation_sync_at', userId),
    );
    _lastOperationSyncError =
        prefs.getString(_prefsKey('last_operation_sync_error', userId)) ?? '';
    _statusMessage = _lastBackupStatus.isNotEmpty
        ? _lastBackupStatus
        : (_isDriveConnected
              ? 'Cloud Sync: Active'
              : 'Refreshing backup status...');
    if (_backupPassphraseUserId != null && _backupPassphraseUserId != userId) {
      _backupPassphrase = null;
      _backupPassphraseUserId = null;
    }
    _lastObservedStateStamp = _currentStateStamp();
  }

  Future<void> _saveSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String userId =
        (appStateController.state.loadedUserId?.isNotEmpty ?? false)
        ? appStateController.state.loadedUserId!
        : 'default';
    await prefs.setBool(_prefsKey('auto_enabled', userId), _autoBackupEnabled);
    await prefs.setInt(
      _prefsKey('interval_hours', userId),
      _minimumIntervalHours,
    );
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
    if (_lastOperationSyncAt != null) {
      await prefs.setString(
        _prefsKey('last_operation_sync_at', userId),
        _lastOperationSyncAt!,
      );
    } else {
      await prefs.remove(_prefsKey('last_operation_sync_at', userId));
    }
    if (_lastOperationSyncError.isNotEmpty) {
      await prefs.setString(
        _prefsKey('last_operation_sync_error', userId),
        _lastOperationSyncError,
      );
    } else {
      await prefs.remove(_prefsKey('last_operation_sync_error', userId));
    }
  }

  String _prefsKey(String suffix, String userId) {
    return 'cloud_backup_${suffix}_$userId';
  }

  String _drivePermissionKey(String userId) {
    return 'cloud_backup_drive_permission_granted_$userId';
  }

  String _currentPermissionUserId() {
    final String loadedUserId =
        appStateController.state.loadedUserId?.trim() ?? '';
    if (loadedUserId.isNotEmpty) return loadedUserId;
    final String authUserId = authController.currentUser?.id.trim() ?? '';
    if (authUserId.isNotEmpty) return authUserId;
    return 'default';
  }

  Future<bool> _hasDrivePermissionGranted() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_drivePermissionKey(_currentPermissionUserId())) ??
        false;
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
    final String currentUserId = _currentUserId();
    if (_backupPassphrase != null &&
        _backupPassphrase!.isNotEmpty &&
        _backupPassphraseUserId == currentUserId) {
      return _backupPassphrase;
    }
    try {
      await loadBackupPassphrase();
      if (_backupPassphrase != null &&
          _backupPassphrase!.isNotEmpty &&
          _backupPassphraseUserId == currentUserId) {
        return _backupPassphrase;
      }

      if (!createIfMissing) {
        return null;
      }

      final Uint8List key = await backupKeyManager.getOrCreateKey();
      _backupPassphrase = base64UrlEncode(key);
      _backupPassphraseUserId = currentUserId;
      return _backupPassphrase;
    } on BackupKeyRecoveryException catch (error) {
      _setStatus('Backup key recovery failed', error: error.message);
      return null;
    }
  }

  String _currentUserId() {
    final String loadedUserId =
        appStateController.state.loadedUserId?.trim() ?? '';
    if (loadedUserId.isNotEmpty) return loadedUserId;
    final String authUserId = authController.currentUser?.id.trim() ?? '';
    if (authUserId.isNotEmpty) return authUserId;
    return 'default';
  }

  void _cancelTimers() {
    _debounceTimer?.cancel();
    _eligibleTimer?.cancel();
    _retryTimer?.cancel();
    _operationSyncTimer?.cancel();
    _debounceTimer = null;
    _eligibleTimer = null;
    _retryTimer = null;
    _operationSyncTimer = null;
  }

  Future<bool> _refreshRemoteState({UserCloudStorageProvider? provider}) async {
    try {
      final CloudSyncManager? manager = provider == null
          ? await _resolveSyncManager()
          : null;
      final UserCloudStorageProvider? activeProvider =
          provider ?? manager?.provider;
      if (activeProvider == null || !await activeProvider.isConnected()) {
        _isDriveConnected = false;
        _latestSnapshot = null;
        _latestPreview = null;
        if (authController.currentUser == null) {
          _statusMessage = 'Refreshing backup status...';
        } else {
          _statusMessage = 'Google Drive is not connected';
        }
        return false;
      }
      _isDriveConnected = true;

      final CloudManifest? manifest = await activeProvider.readManifest();
      if (manifest == null) {
        _latestSnapshot = null;
        _latestPreview = null;
        if (_lastBackupStatus.isEmpty) {
          _statusMessage = 'Cloud Sync: Active';
        }
        return true;
      }

      final CloudSyncManifest cloudManifest = CloudSyncManifest.fromJson(
        manifest.content,
      );
      _latestSnapshot = await _latestAvailableSnapshot(
        activeProvider,
        cloudManifest,
      );

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

      if (_lastBackupStatus.isEmpty ||
          _lastBackupStatus == 'Cloud Sync: Active') {
        _statusMessage = 'Cloud Sync: Active';
      }
      return true;
    } catch (_) {
      // Best-effort refresh. Existing status is preserved on transient failures.
      return _isDriveConnected;
    }
  }

  void _invalidateOperationSyncPassphrase() {
    _backupPassphrase = null;
    _backupPassphraseUserId = null;
  }

  Future<SnapshotEntry?> _latestAvailableSnapshot(
    UserCloudStorageProvider provider,
    CloudSyncManifest manifest,
  ) async {
    final Set<String> availableSnapshotPaths = <String>{
      for (final CloudFileInfo file in await provider.listFiles('snapshots/'))
        file.path,
    };
    for (final SnapshotEntry snapshot in manifest.snapshots.reversed) {
      if (snapshot.path.trim().isEmpty) continue;
      if (availableSnapshotPaths.contains(snapshot.path)) {
        return snapshot;
      }
    }
    return null;
  }

  Future<String?> _loadPassphraseFromBackupKeyManager({
    required String currentUserId,
    required bool preferRecovery,
  }) async {
    if (preferRecovery) {
      try {
        await backupKeyManager.recoverKeyFromFirestore();
      } on BackupKeyRecoveryException {
        // Fall through to existing local key or cached passphrase.
      }
    }

    final Uint8List? key = await backupKeyManager.getExistingKey();
    if (key == null || key.isEmpty) {
      return null;
    }
    final String passphrase = base64UrlEncode(key);
    _backupPassphrase = passphrase;
    _backupPassphraseUserId = currentUserId;
    await appStateController.secureStorageService.saveBackupPassphrase(
      passphrase,
      userId: currentUserId,
    );
    return passphrase;
  }

  Future<String?> _repairBackupPassphraseFromFirestore() async {
    final String currentUserId = _currentUserId();
    try {
      return await _loadPassphraseFromBackupKeyManager(
        currentUserId: currentUserId,
        preferRecovery: true,
      );
    } catch (_) {
      return null;
    }
  }

  bool _isMacAuthError(Object error) {
    final String lower = error.toString().toLowerCase();
    return lower.contains('secretboxauthenticationerror') ||
        lower.contains('mac check failed') ||
        lower.contains('wrong message authentication code');
  }
}
