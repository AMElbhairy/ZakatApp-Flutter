import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/backup_preview.dart';
import 'app_state_controller.dart';
import 'backup_restore_service.dart';
import 'backup_service.dart';

class BackupRestoreCard extends StatelessWidget {
  const BackupRestoreCard({
    super.key,
    required this.controller,
  });

  final AppStateController controller;

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final String jsonStr = BackupService.exportBackup(controller.state.toJson());
      final Directory dir = await getTemporaryDirectory();
      final String dateStamp = DateTime.now().toIso8601String().split('T').first;
      final File file = File('${dir.path}/zakatapp-backup-$dateStamp.json');
      await file.writeAsString(jsonStr);

      if (!context.mounted) return;
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        <XFile>[XFile(file.path)],
        subject: 'ZakatApp Backup',
        sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export backup: $e')),
      );
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['json'],
      );
      if (result == null || result.files.single.path == null) return;
      final String rawJson = await File(result.files.single.path!).readAsString();
      final BackupPreview preview = BackupService.parseBackupPreview(rawJson);
      if (!context.mounted) return;
      _showPreviewDialog(context, preview);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: invalid backup file. $e')),
      );
    }
  }

  void _showPreviewDialog(BuildContext context, BackupPreview preview) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Backup Preview'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (!preview.canRestore)
                const Text(
                  'This file is not a valid backup and cannot be restored.',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              if (preview.isLegacy)
                const Text(
                  'Legacy backup detected. Migration will be applied before restore.',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 8),
              Text('Source: ${preview.sourceType}'),
              Text('Schema/Version: ${preview.schemaOrVersion}'),
              Text('Exported At: ${preview.exportedAt.isEmpty ? 'Unknown' : preview.exportedAt}'),
              const Divider(),
              Text('Transactions: ${preview.transactionsCount}'),
              Text('Savings: ${preview.savingsCount}'),
              Text('Investments: ${preview.investmentsCount}'),
              Text('Recurring: ${preview.recurringTransactionsCount}'),
              Text('Financial Plans: ${preview.financialPlansCount}'),
              Text('Has Market Data: ${preview.hasMarketData ? 'Yes' : 'No'}'),
              if (preview.warnings.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                const Text('Warnings:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...preview.warnings.map((String w) => Text('• $w')),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: preview.canRestore
                ? () {
                    Navigator.pop(ctx);
                    _handleRestore(context, preview);
                  }
                : null,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _handleRestore(BuildContext context, BackupPreview preview) {
    if (BackupService.hasData(controller.state.toJson())) {
      showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('Local Data Conflict'),
          content: const Text('Local data exists. Choose an explicit action.'),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _exportBackup(context);
              },
              child: const Text('Export Current Backup First'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _executeRestore(context, preview, replace: true);
              },
              child: const Text('Replace Everything'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _executeRestore(context, preview, replace: false);
              },
              child: const Text('Merge Import'),
            ),
          ],
        ),
      );
      return;
    }
    _executeRestore(context, preview, replace: true);
  }

  Future<void> _executeRestore(
    BuildContext context,
    BackupPreview preview, {
    required bool replace,
  }) async {
    try {
      final BackupRestoreService service = BackupRestoreService(controller: controller);
      final RestoreResult result = replace
          ? await service.restoreReplace(preview.rawJson, allowWhenLocalDataExists: true)
          : await service.restoreMerge(preview.rawJson, allowWhenLocalDataExists: true);
      if (!context.mounted) return;
      final String counts =
          'tx:${result.counts['transactions']} sav:${result.counts['savings']} inv:${result.counts['investments']}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.mode.toUpperCase()} restore success. $counts')),
      );
      if (result.warnings.isNotEmpty) {
        showDialog<void>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Restore Summary'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: result.warnings.map((String e) => Text('• $e')).toList(growable: false),
              ),
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to restore backup: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ElevatedButton.icon(
          onPressed: () => _exportBackup(context),
          icon: const Icon(Icons.upload_file),
          label: const Text('Export Backup'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _importBackup(context),
          icon: const Icon(Icons.download),
          label: const Text('Import Backup'),
        ),
      ],
    );
  }
}
