import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart' as crypto;
import '../../data/local/app_database.dart';
import 'cloud_sync_manifest.dart';
import 'snapshot_manager.dart';
import 'user_cloud_storage_provider.dart';

enum CloudSyncStatus {
  success,
  upToDate,
  noRemoteSnapshot,
  newerAvailable,
  conflict,
  error,
}

class CloudSyncResult {
  final CloudSyncStatus status;
  final String message;
  final CloudSyncManifest? manifest;

  const CloudSyncResult({
    required this.status,
    required this.message,
    this.manifest,
  });
}

class CloudSyncManager {
  final UserCloudStorageProvider provider;
  final SnapshotManager snapshotManager;
  final String deviceId;
  final String deviceName;
  final String platform;
  final String appVersion;

  String? _passphrase;

  CloudSyncManager({
    required this.provider,
    required this.snapshotManager,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    String? appVersion,
  }) : appVersion = appVersion ??
            const String.fromEnvironment(
              'APP_VERSION',
              defaultValue: '1.0.0',
            );

  /// Configures the sync encryption passphrase.
  void setPassphrase(String passphrase) {
    _passphrase = passphrase.trim();
  }

  bool get isConfigured => _passphrase != null && _passphrase!.isNotEmpty;

  /// Helper to calculate the SHA-256 checksum of a local file.
  Future<String> calculateFileChecksum(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return '';
    }
    final bytes = await file.readAsBytes();
    final hash = await crypto.Sha256().hash(bytes);
    return base64Encode(hash.bytes);
  }

  /// Checks the cloud manifest to determine if updates are available.
  /// Compares sequences and database checksums to decide if download is required.
  Future<CloudSyncResult> checkForUpdates({
    required int localSequence,
    required String localChecksum,
  }) async {
    try {
      final cloudManifestMeta = await provider.readManifest();
      if (cloudManifestMeta == null) {
        return const CloudSyncResult(
          status: CloudSyncStatus.noRemoteSnapshot,
          message: 'No remote manifest or snapshot exists.',
        );
      }

      final manifest = CloudSyncManifest.fromJson(cloudManifestMeta.content);
      
      // Get the latest snapshot entry from the manifest list
      if (manifest.snapshots.isEmpty) {
        return CloudSyncResult(
          status: CloudSyncStatus.noRemoteSnapshot,
          message: 'No snapshots registered in manifest.',
          manifest: manifest,
        );
      }

      final latestSnapshot = manifest.snapshots.last;

      if (latestSnapshot.sequence == localSequence && latestSnapshot.checksum == localChecksum) {
        return CloudSyncResult(
          status: CloudSyncStatus.upToDate,
          message: 'Already up to date.',
          manifest: manifest,
        );
      }

      if (latestSnapshot.sequence > localSequence) {
        return CloudSyncResult(
          status: CloudSyncStatus.newerAvailable,
          message: 'Newer remote snapshot sequence ${latestSnapshot.sequence} is available.',
          manifest: manifest,
        );
      }

      // If local sequence is equal or greater, but checksum is different, there is a divergence.
      return CloudSyncResult(
        status: CloudSyncStatus.conflict,
        message: 'Local and cloud snapshots have diverged.',
        manifest: manifest,
      );
    } catch (e) {
      return CloudSyncResult(
        status: CloudSyncStatus.error,
        message: 'Failed checking updates: $e',
      );
    }
  }

  /// Downloads, decrypts, and restores the latest snapshot from cloud storage to [targetPath].
  Future<CloudSyncResult> pullAndRestore({
    required String targetPath,
  }) async {
    if (!isConfigured) {
      return const CloudSyncResult(
        status: CloudSyncStatus.error,
        message: 'CloudSyncManager passphrase is not configured.',
      );
    }

    try {
      await snapshotManager.restoreSnapshot(
        provider: provider,
        passphrase: _passphrase!,
        targetPath: targetPath,
      );

      return const CloudSyncResult(
        status: CloudSyncStatus.success,
        message: 'Snapshot restored successfully.',
      );
    } catch (e) {
      return CloudSyncResult(
        status: CloudSyncStatus.error,
        message: 'Failed to pull and restore snapshot: $e',
      );
    }
  }

  /// Performs WAL-safe database backup, encryption, and manifest upload using ETag lock verification.
  /// If the manifest update fails due to ETag mismatch, returns a conflict status, leaving
  /// the manifest and local snapshot untouched.
  Future<CloudSyncResult> pushSnapshot({
    required AppDatabase db,
    String? customDbPath,
    String? expectedManifestRevision,
  }) async {
    if (!isConfigured) {
      return const CloudSyncResult(
        status: CloudSyncStatus.error,
        message: 'CloudSyncManager passphrase is not configured.',
      );
    }

    try {
      // 1. Get the current manifest revision to check for modification concurrently if expected revision is not supplied
      String? revision = expectedManifestRevision;
      if (revision == null) {
        final existing = await provider.readManifest();
        revision = existing?.revision;
      }

      // 2. Trigger WAL-safe export snapshot
      await snapshotManager.exportSnapshot(
        db: db,
        provider: provider,
        passphrase: _passphrase!,
        deviceId: deviceId,
        deviceName: deviceName,
        platform: platform,
        appVersion: appVersion,
        expectedManifestRevision: revision,
        customDbPath: customDbPath,
      );

      return const CloudSyncResult(
        status: CloudSyncStatus.success,
        message: 'Snapshot pushed successfully.',
      );
    } on StateError catch (e) {
      if (e.message.contains('Revision mismatch') || e.message.contains('ETag')) {
        return CloudSyncResult(
          status: CloudSyncStatus.conflict,
          message: 'Manifest write failed: ETag revision collision. ${e.message}',
        );
      }
      return CloudSyncResult(
        status: CloudSyncStatus.error,
        message: 'Failed to push snapshot: ${e.message}',
      );
    } catch (e) {
      return CloudSyncResult(
        status: CloudSyncStatus.error,
        message: 'Failed to push snapshot: $e',
      );
    }
  }
}
