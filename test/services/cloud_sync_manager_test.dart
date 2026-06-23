import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/sync/cloud_sync_manager.dart';
import 'package:zakatapp_flutter/services/sync/cloud_sync_manifest.dart';
import 'package:zakatapp_flutter/services/sync/snapshot_manager.dart';
import 'package:zakatapp_flutter/services/sync/sync_encryption_service.dart';
import '../support/mock_cloud_storage_provider.dart';

class _Gate implements UseSqliteLocalStoreProvider {
  _Gate(this.value);
  final bool value;
  @override
  Future<bool> prepareForRead({String? userId}) async => value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MockCloudStorageProvider mockProvider;
  late SyncEncryptionService encryptionService;
  late SnapshotManager snapshotManager;
  late CloudSyncManager syncManagerDeviceA;
  late CloudSyncManager syncManagerDeviceB;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zakatapp_mgr_test_');
    mockProvider = MockCloudStorageProvider(connected: true);
    encryptionService = SyncEncryptionService();
    snapshotManager = SnapshotManager(encryptionService: encryptionService);

    syncManagerDeviceA = CloudSyncManager(
      provider: mockProvider,
      snapshotManager: snapshotManager,
      deviceId: 'device-a',
      deviceName: 'Device A',
      platform: 'android',
      appVersion: '1.0.0',
    );
    syncManagerDeviceA.setPassphrase('mgr-secret-password');

    syncManagerDeviceB = CloudSyncManager(
      provider: mockProvider,
      snapshotManager: snapshotManager,
      deviceId: 'device-b',
      deviceName: 'Device B',
      platform: 'ios',
      appVersion: '1.0.0',
    );
    syncManagerDeviceB.setPassphrase('mgr-secret-password');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('CloudSyncManager CheckForUpdates returns noRemoteSnapshot when cloud is empty', () async {
    final result = await syncManagerDeviceA.checkForUpdates(
      localSequence: 0,
      localChecksum: 'some-checksum',
    );
    expect(result.status, equals(CloudSyncStatus.noRemoteSnapshot));
    expect(result.manifest, isNull);
  });

  test('CloudSyncManager pushes, checklist history, and prunes older than 5 snapshots', () async {
    // Setup original DB
    final dbPath = p.join(tempDir.path, 'source.sqlite');
    final dbFile = File(dbPath);
    final db = AppDatabase(userId: 'user-source', executor: NativeDatabase(dbFile));

    // Populate a test row
    await db.customStatement(
      "INSERT INTO app_settings (key, value_json, updated_at) VALUES ('locale', '\"en\"', '2026-06-23T08:00:00Z')",
    );

    // Push 6 snapshot updates using Device A
    for (int i = 1; i <= 6; i++) {
      // Modify a value slightly so checksum differs
      await db.customStatement(
        "UPDATE app_settings SET value_json = '\"en_$i\"' WHERE key = 'locale'",
      );
      final pushResult = await syncManagerDeviceA.pushSnapshot(db: db, customDbPath: dbPath);
      expect(pushResult.status, equals(CloudSyncStatus.success));
    }

    await db.close();

    // Check that manifest shows latest currentSnapshotSequence is 6
    final manifestMeta = await mockProvider.readManifest();
    expect(manifestMeta, isNotNull);
    final manifest = CloudSyncManifest.fromJson(manifestMeta!.content);
    expect(manifest.currentSnapshotSequence, equals(6));
    expect(manifest.latestGlobalSequence, equals(6));
    expect(manifest.knownDevices['device-a']!.deviceId, equals('device-a'));
    expect(manifest.knownDevices['device-a']!.appVersion, equals('1.0.0'));

    // Verify snapshot list is pruned to exactly 5 snapshots (history pruner threshold)
    expect(manifest.snapshots.length, equals(5));
    // Verify sequence history contains sequences 2, 3, 4, 5, 6 (sequence 1 should be pruned)
    expect(manifest.snapshots.map((s) => s.sequence).toList(), equals([2, 3, 4, 5, 6]));

    // Verify pruned snapshot 1 file is deleted from mock provider
    final cloudFiles = await mockProvider.listFiles('snapshots/');
    // There should be exactly 5 encrypted snapshot files left
    expect(cloudFiles.length, equals(5));
    expect(cloudFiles.any((f) => f.path.contains('snapshot_00000001.sqlite.enc')), isFalse);
    expect(cloudFiles.any((f) => f.path.contains('snapshot_00000006.sqlite.enc')), isTrue);
  });

