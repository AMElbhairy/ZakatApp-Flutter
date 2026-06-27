import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_metadata_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_queue_dao.dart';
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
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
import 'package:zakatapp_flutter/services/sync/google_drive_operation_sync_manager.dart';
import 'package:zakatapp_flutter/services/sync/snapshot_manager.dart';
import 'package:zakatapp_flutter/services/sync/sync_encryption_service.dart';

import 'mock_cloud_storage_provider.dart';

class _AlwaysSqliteGate implements UseSqliteLocalStoreProvider {
  @override
  Future<bool> prepareForRead({String? userId}) async => true;
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

class _MemorySecureStorageService extends SecureStorageService {
  _MemorySecureStorageService();

  final Map<String, String> _values = <String, String>{};

  String _key(String prefix, String? userId) =>
      '$prefix:${userId ?? 'default'}';

  @override
  Future<String?> loadBackupKey({String? userId}) async {
    return _values[_key('backupKey', userId)];
  }

  @override
  Future<void> saveBackupKey(String keyValue, {String? userId}) async {
    _values[_key('backupKey', userId)] = keyValue;
  }

  @override
  Future<void> deleteBackupKey({String? userId}) async {
    _values.remove(_key('backupKey', userId));
  }

  @override
  Future<String?> loadBackupPassphrase({String? userId}) async {
    return _values[_key('backupPassphrase', userId)];
  }

  @override
  Future<void> saveBackupPassphrase(String passphrase, {String? userId}) async {
    _values[_key('backupPassphrase', userId)] = passphrase;
  }

  @override
  Future<void> deleteBackupPassphrase({String? userId}) async {
    _values.remove(_key('backupPassphrase', userId));
  }
}

class _FakeAuthService implements AuthService {
  _FakeAuthService({required this.user});

  final UserProfile user;

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

class GoogleDriveOperationSyncDevice {
  GoogleDriveOperationSyncDevice({
    required this.deviceId,
    required this.deviceName,
    required this.userId,
    required this.database,
    required this.appStateController,
    required this.authController,
    required this.cloudBackupController,
    required this.backupKeyManager,
  });

  final String deviceId;
  final String deviceName;
  final String userId;
  final AppDatabase database;
  final AppStateController appStateController;
  final AuthController authController;
  final CloudBackupController cloudBackupController;
  final BackupKeyManager backupKeyManager;

  AppDatabase get currentDatabase => appStateController.database ?? database;

  Future<void> dispose() async {
    cloudBackupController.dispose();
    authController.dispose();
    appStateController.dispose();
    await currentDatabase.close();
  }
}

class GoogleDriveOperationSyncHarness {
  GoogleDriveOperationSyncHarness({
    required this.rootDir,
    required this.provider,
    required this.firestore,
    required this.deviceA,
    required this.deviceB,
    required this.pathProviderChannel,
    required this.pathProviderHandler,
  });

  final Directory rootDir;
  final MockCloudStorageProvider provider;
  final FakeFirebaseFirestore firestore;
  final GoogleDriveOperationSyncDevice deviceA;
  final GoogleDriveOperationSyncDevice deviceB;
  final MethodChannel pathProviderChannel;
  final Future<dynamic> Function(MethodCall methodCall) pathProviderHandler;

