import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/services/backup_key_manager.dart';
import 'package:zakatapp_flutter/services/secure_storage_service.dart';
import 'package:zakatapp_flutter/services/sync/cloud_sync_manager.dart';
import 'package:zakatapp_flutter/services/sync/snapshot_manager.dart';
import 'package:zakatapp_flutter/services/sync/sync_encryption_service.dart';

import '../support/mock_cloud_storage_provider.dart';

class _MemorySecureStorageService extends SecureStorageService {
  _MemorySecureStorageService();

  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> loadBackupKey({String? userId}) async {
    return _values['backupKey:${userId ?? 'default'}'];
  }

  @override
  Future<void> saveBackupKey(String keyValue, {String? userId}) async {
    _values['backupKey:${userId ?? 'default'}'] = keyValue;
  }

  @override
  Future<void> deleteBackupKey({String? userId}) async {
    _values.remove('backupKey:${userId ?? 'default'}');
  }
}

String _encodeKey(Uint8List key) => base64UrlEncode(key);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late _MemorySecureStorageService storage;
  late BackupKeyManager manager;
  late Directory tempDir;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'user-1', email: 'user@example.com'),
    );
    storage = _MemorySecureStorageService();
    manager = BackupKeyManager(
      auth: auth,
      firestore: firestore,
      secureStorageService: storage,
      nowProvider: () => DateTime.utc(2026, 6, 23, 12),
    );
    tempDir = await Directory.systemTemp.createTemp('backup_key_manager_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('key is generated once and reused locally', () async {
    final Uint8List first = await manager.getOrCreateKey();
    final Uint8List second = await manager.getOrCreateKey();

    expect(first, equals(second));

    final snapshot = await firestore
        .collection('users')
        .doc('user-1')
        .collection('security')
        .doc('backupKey')
        .get();
    expect(snapshot.exists, isTrue);
    expect(snapshot.data()!['version'], equals(1));
    expect(snapshot.data()!['algorithm'], equals('AES-256-GCM'));
  });

  test('wrapped key is uploaded to Firestore', () async {
    await manager.getOrCreateKey();

    final snapshot = await firestore
        .collection('users')
        .doc('user-1')
        .collection('security')
        .doc('backupKey')
        .get();

    expect(snapshot.exists, isTrue);
    expect((snapshot.data()!['wrappedKey'] as String).isNotEmpty, isTrue);
    expect(snapshot.data()!['keyStatus'], equals('active'));
  });

  test('second device recovers key from Firestore', () async {
    final Uint8List original = await manager.getOrCreateKey();

    final BackupKeyManager secondDeviceManager = BackupKeyManager(
      auth: auth,
      firestore: firestore,
      secureStorageService: _MemorySecureStorageService(),
      nowProvider: () => DateTime.utc(2026, 6, 23, 12),
    );

    await secondDeviceManager.recoverKeyFromFirestore();
    final Uint8List? recovered = await secondDeviceManager.getExistingKey();

    expect(recovered, isNotNull);
    expect(recovered, equals(original));
  });

  test('reinstall recovers key from Firestore', () async {
    final Uint8List original = await manager.getOrCreateKey();
    await storage.deleteBackupKey(userId: 'user-1');

    final BackupKeyManager reinstallManager = BackupKeyManager(
      auth: auth,
      firestore: firestore,
      secureStorageService: storage,
      nowProvider: () => DateTime.utc(2026, 6, 23, 12),
    );

    await reinstallManager.recoverKeyFromFirestore();
    final Uint8List? recovered = await reinstallManager.getExistingKey();

    expect(recovered, equals(original));
  });

  test('Google Drive backup decrypts after recovery', () async {
    final MockCloudStorageProvider provider = MockCloudStorageProvider(connected: true);
    final SyncEncryptionService encryptionService = SyncEncryptionService();
    final SnapshotManager snapshotManager = SnapshotManager(
      encryptionService: encryptionService,
    );

    final File dbFile = File(p.join(tempDir.path, 'source.sqlite'));
    final AppDatabase sourceDb = AppDatabase(
      userId: 'user-1',
      executor: NativeDatabase(dbFile),
    );
    await sourceDb.customStatement(
      "INSERT INTO app_settings (key, value_json, updated_at) VALUES ('theme', '\"automatic\"', '2026-06-23T08:00:00Z')",
    );

    final Uint8List key = await manager.getOrCreateKey();
    final CloudSyncManager syncManagerA = CloudSyncManager(
      provider: provider,
      snapshotManager: snapshotManager,
      deviceId: 'device-a',
      deviceName: 'Device A',
      platform: 'android',
      appVersion: '1.0.0',
    );
    syncManagerA.setPassphrase(_encodeKey(key));
    final pushResult = await syncManagerA.pushSnapshot(db: sourceDb, customDbPath: dbFile.path);
    expect(pushResult.status, equals(CloudSyncStatus.success));
    await sourceDb.close();

    final BackupKeyManager secondDeviceManager = BackupKeyManager(
      auth: auth,
      firestore: firestore,
      secureStorageService: _MemorySecureStorageService(),
      nowProvider: () => DateTime.utc(2026, 6, 23, 12),
    );
    await secondDeviceManager.recoverKeyFromFirestore();
    final Uint8List? recovered = await secondDeviceManager.getExistingKey();
    expect(recovered, isNotNull);

    final CloudSyncManager syncManagerB = CloudSyncManager(
      provider: provider,
      snapshotManager: snapshotManager,
      deviceId: 'device-b',
      deviceName: 'Device B',
      platform: 'ios',
      appVersion: '1.0.0',
    );
    syncManagerB.setPassphrase(_encodeKey(recovered!));

    final String restoredPath = p.join(tempDir.path, 'restored.sqlite');
    final pullResult = await syncManagerB.pullAndRestore(targetPath: restoredPath);
    expect(pullResult.status, equals(CloudSyncStatus.success));

    final String restoredChecksum = await syncManagerB.calculateFileChecksum(restoredPath);
    final manifest = await provider.readManifest();
    expect(restoredChecksum, equals(manifest!.content['snapshots'][0]['checksum']));
  });

  test('missing Firestore key is handled gracefully', () async {
    await manager.recoverKeyFromFirestore();
    final Uint8List? recovered = await manager.getExistingKey();
    expect(recovered, isNull);
  });

  test('key rotation creates a new version', () async {
    final Uint8List original = await manager.getOrCreateKey();
    await manager.rotateKey();
    final Uint8List? rotated = await manager.getExistingKey();

    expect(rotated, isNotNull);
    expect(rotated, isNot(equals(original)));

    final snapshot = await firestore
        .collection('users')
        .doc('user-1')
        .collection('security')
        .doc('backupKey')
        .get();
    expect(snapshot.data()!['version'], equals(2));
  });
}