import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_typography.dart';
import '../../services/app_diagnostics.dart';
import '../../services/app_state_controller.dart';
import '../../services/google_sign_in_factory.dart';
import '../../services/sync_diagnostics_service.dart';
import '../../core/widgets/app_ui.dart';
import '../../services/sync/google_drive_storage_provider.dart';
import '../../services/sync/sync_encryption_service.dart';
import '../../services/sync/user_cloud_storage_provider.dart';
import '../../services/sync/snapshot_manager.dart';
import '../../services/sync/cloud_sync_manager.dart';
import '../../services/sync/cloud_sync_manifest.dart';
import 'package:drift/native.dart';
import '../../data/local/app_database.dart';

class _DiagnosticsBundle {
  const _DiagnosticsBundle({required this.snapshot, this.report});

  final AppDiagnosticsSnapshot snapshot;
  final DebugDiagnosticsReport? report;
}

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({
    super.key,
    this.enableDeveloperDiagnostics = false,
    this.enableDeepDiagnostics = false,
  });

  final bool enableDeveloperDiagnostics;
  final bool enableDeepDiagnostics;

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  Future<_DiagnosticsBundle>? _bundleFuture;
  _DiagnosticsBundle? _latestBundle;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _bundleFuture = _loadBundle();
  }

  Future<_DiagnosticsBundle> _loadBundle({
    bool includeFirebaseSavingsComparison = false,
  }) async {
    final AppStateController controller = context.read<AppStateController>();
    final AppDiagnosticsSnapshot snapshot = await controller
        .collectDiagnostics();
    DebugDiagnosticsReport? report;
    if (widget.enableDeepDiagnostics) {
      report = await controller.collectDebugDiagnostics(
        includeFirebaseSavingsComparison: includeFirebaseSavingsComparison,
      );
    }
    final _DiagnosticsBundle bundle = _DiagnosticsBundle(
      snapshot: snapshot,
      report: report,
    );
    _latestBundle = bundle;
    return bundle;
  }

  Future<void> _refreshDiagnostics() async {
    setState(() {
      _busy = true;
      _bundleFuture = _loadBundle();
    });
    try {
      await _bundleFuture;
      _showMessage('Diagnostics refreshed');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _copyDiagnostics() async {
    final _DiagnosticsBundle bundle =
        _latestBundle ?? await (_bundleFuture ?? _loadBundle());
    final DebugDiagnosticsReport? report = bundle.report;
    if (report == null) return;
    final String text = formatDiagnosticsForClipboard(report);
    await Clipboard.setData(ClipboardData(text: text));
    _showMessage('Diagnostics copied to clipboard');
  }

  Future<void> _exportDiagnosticsJson() async {
    final _DiagnosticsBundle bundle =
        _latestBundle ?? await (_bundleFuture ?? _loadBundle());
    final DebugDiagnosticsReport? report = bundle.report;
    if (report == null) return;
    final Directory directory = await getTemporaryDirectory();
    final String fileName =
        'debug_diagnostics_${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}.json';
    final File file = File(p.join(directory.path, fileName));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report.toJson()),
    );
    await Share.shareXFiles(<XFile>[
      XFile(file.path),
    ], text: 'Debug diagnostics JSON export');
  }

  Future<void> _clearLogs() async {
    if (!widget.enableDeepDiagnostics) return;
    await SyncDiagnosticsService.clear();
    await _refreshDiagnostics();
    _showMessage('Diagnostics logs cleared');
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    setState(() {
      _busy = true;
    });
    try {
      await action();
      await _refreshDiagnostics();
      _showMessage(successMessage);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    showTopSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode && !widget.enableDeveloperDiagnostics) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.enableDeepDiagnostics || widget.enableDeveloperDiagnostics
              ? 'Developer Diagnostics'
              : 'Sync Status',
        ),
      ),
      body: FutureBuilder<_DiagnosticsBundle>(
        future: _bundleFuture,
        builder:
            (BuildContext context, AsyncSnapshot<_DiagnosticsBundle> snapshot) {
              final _DiagnosticsBundle? bundle = snapshot.data ?? _latestBundle;
              final DebugDiagnosticsReport? report = bundle?.report;
              final AppDiagnosticsSnapshot? diagnostics = bundle?.snapshot;
              final bool loading =
                  snapshot.connectionState == ConnectionState.waiting &&
                  bundle == null;
              final bool deepEnabled = widget.enableDeepDiagnostics;

              return RefreshIndicator(
                onRefresh: _refreshDiagnostics,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    _ActionRow(
                      busy: _busy,
                      deepEnabled: deepEnabled,
                      onRefreshDiagnostics: _busy ? null : _refreshDiagnostics,
                      onCopyDiagnostics: !deepEnabled || report == null || _busy
                          ? null
                          : _copyDiagnostics,
                      onExportJson: !deepEnabled || report == null || _busy
                          ? null
                          : _exportDiagnosticsJson,
                      onClearLogs: !deepEnabled || _busy ? null : _clearLogs,
                    ),
                    const SizedBox(height: 16),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...<Widget>[
                      if (diagnostics != null) ...[
                        _SyncStatusCard(diagnostics: diagnostics),
                        if (widget.enableDeveloperDiagnostics) ...[
                          const SizedBox(height: 12),
                          const _GoogleDrivePoCCard(),
                        ],
                      ],
                      if (deepEnabled &&
                          report != null &&
                          diagnostics != null) ...<Widget>[
                        const SizedBox(height: 12),
                        _PullCursorCard(diagnostics: diagnostics),
                        const SizedBox(height: 12),
                        _SQLiteRowCountsCard(diagnostics: diagnostics),
                        const SizedBox(height: 12),
                        _SummaryCard(report: report),
                        const SizedBox(height: 12),
                        _ReportCard(
                          reportText: formatDiagnosticsForClipboard(report),
                        ),
                      ],
                    ],
                  ],
                ),
              );
            },
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.busy,
    required this.deepEnabled,
    required this.onRefreshDiagnostics,
    required this.onCopyDiagnostics,
    required this.onExportJson,
    required this.onClearLogs,
  });

  final bool busy;
  final bool deepEnabled;
  final VoidCallback? onRefreshDiagnostics;
  final VoidCallback? onCopyDiagnostics;
  final VoidCallback? onExportJson;
  final VoidCallback? onClearLogs;

  @override
  Widget build(BuildContext context) {
    final List<Widget> buttons = <Widget>[
      FilledButton.tonalIcon(
        onPressed: onRefreshDiagnostics,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh Diagnostics'),
      ),
    ];
    if (deepEnabled) {
      buttons.addAll(<Widget>[
        FilledButton.tonalIcon(
          onPressed: onCopyDiagnostics,
          icon: const Icon(Icons.copy),
          label: const Text('Copy Diagnostics'),
        ),
        FilledButton.tonalIcon(
          onPressed: onExportJson,
          icon: const Icon(Icons.upload_file),
          label: const Text('Export Diagnostics JSON'),
        ),
        OutlinedButton.icon(
          onPressed: onClearLogs,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Clear Diagnostics Logs'),
        ),
      ]);
    }
    return Wrap(spacing: 12, runSpacing: 12, children: buttons);
  }
}

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({required this.diagnostics});

  final AppDiagnosticsSnapshot diagnostics;

  @override
  Widget build(BuildContext context) {
    final String sqliteDbUser =
        '${diagnostics.databasePath ?? 'unavailable'} / '
        '${diagnostics.firebaseUid.isEmpty ? '-' : diagnostics.firebaseUid}';
    final String pendingQueueCount =
        (diagnostics.tableRowCounts['sync_queue'] ?? 0).toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Sync Status', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _KeyValueRow('Pending sync queue count', pendingQueueCount),
            _KeyValueRow('Last push success', diagnostics.lastPushSuccessAt),
            _KeyValueRow('Last pull success', diagnostics.lastPullSuccessAt),
            _KeyValueRow(
              'Next auto pull allowed',
              diagnostics.nextAutoPullAllowed.toString(),
            ),
            _KeyValueRow('Last sync error', diagnostics.lastSyncError),
            _KeyValueRow('Current SQLite DB / user', sqliteDbUser),
          ],
        ),
      ),
    );
  }
}

