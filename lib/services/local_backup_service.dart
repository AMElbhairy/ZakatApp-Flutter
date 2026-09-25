import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/app_state.dart';
import '../models/backup_preview.dart';
import 'backup_service.dart';
import '../main.dart';
import 'startup_restore_discovery.dart';

class LocalBackupService {
  LocalBackupService({
    this.maxBackups = 5,
    Future<Directory> Function()? documentsDirectoryProvider,
    this.enableInTesting = false,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final int maxBackups;
  final Future<Directory> Function() _documentsDirectoryProvider;
  final bool enableInTesting;

  Future<void> captureSnapshot({
    required AppStateModel state,
    String? provider,
    String? email,
  }) async {
    if (!_shouldRun(state)) return;
    try {
      final String userId = (state.userId ?? '').trim();
      final Directory directory = await _backupDirectory(userId);
      await directory.create(recursive: true);
      final String timestamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(':', '-');
      final File file = File(p.join(directory.path, 'backup_$timestamp.json'));
      final String backup = BackupService.exportBackup(
        state.toJson(),
        userId: userId,
        provider: _nonEmptyOrUnknown(provider ?? state.userProvider),
        email: _nonEmptyOrUnknown(email ?? state.userEmail),
      );
      await file.writeAsString(backup);
      await _pruneBackups(userId);
    } catch (error, stackTrace) {
      debugPrint('LocalBackupService.captureSnapshot failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> deleteBackupsForUser(String userId) async {
    final Directory directory = await _backupDirectory(userId);
    if (!await directory.exists()) return;
    try {
      await directory.delete(recursive: true);
    } catch (error, stackTrace) {
      debugPrint('LocalBackupService.deleteBackupsForUser failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<String?> readLatestBackup({required String userId}) async {
    final File? file = await _latestBackupFile(userId);
    if (file == null) return null;
    return file.readAsString();
  }

  Future<BackupPreview?> previewLatestBackup({required String userId}) async {
    final String? rawJson = await readLatestBackup(userId: userId);
    if (rawJson == null || rawJson.trim().isEmpty) {
      return null;
    }
    return BackupService.parseBackupPreview(rawJson);
  }

  Future<StartupRestoreDiscoveryResult> discoverStartupRestore({
    required String userId,
    required bool localHasData,
  }) async {
    if (localHasData || userId.trim().isEmpty) {
      return const StartupRestoreDiscoveryResult(
        status: StartupRestoreDiscoveryStatus.none,
        message: '',
        source: StartupRestoreSource.local,
      );
    }

    try {
      final BackupPreview? preview = await previewLatestBackup(userId: userId);
      if (preview == null || !preview.canRestore) {
        return const StartupRestoreDiscoveryResult(
          status: StartupRestoreDiscoveryStatus.none,
          message: '',
          source: StartupRestoreSource.local,
        );
      }
      return StartupRestoreDiscoveryResult(
        status: StartupRestoreDiscoveryStatus.restorePrompt,
        message: 'Local backup found.',
        preview: preview,
        source: StartupRestoreSource.local,
      );
    } catch (error, stackTrace) {
      debugPrint('LocalBackupService.discoverStartupRestore failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return StartupRestoreDiscoveryResult(
        status: StartupRestoreDiscoveryStatus.none,
        message: '',
        error: 'The local backup could not be read.',
        source: StartupRestoreSource.local,
      );
    }
  }

  Future<File?> _latestBackupFile(String userId) async {
    final Directory directory = await _backupDirectory(userId);
    if (!await directory.exists()) return null;
    final List<FileSystemEntity> entries = await directory
        .list(followLinks: false)
        .toList();
    final List<File> files = entries
        .whereType<File>()
        .where((File file) => file.path.endsWith('.json'))
        .toList(growable: false);
    if (files.isEmpty) return null;
    files.sort(
      (File a, File b) =>
          b.statSync().modified.compareTo(a.statSync().modified),
    );
    return files.first;
  }

  Future<void> _pruneBackups(String userId) async {
    final Directory directory = await _backupDirectory(userId);
    if (!await directory.exists()) return;
    final List<File> files = (await directory.list(followLinks: false).toList())
        .whereType<File>()
        .where((File file) => file.path.endsWith('.json'))
        .toList(growable: false);
    if (files.length <= maxBackups) return;
    files.sort(
      (File a, File b) =>
          b.statSync().modified.compareTo(a.statSync().modified),
    );
    for (final File file in files.skip(maxBackups)) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  Future<Directory> _backupDirectory(String userId) async {
    final Directory root = await _documentsDirectoryProvider();
    return Directory(p.join(root.path, 'local_backups', userId));
  }

  bool _shouldRun(AppStateModel state) {
    if (!enableInTesting && ZakatApp.isTesting) {
      return false;
    }
    return (state.userId ?? '').trim().isNotEmpty &&
        BackupService.hasData(state.toJson());
  }

  String _nonEmptyOrUnknown(String? value) {
    final String clean = (value ?? '').trim();
    return clean.isEmpty ? 'unknown' : clean;
  }
}
