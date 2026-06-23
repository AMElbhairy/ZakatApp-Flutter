import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/widgets/app_ui.dart';
import '../../services/app_state_controller.dart';
import '../../services/sync/cloud_sync_manager.dart';
import '../../services/sync/cloud_sync_manifest.dart';
import '../../services/sync/google_drive_storage_provider.dart';
import '../../services/sync/snapshot_manager.dart';
import '../../services/sync/sync_encryption_service.dart';
import '../../services/sync/user_cloud_storage_provider.dart';

class CloudBackupScreen extends StatefulWidget {
  final GoogleSignIn? googleSignIn;
  final CloudSyncManager? syncManager;

  const CloudBackupScreen({
    super.key,
    this.googleSignIn,
    this.syncManager,
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
  String _statusMessage = 'Not connected';

  List<SnapshotEntry> _backups = [];
  Map<String, DeviceMetadata> _knownDevices = {};
  String? _latestSnapshotChecksum;
  int _latestGlobalSequence = 0;
  String? _localChecksum;
  String? _currentDeviceId;

  final TextEditingController _passphraseController = TextEditingController();
  bool _obscurePassphrase = true;
  final SyncEncryptionService _encryptionService = SyncEncryptionService();

  @override
  void initState() {
    super.initState();
    _googleSignIn = widget.googleSignIn ??
        GoogleSignIn(
          scopes: const <String>[
            'profile',
            'email',
            'https://www.googleapis.com/auth/drive.appdata',
          ],
        );
    _initStatus();
  }

  @override
  void dispose() {
    _passphraseController.dispose();
    super.dispose();
  }

  Future<void> _initStatus() async {
    setState(() {
      _busy = true;
    });
    try {
      final signedIn = await _googleSignIn.isSignedIn();
      if (signedIn) {
        final currentUser = _googleSignIn.currentUser;
        if (currentUser != null) {
          final scopesGranted = await _googleSignIn.canAccessScopes([
            'https://www.googleapis.com/auth/drive.appdata',
          ]);
          if (scopesGranted) {
            setState(() {
              _isConnected = true;
              _userEmail = currentUser.email;
              _statusMessage = 'Connected';
            });
            await _loadLocalChecksum();
            await _loadBackupPassphrase();
            await _fetchBackups();
            return;
          }
        }
      }
      setState(() {
        _isConnected = false;
        _userEmail = null;
        _statusMessage = 'Not connected';
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
        });
      }
    }
  }

  Future<void> _loadBackupPassphrase() async {
    final controller = context.read<AppStateController>();
    final userId = controller.state.loadedUserId;
    final saved =
        await controller.secureStorageService.loadBackupPassphrase(userId: userId);
    if (saved != null && saved.isNotEmpty) {
      _passphraseController.text = saved;
    }
  }

  Future<void> _saveBackupPassphrase(String passphrase) async {
    final controller = context.read<AppStateController>();
    final userId = controller.state.loadedUserId;
    await controller.secureStorageService.saveBackupPassphrase(
      passphrase,
      userId: userId,
    );
  }

  Future<void> _deleteBackupPassphrase() async {
    final controller = context.read<AppStateController>();
    final userId = controller.state.loadedUserId;
    await controller.secureStorageService.deleteBackupPassphrase(userId: userId);
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
    final str = e.toString().toLowerCase();
    if (str.contains('secretboxauthenticationerror') ||
        str.contains('mac check failed') ||
        str.contains('wrong passphrase')) {
      return 'Wrong passphrase';
    }
    if (str.contains('socketexception') ||
        str.contains('handshake') ||
        str.contains('network') ||
        str.contains('http') ||
        str.contains('detailedapirequesterror')) {
      return 'Network error';
    }
    if (str.contains('etag') ||
        str.contains('revision mismatch') ||
        str.contains('conflict')) {
      return 'Conflict / try again';
    }
    return 'Error: $e';
  }

  UserCloudStorageProvider _getProvider() {
    return GoogleDriveStorageProvider(
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
    );
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
    final snapshotManager = SnapshotManager(encryptionService: _encryptionService);
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
      final account = await _googleSignIn.signIn();
      if (account != null) {
        final scopesGranted = await _googleSignIn.requestScopes([
          'https://www.googleapis.com/auth/drive.appdata',
        ]);
        if (scopesGranted) {
          setState(() {
            _isConnected = true;
            _userEmail = account.email;
            _statusMessage = 'Connected';
          });
          await _fetchBackups();
        } else {
          setState(() {
            _isConnected = false;
            _statusMessage = 'Not connected';
          });
        }
      } else {
        setState(() {
          _isConnected = false;
          _statusMessage = 'Not connected';
        });
      }
    } catch (e) {
      setState(() {
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
      await _googleSignIn.signOut();
      await _deleteBackupPassphrase();
      setState(() {
        _isConnected = false;
        _userEmail = null;
        _statusMessage = 'Not connected';
        _backups = [];
        _latestSnapshotChecksum = null;
        _latestGlobalSequence = 0;
      });
    } catch (e) {
      setState(() {
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

  Future<void> _fetchBackups() async {
    if (!mounted) return;
    setState(() {
      _loadingBackups = true;
    });
    try {
      final syncManager = await _getSyncManager();
      final checkResult = await syncManager.checkForUpdates(
        localSequence: 0,
        localChecksum: '',
      );

      if (checkResult.manifest != null) {
        final manifest = checkResult.manifest!;
        if (!mounted) return;
        setState(() {
          _backups = List<SnapshotEntry>.from(manifest.snapshots);
          _knownDevices = Map<String, DeviceMetadata>.from(manifest.knownDevices);
          _latestGlobalSequence = manifest.latestGlobalSequence;
          _latestSnapshotChecksum =
              manifest.snapshots.isNotEmpty ? manifest.snapshots.last.checksum : null;
          _currentDeviceId = syncManager.deviceId;

          if (_statusMessage != 'Backup completed' &&
              _statusMessage != 'Restore completed') {
            if (_localChecksum != null && _localChecksum == _latestSnapshotChecksum) {
              _statusMessage = 'Already backed up';
            } else {
              _statusMessage = 'Connected';
            }
          }
        });
      } else if (mounted) {
        setState(() {
          _backups = [];
          _latestGlobalSequence = 0;
          _latestSnapshotChecksum = null;
          if (_statusMessage != 'Backup completed' &&
              _statusMessage != 'Restore completed') {
            _statusMessage = 'Connected';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
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
    final passphrase = _passphraseController.text.trim();
    if (passphrase.isEmpty) {
      showTopSnackBar(
        context,
        'Please enter a backup passphrase',
        kind: AppToastKind.warning,
      );
      return;
    }

    final controller = context.read<AppStateController>();
    setState(() {
      _busy = true;
      _statusMessage = 'Backing up...';
    });

    try {
      await _saveBackupPassphrase(passphrase);
      final syncManager = await _getSyncManager();
      final db = controller.database;
      if (db == null) {
        throw StateError('Active database is not initialized.');
      }

      final result = await syncManager.pushSnapshot(db: db);
      if (!mounted) return;

      if (result.status == CloudSyncStatus.success) {
        setState(() {
          _statusMessage = 'Backup completed';
        });
        showTopSnackBar(
          context,
          'Backup completed successfully',
          kind: AppToastKind.success,
        );
        await _loadLocalChecksum();
        if (!mounted) return;
        await _fetchBackups();
      } else {
        setState(() {
          _statusMessage = _mapErrorToMessage(result.message);
        });
        showTopSnackBar(
          context,
          'Backup failed: ${result.message}',
          kind: AppToastKind.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = _mapErrorToMessage(e);
      });
      showTopSnackBar(context, 'Backup failed: $e', kind: AppToastKind.error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  int _compareVersionStrings(String left, String right) {
    List<int> parse(String input) {
      final core = input.trim().split('+').first.split('-').first;
      return core
          .split('.')
          .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
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

  String? _compatibilityErrorFor(
    SnapshotEntry backup,
    int localSchemaVersion,
  ) {
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
    final passphrase = _passphraseController.text.trim();
    if (passphrase.isEmpty) {
      showTopSnackBar(
        context,
        'Please enter the backup passphrase to decrypt',
        kind: AppToastKind.warning,
      );
      return;
    }

    final controller = context.read<AppStateController>();
    final compatibilityError =
        _compatibilityErrorFor(snapshot, controller.database?.schemaVersion ?? 0);
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
          'Are you sure you want to replace your local database with Cloud Backup Sequence #${snapshot.sequence}?\n\n'
          'All current local data will be replaced. A timestamped local backup file will be created first.',
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

      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/restored_user_backup_${DateTime.now().millisecondsSinceEpoch}.sqlite';

      final pullResult = await syncManager.pullAndRestore(targetPath: tempPath);
      if (pullResult.status != CloudSyncStatus.success) {
        throw StateError(pullResult.message);
      }

      await controller.replaceActiveDatabaseWithRestoredFile(tempPath);

      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      if (mounted) {
        setState(() {
          _statusMessage = 'Restore completed';
        });
        showTopSnackBar(
          context,
          'Restore completed successfully',
          kind: AppToastKind.success,
        );
      }
      await _loadLocalChecksum();
      await _fetchBackups();
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = _mapErrorToMessage(e);
        });
        showTopSnackBar(
          context,
          'Restore failed: $_statusMessage',
          kind: AppToastKind.error,
        );
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

  Widget _badge({
    required String label,
    required Color color,
  }) {
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
    final isCurrent = _currentDeviceId != null && backup.deviceId == _currentDeviceId;
    final isNewest = _latestGlobalSequence > 0 &&
        backup.globalSequence == _latestGlobalSequence;
    final isOlder = _latestGlobalSequence > 0 &&
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
                  child: Icon(
                    _platformIcon(platform),
                    color: borderColor,
                  ),
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
                        backup.deviceName.isEmpty ? 'Unknown device' : backup.deviceName,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
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
                  label: backup.deviceName.isEmpty ? 'Unknown device' : backup.deviceName,
                ),
                _detailChip(
                  context,
                  icon: Icons.data_object,
                  label: 'DB schema ${backup.databaseSchemaVersion}',
                ),
                _detailChip(
                  context,
                  icon: Icons.apps,
                  label: 'App ${backup.appVersion.isEmpty ? 'unknown' : backup.appVersion}',
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
              'Checksum: ${backup.checksum.length > 12 ? '${backup.checksum.substring(0, 12)}...' : backup.checksum}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: isLatestCard
                  ? ElevatedButton.icon(
                      onPressed: _busy ? null : () => _confirmAndRestore(backup),
                      icon: const Icon(Icons.restore),
                      label: const Text('Restore'),
                    )
                  : OutlinedButton.icon(
                      onPressed: _busy ? null : () => _confirmAndRestore(backup),
                      icon: const Icon(Icons.restore),
                      label: const Text('Restore'),
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
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
    final sortedBackups = _sortedBackups;
    final latestBackup = sortedBackups.isNotEmpty ? sortedBackups.first : null;
    final previousBackups =
        sortedBackups.length > 1 ? sortedBackups.skip(1).toList() : <SnapshotEntry>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Backup & Sync'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 0,
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
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
                              color: _isConnected ? Colors.green : Colors.grey.shade600,
                            ),
                          ),
                          if (_isConnected && _userEmail != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Account: $_userEmail',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            if (!_isConnected)
              AppPrimaryButton(
                onPressed: _busy ? null : _connect,
                label: 'Connect Google Drive',
                icon: Icons.login,
              )
            else ...[
              AppPrimaryButton(
                onPressed: _busy ? null : _disconnect,
                label: 'Disconnect Google Drive',
                icon: Icons.logout,
              ),
              const SizedBox(height: 24),
              Text(
                'Encryption Passphrase',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _passphraseController,
                        obscureText: _obscurePassphrase,
                        decoration: InputDecoration(
                          labelText: 'Backup Passphrase',
                          hintText: 'Enter a strong passphrase to encrypt backups',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassphrase
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassphrase = !_obscurePassphrase;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: _busy ? null : _createBackup,
                        icon: const Icon(Icons.backup),
                        label: const Text('Backup Now'),
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
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _busy ? null : _fetchBackups,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_backups.isEmpty)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
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
                  _buildBackupCard(
                    context,
                    latestBackup,
                    isLatestCard: true,
                  ),
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
