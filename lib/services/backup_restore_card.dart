import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/backup_preview.dart';
import '../../services/backup_service.dart';

class BackupRestoreCard extends StatelessWidget {
  const BackupRestoreCard({
    super.key,
    required this.currentAppStateJson,
    required this.onRestore,
  });

  /// The current state of the app (used to perform exports or check for local data conflicts).
  final Map<String, dynamic> currentAppStateJson;

  /// Callback fired when the user commits to replacing local data with an imported backup.
  final Future<void> Function(Map<String, dynamic> extractedState) onRestore;

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final String jsonStr = BackupService.exportBackup(currentAppStateJson);
      final Directory dir = await getTemporaryDirectory();
      final String dateStamp = DateTime.now().toIso8601String().split('T').first;
      final File file = File('${dir.path}/zakatapp-backup-$dateStamp.json');
      
      await file.writeAsString(jsonStr);
      
      if (context.mounted) {
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'ZakatApp Backup',
          sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export backup: $e')),
        );
      }
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) return;

      final File file = File(result.files.single.path!);
      final String jsonStr = await file.readAsString();

      final BackupPreview preview = BackupService.parseBackup(jsonStr);

      if (context.mounted) {
        _showPreviewDialog(context, preview);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read or parse backup file: $e')),
        );
      }
    }
  }

  void _showPreviewDialog(BuildContext context, BackupPreview preview) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Backup Preview'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (preview.isLegacy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Old ZakatApp backup format detected. Data will be converted.',
                    style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                  ),
                ),
              Text('Date: ${preview.exportedAt.isEmpty ? "Unknown" : preview.exportedAt}'),
              const Divider(),
              Text('Transactions: ${preview.transactionsCount}'),
              Text('Savings: ${preview.savingsCount}'),
              Text('Investments: ${preview.investmentsCount}'),
              Text('Recurring: ${preview.recurringCount}'),
              Text('Financial Plans: ${preview.financialPlansCount}'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleRestore(context, preview);
            },
            child: const Text('Restore Backup'),
          ),
        ],
      ),
    );
  }

  void _handleRestore(BuildContext context, BackupPreview preview) {
    final bool hasLocalData = BackupService.hasData(currentAppStateJson);

    if (hasLocalData) {
      showDialog(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('Backup Conflict Detected'),
          content: const Text(
            'Your local app already contains data. Restoring this backup will replace it entirely.\n\n'
            'What would you like to do?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _exportBackup(context);
              },
              child: const Text('Export Local Data First'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(ctx);
                await _executeRestore(context, preview);
              },
              child: const Text('Replace Local Data', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      _executeRestore(context, preview);
    }
  }

  Future<void> _executeRestore(BuildContext context, BackupPreview preview) async {
    final Map<String, dynamic> appStateToRestore = BackupService.extractAppState(preview.rawJson);
    await onRestore(appStateToRestore);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restored successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('Manual Backup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton.icon(onPressed: () => _exportBackup(context), icon: const Icon(Icons.upload_file), label: const Text('Export Backup File')),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: () => _importBackup(context), icon: const Icon(Icons.download), label: const Text('Import Backup File')),
          ],
        ),
      ),
    );
  }
}