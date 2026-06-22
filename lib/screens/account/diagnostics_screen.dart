import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/app_diagnostics.dart';
import '../../services/app_state_controller.dart';
import '../../services/sync_diagnostics_service.dart';
import '../../data/sync/sync_reports.dart';
import '../../core/widgets/app_ui.dart';

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

  Future<void> _compareLocalVsFirebase() async {
    if (!widget.enableDeepDiagnostics) return;
    setState(() {
      _busy = true;
      _bundleFuture = _loadBundle(includeFirebaseSavingsComparison: true);
    });
    try {
      await _bundleFuture;
      _showMessage('Local vs Firebase comparison loaded');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _manualSyncNow() async {
    setState(() {
      _busy = true;
    });
    try {
      final ManualSyncResult result = await context
          .read<AppStateController>()
          .runManualSync();
      await _refreshDiagnostics();
      _showMessage(result.message);
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

  Future<void> _enqueueAllLocalData() async {
    if (!widget.enableDeepDiagnostics) return;
    await _runAction(
      () =>
          context.read<AppStateController>().enqueueAllLocalDataForCloudSync(),
      successMessage: 'All local data enqueued',
    );
  }

  Future<void> _forceUploadAllLocalData() async {
    if (!widget.enableDeepDiagnostics) return;
    await _runAction(
      () => context.read<AppStateController>().forceUploadAllLocalData(),
      successMessage: 'Force upload completed',
    );
  }

  Future<void> _runFullReconciliation() async {
    if (!widget.enableDeepDiagnostics) return;
    await _runAction(
      () => context.read<AppStateController>().runFullReconciliation(),
      successMessage: 'Full reconciliation report refreshed',
    );
  }

  Future<void> _repairSyncCursors() async {
    if (!widget.enableDeepDiagnostics) return;
    await _runAction(
      () => context.read<AppStateController>().repairSavingsSyncCursors(),
      successMessage: 'Savings cursors repaired',
    );
  }

  Future<void> _enqueueMissingFirebaseSavings() async {
    if (!widget.enableDeepDiagnostics) return;
    await _runAction(() async {
      await context.read<AppStateController>().enqueueMissingFirebaseSavings();
    }, successMessage: 'Missing Firebase savings enqueued');
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
                      onCompareLocalVsFirebase: deepEnabled && !_busy
                          ? _compareLocalVsFirebase
                          : null,
                      onManualSyncNow: _busy ? null : _manualSyncNow,
                      onCopyDiagnostics: !deepEnabled || report == null || _busy
                          ? null
                          : _copyDiagnostics,
                      onExportJson: !deepEnabled || report == null || _busy
                          ? null
                          : _exportDiagnosticsJson,
                      onClearLogs: !deepEnabled || _busy ? null : _clearLogs,
                      onEnqueueAllLocalData: !deepEnabled || _busy
                          ? null
                          : _enqueueAllLocalData,
                      onForceUploadAllLocalData: !deepEnabled || _busy
                          ? null
                          : _forceUploadAllLocalData,
                      onRunFullReconciliation: !deepEnabled || _busy
                          ? null
                          : _runFullReconciliation,
                      onRepairSyncCursors: !deepEnabled || _busy
                          ? null
                          : _repairSyncCursors,
                      onEnqueueMissingFirebaseSavings: !deepEnabled || _busy
                          ? null
                          : _enqueueMissingFirebaseSavings,
                    ),
                    const SizedBox(height: 16),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...<Widget>[
                      if (diagnostics != null)
                        _SyncStatusCard(diagnostics: diagnostics),
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
    required this.onCompareLocalVsFirebase,
    required this.onManualSyncNow,
    required this.onCopyDiagnostics,
    required this.onExportJson,
    required this.onClearLogs,
    required this.onEnqueueAllLocalData,
    required this.onForceUploadAllLocalData,
    required this.onRunFullReconciliation,
    required this.onRepairSyncCursors,
    required this.onEnqueueMissingFirebaseSavings,
  });

  final bool busy;
  final bool deepEnabled;
  final VoidCallback? onRefreshDiagnostics;
  final VoidCallback? onCompareLocalVsFirebase;
  final VoidCallback? onManualSyncNow;
  final VoidCallback? onCopyDiagnostics;
  final VoidCallback? onExportJson;
  final VoidCallback? onClearLogs;
  final VoidCallback? onEnqueueAllLocalData;
  final VoidCallback? onForceUploadAllLocalData;
  final VoidCallback? onRunFullReconciliation;
  final VoidCallback? onRepairSyncCursors;
  final VoidCallback? onEnqueueMissingFirebaseSavings;

  @override
  Widget build(BuildContext context) {
    final List<Widget> buttons = <Widget>[
      FilledButton.icon(
        onPressed: onManualSyncNow,
        icon: busy
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.sync),
        label: const Text('Manual Sync Now'),
      ),
      FilledButton.tonalIcon(
        onPressed: onRefreshDiagnostics,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh Diagnostics'),
      ),
    ];
    if (deepEnabled) {
      buttons.addAll(<Widget>[
        FilledButton.tonalIcon(
          onPressed: onCompareLocalVsFirebase,
          icon: const Icon(Icons.compare),
          label: const Text('Compare Local vs Firebase'),
        ),
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
        OutlinedButton.icon(
          onPressed: onEnqueueAllLocalData,
          icon: const Icon(Icons.queue),
          label: const Text('Enqueue All Local Data'),
        ),
        FilledButton.tonalIcon(
          onPressed: onForceUploadAllLocalData,
          icon: const Icon(Icons.cloud_upload),
          label: const Text('Force Upload All Local Data'),
        ),
        OutlinedButton.icon(
          onPressed: onRunFullReconciliation,
          icon: const Icon(Icons.fact_check),
          label: const Text('Run Full Reconciliation'),
        ),
        OutlinedButton.icon(
          onPressed: onRepairSyncCursors,
          icon: const Icon(Icons.tune),
          label: const Text('Repair Sync Cursors'),
        ),
        OutlinedButton.icon(
          onPressed: onEnqueueMissingFirebaseSavings,
          icon: const Icon(Icons.fiber_new),
          label: const Text('Enqueue Missing Firebase Savings'),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: 1.35,
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
