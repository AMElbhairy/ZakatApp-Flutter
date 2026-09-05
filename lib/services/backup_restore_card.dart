import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/i18n/app_localizations.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_ui.dart';
import '../models/backup_preview.dart';
import 'app_state_controller.dart';
import 'backup_restore_service.dart';
import 'backup_service.dart';
import 'biometric_service.dart';
import 'csv_excel_data_service.dart';

class BackupRestoreCard extends StatelessWidget {
  const BackupRestoreCard({super.key, required this.controller});

  final AppStateController controller;

  // ---------------------------------------------------------------------------
  // JSON BACKUP / RESTORE
  // ---------------------------------------------------------------------------

  Future<void> _exportBackup(BuildContext context) async {
    if ((controller.state.biometricLockEnabled ||
            controller.state.biometricExportEnabled) &&
        await BiometricService.canAuthenticate()) {
      final auth = await BiometricService.authenticate(
        reason: 'Confirm identity to export local backup JSON file',
        isSensitiveAction: true,
      );
      if (!auth) return;
    }
    try {
      final String jsonStr = BackupService.exportBackup(
        controller.state.toJson(),
        userId: controller.state.userId ?? '',
        provider: controller.state.userProvider ?? 'local',
        email: controller.state.userEmail ?? '',
      );
      final Directory dir = await getTemporaryDirectory();
      final String dateStamp = DateTime.now()
          .toIso8601String()
          .split('T')
          .first;
      final File file = File('${dir.path}/zakatapp-backup-$dateStamp.json');
      await file.writeAsString(jsonStr);

      if (!context.mounted) return;
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        <XFile>[XFile(file.path)],
        subject: 'ZakatApp Backup',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } catch (e) {
      if (!context.mounted) return;
      showTopSnackBar(context, 'Failed to export backup: $e');
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    if ((controller.state.biometricLockEnabled ||
            controller.state.biometricRestoreEnabled) &&
        await BiometricService.canAuthenticate()) {
      final auth = await BiometricService.authenticate(
        reason: 'Confirm identity to import a backup JSON file',
        isSensitiveAction: true,
      );
      if (!auth) return;
    }
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['json'],
      );
      if (result == null || result.files.single.path == null) return;
      final String rawJson = await File(
        result.files.single.path!,
      ).readAsString();
      final BackupPreview preview = BackupService.parseBackupPreview(rawJson);
      if (!context.mounted) return;
      _showPreviewDialog(context, preview);
    } catch (e) {
      if (!context.mounted) return;
      showTopSnackBar(context, 'Error: invalid backup file. $e');
    }
  }

  void _showPreviewDialog(BuildContext context, BackupPreview preview) {
    final String currentUserId = (controller.state.userId ?? '').trim();
    final String currentEmail = (controller.state.userEmail ?? '').trim();
    final bool isDifferentAccount =
        (preview.backupUserId != null &&
            preview.backupUserId!.trim().isNotEmpty &&
            currentUserId.isNotEmpty &&
            preview.backupUserId!.trim() != currentUserId) ||
        (preview.backupEmail != null &&
            preview.backupEmail!.trim().isNotEmpty &&
            currentEmail.isNotEmpty &&
            preview.backupEmail!.trim().toLowerCase() !=
                currentEmail.toLowerCase());

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
                  style: TextStyle(
                    color: AppColors.redStrong,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (preview.isLegacy)
                const Text(
                  'Legacy backup detected. Migration will be applied before restore.',
                  style: TextStyle(
                    color: AppColors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (isDifferentAccount) ...<Widget>[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.gold,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          preview.backupEmail != null &&
                                  preview.backupEmail!.trim().isNotEmpty
                              ? 'Backup exported from ${preview.backupEmail}. It will be imported into your current account.'
                              : 'Backup from another account. It will be imported into your current account.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text('Source: ${preview.sourceType}'),
              Text('Schema/Version: ${preview.schemaOrVersion}'),
              Text(
                'Exported At: ${preview.exportedAt.isEmpty ? 'Unknown' : preview.exportedAt}',
              ),
              const Divider(),
              Text('Transactions: ${preview.transactionsCount}'),
              Text('Credit Cards: ${preview.creditCardsCount}'),
              Text('Savings: ${preview.savingsCount}'),
              Text('Investments: ${preview.investmentsCount}'),
              Text('Recurring: ${preview.recurringTransactionsCount}'),
              Text('Financial Plans: ${preview.financialPlansCount}'),
              Text('Has Market Data: ${preview.hasMarketData ? 'Yes' : 'No'}'),
              if (preview.warnings.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                const Text(
                  'Warnings:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...preview.warnings.map((String w) => Text('• $w')),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
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
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
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
                final bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext c) => AlertDialog(
                    title: const Text('Confirm Replacement'),
                    content: const Text(
                      'Warning: Replacing everything will overwrite all local data. '
                      'Any unsynced local changes will be permanently lost and replaced. '
                      'Do you want to proceed?',
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Confirm Replace'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  if (!context.mounted) return;
                  await _executeRestore(context, preview, replace: true);
                }
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
    if ((controller.state.biometricLockEnabled ||
            controller.state.biometricRestoreEnabled) &&
        await BiometricService.canAuthenticate()) {
      final auth = await BiometricService.authenticate(
        reason:
            'Confirm identity to restore and replace/merge local database data',
        isSensitiveAction: true,
      );
      if (!auth) return;
    }
    try {
      final BackupRestoreService service = BackupRestoreService(
        controller: controller,
      );
      final RestoreResult result = replace
          ? await service.restoreReplace(
              preview.rawJson,
              allowWhenLocalDataExists: true,
              allowCrossAccount: true,
            )
          : await service.restoreMerge(
              preview.rawJson,
              allowWhenLocalDataExists: true,
              allowCrossAccount: true,
            );
      if (!context.mounted) return;
      final String counts =
          'tx:${result.counts['transactions']} sav:${result.counts['savings']} inv:${result.counts['investments']}';
      showTopSnackBar(
        context,
        '${result.mode.toUpperCase()} restore success. $counts',
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
                children: result.warnings
                    .map((String e) => Text('• $e'))
                    .toList(growable: false),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      showTopSnackBar(context, 'Failed to restore backup: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // EXCEL / CSV EXPORT & IMPORT
  // ---------------------------------------------------------------------------

  Future<void> _exportCsvOrExcel(BuildContext context) async {
    if ((controller.state.biometricLockEnabled ||
            controller.state.biometricExportEnabled) &&
        await BiometricService.canAuthenticate()) {
      final auth = await BiometricService.authenticate(
        reason: 'Confirm identity to export Excel / CSV data',
        isSensitiveAction: true,
      );
      if (!auth) return;
    }

    if (!context.mounted) return;
    final l10n = context.l10n;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.table_chart_rounded,
                        color: AppColors.tealAccent,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.tr('export_csv_sheet_title'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.folder_zip_outlined,
                    color: AppColors.gold,
                  ),
                  title: Text(l10n.tr('export_all_zip')),
                  subtitle: const Text(
                    'transactions, savings, investments, recurring in .zip',
                  ),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await _shareCsvZip(context);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.table_rows_outlined,
                    color: AppColors.tealAccent,
                  ),
                  title: Text(l10n.tr('export_master_csv')),
                  subtitle: const Text(
                    'Unified CSV table for Excel & Google Sheets',
                  ),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await _shareCsvFile(
                      context,
                      content: CsvExcelDataService.exportMasterCsv(
                        controller.state,
                      ),
                      fileName: 'all_entries_master.csv',
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.blue,
                  ),
                  title: Text(l10n.tr('export_transactions_csv')),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await _shareCsvFile(
                      context,
                      content: CsvExcelDataService.exportTransactionsCsv(
                        controller.state.transactions,
                      ),
                      fileName: 'transactions.csv',
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.savings_outlined,
                    color: AppColors.gold,
                  ),
                  title: Text(l10n.tr('export_savings_csv')),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await _shareCsvFile(
                      context,
                      content: CsvExcelDataService.exportSavingsCsv(
                        controller.state.savings,
                      ),
                      fileName: 'savings.csv',
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.apartment_outlined,
                    color: AppColors.purpleSoft,
                  ),
                  title: Text(l10n.tr('export_investments_csv')),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await _shareCsvFile(
                      context,
                      content: CsvExcelDataService.exportInvestmentsCsv(
                        controller.state.investments,
                      ),
                      fileName: 'investments.csv',
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.event_repeat_outlined,
                    color: AppColors.tealAccent,
                  ),
                  title: Text(l10n.tr('export_recurring_csv')),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await _shareCsvFile(
                      context,
                      content: CsvExcelDataService.exportRecurringCsv(
                        controller.state.recurringTransactions,
                      ),
                      fileName: 'recurring.csv',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareCsvFile(
    BuildContext context, {
    required String content,
    required String fileName,
  }) async {
    try {
      final Directory dir = await getTemporaryDirectory();
      final String dateStamp = DateTime.now()
          .toIso8601String()
          .split('T')
          .first;
      final File file = File('${dir.path}/$dateStamp-$fileName');
      await file.writeAsString(content);

      if (!context.mounted) return;
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        <XFile>[XFile(file.path)],
        subject: fileName,
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } catch (e) {
      if (!context.mounted) return;
      showTopSnackBar(context, 'Failed to export CSV: $e');
    }
  }

  Future<void> _shareCsvZip(BuildContext context) async {
    try {
      final List<int> zipBytes = CsvExcelDataService.exportCsvZip(
        controller.state,
      );
      final Directory dir = await getTemporaryDirectory();
      final String dateStamp = DateTime.now()
          .toIso8601String()
          .split('T')
          .first;
      final File file = File(
        '${dir.path}/zakatapp-excel-export-$dateStamp.zip',
      );
      await file.writeAsBytes(zipBytes);

      if (!context.mounted) return;
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        <XFile>[XFile(file.path)],
        subject: 'ZakatApp Excel Export',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } catch (e) {
      if (!context.mounted) return;
      showTopSnackBar(context, 'Failed to export Zip: $e');
    }
  }

  Future<void> _importCsvOrExcel(BuildContext context) async {
    if ((controller.state.biometricLockEnabled ||
            controller.state.biometricRestoreEnabled) &&
        await BiometricService.canAuthenticate()) {
      final auth = await BiometricService.authenticate(
        reason: 'Confirm identity to import Excel / CSV data',
        isSensitiveAction: true,
      );
      if (!auth) return;
    }

    try {
      final FilePickerResult? pickerResult = await FilePicker.platform
          .pickFiles(
            type: FileType.custom,
            allowedExtensions: <String>['csv', 'xlsx', 'zip'],
          );
      if (pickerResult == null || pickerResult.files.single.path == null)
        return;

      final File file = File(pickerResult.files.single.path!);
      final List<int> bytes = await file.readAsBytes();
      final String fileName = pickerResult.files.single.name;

      final CsvImportResult importResult = CsvExcelDataService.parseFileContent(
        bytes: bytes,
        fileName: fileName,
      );

      if (importResult.isEmpty) {
        if (!context.mounted) return;
        showTopSnackBar(
          context,
          'No valid entries found in file. Please ensure columns match standard format.',
          kind: AppToastKind.warning,
        );
        return;
      }

      if (!context.mounted) return;
      _showCsvImportDialog(context, importResult, fileName);
    } catch (e) {
      if (!context.mounted) return;
      showTopSnackBar(
        context,
        'Error importing file: $e',
        kind: AppToastKind.error,
      );
    }
  }

  void _showCsvImportDialog(
    BuildContext context,
    CsvImportResult result,
    String fileName,
  ) {
    final l10n = context.l10n;

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Row(
          children: <Widget>[
            const Icon(Icons.table_chart_rounded, color: AppColors.tealAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.tr('csv_import_preview_title'),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'File: $fileName',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.tealAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.tealAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.shield_outlined,
                      color: AppColors.tealAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.tr('csv_import_no_account_data_note'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('• Transactions: ${result.transactions.length}'),
              Text('• Savings & Accounts: ${result.savings.length}'),
              Text('• Investments & Properties: ${result.investments.length}'),
              Text(
                '• Recurring Transactions: ${result.recurringTransactions.length}',
              ),
              if (result.warnings.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                const Text(
                  'Warnings:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.orange,
                  ),
                ),
                ...result.warnings.map((String w) => Text('• $w')),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.tr('cancel')),
          ),
          FilledButton.tonal(
            onPressed: () async {
              Navigator.pop(ctx);
              await _executeCsvImport(context, result, replace: false);
            },
            child: Text(l10n.tr('csv_merge_action')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
            onPressed: () async {
              Navigator.pop(ctx);
              await _executeCsvImport(context, result, replace: true);
            },
            child: Text(l10n.tr('csv_replace_action')),
          ),
        ],
      ),
    );
  }

  Future<void> _executeCsvImport(
    BuildContext context,
    CsvImportResult importResult, {
    required bool replace,
  }) async {
    try {
      final RestoreResult result = await CsvExcelDataService.applyImport(
        controller: controller,
        data: importResult,
        replace: replace,
      );

      if (!context.mounted) return;
      final String counts =
          'tx:${result.counts['transactions']} sav:${result.counts['savings']} inv:${result.counts['investments']} rec:${result.counts['recurring']}';
      showTopSnackBar(
        context,
        '${replace ? "Replace" : "Merge"} import completed. ($counts)',
        kind: AppToastKind.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      showTopSnackBar(
        context,
        'Failed to apply import: $e',
        kind: AppToastKind.error,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // JSON Full Backup Row
        Row(
          children: <Widget>[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _exportBackup(context),
                icon: const Icon(Icons.upload_file, size: 18),
                label: Text(
                  l10n.tr('export_json_backup'),
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _importBackup(context),
                icon: const Icon(Icons.download, size: 18),
                label: Text(
                  l10n.tr('import_json_backup'),
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Excel / CSV Row
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _exportCsvOrExcel(context),
                icon: const Icon(Icons.table_chart_outlined, size: 18),
                label: Text(
                  l10n.tr('export_csv_excel'),
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _importCsvOrExcel(context),
                icon: const Icon(Icons.file_open_outlined, size: 18),
                label: Text(
                  l10n.tr('import_csv_excel'),
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