  Future<void> dispose() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await deviceA.dispose();
    await deviceB.dispose();
    if (await rootDir.exists()) {
      await rootDir.delete(recursive: true);
    }
  }
}

Future<GoogleDriveOperationSyncHarness> buildGoogleDriveOperationSyncHarness({
  Duration debounceDuration = const Duration(days: 1),
  MockCloudStorageProvider? provider,
  FakeFirebaseFirestore? firestore,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final Directory rootDir = await Directory.systemTemp.createTemp(
    'google_drive_operation_sync_',
  );
  final MethodChannel pathProviderChannel = const MethodChannel(
    'plugins.flutter.io/path_provider',
  );
  Future<dynamic> pathProviderHandler(MethodCall methodCall) async {
    if (methodCall.method == 'getApplicationDocumentsDirectory') {
      return rootDir.path;
    }
    return null;
  }

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProviderChannel, pathProviderHandler);

  final FakeFirebaseFirestore sharedFirestore =
      firestore ?? FakeFirebaseFirestore();
  final MockCloudStorageProvider sharedProvider =
      provider ?? MockCloudStorageProvider(connected: true);
  final SnapshotManager snapshotManager = SnapshotManager(
    encryptionService: SyncEncryptionService(),
  );
  const LocalStorageService localStorage = LocalStorageService();
  const String authUserId = 'shared-backup-user';
  const String deviceAUserId = 'device-a';
  const String deviceBUserId = 'device-b';

  final GoogleDriveOperationSyncDevice deviceA = await _buildDevice(
    rootDir: rootDir,
    provider: sharedProvider,
    firestore: sharedFirestore,
    snapshotManager: snapshotManager,
    localStorage: localStorage,
    authUserId: authUserId,
    userId: deviceAUserId,
    deviceId: 'device-a',
    deviceName: 'Device A',
    debounceDuration: debounceDuration,
  );
  final GoogleDriveOperationSyncDevice deviceB = await _buildDevice(
    rootDir: rootDir,
    provider: sharedProvider,
    firestore: sharedFirestore,
    snapshotManager: snapshotManager,
    localStorage: localStorage,
    authUserId: authUserId,
    userId: deviceBUserId,
    deviceId: 'device-b',
    deviceName: 'Device B',
    debounceDuration: debounceDuration,
  );

  return GoogleDriveOperationSyncHarness(
    rootDir: rootDir,
    provider: sharedProvider,
    firestore: sharedFirestore,
    deviceA: deviceA,
    deviceB: deviceB,
    pathProviderChannel: pathProviderChannel,
    pathProviderHandler: pathProviderHandler,
  );
}

Future<GoogleDriveOperationSyncDevice> _buildDevice({
  required Directory rootDir,
  required MockCloudStorageProvider provider,
  required FakeFirebaseFirestore firestore,
  required SnapshotManager snapshotManager,
  required LocalStorageService localStorage,
  required String authUserId,
  required String userId,
  required String deviceId,
  required String deviceName,
  required Duration debounceDuration,
}) async {
  final _MemorySecureStorageService secureStorageService =
      _MemorySecureStorageService();
  final File dbFile = File(
    p.join(rootDir.path, AppDatabase.fileNameForUser(userId)),
  );
  final AppDatabase database = AppDatabase(
    userId: userId,
    executor: NativeDatabase(dbFile),
  );
  final AppStateController appStateController = AppStateController(
    repository: AppStateRepository(localStorage: localStorage),
    database: database,
    ownsDatabase: false,
    secureStorageService: secureStorageService,
    marketDataApiService: _NoopMarketDataApiService(),
    enableBackgroundSync: false,
    enableMarketAutoRefresh: false,
    useSqliteLocalStoreProvider: _AlwaysSqliteGate(),
  );
  await appStateController.loadAuthenticated(userId);
  final AppDatabase activeDatabase = appStateController.database ?? database;

  final AuthController authController = AuthController(
    authService: _FakeAuthService(
      user: UserProfile(
        id: authUserId,
        email: 'shared@example.com',
        displayName: 'Shared User',
        provider: 'google',
        accessToken: 'token',
      ),
    ),
    localStorage: localStorage,
  );
  await authController.signIn();

  final MockFirebaseAuth firebaseAuth = MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(uid: authUserId, email: 'shared@example.com'),
  );
  final BackupKeyManager backupKeyManager = BackupKeyManager(
    auth: firebaseAuth,
    firestore: firestore,
    secureStorageService: secureStorageService,
    nowProvider: () => DateTime.utc(2026, 6, 23, 12),
  );

  final Uint8List backupKey = userId == 'device-a'
      ? await backupKeyManager.getOrCreateKey()
      : await _recoverBackupKey(backupKeyManager);

  final CloudSyncManager cloudSyncManager = CloudSyncManager(
    provider: provider,
    snapshotManager: snapshotManager,
    deviceId: deviceId,
    deviceName: deviceName,
    platform: 'android',
    appVersion: '1.0.0',
  );