class _SQLiteRowCountsCard extends StatelessWidget {
  const _SQLiteRowCountsCard({required this.diagnostics});

  final AppDiagnosticsSnapshot diagnostics;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, int>> counts = diagnostics
        .tableRowCounts
        .entries
        .toList(growable: false);
    counts.sort((MapEntry<String, int> a, MapEntry<String, int> b) {
      return a.key.compareTo(b.key);
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'SQLite Row Counts',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final MapEntry<String, int> entry in counts)
              _KeyValueRow(_prettyLabel(entry.key), entry.value.toString()),
          ],
        ),
      ),
    );
  }

  String _prettyLabel(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (String word) =>
              word.isEmpty ? word : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
  }
}

class _PullCursorCard extends StatelessWidget {
  const _PullCursorCard({required this.diagnostics});

  final AppDiagnosticsSnapshot diagnostics;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, String>> cursors = diagnostics
        .syncCursors
        .entries
        .toList(growable: false);
    cursors.sort((MapEntry<String, String> a, MapEntry<String, String> b) {
      return a.key.compareTo(b.key);
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Pull Cursors',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final MapEntry<String, String> entry in cursors)
              _KeyValueRow(_prettyLabel(entry.key), entry.value),
          ],
        ),
      ),
    );
  }

  String _prettyLabel(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (String word) =>
              word.isEmpty ? word : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report});

  final DebugDiagnosticsReport? report;

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Summary', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _KeyValueRow('App version', report!.app.version),
            _KeyValueRow('Build number', report!.app.buildNumber),
            _KeyValueRow('User ID', report!.auth.userId),
            _KeyValueRow(
              'SQLite active',
              report!.storage.sqliteActive.toString(),
            ),
            _KeyValueRow(
              'Sync enabled',
              report!.storage.syncEnabled.toString(),
            ),
            _KeyValueRow(
              'Pending queue',
              report!.storage.pendingSyncQueueCount.toString(),
            ),
            _KeyValueRow(
              'Savings local/Firebase',
              '${report!.savingsSummary.localCount} / ${report!.savingsSummary.firebaseCount}',
            ),
            _KeyValueRow(
              'Gold local/Firebase',
              '${report!.preciousMetalsSummary.localGoldCount} / ${report!.preciousMetalsSummary.firebaseGoldCount}',
            ),
            _KeyValueRow(
              'Silver local/Firebase',
              '${report!.preciousMetalsSummary.localSilverCount} / ${report!.preciousMetalsSummary.firebaseSilverCount}',
            ),
            _KeyValueRow(
              'Mismatches',
              report!.comparison.mismatchCount.toString(),
            ),
            _KeyValueRow(
              'Gold API key configured',
              report!.marketData.goldApiKeyConfigured.toString(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.reportText});

  final String reportText;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Clipboard Report',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SelectableText(
              reportText,
              style: AppTypography.monospace(
                color:
                    Theme.of(context).textTheme.bodySmall?.color ??
                    Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleDrivePoCCard extends StatefulWidget {
  const _GoogleDrivePoCCard();

  @override
  State<_GoogleDrivePoCCard> createState() => _GoogleDrivePoCCardState();
}

class _GoogleDrivePoCCardState extends State<_GoogleDrivePoCCard> {
  final GoogleSignIn _googleSignIn = createAppGoogleSignIn(
    extraScopes: const <String>[
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  );

  bool _isConnected = false;
  String? _userEmail;
  bool _busy = false;
  String _statusMessage = 'Not connected';
  String? _lastDecryptedData;
  List<SnapshotEntry> _remoteSnapshots = [];
  bool _fetchingSnapshots = false;

  final SyncEncryptionService _encryptionService = SyncEncryptionService();

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final signedIn = await _googleSignIn.isSignedIn();
    if (signedIn) {
      final currentUser = _googleSignIn.currentUser;
      if (currentUser != null) {
        final scopesGranted = await _googleSignIn.canAccessScopes([
          'https://www.googleapis.com/auth/drive.appdata',
        ]);
        setState(() {
          _isConnected = scopesGranted;
          _userEmail = currentUser.email;
          _statusMessage = scopesGranted
              ? 'Connected (Scope granted)'
              : 'Signed in, but Google Drive scope is missing';
        });
        if (scopesGranted) {
          _loadRemoteSnapshots();
        }
        return;
      }
    }
    setState(() {
      _isConnected = false;
      _userEmail = null;
      _statusMessage = 'Not connected';
    });
  }

  Future<void> _loadRemoteSnapshots() async {
    if (!mounted) return;
    setState(() {
      _fetchingSnapshots = true;
      _statusMessage = 'Reading remote manifest...';
    });
    try {
      final syncManager = _getSyncManager();
      final checkResult = await syncManager.checkForUpdates(
        localSequence: 0,
        localChecksum: '',
      );
      if (checkResult.manifest != null) {
        if (mounted) {
          setState(() {
            _remoteSnapshots = checkResult.manifest!.snapshots;
            _statusMessage =
                'Loaded ${_remoteSnapshots.length} remote snapshots.';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _remoteSnapshots = [];
            _statusMessage = 'No remote manifest found.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Failed to load snapshots: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _fetchingSnapshots = false;
        });
      }
    }
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
            _statusMessage = 'Successfully connected with Google Drive access!';
          });
          _loadRemoteSnapshots();
        } else {
          setState(() {
            _isConnected = false;
            _statusMessage = 'Google Drive access denied by user.';
          });
        }
      } else {
        setState(() {
          _isConnected = false;
          _statusMessage = 'Sign-in cancelled.';
        });
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _statusMessage = 'Connection failed: $e';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _busy = true;
    });
    try {
      await _googleSignIn.signOut();
      setState(() {
        _isConnected = false;
        _userEmail = null;
        _statusMessage = 'Disconnected';
        _lastDecryptedData = null;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Disconnect failed: $e';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  UserCloudStorageProvider _getProvider() {
    final String namespace = _cloudNamespace();
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
      namespacePrefix: namespace,
    );
  }

  String _cloudNamespace() {
    try {
      final controller = context.read<AppStateController>();
      final String loadedUserId =
          controller.state.loadedUserId?.trim().isNotEmpty == true
          ? controller.state.loadedUserId!.trim()
          : '';
      if (loadedUserId.isNotEmpty) {
        return loadedUserId;
      }
      final String userId = controller.state.userId?.trim().isNotEmpty == true
          ? controller.state.userId!.trim()
          : '';
      if (userId.isNotEmpty) {
        return userId;
      }
    } catch (_) {}
    return 'default';
  }

  CloudSyncManager _getSyncManager() {
    final provider = _getProvider();
    final snapshotManager = SnapshotManager(
      encryptionService: _encryptionService,
    );
    final syncManager = CloudSyncManager(
      provider: provider,
      snapshotManager: snapshotManager,
      deviceId: 'diagnostics-poc-device',
      deviceName: 'Diagnostics PoC Card',
      platform: 'debug',
    );
    syncManager.setPassphrase('diagnostics-passphrase');
    return syncManager;
  }

  Future<void> _uploadTestFile() async {
    setState(() {
      _busy = true;
      _statusMessage =
          'Exporting and uploading encrypted SQLite database snapshot...';
    });
    try {
      final controller = context.read<AppStateController>();
      final db = controller.database;
      if (db == null) {
        setState(() {
          _statusMessage = 'Active database is not initialized.';
        });
        return;
      }

      final syncManager = _getSyncManager();
      final result = await syncManager.pushSnapshot(db: db);

      if (result.status == CloudSyncStatus.success) {
        setState(() {
          _statusMessage =
              'Active SQLite snapshot exported and uploaded successfully to Drive appDataFolder!';
        });
        _loadRemoteSnapshots();
      } else {
        setState(() {
          _statusMessage = 'Upload failed: ${result.message}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Upload failed: $e';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _downloadTestFile() async {
    setState(() {
      _busy = true;
      _statusMessage =
          'Checking updates, downloading and restoring to temp database copy...';
    });
    try {
      final syncManager = _getSyncManager();

      final checkResult = await syncManager.checkForUpdates(
        localSequence: 0,
        localChecksum: '',
      );

      if (checkResult.status == CloudSyncStatus.noRemoteSnapshot) {
        setState(() {
          _statusMessage =
              'No remote snapshot found on Google Drive appDataFolder.';
        });
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final tempTargetPath =
          '${tempDir.path}/restored_diagnostics_poc_${DateTime.now().millisecondsSinceEpoch}.sqlite';

      final pullResult = await syncManager.pullAndRestore(
        targetPath: tempTargetPath,
      );
      if (pullResult.status != CloudSyncStatus.success) {
        setState(() {
          _statusMessage = 'Download/Restore failed: ${pullResult.message}';
        });
        return;
      }

      final restoredFile = File(tempTargetPath);
      if (!await restoredFile.exists()) {
        setState(() {
          _statusMessage = 'Restored file does not exist at $tempTargetPath';
        });
        return;
      }

      final tempDb = AppDatabase(
        userId: 'temp-poc-restore',
        executor: NativeDatabase(restoredFile),
      );

      final transactions = await tempDb
          .customSelect("SELECT count(*) as count FROM transactions")
          .get();
      final savings = await tempDb
          .customSelect("SELECT count(*) as count FROM savings")
          .get();
      final txCount = transactions.first.read<int>('count');
      final savCount = savings.first.read<int>('count');

      await tempDb.close();

      try {
        await restoredFile.delete();
      } catch (_) {}

      final cloudManifest = checkResult.manifest;
      final sequence = cloudManifest?.currentSnapshotSequence ?? 0;
      final historyCount = cloudManifest?.snapshots.length ?? 0;

      setState(() {
        _lastDecryptedData =
            'SUCCESSFULLY OPENED RESTORED DB COPY:\n'
            '- File path: $tempTargetPath (verified & cleaned up)\n'
            '- Restored Transactions Count: $txCount\n'
            '- Restored Savings Count: $savCount\n'
            '- Cloud Current Sequence: $sequence\n'
            '- Cloud Snapshots History Count: $historyCount';
        _statusMessage =
            'Downloaded snapshot sequence $sequence and verified restored temp DB copy successfully!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Download/Decrypt/Restore failed: $e';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _confirmAndRestoreSnapshot(SnapshotEntry snapshot) async {
    final controller = context.read<AppStateController>();

    // First confirmation
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Database Snapshot?'),
        content: Text(
          'Are you sure you want to replace your active local database with the remote snapshot Sequence #${snapshot.sequence}?\n\n'
          'All current local data will be replaced. A timestamped local backup file of your current database will be created.',
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

    if (confirm1 != true) return;
    if (!mounted) return;

    // Second confirmation (Double confirmation)
    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WARNING: Critical Operation'),
        content: const Text(
          'This will close your active database connections, overwrite the file, and reload your application state.\n\n'
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

    if (confirm2 != true) return;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _statusMessage =
          'Downloading and restoring active database from snapshot #${snapshot.sequence}...';
    });

    try {
      final syncManager = _getSyncManager();

      // Download and decrypt to a temporary location
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/restored_active_db_temp_${DateTime.now().millisecondsSinceEpoch}.sqlite';

      final pullResult = await syncManager.pullAndRestore(targetPath: tempPath);
      if (pullResult.status != CloudSyncStatus.success) {
        throw StateError('Download/decryption failed: ${pullResult.message}');
      }

      // Replaces active DB file using AppStateController method
      await controller.replaceActiveDatabaseWithRestoredFile(tempPath);

      // Clean up the temp file
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      if (mounted) {
        setState(() {
          _statusMessage =
              'Active database successfully replaced with Snapshot #${snapshot.sequence}!';
        });
        showTopSnackBar(context, 'Database restored successfully');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Active restore failed: $e';
        });
        showTopSnackBar(context, 'Restore failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blueGrey.shade900.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blueGrey.shade800, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_queue, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Google Drive Sync Proof-of-Concept',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade100,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Status: $_statusMessage',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _isConnected
                    ? Colors.green.shade300
                    : Colors.orange.shade300,
              ),
            ),
            if (_userEmail != null) ...[
              const SizedBox(height: 4),
              Text(
                'Linked Account: $_userEmail',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (!_isConnected)
                  FilledButton.icon(
                    onPressed: _busy ? null : _connect,
                    icon: const Icon(Icons.login),
                    label: const Text('Connect Google Drive'),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _disconnect,
                    icon: const Icon(Icons.logout),
                    label: const Text('Disconnect'),
                  ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _uploadTestFile,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Encrypted Snapshot'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _downloadTestFile,
                    icon: const Icon(Icons.download),
                    label: const Text('Download & Decrypt'),
                  ),
                ],
              ],
            ),
            if (_isConnected) ...[
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available Remote Snapshots',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade200,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _busy || _fetchingSnapshots
                        ? null
                        : _loadRemoteSnapshots,
                    tooltip: 'Refresh Snapshot List',
                  ),
                ],
              ),
              if (_fetchingSnapshots)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: LinearProgressIndicator(),
                )
              else if (_remoteSnapshots.isEmpty)
                const Text(
                  'No snapshots registered in cloud manifest.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _remoteSnapshots.length,
                  itemBuilder: (context, index) {
                    final snapshot = _remoteSnapshots[index];
                    final dateStr = snapshot.createdAt
                        .toLocal()
                        .toString()
                        .split('.')
                        .first;
                    final checksumShort = snapshot.checksum.length > 8
                        ? snapshot.checksum.substring(0, 8)
                        : snapshot.checksum;
                    return Card(
                      color: Colors.black26,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          'Sequence #${snapshot.sequence}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Date: $dateStr\nChecksum: $checksumShort',
                        ),
                        trailing: ElevatedButton(
                          onPressed: _busy
                              ? null
                              : () => _confirmAndRestoreSnapshot(snapshot),
                          child: const Text('Restore Active DB'),
                        ),
                      ),
                    );
                  },
                ),
            ],
            if (_lastDecryptedData != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Last Decrypted Snapshot Data:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      _lastDecryptedData!,
                      style: AppTypography.monospace(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
