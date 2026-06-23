import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/services/sync/cloud_sync_manifest.dart';
import 'package:zakatapp_flutter/services/sync/snapshot_manager.dart';
import 'package:zakatapp_flutter/services/sync/sync_encryption_service.dart';
import '../support/mock_cloud_storage_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MockCloudStorageProvider mockProvider;
  late SyncEncryptionService encryptionService;
  late SnapshotManager snapshotManager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zakatapp_test_');
    mockProvider = MockCloudStorageProvider(connected: true);
    encryptionService = SyncEncryptionService();
    snapshotManager = SnapshotManager(encryptionService: encryptionService);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Export SQLite snapshot to MockCloudStorageProvider and restore to separate temp DB', () async {
    // 1. Initialize original database
    final originalDbPath = p.join(tempDir.path, 'original.sqlite');
    final originalDbFile = File(originalDbPath);
    final originalDb = AppDatabase(
      userId: 'test-user',
      executor: NativeDatabase(originalDbFile),
    );

    // Populate sample rows using custom SQL statements to be domain independent
    await originalDb.customStatement(
      "INSERT INTO app_settings (key, value_json, updated_at) VALUES ('theme', '\"dark\"', '2026-06-23T08:00:00Z')",
    );
    await originalDb.customStatement(
      "INSERT INTO transactions (id, type, date, amount_text, currency, category, description, created_at, updated_at, rolled_over) "
      "VALUES ('tx-01', 'expense', '2026-06-23', '150.0', 'USD', 'Food', 'Dinner', '2026-06-23T08:00:00Z', '2026-06-23T08:00:00Z', 0)",
    );

    // Verify row count locally first
    final originalSettings = await originalDb.customSelect("SELECT * FROM app_settings").get();
    expect(originalSettings.length, equals(1));
    expect(originalSettings.first.read<String>('value_json'), equals('"dark"'));

    final originalTxs = await originalDb.customSelect("SELECT * FROM transactions").get();
    expect(originalTxs.length, equals(1));
    expect(originalTxs.first.read<String>('amount_text'), equals('150.0'));

    // 2. Export the snapshot using SnapshotManager
    const passphrase = 'secret-passphrase-abc';
    await snapshotManager.exportSnapshot(
      db: originalDb,
      provider: mockProvider,
      passphrase: passphrase,
      deviceId: 'device-iphone-12',
      deviceName: 'My iPhone',
      platform: 'ios',
      appVersion: '1.0.0',
      customDbPath: originalDbPath,
    );

    // Close original database to free SQLite resources
    await originalDb.close();

    // 3. Verify mock provider has manifest and encrypted snapshot file
    final manifestResult = await mockProvider.readManifest();
    expect(manifestResult, isNotNull);

    final manifest = CloudSyncManifest.fromJson(manifestResult!.content);
    expect(manifest.schemaVersion, equals(1));
    expect(manifest.currentSnapshotSequence, equals(1));
    expect(manifest.latestGlobalSequence, equals(1));
    expect(manifest.latestSnapshotPath, equals('snapshots/snapshot_00000001.sqlite.enc'));
    expect(manifest.knownDevices.containsKey('device-iphone-12'), isTrue);
    expect(manifest.knownDevices['device-iphone-12']!.deviceId, equals('device-iphone-12'));
    expect(manifest.knownDevices['device-iphone-12']!.deviceName, equals('My iPhone'));
    expect(manifest.knownDevices['device-iphone-12']!.appVersion, equals('1.0.0'));
    expect(manifest.snapshots.first.id, isNotEmpty);
    expect(manifest.snapshots.first.deviceId, equals('device-iphone-12'));
    expect(manifest.snapshots.first.deviceName, equals('My iPhone'));
    expect(manifest.snapshots.first.databaseSchemaVersion, equals(originalDb.schemaVersion));
    expect(manifest.snapshots.first.appVersion, equals('1.0.0'));

    // Check that the encrypted snapshot file exists in provider memory
    final fileInfoList = await mockProvider.listFiles('snapshots/');
    expect(fileInfoList.length, equals(1));
    expect(fileInfoList.first.path, equals('snapshots/snapshot_00000001.sqlite.enc'));
    expect(fileInfoList.first.sizeBytes, greaterThan(0));

    // 4. Restore the snapshot into a separate temp database file
    final restoredDbPath = p.join(tempDir.path, 'restored.sqlite');
    await snapshotManager.restoreSnapshot(
      provider: mockProvider,
      passphrase: passphrase,
      targetPath: restoredDbPath,
    );

    // Verify the restored file exists and is not empty
    final restoredFile = File(restoredDbPath);
    expect(await restoredFile.exists(), isTrue);
    expect(await restoredFile.length(), greaterThan(0));

    // 5. Open the restored SQLite copy as a new Drift database instance
    final restoredDb = AppDatabase(
      userId: 'test-user-restored',
      executor: NativeDatabase(restoredFile),
    );

    // Query and verify all data matches the original database perfectly
    final restoredSettings = await restoredDb.customSelect("SELECT * FROM app_settings").get();
    expect(restoredSettings.length, equals(1));
    expect(restoredSettings.first.read<String>('value_json'), equals('"dark"'));

    final restoredTxs = await restoredDb.customSelect("SELECT * FROM transactions").get();
    expect(restoredTxs.length, equals(1));
    expect(restoredTxs.first.read<String>('amount_text'), equals('150.0'));
    expect(restoredTxs.first.read<String>('category'), equals('Food'));

    await restoredDb.close();
  });
}
