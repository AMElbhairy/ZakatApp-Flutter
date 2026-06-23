import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/models/user_profile.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/auth_controller.dart';
import 'package:zakatapp_flutter/services/auth_service.dart';
import 'package:zakatapp_flutter/services/backup_key_manager.dart';
import 'package:zakatapp_flutter/services/cloud_backup_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/market_data_api_service.dart';
import 'package:zakatapp_flutter/services/secure_storage_service.dart';
import 'package:zakatapp_flutter/services/sync/cloud_sync_manager.dart';
import 'package:zakatapp_flutter/services/sync/cloud_sync_manifest.dart';
import 'package:zakatapp_flutter/services/sync/snapshot_manager.dart';
import 'package:zakatapp_flutter/services/sync/sync_encryption_service.dart';

import '../support/mock_cloud_storage_provider.dart';

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.user});

  final UserProfile? user;

  @override
  Future<bool> ensureSession() async => true;

  @override
  Future<UserProfile?> restoreSession() async => user;

  @override
  Future<UserProfile?> signIn({
    AuthProvider provider = AuthProvider.google,
  }) async => user;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RestoringAppStateController extends AppStateController {
  _RestoringAppStateController({
    required super.repository,
    required super.database,
    required super.ownsDatabase,
    required super.secureStorageService,
    required super.useSqliteLocalStoreProvider,
    required super.marketDataApiService,
    required super.enableBackgroundSync,
    required super.enableMarketAutoRefresh,
  });

  @override
  bool get isRestoringDatabase => true;
}

class _SlowMockCloudStorageProvider extends MockCloudStorageProvider {
  _SlowMockCloudStorageProvider()
      : super(connected: true);

  @override
  Future<void> writeManifest(
    Map<String, dynamic> manifestData, {
    String? expectedRevision,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return super.writeManifest(
      manifestData,
      expectedRevision: expectedRevision,
    );
  }
}

class _NoopMarketDataApiService implements MarketDataApiService {
  @override
  Future<Map<String, double>?> fetchFxRatesToEgp() async => <String, double>{};

  @override
  Future<double?> fetchGold24kPerGramEgp({required double usdToEgp}) async =>
      null;

  @override
  Future<double?> fetchSilverPerGramEgp({required double usdToEgp}) async =>
      null;
}

class _Harness {
  _Harness({
    required this.appState,
    required this.auth,
    required this.cloud,
    required this.provider,
    required this.database,
    required this.tempDir,
  });

  final AppStateController appState;
  final AuthController auth;
  final CloudBackupController cloud;
  final MockCloudStorageProvider provider;
  final AppDatabase database;
  final Directory tempDir;
}

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
  Future<String?> loadBackupPassphrase({String? userId}) async {
    return _values['backupPassphrase:${userId ?? 'default'}'];
  }

  @override
  Future<void> saveBackupPassphrase(String passphrase, {String? userId}) async {
    _values['backupPassphrase:${userId ?? 'default'}'] = passphrase;
  }
}