  test('CloudSyncManager CheckForUpdates detects up-to-date and newer remote snapshots', () async {
    // 1. Export snapshot from Device A
    final dbPathA = p.join(tempDir.path, 'db_a.sqlite');
    final dbFileA = File(dbPathA);
    final dbA = AppDatabase(userId: 'user-a', executor: NativeDatabase(dbFileA));
    await dbA.customStatement(
      "INSERT INTO app_settings (key, value_json, updated_at) VALUES ('theme', '\"light\"', '2026-06-23T08:00:00Z')",
    );

    final pushResult = await syncManagerDeviceA.pushSnapshot(db: dbA, customDbPath: dbPathA);
    expect(pushResult.status, equals(CloudSyncStatus.success));

    final manifestMeta = await mockProvider.readManifest();
    final manifest = CloudSyncManifest.fromJson(manifestMeta!.content);
    final snapshotChecksum = manifest.snapshots.last.checksum;
    expect(manifest.knownDevices['device-a']!.deviceName, equals('Device A'));
    expect(manifest.latestGlobalSequence, equals(1));
    
    await dbA.close();

    // 2. Device B checks for updates with local sequence 0 (meaning empty state)
    final checkResult1 = await syncManagerDeviceB.checkForUpdates(
      localSequence: 0,
      localChecksum: '',
    );
    expect(checkResult1.status, equals(CloudSyncStatus.newerAvailable));
    expect(checkResult1.manifest!.currentSnapshotSequence, equals(1));

    // 3. Device B pulls the snapshot and restores it
    final dbPathB = p.join(tempDir.path, 'db_b.sqlite');
    final pullResult = await syncManagerDeviceB.pullAndRestore(targetPath: dbPathB);
    expect(pullResult.status, equals(CloudSyncStatus.success));

    // 4. Device B checks for updates again (now configured with sequence 1 and matching checksum)
    final localChecksumB = await syncManagerDeviceB.calculateFileChecksum(dbPathB);
    expect(localChecksumB, equals(snapshotChecksum));

    final checkResult2 = await syncManagerDeviceB.checkForUpdates(
      localSequence: 1,
      localChecksum: localChecksumB,
    );
    expect(checkResult2.status, equals(CloudSyncStatus.upToDate));
  });

  test('Manifest update with stale revision fails and leaves snapshot and manifest in recoverable state', () async {
    // 1. Setup DB
    final dbPath = p.join(tempDir.path, 'db_opt.sqlite');
    final db = AppDatabase(userId: 'user-opt', executor: NativeDatabase(File(dbPath)));
    await db.customStatement(
      "INSERT INTO app_settings (key, value_json, updated_at) VALUES ('color', '\"blue\"', '2026-06-23T08:00:00Z')",
    );

    // 2. Initial push from Device A
    final pushResult1 = await syncManagerDeviceA.pushSnapshot(db: db, customDbPath: dbPath);
    expect(pushResult1.status, equals(CloudSyncStatus.success));

    // Read the current manifest (this is version 1)
    final manifestMeta1 = await mockProvider.readManifest();
    expect(manifestMeta1, isNotNull);
    final revision1 = manifestMeta1!.revision;

    // 3. Make another push from Device A (updates manifest, revision becomes version 2)
    await db.customStatement("UPDATE app_settings SET value_json = '\"red\"' WHERE key = 'color'");
    final pushResult2 = await syncManagerDeviceA.pushSnapshot(db: db, customDbPath: dbPath);
    expect(pushResult2.status, equals(CloudSyncStatus.success));

    // Read latest manifest (version 2)
    final manifestMeta2 = await mockProvider.readManifest();
    expect(manifestMeta2, isNotNull);
    final revision2 = manifestMeta2!.revision;
    expect(revision2, isNot(equals(revision1)));

    // 4. Try to push snapshot from Device B simulating stale revision1 (which B read earlier)
    final pushResultStale = await syncManagerDeviceB.pushSnapshot(
      db: db,
      customDbPath: dbPath,
      expectedManifestRevision: revision1, // Pass stale revision
    );

    // Must return a conflict status
    expect(pushResultStale.status, equals(CloudSyncStatus.conflict));

    // Verify manifest contents are still intact (corresponds to pushResult2, not the rejected push)
    final manifestMetaFinal = await mockProvider.readManifest();
    expect(manifestMetaFinal!.revision, equals(revision2));
    
    final manifestFinal = CloudSyncManifest.fromJson(manifestMetaFinal.content);
    expect(manifestFinal.currentSnapshotSequence, equals(2));
    expect(manifestFinal.latestGlobalSequence, equals(2));
    expect(manifestFinal.snapshots.last.checksum, isNotEmpty);

    await db.close();
  });

