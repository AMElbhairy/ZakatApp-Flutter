import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:uuid/uuid.dart';
import '../../data/local/app_database.dart';
import 'cloud_sync_manifest.dart';
import 'sync_encryption_service.dart';
import 'user_cloud_storage_provider.dart';

class BackupCorruptedException implements Exception {
  final String message;
  const BackupCorruptedException(this.message);
  @override
  String toString() => 'BackupCorruptedException: $message';
}

class BackupSchemaIncompatibleException implements Exception {
  final String message;
  const BackupSchemaIncompatibleException(this.message);
  @override
  String toString() => 'BackupSchemaIncompatibleException: $message';
}

class BackupDecryptionException implements Exception {
  final String message;
  const BackupDecryptionException(this.message);
  @override
  String toString() => 'BackupDecryptionException: $message';
}

class SnapshotManager {
  final SyncEncryptionService encryptionService;

  SnapshotManager({required this.encryptionService});

  Future<String> calculateDatabaseChecksum({
    required AppDatabase db,
    String? customDbPath,
  }) async {
    final tempDir = Directory.systemTemp;
    final tempSnapshotFile = File(
      '${tempDir.path}/temp_checksum_${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );

    try {
      if (await tempSnapshotFile.exists()) {
        await tempSnapshotFile.delete();
      }
      await db.customStatement("VACUUM INTO '${tempSnapshotFile.path}'");
      final rawBytes = await tempSnapshotFile.readAsBytes();
      final hash = await crypto.Sha256().hash(rawBytes);
      return base64Encode(hash.bytes);
    } finally {
      if (await tempSnapshotFile.exists()) {
        try {
          await tempSnapshotFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Exports an encrypted SQLite snapshot of the active Drift [db] to the [provider].
  /// Updates or creates the global manifest.json using [expectedManifestRevision].
  /// Keeps the last 5 snapshots in cloud history, deleting the older ones from storage.
  Future<void> exportSnapshot({
    required AppDatabase db,
    required UserCloudStorageProvider provider,
    required String passphrase,
    required String deviceId,
    required String deviceName,
    required String platform,
    required String appVersion,
    String? expectedManifestRevision,
    String? customDbPath,
  }) async {
    // 1. Prepare temporary file for vacuum snapshot
    final tempDir = Directory.systemTemp;
    final tempSnapshotFile = File(
      '${tempDir.path}/temp_snapshot_${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );

    try {
      // 2. Create a clean SQLite snapshot via VACUUM INTO
      if (await tempSnapshotFile.exists()) {
        await tempSnapshotFile.delete();
      }
      await db.customStatement("VACUUM INTO '${tempSnapshotFile.path}'");

      // 3. Read snapshot bytes
      final rawBytes = await tempSnapshotFile.readAsBytes();

      // Calculate unencrypted SHA-256 checksum for history duplication detection
      final hash = await crypto.Sha256().hash(rawBytes);
      final checksum = base64Encode(hash.bytes);

      // 4. Read current manifest (if it exists) to fetch salt or create new salt
      final existingCloudManifest = await provider.readManifest();
      CloudSyncManifest manifest;
      List<int> salt;
      int snapshotSeq = 1;
      int globalSeq = 0;

      if (existingCloudManifest != null) {
        manifest = CloudSyncManifest.fromJson(existingCloudManifest.content);
        final encInfo = existingCloudManifest.content['encryption'] as Map<String, dynamic>?;
        if (encInfo != null && encInfo['salt'] != null) {
          salt = base64Decode(encInfo['salt'] as String);
        } else {
          salt = encryptionService.generateSalt();
        }
        snapshotSeq = manifest.currentSnapshotSequence + 1;
        globalSeq = manifest.latestGlobalSequence + 1;
      } else {
        salt = encryptionService.generateSalt();
        globalSeq = 1;
        manifest = CloudSyncManifest(
          schemaVersion: 1,
          databaseSchemaVersion: db.schemaVersion,
          currentSnapshotSequence: 0,
          snapshots: [],
          latestGlobalSequence: 0,
          lastMergedAt: DateTime.now().toUtc(),
          encryption: EncryptionConfig(
            keyDerivation: 'PBKDF2',
            iterations: 100000,
            saltBase64: base64Encode(salt),
          ),
          knownDevices: {},
        );
      }

      // 5. Derive key & encrypt snapshot
      final key = await encryptionService.deriveKey(
        passphrase: passphrase,
        salt: salt,
      );
      final encryptedBytes = await encryptionService.encrypt(
        clearText: rawBytes,
        secretKey: key,
      );

      // 6. Write encrypted snapshot file to provider
      final snapshotPath =
          'snapshots/snapshot_${snapshotSeq.toString().padLeft(8, '0')}.sqlite.enc';
      await provider.writeFile(snapshotPath, encryptedBytes);

      // 7. Construct new SnapshotEntry and append it
      final newEntry = SnapshotEntry(
        id: const Uuid().v4(),
        sequence: snapshotSeq,
        checksum: checksum,
        createdAt: DateTime.now().toUtc(),
        path: snapshotPath,
        globalSequence: globalSeq,
        deviceId: deviceId,
        deviceName: deviceName,
        databaseSchemaVersion: db.schemaVersion,
        appVersion: appVersion,
      );

      final bool alreadyPresent = manifest.snapshots.any(
        (s) => s.checksum == checksum || s.path == snapshotPath,
      );
      final List<SnapshotEntry> updatedSnapshots = List.from(manifest.snapshots);
      if (!alreadyPresent) {
        updatedSnapshots.add(newEntry);
      }

      // 8. Prune snapshots history to keep only the last 5 snapshots in memory
      while (updatedSnapshots.length > 5) {
        final oldest = updatedSnapshots.removeAt(0);
        try {
          await provider.deleteFile(oldest.path);
        } catch (_) {
          // Best-effort cleanup of storage snapshot binary file
        }
      }

      // 9. Update manifest JSON content
      final updatedDevices = Map<String, DeviceMetadata>.from(manifest.knownDevices);
      final now = DateTime.now().toUtc();
      final existingDevice = updatedDevices[deviceId];
      updatedDevices[deviceId] = DeviceMetadata(
        deviceId: deviceId,
        deviceName: deviceName,
        platform: platform,
        appVersion: appVersion,
        registeredAt: existingDevice?.registeredAt ?? now,
        lastSeenAt: now,
        lastActive: now,
        latestProcessedSequence: globalSeq,
      );

      final newManifest = CloudSyncManifest(
        schemaVersion: 1,
        databaseSchemaVersion: db.schemaVersion,
        currentSnapshotSequence: snapshotSeq,
        snapshots: updatedSnapshots,
        latestGlobalSequence: globalSeq,
        lastMergedAt: now,
        encryption: EncryptionConfig(
          keyDerivation: 'PBKDF2',
          iterations: 100000,
          saltBase64: base64Encode(salt),
        ),
        knownDevices: updatedDevices,
      );

      // 10. Write manifest back using conditional write / optimistic locking
      await provider.writeManifest(
        newManifest.toJson(),
        expectedRevision: expectedManifestRevision ?? existingCloudManifest?.revision,
      );

      // 11. Strict cleanup of old/orphaned snapshots on Google Drive AppDataFolder
      try {
        final List<CloudFileInfo> allRemoteFiles = await provider.listFiles('snapshots/');
        final Set<String> allowedPaths = updatedSnapshots.map((s) => s.path).toSet();
        for (final fileInfo in allRemoteFiles) {
          if (!allowedPaths.contains(fileInfo.path)) {
            try {
              await provider.deleteFile(fileInfo.path);
            } catch (_) {}
          }
        }
      } catch (_) {}
    } finally {
      // 12. Clean up temp file
      if (await tempSnapshotFile.exists()) {
        try {
          await tempSnapshotFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Downloads, decrypts, and restores the latest snapshot from the [provider] into a local file at [targetPath].
  Future<void> restoreSnapshot({
    required UserCloudStorageProvider provider,
    required String passphrase,
    required String targetPath,
    int? localSchemaVersion,
  }) async {
    // 1. Read manifest to identify the newest snapshot file that still exists.
    final manifestInfo = await provider.readManifest();
    if (manifestInfo == null) {
      throw const BackupCorruptedException('No manifest file found in cloud storage.');
    }

    final manifest = CloudSyncManifest.fromJson(manifestInfo.content);
    if (manifest.snapshots.isEmpty) {
      throw const BackupCorruptedException('No snapshots registered in the manifest.');
    }
    final Set<String> availableSnapshotPaths = <String>{
      for (final CloudFileInfo file in await provider.listFiles('snapshots/'))
        file.path,
    };
    SnapshotEntry? latestSnapshot;
    for (final SnapshotEntry candidate in manifest.snapshots.reversed) {
      if (candidate.path.trim().isEmpty) continue;
      if (availableSnapshotPaths.contains(candidate.path)) {
        latestSnapshot = candidate;
        break;
      }
    }
    if (latestSnapshot == null) {
      throw const BackupCorruptedException(
        'No snapshot files from the manifest are available in cloud storage.',
      );
    }
    final String snapshotPath = latestSnapshot.path;

    // Check schema version compatibility
    if (localSchemaVersion != null && latestSnapshot.databaseSchemaVersion > localSchemaVersion) {
      throw BackupSchemaIncompatibleException(
        'This backup requires database schema version ${latestSnapshot.databaseSchemaVersion}, but this device only supports schema version $localSchemaVersion.',
      );
    }

    final salt = base64Decode(manifest.encryption.saltBase64);

    // 2. Derive key using manifest salt
    final key = await encryptionService.deriveKey(
      passphrase: passphrase,
      salt: salt,
    );

    // 3. Download encrypted snapshot
    final encryptedBytes = await provider.readFile(snapshotPath);
    if (encryptedBytes == null) {
      throw BackupCorruptedException(
        'Snapshot file at $snapshotPath could not be retrieved.',
      );
    }

    // 4. Decrypt snapshot bytes
    Uint8List decryptedBytes;
    try {
      decryptedBytes = await encryptionService.decrypt(
        encryptedData: encryptedBytes,
        secretKey: key,
      );
    } catch (e) {
      throw const BackupDecryptionException('Failed to decrypt backup. Verify your passphrase.');
    }

    // Verify decrypted backup checksum
    final hash = await crypto.Sha256().hash(decryptedBytes);
    final calculatedChecksum = base64Encode(hash.bytes);
    if (calculatedChecksum != latestSnapshot.checksum) {
      throw const BackupCorruptedException('Decrypted backup checksum does not match expected checksum.');
    }

    // 5. Write raw SQLite snapshot to target file path
    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    // Ensure parent directory exists
    await targetFile.parent.create(recursive: true);
    await targetFile.writeAsBytes(decryptedBytes, flush: true);
  }
}