Future<_Harness> _buildHarness({
  required MockCloudStorageProvider provider,
  DateTime Function()? nowProvider,
  Duration debounceDuration = const Duration(milliseconds: 20),
  bool restoring = false,
  bool setupPassphrase = true,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  const LocalStorageService localStorage = LocalStorageService();
  final _MemorySecureStorageService secureStorageService =
      _MemorySecureStorageService();
  final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
  final AppStateRepository repository = AppStateRepository(
    localStorage: localStorage,
  );
  final Directory tempDir = await Directory.systemTemp.createTemp(
    'cloud_backup_controller_test_',
  );
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
  final File dbFile = File(p.join(tempDir.path, 'app.sqlite'));
  final AppDatabase database = AppDatabase(
    userId: 'test-user',
    executor: NativeDatabase(dbFile),
  );
  final AppStateController appState = restoring
      ? _RestoringAppStateController(
          repository: repository,
          database: database,
          ownsDatabase: false,
          secureStorageService: secureStorageService,
          useSqliteLocalStoreProvider: null,
          marketDataApiService: _NoopMarketDataApiService(),
          enableBackgroundSync: false,
          enableMarketAutoRefresh: false,
        )
      : AppStateController(
          repository: repository,
          database: database,
          ownsDatabase: false,
          secureStorageService: secureStorageService,
          marketDataApiService: _NoopMarketDataApiService(),
          enableBackgroundSync: false,
          enableMarketAutoRefresh: false,
        );
  await appState.load();
  await appState.loadAuthenticated('test-user');

  final UserProfile user = const UserProfile(
    id: 'test-user',
    email: 'test@example.com',
    displayName: 'Test User',
    provider: 'google',
    accessToken: 'token',
  );
  final AuthController auth = AuthController(
    authService: _FakeAuthService(user: user),
    localStorage: localStorage,
  );
  await auth.signIn();

  final SnapshotManager snapshotManager = SnapshotManager(
    encryptionService: SyncEncryptionService(),
  );
  final BackupKeyManager backupKeyManager = BackupKeyManager(
    auth: MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'test-user', email: 'test@example.com'),
    ),
    firestore: firestore,
    secureStorageService: secureStorageService,
    nowProvider: nowProvider ?? DateTime.now,
  );
  final CloudSyncManager syncManager = CloudSyncManager(
    provider: provider,
    snapshotManager: snapshotManager,
    deviceId: 'device-1',
    deviceName: 'Test Device',
    platform: 'android',
    appVersion: '1.0.0',
  );

  final CloudBackupController cloud = CloudBackupController(
    appStateController: appState,
    authController: auth,
    backupKeyManager: backupKeyManager,
    snapshotManager: snapshotManager,
    cloudSyncManagerBuilder: () async => syncManager,
    debounceDuration: debounceDuration,
    nowProvider: nowProvider ?? DateTime.now,
  );
  if (setupPassphrase) {
    cloud.setBackupPassphrase(
      base64UrlEncode(await backupKeyManager.getOrCreateKey()),
    );
  }

  return _Harness(
    appState: appState,
    auth: auth,
    cloud: cloud,
    provider: provider,
    database: database,
    tempDir: tempDir,
  );
}