  test('replaceActiveDatabaseWithRestoredFile closes active DB, creates timestamped backup, overwrites with restored DB, reopens, and reloads state', () async {
    // 1. Mock path provider to return tempDir
    const MethodChannel pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        pathProviderChannel,
        null,
      );
    });

    SharedPreferences.setMockInitialValues(<String, Object>{});

    // 2. Initialize AppStateController
    final activeDb = AppDatabase(userId: 'test-user-active');
    final controller = AppStateController(
      repository: AppStateRepository(localStorage: const LocalStorageService()),
      database: activeDb,
      ownsDatabase: true,
      useSqliteLocalStoreProvider: _Gate(true),
    );

    await controller.load();
    await controller.loadAuthenticated('test-user-active');

    // 3. Write initial transaction in active DB
    await controller.database!.customStatement(
      "INSERT INTO transactions (id, type, date, amount_text, currency, category, description, created_at, updated_at, rolled_over) "
      "VALUES ('tx-original', 'expense', '2026-06-23', '100.0', 'USD', 'Food', 'Lunch', '2026-06-23T08:00:00Z', '2026-06-23T08:00:00Z', 0)",
    );

    // Initial check: active db contains tx-original
    final activeCheck = await controller.database!.customSelect("SELECT * FROM transactions").get();
    expect(activeCheck.length, equals(1));
    expect(activeCheck.first.read<String>('id'), equals('tx-original'));

    // 4. Create another sqlite db file as the "restored" db source
    final tempRestoredPath = p.join(tempDir.path, 'restored_temp.sqlite');
    final tempRestoredDb = AppDatabase(userId: 'restored-source', executor: NativeDatabase(File(tempRestoredPath)));
    // Populate "restored" db with tx-restored
    await tempRestoredDb.customStatement(
      "INSERT INTO transactions (id, type, date, amount_text, currency, category, description, created_at, updated_at, rolled_over) "
      "VALUES ('tx-restored', 'income', '2026-06-23', '500.0', 'USD', 'Salary', 'Paycheck', '2026-06-23T08:00:00Z', '2026-06-23T08:00:00Z', 0)",
    );
    await tempRestoredDb.close();

    // 5. Call replaceActiveDatabaseWithRestoredFile on controller
    final activePath = await controller.database!.resolveDatabasePath();
    expect(activePath, isNotNull);

    await controller.replaceActiveDatabaseWithRestoredFile(tempRestoredPath);

    // 6. Verify restored database loaded successfully in controller and memory is refreshed
    expect(controller.isRestoringDatabase, isFalse);
    expect(controller.state.transactions.length, equals(1));
    expect(controller.state.transactions.first.id, equals('tx-restored'));

    final verifyCheck = await controller.database!.customSelect("SELECT * FROM transactions").get();
    expect(verifyCheck.length, equals(1));
    expect(verifyCheck.first.read<String>( 'id'), equals('tx-restored'));

    // 7. Verify timestamped backup file was created containing "tx-original" state
    final dirFiles = tempDir.listSync();
    final backupFiles = dirFiles.where((f) => f.path.contains('restore_backup_') && f.path.endsWith('.bak')).toList();
    expect(backupFiles.length, equals(1));

    final backupFile = File(backupFiles.first.path);
    final backupDb = AppDatabase(userId: 'backup-verify', executor: NativeDatabase(backupFile));
    final backupCheck = await backupDb.customSelect("SELECT * FROM transactions").get();
    expect(backupCheck.length, equals(1));
    expect(backupCheck.first.read<String>('id'), equals('tx-original'));

    await backupDb.close();
    await controller.database!.close();
  });
}