  final GoogleDriveOperationSyncManager operationSyncManager =
      GoogleDriveOperationSyncManager(
        provider: provider,
        encryptionService: SyncEncryptionService(),
        syncQueueDao: SyncQueueDao(activeDatabase),
        syncMetadataDao: SyncMetadataDao(activeDatabase),
        controller: appStateController,
        deviceId: deviceId,
        deviceName: deviceName,
        appVersion: '1.0.0',
      );

  final CloudBackupController cloudBackupController = CloudBackupController(
    appStateController: appStateController,
    authController: authController,
    backupKeyManager: backupKeyManager,
    snapshotManager: snapshotManager,
    cloudSyncManagerBuilder: () async => cloudSyncManager,
    operationSyncManagerBuilder: () async => operationSyncManager,
    enableOperationSync: true,
    debounceDuration: debounceDuration,
    nowProvider: () => DateTime.utc(2026, 6, 23, 12),
  );
  await cloudBackupController.saveBackupPassphrase(base64UrlEncode(backupKey));

  return GoogleDriveOperationSyncDevice(
    deviceId: deviceId,
    deviceName: deviceName,
    userId: userId,
    database: activeDatabase,
    appStateController: appStateController,
    authController: authController,
    cloudBackupController: cloudBackupController,
    backupKeyManager: backupKeyManager,
  );
}

Future<Uint8List> _recoverBackupKey(BackupKeyManager backupKeyManager) async {
  await backupKeyManager.recoverKeyFromFirestore();
  final Uint8List? recovered = await backupKeyManager.getExistingKey();
  if (recovered == null || recovered.isEmpty) {
    throw StateError('Expected shared backup key to be recoverable.');
  }
  return recovered;
}

Future<void> expectDatabasesEqual(AppDatabase dbA, AppDatabase dbB) async {
  final Map<String, List<String>> left = await _readComparableTables(dbA);
  final Map<String, List<String>> right = await _readComparableTables(dbB);
  expect(left, equals(right));
}

Future<Map<String, List<String>>> _readComparableTables(AppDatabase db) async {
  return <String, List<String>>{
    'transactions': await _readTable(db, 'transactions'),
    'savings': await _readTable(db, 'savings'),
    'investments': await _readTable(db, 'investments'),
    'recurring_transactions': await _readTable(db, 'recurring_transactions'),
    'financial_plans': await _readTable(db, 'financial_plans'),
    'merchant_rules': await _readTable(db, 'merchant_rules'),
    'merchant_confirmations': await _readTable(db, 'merchant_confirmations'),
    'correction_feedback': await _readTable(db, 'correction_feedbacks'),
    'app_settings': await _readTable(db, 'app_settings'),
  };
}

Future<List<String>> _readTable(AppDatabase db, String table) async {
  final String? path = await db.resolveDatabasePath();
  if (path == null || path.trim().isEmpty) {
    return <String>[];
  }

  await Future<void>.delayed(const Duration(milliseconds: 50));
  final AppDatabase reader = AppDatabase(executor: NativeDatabase(File(path)));
  try {
    final List<QueryRow> rows = await reader
        .customSelect('SELECT * FROM $table')
        .get();
    final List<String> comparable =
        rows
            .map((QueryRow row) => _canonicalizeRow(row.data))
            .toList(growable: false)
          ..sort();
    return comparable;
  } finally {
    await reader.close();
  }
}

String _canonicalizeRow(Map<String, Object?> row) {
  const Set<String> ignoredKeys = <String>{'updated_at', 'deleted_at'};
  final List<String> keys =
      row.keys.map((Object? key) => key.toString()).toList()..sort();
  final Map<String, Object?> normalized = <String, Object?>{};
  for (final String key in keys) {
    if (ignoredKeys.contains(key)) {
      continue;
    }
    normalized[key] = _normalizeValue(row[key]);
  }
  return jsonEncode(normalized);
}

Object? _normalizeValue(Object? value) {
  if (value is Map) {
    final List<String> keys =
        value.keys.map((Object? key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final String key in keys) key: _normalizeValue(value[key]),
    };
  }
  if (value is List) {
    return value.map(_normalizeValue).toList(growable: false);
  }
  return value;
}
