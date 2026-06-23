import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:uuid/uuid.dart';
import '../../data/local/app_database.dart';
import 'cloud_sync_manifest.dart';
import 'sync_encryption_service.dart';
import 'user_cloud_storage_provider.dart';

class SnapshotManager {
  final SyncEncryptionService encryptionService;

  SnapshotManager({required this.encryptionService});

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
    // 1. Resolve active SQLite db path
    final dbPath = customDbPath ?? await db.resolveDatabasePath();
    if (dbPath == null) {
      throw StateError('Cannot resolve database path.');
    }

    // 2. Prepare temporary file for vacuum snapshot
    final tempDir = Directory.systemTemp;
    final tempSnapshotFile = File(
      '${tempDir.path}/temp_snapshot_${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );

    try {
      // 3. Create a clean SQLite snapshot via VACUUM INTO
      if (await tempSnapshotFile.exists()) {
        await tempSnapshotFile.delete();
      }
      await db.customStatement("VACUUM INTO '${tempSnapshotFile.path}'");

      // 4. Read snapshot bytes
      final rawBytes = await tempSnapshotFile.readAsBytes();

      // Calculate unencrypted SHA-256 checksum for history duplication detection
      final hash = await crypto.Sha256().hash(rawBytes);
      final checksum = base64Encode(hash.bytes);

      // 5. Read current manifest (if it exists) to fetch salt or create new salt
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

      // 6. Derive key & encrypt snapshot
      final key = await encryptionService.deriveKey(
        passphrase: passphrase,
        salt: salt,
      );
      final encryptedBytes = await encryptionService.encrypt(
        clearText: rawBytes,
        secretKey: key,
      );

      // 7. Write encrypted snapshot file to provider
      final snapshotPath =
          'snapshots/snapshot_${snapshotSeq.toString().padLeft(8, '0')}.sqlite.enc';
      await provider.writeFile(snapshotPath, encryptedBytes);

      // 8. Construct new SnapshotEntry and append it
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

      final List<SnapshotEntry> updatedSnapshots = List.from(manifest.snapshots)..add(newEntry);

      // 9. Prune snapshots history to keep only the last 5 snapshots
      while (updatedSnapshots.length > 5) {
        final oldest = updatedSnapshots.removeAt(0);
        try {
          await provider.deleteFile(oldest.path);
        } catch (_) {
          // Best-effort cleanup of storage snapshot binary file
        }
      }

      // 10. Update manifest JSON content
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

      // 11. Write manifest back using conditional write / optimistic locking
      await provider.writeManifest(
        newManifest.toJson(),
        expectedRevision: expectedManifestRevision ?? existingCloudManifest?.revision,
      );
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
  }) async {
    // 1. Read manifest to identify snapshot location
    final manifestInfo = await provider.readManifest();
    if (manifestInfo == null) {
      throw StateError('No manifest file found in cloud storage.');
    }

    final manifest = CloudSyncManifest.fromJson(manifestInfo.content);
    final snapshotPath = manifest.latestSnapshotPath;
    if (snapshotPath == null || snapshotPath.isEmpty) {
      throw StateError('No snapshot path registered in the manifest.');
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
      throw StateError('Snapshot file at $snapshotPath could not be retrieved.');
    }

    // 4. Decrypt snapshot bytes
    final decryptedBytes = await encryptionService.decrypt(
      encryptedData: encryptedBytes,
      secretKey: key,
    );

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
