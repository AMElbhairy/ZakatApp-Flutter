import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/widgets/app_ui.dart';
import '../../services/backup_key_manager.dart';
import '../../services/app_state_controller.dart';
import '../../services/cloud_backup_controller.dart';
import '../../services/google_sign_in_factory.dart';
import '../../services/sync/cloud_sync_manager.dart';
import '../../services/sync/cloud_sync_manifest.dart';
import '../../services/sync/google_drive_storage_provider.dart';
import '../../services/sync/snapshot_manager.dart';
import '../../services/sync/sync_encryption_service.dart';
import '../../services/sync/user_cloud_storage_provider.dart';

class CloudBackupScreen extends StatefulWidget {
  final GoogleSignIn? googleSignIn;
  final CloudSyncManager? syncManager;
  final BackupKeyManager? backupKeyManager;
  final http.Client? driveHttpClient;

  const CloudBackupScreen({
    super.key,
    this.googleSignIn,
    this.syncManager,
    this.backupKeyManager,
    this.driveHttpClient,
  });

  @override
  State<CloudBackupScreen> createState() => _CloudBackupScreenState();
}

class _CloudBackupScreenState extends State<CloudBackupScreen> {
  static const String _localAppVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  late final GoogleSignIn _googleSignIn;

  bool _isConnected = false;
  String? _userEmail;
  bool _busy = false;
  bool _loadingBackups = false;
  bool _isInitializing = true;
  String _statusMessage = 'Refreshing backup status...';

  List<SnapshotEntry> _backups = [];
  Map<String, DeviceMetadata> _knownDevices = {};
  String? _latestSnapshotChecksum;
  int _latestGlobalSequence = 0;
  String? _localChecksum;
  String? _currentDeviceId;
  String? _latestRestoreLocalBackupPath;

  final TextEditingController _passphraseController = TextEditingController();
  final TextEditingController _confirmPassphraseController =
      TextEditingController();
  bool _hasExistingPassphrase = false;
  bool _isChangingPassphrase = false;
  final SyncEncryptionService _encryptionService = SyncEncryptionService();
  Set<String>? _availableSnapshotPaths;

  @override
  void initState() {
    super.initState();
    _googleSignIn = widget.googleSignIn ?? _resolveSharedGoogleSignIn();
    _initStatus();
  }

  GoogleSignIn _resolveSharedGoogleSignIn() {
    try {
      return context.read<GoogleSignIn>();
    } catch (_) {
      return createAppGoogleSignIn();
    }
  }

  @override
  void dispose() {
    _passphraseController.dispose();
    _confirmPassphraseController.dispose();
    super.dispose();
  }