Future<void> _disposeHarness(_Harness harness) async {
  harness.cloud.dispose();
  await harness.database.close();
  const MethodChannel pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    pathProviderChannel,
    null,
  );
  if (await harness.tempDir.exists()) {
    await harness.tempDir.delete(recursive: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('auto backup does not run when disabled', () async {
    final harness = await _buildHarness(
      provider: _SlowMockCloudStorageProvider(),
    );

    harness.cloud.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    final manifest = await harness.provider.readManifest();
    expect(manifest, isNull);
    expect(harness.cloud.automaticBackupEnabled, isFalse);
    expect(harness.cloud.hasPendingAutoBackup, isFalse);

    await _disposeHarness(harness);
  });

  test('auto backup runs when enabled and overdue', () async {
    var currentTime = DateTime.utc(2026, 6, 23, 8);
    final provider = _SlowMockCloudStorageProvider();
    final harness = await _buildHarness(
      provider: provider,
      nowProvider: () => currentTime,
    );

    await harness.cloud.setAutomaticBackupEnabled(true);
    harness.cloud.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final manifestMeta = await provider.readManifest();
    expect(manifestMeta, isNotNull);
    final manifest = CloudSyncManifest.fromJson(manifestMeta!.content);
    expect(manifest.snapshots.length, 1);
    expect(harness.cloud.lastBackupStatus, 'Backup completed');
    expect(harness.cloud.lastBackupAt, isNotNull);
    expect(harness.cloud.nextEligibleBackupAt, isNotNull);
    expect(harness.cloud.lastBackupError, isEmpty);

    currentTime = currentTime.add(const Duration(hours: 7));
    harness.cloud.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final updatedManifestMeta = await provider.readManifest();
    final updatedManifest = CloudSyncManifest.fromJson(updatedManifestMeta!.content);
    expect(updatedManifest.snapshots.length, 1);

    await _disposeHarness(harness);
  });

  test('auto backup skips when checksum unchanged', () async {
    final harness = await _buildHarness(
      provider: _SlowMockCloudStorageProvider(),
    );

    await harness.cloud.backupNow();
    final firstManifestMeta = await harness.provider.readManifest();
    final firstManifest = CloudSyncManifest.fromJson(firstManifestMeta!.content);

    final bool skipped = await harness.cloud.backupNow();
    final secondManifestMeta = await harness.provider.readManifest();
    final secondManifest = CloudSyncManifest.fromJson(secondManifestMeta!.content);

    expect(skipped, isTrue);
    expect(firstManifest.snapshots.length, 1);
    expect(secondManifest.snapshots.length, 1);
    expect(harness.cloud.lastBackupStatus, 'Already backed up');
    expect(harness.cloud.lastBackupError, isEmpty);

    await _disposeHarness(harness);
  });

  test('auto backup does not run during active restore', () async {
    final harness = await _buildHarness(
      provider: _SlowMockCloudStorageProvider(),
      restoring: true,
    );

    await harness.cloud.setAutomaticBackupEnabled(true);
    harness.cloud.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    final manifest = await harness.provider.readManifest();
    expect(manifest, isNull);
    expect(harness.cloud.isRestoring, isTrue);

    await _disposeHarness(harness);
  });

  test('overlapping auto backups are prevented', () async {
    final harness = await _buildHarness(
      provider: _SlowMockCloudStorageProvider(),
    );

    await harness.cloud.setAutomaticBackupEnabled(true);
    final Future<bool> first = harness.cloud.backupNow(automatic: true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final bool second = await harness.cloud.backupNow(automatic: true);
    final bool firstResult = await first;

    final manifestMeta = await harness.provider.readManifest();
    final manifest = CloudSyncManifest.fromJson(manifestMeta!.content);

    expect(firstResult, isTrue);
    expect(second, isFalse);
    expect(manifest.snapshots.length, 1);

    await _disposeHarness(harness);
  });

  test('backup metadata and status update correctly', () async {
    final harness = await _buildHarness(
      provider: _SlowMockCloudStorageProvider(),
    );

    await harness.cloud.refreshCloudState(evaluatePrompt: false);
    expect(harness.cloud.statusMessage, 'Cloud Sync: Active');

    final bool ok = await harness.cloud.backupNow();
    expect(ok, isTrue);
    expect(harness.cloud.lastBackupAt, isNotNull);
    expect(harness.cloud.nextEligibleBackupAt, isNotNull);
    expect(harness.cloud.lastBackupStatus, 'Backup completed');
    expect(harness.cloud.lastBackupError, isEmpty);
    expect(harness.cloud.currentStatus, 'Cloud Sync: Active');

    await _disposeHarness(harness);
  });

  test('corrupted backup or checksum mismatch fails restore', () async {
    final provider = _SlowMockCloudStorageProvider();
    final harness = await _buildHarness(
      provider: provider,
    );

    // Create a valid backup first
    final bool ok = await harness.cloud.backupNow();
    expect(ok, isTrue);

    // Retrieve the manifest and corrupt the latest snapshot's checksum
    final manifestMeta = await provider.readManifest();
    final manifestContent = Map<String, dynamic>.from(manifestMeta!.content);
    final snapshots = List<dynamic>.from(manifestContent['snapshots']);
    final latestSnapshot = Map<String, dynamic>.from(snapshots.last);
    latestSnapshot['checksum'] = 'corrupted_checksum_value';
    snapshots[snapshots.length - 1] = latestSnapshot;
    manifestContent['snapshots'] = snapshots;

    await provider.writeManifest(manifestContent);

    // Trigger restore which should fail due to checksum mismatch
    final bool restoreOk = await harness.cloud.restoreLatestBackup();
    expect(restoreOk, isFalse);
    expect(harness.cloud.lastBackupStatus, contains('checksum does not match'));

    await _disposeHarness(harness);
  });

  test('missing key recovery fails restore gracefully', () async {
    final provider = _SlowMockCloudStorageProvider();
    final harness = await _buildHarness(
      provider: provider,
    );

    // Create a valid backup
    final bool ok = await harness.cloud.backupNow();
    expect(ok, isTrue);

    // Create a new controller instance without passphrase/key in secure storage
    final harness2 = await _buildHarness(
      provider: provider,
      setupPassphrase: false,
    );

    // Also simulate Firestore missing the recovery key
    final BackupKeyManager km = harness2.cloud.backupKeyManager;
    // We can simulate missing Firestore metadata by not uploading/deleting it
    final fakeFirebase = harness2.cloud.backupKeyManager;

    final bool restoreOk = await harness2.cloud.restoreLatestBackup();
    expect(restoreOk, isFalse);
    expect(harness2.cloud.lastBackupStatus, contains('passphrase is required'));

    await _disposeHarness(harness);
    await _disposeHarness(harness2);
  });

  test('revoked Drive permission sets isConnected to false', () async {
    final provider = _SlowMockCloudStorageProvider();
    final harness = await _buildHarness(
      provider: provider,
    );

    // Force drive provider connection probe to return failure due to revoked scope/permission
    provider.connected = false;

    // Refresh state should detect the disconnection
    await harness.cloud.refreshCloudState(evaluatePrompt: false);
    expect(harness.cloud.statusMessage, contains('Google Drive is not connected'));

    await _disposeHarness(harness);
  });

  test('cross-device restore successfully retrieves database from Device A to Device B', () async {
    final provider = _SlowMockCloudStorageProvider();
    final harnessA = await _buildHarness(
      provider: provider,
    );

    // Device A writes a value to local DB and pushes backup
    await harnessA.database.customStatement("CREATE TABLE device_a_test (id INTEGER PRIMARY KEY);");
    final bool backupOk = await harnessA.cloud.backupNow();
    expect(backupOk, isTrue);

    final keyBytes = await harnessA.cloud.backupKeyManager.getExistingKey();
    expect(keyBytes, isNotNull);

    // Device B has same credentials but starts with a fresh empty database
    final harnessB = await _buildHarness(
      provider: provider,
      setupPassphrase: false,
    );

    // Device B recovers Device A's passphrase key (mocked locally using the same harness config)
    harnessB.cloud.setBackupPassphrase(base64UrlEncode(keyBytes!));

    final bool restoreOk = await harnessB.cloud.restoreLatestBackup();
    expect(restoreOk, isTrue);

    // Verify Device B now has Device A's table
    final tablesList = await harnessB.appState.database!.customSelect("SELECT name FROM sqlite_master WHERE type='table' AND name='device_a_test';").get();
    expect(tablesList.length, 1);

    await _disposeHarness(harnessA);
    await _disposeHarness(harnessB);
  });

  test('backup retention keeps only the newest 5 snapshots in provider storage', () async {
    final provider = _SlowMockCloudStorageProvider();
    final harness = await _buildHarness(
      provider: provider,
    );

    // Create 6 unique backups
    for (int i = 1; i <= 6; i++) {
      // Force change local database checksum so it doesn't skip
      await harness.database.customStatement("CREATE TABLE test_retention_$i (id INTEGER PRIMARY KEY);");
      final bool ok = await harness.cloud.backupNow();
      expect(ok, isTrue);
    }

    final manifestMeta = await provider.readManifest();
    final manifest = CloudSyncManifest.fromJson(manifestMeta!.content);
    expect(manifest.snapshots.length, 5); // Manifest keeps 5

    // Also check provider has deleted the oldest physical files
    final remoteFiles = await provider.listFiles('snapshots/');
    expect(remoteFiles.length, 5); // Google Drive contains exactly 5 files

    await _disposeHarness(harness);
  });
}