  Future<void> _initStatus() async {
    setState(() {
      _busy = true;
      _isInitializing = true;
      _statusMessage = 'Refreshing backup status...';
    });
    try {
      final bool connected = await _tryAuthorizeDrive(
        interactive: false,
        phase: 'init',
      );
      if (connected) {
        await _loadLocalChecksum();
        await _loadBackupPassphrase();
        await _fetchBackups();
        return;
      }
      setState(() {
        _isConnected = false;
        _userEmail = null;
        _statusMessage = 'Refreshing backup status...';
      });
      await _loadLocalChecksum();
      await _loadBackupPassphrase();
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = _mapErrorToMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _isInitializing = false;
        });
      }
    }
  }

  Future<bool> _tryAuthorizeDrive({
    required bool interactive,
    required String phase,
  }) async {
    final String namespace = _cloudNamespace();
    final provider = GoogleDriveStorageProvider(
      googleSignIn: _googleSignIn,
      getAuthHeaders: () async {
        final headers = await _googleSignIn.currentUser?.authHeaders;
        return headers ?? {};
      },
      checkConnected: () async => _isConnected,
      requestConnect: () async => false,
      requestDisconnect: () async {},
      namespacePrefix: namespace,
      httpClient: widget.driveHttpClient,
    );
    final status = await provider.resolveConnection(
      interactive: interactive,
      phase: phase,
    );
    if (mounted) {
      setState(() {
        _isConnected = status.connected;
        _userEmail = status.accountEmail;
        _statusMessage = status.connected
            ? 'Connected'
            : (status.message ??
                  'Google Drive permission is required for cloud backup.');
      });
    }
    return status.connected;
  }

  Future<void> _loadBackupPassphrase() async {
    String? resolvedSecret;
    try {
      await _backupKeyManager().recoverKeyFromFirestore();
      final Uint8List? recoveredKey = await _backupKeyManager()
          .getExistingKey();
      if (recoveredKey != null && recoveredKey.isNotEmpty) {
        resolvedSecret = base64UrlEncode(recoveredKey);
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _hasExistingPassphrase =
          resolvedSecret != null && resolvedSecret.isNotEmpty;
      _isChangingPassphrase = false;
      if (_hasExistingPassphrase) {
        _passphraseController.text = resolvedSecret!;
      } else {
        _passphraseController.clear();
      }
      _confirmPassphraseController.clear();
    });
  }

  BackupKeyManager _backupKeyManager() {
    return widget.backupKeyManager ??
        BackupKeyManager(
          secureStorageService: context
              .read<AppStateController>()
              .secureStorageService,
        );
  }

  String _drivePermissionPrefsKey() {
    final controller = context.read<AppStateController>();
    final String userId =
        (controller.state.loadedUserId?.trim().isNotEmpty ?? false)
        ? controller.state.loadedUserId!.trim()
        : 'default';
    return 'cloud_backup_drive_permission_granted_$userId';
  }

  Future<bool> _hasDrivePermissionGranted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_drivePermissionPrefsKey()) ?? false;
  }

  Future<void> _setDrivePermissionGranted(bool granted) async {
    final prefs = await SharedPreferences.getInstance();
    if (granted) {
      await prefs.setBool(_drivePermissionPrefsKey(), true);
    } else {
      await prefs.remove(_drivePermissionPrefsKey());
    }
  }

  Future<String?> _resolveOperationSecret({
    bool showDialogOnFailure = true,
    bool allowKeyCreation = true,
  }) async {
    final String manualSecret = _passphraseController.text.trim();
    if (manualSecret.isNotEmpty) {
      return manualSecret;
    }

    try {
      await _backupKeyManager().recoverKeyFromFirestore();
      final Uint8List? recoveredKey = await _backupKeyManager()
          .getExistingKey();
      if (recoveredKey != null && recoveredKey.isNotEmpty) {
        final String encoded = base64UrlEncode(recoveredKey);
        if (mounted) {
          setState(() {
            _passphraseController.text = encoded;
            _hasExistingPassphrase = true;
            _isChangingPassphrase = false;
          });
        }
        return encoded;
      }

      if (!allowKeyCreation || _backups.isNotEmpty) {
        throw const BackupKeyRecoveryException(
          BackupKeyRecoveryException.recoveryUnavailableMessage,
        );
      }

      final Uint8List generatedKey = await _backupKeyManager().getOrCreateKey();
      final String encoded = base64UrlEncode(generatedKey);
      if (mounted) {
        setState(() {
          _passphraseController.text = encoded;
          _hasExistingPassphrase = true;
          _isChangingPassphrase = false;
        });
      }
      return encoded;
    } on BackupKeyRecoveryException catch (error) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Backup key recovery required';
        });
        if (showDialogOnFailure) {
          await _showBlockingDialog(
            title: 'Backup Key Recovery Required',
            message: error.message,
            buttonLabel: 'OK',
          );
        }
      }
      return null;
    }
  }

  bool _isWrongPassphraseError(Object error) {
    final str = error.toString().toLowerCase();
    return str.contains('secretboxauthenticationerror') ||
        str.contains('mac check failed') ||
        str.contains('wrong passphrase') ||
        str.contains('authentication failed');
  }

  bool _isPermissionRevokedError(Object error) {
    final str = error.toString().toLowerCase();
    return str.contains('insufficientpermissions') ||
        (str.contains('403') && str.contains('permission'));
  }

  bool _isNetworkError(Object error) {
    final str = error.toString().toLowerCase();
    return str.contains('socketexception') ||
        str.contains('handshake') ||
        str.contains('network') ||
        str.contains('http') ||
        str.contains('detailedapirequesterror');
  }

  bool _isConflictError(Object error) {
    final str = error.toString().toLowerCase();
    return str.contains('etag') ||
        str.contains('revision mismatch') ||
        str.contains('conflict');
  }

  bool _isMissingSnapshotError(Object error) {
    final str = error.toString().toLowerCase();
    return str.contains('snapshot file') ||
        str.contains('no snapshot files from the manifest') ||
        str.contains('could not be retrieved');
  }

  String _shortChecksum(String checksum) {
    if (checksum.length <= 12) {
      return checksum;
    }
    return '${checksum.substring(0, 12)}...';
  }

  String _formatMaybeDate(DateTime? value) {
    if (value == null) return 'Not available';
    return DateFormat.yMMMd().add_Hm().format(value.toLocal());
  }

  Future<String?> _findLatestLocalRestoreBackupPath(String activeDbPath) async {
    try {
      final directory = Directory(p.dirname(activeDbPath));
      if (!await directory.exists()) {
        return null;
      }
      final baseName = p.basename(activeDbPath);
      final prefix = '$baseName.restore_backup_';

      final files = await directory
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .where((file) {
            final name = p.basename(file.path);
            return name.startsWith(prefix) && name.endsWith('.bak');
          })
          .toList();

      if (files.isEmpty) {
        return null;
      }

      files.sort((a, b) {
        final aTime = a.statSync().modified;
        final bTime = b.statSync().modified;
        return bTime.compareTo(aTime);
      });
      return files.first.path;
    } catch (_) {
      return null;
    }
  }

  CloudBackupController? _maybeBackupController() {
    try {
      return context.read<CloudBackupController>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveBackupPassphrase(String passphrase) async {
    final controller = context.read<AppStateController>();
    final String userId =
        (controller.state.loadedUserId?.trim().isNotEmpty ?? false)
        ? controller.state.loadedUserId!.trim()
        : (controller.state.userId?.trim().isNotEmpty ?? false)
        ? controller.state.userId!.trim()
        : 'default';
    await controller.secureStorageService.saveBackupPassphrase(
      passphrase,
      userId: userId,
    );
  }

  Future<void> _deleteBackupPassphrase() async {
    final controller = context.read<AppStateController>();
    final String userId =
        (controller.state.loadedUserId?.trim().isNotEmpty ?? false)
        ? controller.state.loadedUserId!.trim()
        : (controller.state.userId?.trim().isNotEmpty ?? false)
        ? controller.state.userId!.trim()
        : 'default';
    await controller.secureStorageService.deleteBackupPassphrase(
      userId: userId,
    );
  }

  Future<void> _loadLocalChecksum() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      setState(() {
        _localChecksum = 'mock-local-checksum';
      });
      return;
    }

    try {
      final controller = context.read<AppStateController>();
      final db = controller.database;
      if (db == null) {
        return;
      }

      final tempFile = File(
        '${Directory.systemTemp.path}/temp_chk_${DateTime.now().microsecondsSinceEpoch}.sqlite',
      );
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      await db.customStatement("VACUUM INTO '${tempFile.path}'");
      final bytes = await tempFile.readAsBytes();
      final hash = await crypto.Sha256().hash(bytes);
      final checksum = base64Encode(hash.bytes);

      try {
        await tempFile.delete();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _localChecksum = checksum;
        });
      }
    } catch (_) {
      // Best-effort checksum detection. Restore gating can still proceed.
    }
  }

  String _mapErrorToMessage(Object e) {
    if (_isWrongPassphraseError(e)) {
      return 'Wrong passphrase';
    }
    if (_isPermissionRevokedError(e)) {
      return 'Google Drive permission was revoked. Please reconnect.';
    }
    if (_isNetworkError(e)) {
      return 'Network error';
    }
    if (_isConflictError(e)) {
      return 'Conflict / try again';
    }
    return 'Error: $e';
  }

  UserCloudStorageProvider _getProvider() {
    final String namespace = _cloudNamespace();
    return GoogleDriveStorageProvider(
      googleSignIn: _googleSignIn,
      getAuthHeaders: () async {
        final headers = await _googleSignIn.currentUser?.authHeaders;
        return headers ?? {};
      },
      checkConnected: () async => _isConnected,
      requestConnect: () async {
        await _connect();
        return _isConnected;
      },
      requestDisconnect: () => _disconnect(),
      hasGrantedDriveScope: _hasDrivePermissionGranted,
      setGrantedDriveScope: _setDrivePermissionGranted,
      namespacePrefix: namespace,
      httpClient: widget.driveHttpClient,
    );
  }

  String _cloudNamespace() {
    final controller = context.read<AppStateController>();
    final String loadedUserId =
        controller.state.loadedUserId?.trim().isNotEmpty == true
        ? controller.state.loadedUserId!.trim()
        : '';
    if (loadedUserId.isNotEmpty) {
      return loadedUserId;
    }
    final String authUserId = controller.state.userId?.trim().isNotEmpty == true
        ? controller.state.userId!.trim()
        : '';
    if (authUserId.isNotEmpty) {
      return authUserId;
    }
    return 'default';
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('cloud_backup_device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('cloud_backup_device_id', deviceId);
    }
    return deviceId;
  }

  Future<CloudSyncManager> _getSyncManager() async {
    final passphrase = _passphraseController.text.trim();
    if (widget.syncManager != null) {
      _currentDeviceId = widget.syncManager!.deviceId;
      if (passphrase.isNotEmpty) {
        widget.syncManager!.setPassphrase(passphrase);
      }
      return widget.syncManager!;
    }

    final provider = _getProvider();
    final snapshotManager = SnapshotManager(
      encryptionService: _encryptionService,
    );
    final deviceId = await _getOrCreateDeviceId();
    final deviceName = Platform.isAndroid
        ? 'Android Device'
        : (Platform.isIOS ? 'iOS Device' : 'Desktop Device');

    final syncManager = CloudSyncManager(
      provider: provider,
      snapshotManager: snapshotManager,
      deviceId: deviceId,
      deviceName: deviceName,
      platform: Platform.operatingSystem,
    );

    _currentDeviceId = syncManager.deviceId;

    if (passphrase.isNotEmpty) {
      syncManager.setPassphrase(passphrase);
    }
    return syncManager;
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _statusMessage = 'Connecting...';
    });
    try {
      final bool connected = await _tryAuthorizeDrive(
        interactive: true,
        phase: 'connect',
      );
      if (connected) {
        await _fetchBackups();
        } else if (mounted && _statusMessage == 'Connecting...') {
          setState(() {
            _isConnected = false;
            _statusMessage = 'Refreshing backup status...';
          });
        }
    } catch (e) {
      setState(() {
        if (_isPermissionRevokedError(e)) {
          _isConnected = false;
          _userEmail = null;
        }
        _isConnected = false;
        _statusMessage = _mapErrorToMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _busy = true;
    });
    try {
      await _setDrivePermissionGranted(false);
      await _deleteBackupPassphrase();
      setState(() {
        _isConnected = false;
        _userEmail = null;
        _statusMessage = 'Refreshing backup status...';
        _backups = [];
        _knownDevices = {};
        _latestSnapshotChecksum = null;
        _latestGlobalSequence = 0;
        _hasExistingPassphrase = false;
        _isChangingPassphrase = false;
        _passphraseController.clear();
        _confirmPassphraseController.clear();
      });
    } catch (e) {
      setState(() {
        _statusMessage = _mapErrorToMessage(e);
      });
      await _setDrivePermissionGranted(false);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _fetchBackups() async {
    if (!mounted) return;
    setState(() {
      _loadingBackups = true;
      _availableSnapshotPaths = null;
    });
    try {
      final syncManager = await _getSyncManager();
      final checkResult = await syncManager.checkForUpdates(
        localSequence: 0,
        localChecksum: '',
      );

      if (checkResult.status == CloudSyncStatus.error) {
        if (mounted) {
          setState(() {
            if (_isPermissionRevokedError(checkResult.message)) {
              _isConnected = false;
              _userEmail = null;
            }
            _statusMessage = _mapErrorToMessage(checkResult.message);
          });
        }
        return;
      }

      if (checkResult.manifest != null) {
        final manifest = checkResult.manifest!;
        final remoteFiles = await syncManager.provider.listFiles('snapshots/');
        final availableSnapshotPaths = <String>{
          for (final CloudFileInfo file in remoteFiles) file.path,
        };
        if (!mounted) return;
        setState(() {
          _backups = List<SnapshotEntry>.from(manifest.snapshots);
          _availableSnapshotPaths = availableSnapshotPaths;
          _knownDevices = Map<String, DeviceMetadata>.from(
            manifest.knownDevices,
          );
          _latestGlobalSequence = manifest.latestGlobalSequence;
          _latestSnapshotChecksum =
              manifest.snapshots
                  .where(
                    (snapshot) =>
                        availableSnapshotPaths.contains(snapshot.path),
                  )
                  .isNotEmpty
              ? manifest.snapshots
                    .where(
                      (snapshot) =>
                          availableSnapshotPaths.contains(snapshot.path),
                    )
                    .last
                    .checksum
              : null;
          _currentDeviceId = syncManager.deviceId;

          if (_statusMessage != 'Backup completed' &&
              _statusMessage != 'Restore completed') {
            if (_localChecksum != null &&
                _localChecksum == _latestSnapshotChecksum) {
              _statusMessage = 'Already backed up';
            } else {
              _statusMessage = 'Connected';
            }
          }
        });
      } else if (mounted) {
        setState(() {
          _backups = [];
          _availableSnapshotPaths = <String>{};
          _latestGlobalSequence = 0;
          _latestSnapshotChecksum = null;
          if (_statusMessage != 'Backup completed' &&
              _statusMessage != 'Restore completed') {
            _statusMessage = 'No cloud backup found';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_isPermissionRevokedError(e)) {
            _isConnected = false;
            _userEmail = null;
          }
          _statusMessage = _mapErrorToMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingBackups = false;
        });
      }
    }
  }

  Future<void> _createBackup() async {
    final controller = context.read<AppStateController>();
    final String? passphrase = await _resolveOperationSecret(
      allowKeyCreation: _backups.isEmpty,
    );
    if (passphrase == null || passphrase.isEmpty) {
      return;
    }

    final backupController = _maybeBackupController();
    final wasChangingPassphrase = _isChangingPassphrase;
    setState(() {
      _busy = true;
      _statusMessage = 'Backing up...';
    });

    try {
      if (backupController != null) {
        backupController.setBackupPassphrase(passphrase);
        await backupController.saveBackupPassphrase(passphrase);
      }
      await _saveBackupPassphrase(passphrase);
      final syncManager = await _getSyncManager();
      final db = controller.database;
      if (db == null) {
        throw StateError('Active database is not initialized.');
      }

      CloudSyncResult result = await syncManager.pushSnapshot(db: db);
      if (result.status == CloudSyncStatus.conflict ||
          _isConflictError(result.message)) {
        result = await syncManager.pushSnapshot(db: db);
      }
      if (!mounted) return;

      if (result.status == CloudSyncStatus.success) {
        setState(() {
          _statusMessage = 'Backup completed';
          _hasExistingPassphrase = true;
          _isChangingPassphrase = false;
          _confirmPassphraseController.clear();
        });
        _showToast('Backup completed successfully', kind: AppToastKind.success);
        if (wasChangingPassphrase) {
          _showToast(
            'Changing your passphrase affects future backups. Older backups may still require the passphrase used when they were created.',
            kind: AppToastKind.warning,
          );
        }
        if (backupController != null) {
          await backupController.refreshCloudState(evaluatePrompt: false);
        }
        await _loadLocalChecksum();
        if (!mounted) return;
        await _fetchBackups();
      } else {
        setState(() {
          if (_isPermissionRevokedError(result.message)) {
            _isConnected = false;
            _userEmail = null;
          }
          _statusMessage = _mapErrorToMessage(result.message);
        });
        _showToast(
          'Backup failed: ${result.message}',
          kind: AppToastKind.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_isPermissionRevokedError(e)) {
          _isConnected = false;
          _userEmail = null;
        }
        _statusMessage = _mapErrorToMessage(e);
      });
      _showToast('Backup failed: $e', kind: AppToastKind.error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _deleteAllCloudBackups() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final TextEditingController confirmController = TextEditingController();
        bool canDelete = false;
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setS) {
            return AlertDialog(
              title: const Text('Delete All Cloud Backups'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'This permanently deletes every backup snapshot from Google Drive for this account.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Type DELETE to confirm',
                    ),
                    onChanged: (String value) {
                      setS(() {
                        canDelete = value.trim().toUpperCase() == 'DELETE';
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: canDelete
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _busy = true;
      _statusMessage = 'Deleting cloud backups...';
    });

    try {
      final backupController = _maybeBackupController();
      await backupController?.deleteCloudBackupData();
      await _fetchBackups();
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Cloud backups deleted';
        _backups = [];
        _availableSnapshotPaths = <String>{};
        _latestSnapshotChecksum = null;
        _latestGlobalSequence = 0;
      });
      _showToast(
        'Cloud backups deleted successfully',
        kind: AppToastKind.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = _mapErrorToMessage(e);
      });
      _showToast('Failed to delete backups: $e', kind: AppToastKind.error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Widget _buildAutomaticBackupPanel(
    BuildContext context,
    CloudBackupController controller,
  ) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? _) {
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Automatic Cloud Backup',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (controller.isBackingUp)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: controller.automaticBackupEnabled,
                  onChanged: _busy
                      ? null
                      : (bool enabled) async {
                          await controller.setAutomaticBackupEnabled(enabled);
                          if (enabled) {
                            await controller.refreshCloudState(
                              evaluatePrompt: true,
                            );
                          }
                        },
                  title: const Text('Enable automatic backups'),
                  subtitle: const Text(
                    'Backups run in the background when the app is idle, resumes, or important data changes.',
                  ),
                ),
                const SizedBox(height: 8),
                ExpansionTile(
                  key: const Key('advancedBackupSettingsTile'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: const Text(
                    'Advanced',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Adjust backup timing and other power-user options.',
                  ),
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Minimum interval',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        DropdownButton<int>(
                          value: controller.minimumIntervalHours,
                          items: const <DropdownMenuItem<int>>[
                            DropdownMenuItem<int>(
                              value: 3,
                              child: Text('3 hours'),
                            ),
                            DropdownMenuItem<int>(
                              value: 6,
                              child: Text('6 hours'),
                            ),
                            DropdownMenuItem<int>(
                              value: 12,
                              child: Text('12 hours'),
                            ),
                          ],
                          onChanged: _busy
                              ? null
                              : (int? value) {
                                  if (value != null) {
                                    controller.setMinimumIntervalHours(value);
                                  }
                                },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _deleteAllCloudBackups,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    'Delete All Cloud Backups',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                const Divider(height: 24),
                _detailRow(
                  context,
                  icon: Icons.history,
                  label: 'Last backup time',
                  value: _formatMaybeDate(controller.lastBackupAt),
                ),
                const SizedBox(height: 8),
                _detailRow(
                  context,
                  icon: Icons.event_available,
                  label: 'Next eligible backup',
                  value: _formatMaybeDate(controller.nextEligibleBackupAt),
                ),
                const SizedBox(height: 8),
                _detailRow(
                  context,
                  icon: Icons.info_outline,
                  label: 'Status',
                  value: controller.statusMessage,
                ),
                if (controller.lastBackupError.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    controller.lastBackupError,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOperationSyncPanel(
    BuildContext context,
    CloudBackupController controller,
  ) {
    if (!controller.isOperationSyncEnabled) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? _) {
        return FutureBuilder<int>(
          future: controller.pendingOperationCount(),
          builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
            final int pending = snapshot.data ?? 0;
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.sync, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cloud Operation Sync',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (controller.isOperationSyncing)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _detailRow(
                      context,
                      icon: Icons.flag_outlined,
                      label: 'Mode',
                      value: controller.operationSyncModeLabel,
                    ),
                    const SizedBox(height: 8),
                    _detailRow(
                      context,
                      icon: Icons.swap_horiz,
                      label: 'Status',
                      value: controller.operationSyncStatusMessage,
                    ),
                    const SizedBox(height: 8),
                    _detailRow(
                      context,
                      icon: Icons.queue,
                      label: 'Pending operations',
                      value: pending.toString(),
                    ),
                    const SizedBox(height: 8),
                    _detailRow(
                      context,
                      icon: Icons.schedule,
                      label: 'Last sync',
                      value: _formatMaybeDate(
                        controller.lastOperationSyncAt == null
                            ? null
                            : DateTime.tryParse(
                                controller.lastOperationSyncAt!,
                              ),
                      ),
                    ),
                    if (controller.lastOperationSyncError.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        controller.lastOperationSyncError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    AppPrimaryButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              await controller.syncOperationsNow();
                            },
                      label: 'Manual Sync Now',
                      icon: Icons.sync,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  int _compareVersionStrings(String left, String right) {
    List<int> parse(String input) {
      final core = input.trim().split('+').first.split('-').first;
      return core
          .split('.')
          .map(
            (part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
          )
          .toList();
    }

    final leftParts = parse(left);
    final rightParts = parse(right);
    final maxLength = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;
    for (var i = 0; i < maxLength; i++) {
      final l = i < leftParts.length ? leftParts[i] : 0;
      final r = i < rightParts.length ? rightParts[i] : 0;
      if (l != r) {
        return l.compareTo(r);
      }
    }
    return 0;
  }

  SnapshotEntry? _latestBackupForCurrentDevice() {
    final deviceId = _currentDeviceId;
    if (deviceId == null || deviceId.isEmpty) {
      return null;
    }
    SnapshotEntry? latest;
    for (final backup in _backups) {
      if (backup.deviceId != deviceId) continue;
      if (latest == null ||
          backup.sequence > latest.sequence ||
          (backup.sequence == latest.sequence &&
              backup.globalSequence > latest.globalSequence)) {
        latest = backup;
      }
    }
    return latest;
  }

  bool _isLocalDatabaseNewerThan(SnapshotEntry backup) {
    if (_localChecksum != null && _localChecksum!.isNotEmpty) {
      SnapshotEntry? localMatch;
      for (final candidate in _backups) {
        if (candidate.checksum == _localChecksum) {
          if (localMatch == null ||
              candidate.sequence > localMatch.sequence ||
              (candidate.sequence == localMatch.sequence &&
                  candidate.globalSequence > localMatch.globalSequence)) {
            localMatch = candidate;
          }
        }
      }

      if (localMatch != null) {
        return backup.sequence < localMatch.sequence;
      }
    }

    final currentDeviceLatest = _latestBackupForCurrentDevice();
    if (currentDeviceLatest != null) {
      return backup.sequence < currentDeviceLatest.sequence;
    }

    return false;
  }

  String? _compatibilityErrorFor(SnapshotEntry backup, int localSchemaVersion) {
    if (backup.databaseSchemaVersion > localSchemaVersion) {
      return 'This backup requires database schema version ${backup.databaseSchemaVersion}, but this device only supports schema version $localSchemaVersion.';
    }

    if (_compareVersionStrings(backup.appVersion, _localAppVersion) > 0) {
      return 'This backup was created by app version ${backup.appVersion}, which is newer than the installed app version $_localAppVersion. Please update the app before restoring.';
    }

    return null;
  }

  Future<void> _showBlockingDialog({
    required String title,
    required String message,
    required String buttonLabel,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  void _showToast(String message, {required AppToastKind kind}) {
    if (!mounted) return;
    showTopSnackBar(context, message, kind: kind);
  }

  Future<bool> _confirmStaleRestore(SnapshotEntry snapshot) async {
    if (!_isLocalDatabaseNewerThan(snapshot)) {
      return true;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Older Backup Warning'),
        content: const Text(
          'This backup is older than your current database. Restoring it may lose recent changes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore Anyway'),
          ),
        ],
      ),
    );

    return confirm == true;
  }

  Future<void> _confirmAndRestore(SnapshotEntry snapshot) async {
    final controller = context.read<AppStateController>();
    final String? passphrase = await _resolveOperationSecret(
      allowKeyCreation: false,
    );
    if (passphrase == null || passphrase.isEmpty) {
      return;
    }

    final compatibilityError = _compatibilityErrorFor(
      snapshot,
      controller.database?.schemaVersion ?? 0,
    );
    if (compatibilityError != null) {
      await _showBlockingDialog(
        title: 'Restore Blocked',
        message: compatibilityError,
        buttonLabel: 'OK',
      );
      return;
    }

    if (!await _confirmStaleRestore(snapshot)) {
      return;
    }

    final confirm1 = await showDialog<bool>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Cloud Backup?'),
        content: Text(
          'This will replace your current data.\n'
          'A local safety copy will be created automatically.\n\n'
          'Are you sure you want to replace your local database with Cloud Backup Sequence #${snapshot.sequence}?\n'
          'Device: ${snapshot.deviceName.isEmpty ? 'Unknown device' : snapshot.deviceName} (${_formatPlatformLabel(_platformForBackup(snapshot))})\n'
          'Backup date: ${_formatBackupDate(snapshot.createdAt)}\n'
          'Schema/App: ${snapshot.databaseSchemaVersion} / ${snapshot.appVersion}\n'
          'Checksum: ${_shortChecksum(snapshot.checksum)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replace', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm1 != true || !mounted) return;

    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WARNING: Destructive Operation'),
        content: const Text(
          'This will close active database connections, overwrite the local file, and reload your application state.\n\n'
          'Do you really want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No, Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Yes, Force Restore',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm2 != true || !mounted) return;

    setState(() {
      _busy = true;
      _statusMessage = 'Restoring...';
    });

    try {
      await _saveBackupPassphrase(passphrase);
      final syncManager = await _getSyncManager();
      final activeDbPath = await controller.database?.resolveDatabasePath();

      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/restored_user_backup_${DateTime.now().millisecondsSinceEpoch}.sqlite';

      final pullResult = await syncManager.pullAndRestore(
        targetPath: tempPath,
        localSchemaVersion: controller.database?.schemaVersion,
      );
      if (pullResult.status != CloudSyncStatus.success) {
        if (_isWrongPassphraseError(pullResult.message)) {
          await _showBlockingDialog(
            title: 'Wrong Passphrase',
            message:
                'The selected cloud backup could not be decrypted with this passphrase. Please verify your passphrase and try again.',
            buttonLabel: 'OK',
          );
          return;
        }
        if (_isMissingSnapshotError(pullResult.message)) {
          await _showBlockingDialog(
            title: 'Backup File Missing',
            message:
                'The selected backup file is no longer available in Google Drive. Refresh the list and choose another backup.',
            buttonLabel: 'OK',
          );
          return;
        }
        throw StateError(pullResult.message);
      }

      await controller.replaceActiveDatabaseWithRestoredFile(tempPath);
      if (activeDbPath != null && activeDbPath.isNotEmpty) {
        _latestRestoreLocalBackupPath = await _findLatestLocalRestoreBackupPath(
          activeDbPath,
        );
      }

      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      if (mounted) {
        setState(() {
          _statusMessage = 'Restore completed';
        });
        await _showBlockingDialog(
          title: 'Restore Completed',
          message: 'Restore completed successfully.',
          buttonLabel: 'OK',
        );
      }
      await _loadLocalChecksum();
      await _fetchBackups();
    } on crypto.SecretBoxAuthenticationError {
      if (mounted) {
        await _showBlockingDialog(
          title: 'Wrong Passphrase',
          message:
              'The selected cloud backup could not be decrypted with this passphrase. Please verify your passphrase and try again.',
          buttonLabel: 'OK',
        );
        setState(() {
          _statusMessage = 'Wrong passphrase';
        });
      }
    } catch (e) {
      if (mounted) {
        final reason = _mapErrorToMessage(e);
        setState(() {
          if (_isPermissionRevokedError(e)) {
            _isConnected = false;
            _userEmail = null;
          }
          _statusMessage = reason;
        });

        final bool? restoreSafety = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Restore Failed'),
            content: Text(
              'Reason: $reason\n\n'
              'Would you like to restore the local safety copy created before the restore attempt?\n\n'
              'Local safety backup:\n${_latestRestoreLocalBackupPath ?? 'Unknown path'}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Restore Safety Copy',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );

        if (restoreSafety == true &&
            mounted &&
            _latestRestoreLocalBackupPath != null) {
          setState(() {
            _busy = true;
            _statusMessage = 'Restoring safety copy...';
          });
          try {
            await controller.replaceActiveDatabaseWithRestoredFile(
              _latestRestoreLocalBackupPath!,
            );
            _showToast(
              'Restore completed successfully.',
              kind: AppToastKind.success,
            );
            setState(() {
              _statusMessage = 'Safety copy restored';
            });
            await _loadLocalChecksum();
            await _fetchBackups();
          } catch (restoreErr) {
            _showToast(
              'Failed to restore safety copy: $restoreErr',
              kind: AppToastKind.error,
            );
          } finally {
            setState(() {
              _busy = false;
            });
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  IconData _platformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'ios':
        return Icons.phone_iphone;
      case 'android':
        return Icons.phone_android;
      case 'macos':
        return Icons.laptop_mac;
      case 'windows':
        return Icons.desktop_windows;
      case 'linux':
        return Icons.computer;
      case 'web':
        return Icons.language;
      default:
        return Icons.devices_other;
    }
  }

  String _formatBackupDate(DateTime timestamp) {
    return DateFormat.yMMMd().add_Hm().format(timestamp.toLocal());
  }

  String _formatPlatformLabel(String platform) {
    if (platform.isEmpty) return 'Unknown platform';
    return platform[0].toUpperCase() + platform.substring(1);
  }

  String _platformForBackup(SnapshotEntry backup) {
    final metadata = _knownDevices[backup.deviceId];
    return metadata?.platform ?? 'unknown';
  }

  Color _cardBorderColor(
    BuildContext context, {
    required bool isCurrent,
    required bool isNewest,
    required bool isOlder,
  }) {
    if (isCurrent) return Colors.green.shade400;
    if (isNewest) return Colors.blue.shade400;
    if (isOlder) return Colors.orange.shade400;
    return Theme.of(context).colorScheme.outlineVariant;
  }

  Widget _badge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildBackupCard(
    BuildContext context,
    SnapshotEntry backup, {
    required bool isLatestCard,
  }) {
    final bool isAvailable =
        _availableSnapshotPaths?.contains(backup.path) ?? true;
    final isCurrent =
        _currentDeviceId != null && backup.deviceId == _currentDeviceId;
    final isNewest =
        _latestGlobalSequence > 0 &&
        backup.globalSequence == _latestGlobalSequence;
    final isOlder =
        _latestGlobalSequence > 0 &&
        backup.globalSequence < _latestGlobalSequence;
    final platform = _platformForBackup(backup);
    final borderColor = _cardBorderColor(
      context,
      isCurrent: isCurrent,
      isNewest: isNewest,
      isOlder: isOlder,
    );
    final dateLabel = _formatBackupDate(backup.createdAt);

    final badges = <Widget>[];
    if (isCurrent) {
      badges.add(_badge(label: 'Current Device', color: Colors.green.shade700));
    }
    if (isNewest) {
      badges.add(_badge(label: 'Newest Backup', color: Colors.blue.shade700));
    }
    if (isOlder) {
      badges.add(_badge(label: 'Older Backup', color: Colors.orange.shade700));
    }
    if (!isAvailable) {
      badges.add(_badge(label: 'Unavailable', color: Colors.grey.shade700));
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: borderColor,
          width: isCurrent || isNewest ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: borderColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_platformIcon(platform), color: borderColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLatestCard
                            ? 'Latest Backup'
                            : 'Backup #${backup.sequence}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        backup.deviceName.isEmpty
                            ? 'Unknown device'
                            : backup.deviceName,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      if (!isAvailable) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Snapshot file missing from Drive',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        '${_formatPlatformLabel(platform)} | $dateLabel',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (badges.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    children: badges,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _detailChip(
                  context,
                  icon: _platformIcon(platform),
                  label: backup.deviceName.isEmpty
                      ? 'Unknown device'
                      : backup.deviceName,
                ),
                _detailChip(
                  context,
                  icon: Icons.data_object,
                  label: 'DB schema ${backup.databaseSchemaVersion}',
                ),
                _detailChip(
                  context,
                  icon: Icons.apps,
                  label:
                      'App ${backup.appVersion.isEmpty ? 'unknown' : backup.appVersion}',
                ),
                _detailChip(
                  context,
                  icon: Icons.tag,
                  label: 'Seq ${backup.sequence} / G${backup.globalSequence}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Checksum: ${_shortChecksum(backup.checksum)}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: isAvailable
                  ? (isLatestCard
                        ? ElevatedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _confirmAndRestore(backup),
                            icon: const Icon(Icons.restore),
                            label: const Text('Restore'),
                          )
                        : OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _confirmAndRestore(backup),
                            icon: const Icon(Icons.restore),
                            label: const Text('Restore'),
                          ))
                  : OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.restore),
                      label: const Text('Unavailable'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  List<SnapshotEntry> get _sortedBackups {
    final sorted = List<SnapshotEntry>.from(_backups);
    sorted.sort((a, b) {
      final byGlobal = b.globalSequence.compareTo(a.globalSequence);
      if (byGlobal != 0) return byGlobal;
      final bySequence = b.sequence.compareTo(a.sequence);
      if (bySequence != 0) return bySequence;
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final backupController = _maybeBackupController();
    final sortedBackups = _sortedBackups;
    final latestBackup = sortedBackups.isNotEmpty ? sortedBackups.first : null;
    final previousBackups = sortedBackups.length > 1
        ? sortedBackups.skip(1).toList()
        : <SnapshotEntry>[];
    final lastBackupTime =
        backupController?.lastBackupAt ?? latestBackup?.createdAt;
    final nextEligibleTime = backupController?.nextEligibleBackupAt;
    final autoBackupSummary = backupController == null
        ? 'Not available'
        : (backupController.automaticBackupEnabled ? 'Enabled' : 'Disabled');
    final lastError =
        backupController == null ||
            backupController.lastBackupError.trim().isEmpty
        ? 'None'
        : backupController.lastBackupError.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Backup & Sync'),
        actions: [
          if (_isConnected)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'disconnect') {
                  _disconnect();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'disconnect',
                  child: Text('Disconnect Google Drive'),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 0,
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _isConnected ? Icons.cloud_done : Icons.cloud_off,
                      color: _isConnected ? Colors.green : Colors.grey,
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status: $_statusMessage',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _isConnected
                                  ? Colors.green
                                  : Colors.grey.shade600,
                            ),
                          ),
                          if (_isConnected && _userEmail != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Account: $_userEmail',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _detailRow(
                            context,
                            icon: Icons.history,
                            label: 'Last backup',
                            value: _formatMaybeDate(lastBackupTime),
                          ),
                          const SizedBox(height: 8),
                          _detailRow(
                            context,
                            icon: Icons.schedule,
                            label: 'Auto backup',
                            value: autoBackupSummary,
                          ),
                          const SizedBox(height: 8),
                          _detailRow(
                            context,
                            icon: Icons.event,
                            label: 'Next eligible backup',
                            value: _formatMaybeDate(nextEligibleTime),
                          ),
                          const SizedBox(height: 8),
                          _detailRow(
                            context,
                            icon: Icons.error_outline,
                            label: 'Last error',
                            value: lastError,
                          ),
                          if (kDebugMode) ...[
                            const SizedBox(height: 8),
                            _detailRow(
                              context,
                              icon: Icons.inventory_2_outlined,
                              label: 'Backup count',
                              value: '${_backups.length}',
                            ),
                          ],
                          if (_isConnected &&
                              _statusMessage == 'Network error') ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : _fetchBackups,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isInitializing)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Checking Google Drive connection...',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (!_isConnected)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connect Google Drive to enable cloud backups',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Google Drive appDataFolder is app-private. Backup files are not visible in your Drive files list.',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Backups are encrypted automatically on this device before upload.',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your backup key is recovered securely when you sign in.',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Firebase app login is separate from Google Drive access. Connecting Drive does not change your app login session.',
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  Navigator.of(context).maybePop();
                                },
                          child: const Text('Skip'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppPrimaryButton(
                        onPressed: _busy ? null : _connect,
                        label: 'Connect Google Drive',
                        icon: Icons.login,
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              if (backupController != null) ...[
                _buildAutomaticBackupPanel(context, backupController),
                const SizedBox(height: 24),
                if (backupController.isOperationSyncEnabled) ...[
                  _buildOperationSyncPanel(context, backupController),
                  const SizedBox(height: 24),
                ],
              ],
              const SizedBox(height: 24),
              Text(
                'Cloud Backup',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: const Text(
                          'Backups are encrypted automatically on this device before upload to Google Drive. Your backup key is recovered securely upon sign in.',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: _busy ? null : _createBackup,
                        icon: const Icon(Icons.backup),
                        label: const Text('Create Backup Now'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Backup History',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_loadingBackups)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    TextButton.icon(
                      onPressed: _busy ? null : _fetchBackups,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh backups'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_backups.isEmpty)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No cloud backups found.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                )
              else ...[
                if (latestBackup != null) ...[
                  _buildBackupCard(context, latestBackup, isLatestCard: true),
                ],
                if (previousBackups.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Previous Backups',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: previousBackups.length,
                    itemBuilder: (context, index) {
                      return _buildBackupCard(
                        context,
                        previousBackups[index],
                        isLatestCard: false,
                      );
                    },
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}
