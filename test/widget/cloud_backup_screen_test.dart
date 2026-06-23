import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/core/widgets/app_ui.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/screens/account/cloud_backup_screen.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/market_data_api_service.dart';
import 'package:zakatapp_flutter/services/sync/cloud_sync_manager.dart';
import 'package:zakatapp_flutter/services/sync/cloud_sync_manifest.dart';
import 'package:zakatapp_flutter/services/sync/snapshot_manager.dart';
import 'package:zakatapp_flutter/services/sync/sync_encryption_service.dart';
import '../support/mock_cloud_storage_provider.dart';

class FakeGoogleSignInAccount extends Fake implements GoogleSignInAccount {
  @override
  String get email => 'user@example.com';
  
  @override
  String get displayName => 'Test User';

  @override
  Future<Map<String, String>> get authHeaders async => {'Authorization': 'Bearer token'};
}

class FakeGoogleSignIn extends Fake implements GoogleSignIn {
  bool isMockSignedIn = false;
  final mockAccount = FakeGoogleSignInAccount();

  @override
  Future<bool> isSignedIn() async => isMockSignedIn;

  @override
  Future<GoogleSignInAccount?> signIn() async {
    isMockSignedIn = true;
    return mockAccount;
  }

  @override
  Future<GoogleSignInAccount?> signOut() async {
    isMockSignedIn = false;
    return null;
  }

  @override
  GoogleSignInAccount? get currentUser => isMockSignedIn ? mockAccount : null;

  @override
  Future<bool> canAccessScopes(List<String> scopes, {String? accessToken}) async => isMockSignedIn;

  @override
  Future<bool> requestScopes(List<String> scopes) async => isMockSignedIn;
}

class FakeMarketDataApiService implements MarketDataApiService {
  @override
  Future<Map<String, double>?> fetchFxRatesToEgp() async => <String, double>{};

  @override
  Future<double?> fetchGold24kPerGramEgp({required double usdToEgp}) async => null;

  @override
  Future<double?> fetchSilverPerGramEgp({required double usdToEgp}) async => null;
}

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
  late CloudSyncManager syncManager;
  late FakeGoogleSignIn fakeGoogleSignIn;
  late AppStateRepository repository;

  final MethodChannel pathProviderChannel = const MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zakatapp_backup_screen_test_');
    mockProvider = MockCloudStorageProvider(connected: true);
    encryptionService = SyncEncryptionService();
    snapshotManager = SnapshotManager(encryptionService: encryptionService);
    
    syncManager = CloudSyncManager(
      provider: mockProvider,
      snapshotManager: snapshotManager,
      deviceId: 'test-device-id',
      deviceName: 'Test Device',
      platform: 'android',
      appVersion: '1.0.0',
    );
    fakeGoogleSignIn = FakeGoogleSignIn();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory' ||
            methodCall.method == 'getTemporaryDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );

    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = AppStateRepository(localStorage: const LocalStorageService());
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      null,
    );
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget buildTestWidget({
    required AppStateController controller,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppStateController>.value(value: controller),
      ],
      child: MaterialApp(
        home: CloudBackupScreen(
          googleSignIn: fakeGoogleSignIn,
          syncManager: syncManager,
        ),
      ),
    );
  }

  testWidgets('Backup screen renders disconnected state', (WidgetTester tester) async {
    final activeDb = AppDatabase(userId: 'test-user', executor: NativeDatabase.memory());
    final controller = AppStateController(
      repository: repository,
      database: activeDb,
      ownsDatabase: false,
      useSqliteLocalStoreProvider: _Gate(true),
      marketDataApiService: FakeMarketDataApiService(),
      enableBackgroundSync: false,
      enableMarketAutoRefresh: false,
    );
    await controller.load();
    await controller.loadAuthenticated('test-user');

    fakeGoogleSignIn.isMockSignedIn = false;

    await tester.pumpWidget(buildTestWidget(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Status: Not connected'), findsOneWidget);
    expect(find.text('Connect Google Drive'), findsOneWidget);
    expect(find.text('Disconnect Google Drive'), findsNothing);
    expect(find.text('Backup Now'), findsNothing);

    await activeDb.close();
  });

  testWidgets('Connected state lists backups from mock provider', (WidgetTester tester) async {
    final activeDb = AppDatabase(userId: 'test-user', executor: NativeDatabase.memory());
    final controller = AppStateController(
      repository: repository,
      database: activeDb,
      ownsDatabase: false,
      useSqliteLocalStoreProvider: _Gate(true),
      marketDataApiService: FakeMarketDataApiService(),
      enableBackgroundSync: false,
      enableMarketAutoRefresh: false,
    );
    await controller.load();
    await controller.loadAuthenticated('test-user');

    fakeGoogleSignIn.isMockSignedIn = true;

    // Seed mock manifest with backups
    final entries = [
      SnapshotEntry(
        id: 'snapshot-1',
        sequence: 1,
        checksum: 'checksum1111111111111111111111',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        path: 'snapshots/snapshot_00000001.sqlite.enc',
        globalSequence: 1,
        deviceId: 'device-ios',
        deviceName: 'iPhone 16',
        databaseSchemaVersion: activeDb.schemaVersion,
        appVersion: '1.0.0',
      ),
      SnapshotEntry(
        id: 'snapshot-2',
        sequence: 2,
        checksum: 'checksum2222222222222222222222',
        createdAt: DateTime.now(),
        path: 'snapshots/snapshot_00000002.sqlite.enc',
        globalSequence: 2,
        deviceId: 'device-android',
        deviceName: 'Pixel 9',
        databaseSchemaVersion: activeDb.schemaVersion,
        appVersion: '1.0.0',
      ),
    ];
    final knownDevices = {
      'device-ios': DeviceMetadata(
        deviceId: 'device-ios',
        deviceName: 'iPhone 16',
        platform: 'ios',
        appVersion: '1.0.0',
        registeredAt: DateTime.now().subtract(const Duration(days: 2)),
        lastSeenAt: DateTime.now().subtract(const Duration(days: 1)),
        lastActive: DateTime.now().subtract(const Duration(days: 1)),
        latestProcessedSequence: 1,
      ),
      'device-android': DeviceMetadata(
        deviceId: 'device-android',
        deviceName: 'Pixel 9',
        platform: 'android',
        appVersion: '1.0.0',
        registeredAt: DateTime.now().subtract(const Duration(hours: 8)),
        lastSeenAt: DateTime.now(),
        lastActive: DateTime.now(),
        latestProcessedSequence: 2,
      ),
    };
    final manifest = CloudSyncManifest(
      schemaVersion: 1,
      databaseSchemaVersion: activeDb.schemaVersion,
      currentSnapshotSequence: 2,
      snapshots: entries,
      latestGlobalSequence: 2,
      lastMergedAt: DateTime.now(),
      encryption: const EncryptionConfig(keyDerivation: 'PBKDF2', iterations: 100000, saltBase64: 'salt'),
      knownDevices: knownDevices,
    );
    await mockProvider.writeManifest(manifest.toJson());

    await tester.pumpWidget(buildTestWidget(controller: controller));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Status: Connected'), findsOneWidget);
    expect(find.text('Disconnect Google Drive'), findsOneWidget);
    expect(find.text('Latest Backup'), findsOneWidget);
    expect(find.text('Previous Backups'), findsOneWidget);
    expect(find.text('iPhone 16'), findsWidgets);
    expect(find.text('Pixel 9'), findsWidgets);
    expect(find.byIcon(Icons.phone_iphone), findsWidgets);
    expect(find.byIcon(Icons.phone_android), findsWidgets);

    await activeDb.close();
  });

  testWidgets('Backup Now creates a new encrypted backup entry', (WidgetTester tester) async {
    final activeDbFile = File(p.join(tempDir.path, 'zakatapp_test-user.sqlite'));
    final activeDb = AppDatabase(userId: 'test-user', executor: NativeDatabase(activeDbFile));
    final controller = AppStateController(
      repository: repository,
      database: activeDb,
      ownsDatabase: false,
      useSqliteLocalStoreProvider: _Gate(true),
      marketDataApiService: FakeMarketDataApiService(),
      enableBackgroundSync: false,
      enableMarketAutoRefresh: false,
    );
    await controller.load();
    await controller.loadAuthenticated('test-user');

    fakeGoogleSignIn.isMockSignedIn = true;

    await tester.pumpWidget(buildTestWidget(controller: controller));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    // Type passphrase
    final textField = find.byType(TextFormField);
    expect(textField, findsOneWidget);
    await tester.enterText(textField, 'test-passphrase-key');
    await tester.pump();

    // Tap backup now
    final backupBtn = find.widgetWithText(ElevatedButton, 'Backup Now');
    // We wait for the async pushSnapshot operation using runAsync
    await tester.runAsync(() async {
      await tester.tap(backupBtn);
      for (int i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        if (find.text('Status: Backup completed').evaluate().isNotEmpty) {
          break;
        }
      }
    });

    expect(find.text('Status: Backup completed'), findsOneWidget);
    expect(find.text('Latest Backup'), findsOneWidget);

    final manifestMeta = await mockProvider.readManifest();
    expect(manifestMeta, isNotNull);
    final manifest = CloudSyncManifest.fromJson(manifestMeta!.content);
    expect(manifest.currentSnapshotSequence, equals(1));
    expect(manifest.snapshots.length, equals(1));

    await activeDb.close();
  });

  testWidgets('Restore calls active database replacement only after double confirmation', (WidgetTester tester) async {
    final activeDbFile = File(p.join(tempDir.path, 'zakatapp_test-user.sqlite'));
    final activeDb = AppDatabase(userId: 'test-user', executor: NativeDatabase(activeDbFile));
    final controller = AppStateController(
      repository: repository,
      database: activeDb,
      ownsDatabase: false,
      useSqliteLocalStoreProvider: _Gate(true),
      marketDataApiService: FakeMarketDataApiService(),
      enableBackgroundSync: false,
      enableMarketAutoRefresh: false,
    );
    await controller.load();
    await controller.loadAuthenticated('test-user');

    // Populate active database with a dummy transaction
    await controller.database!.customStatement(
      "INSERT INTO transactions (id, type, date, amount_text, currency, category, description, created_at, updated_at, rolled_over) "
      "VALUES ('tx-origin-1', 'expense', '2026-06-23', '100.0', 'USD', 'Food', 'Lunch', '2026-06-23T08:00:00Z', '2026-06-23T08:00:00Z', 0)",
    );

    // Create a mock snapshot to restore
    final snapshotDbPath = p.join(tempDir.path, 'snapshot_source.sqlite');
    final snapshotDb = AppDatabase(userId: 'snapshot-source', executor: NativeDatabase(File(snapshotDbPath)));
    await snapshotDb.customStatement(
      "INSERT INTO transactions (id, type, date, amount_text, currency, category, description, created_at, updated_at, rolled_over) "
      "VALUES ('tx-snapshot-1', 'income', '2026-06-23', '500.0', 'USD', 'Salary', 'Pay', '2026-06-23T08:00:00Z', '2026-06-23T08:00:00Z', 0)",
    );
    await snapshotDb.close();

    // Export this snapshot to the mock provider
    const passphrase = 'test-passphrase-key';
    final tempSnapshotDb = AppDatabase(userId: 'temp-db', executor: NativeDatabase(File(snapshotDbPath)));
    await tester.runAsync(() async {
      await snapshotManager.exportSnapshot(
        db: tempSnapshotDb,
        provider: mockProvider,
        passphrase: passphrase,
        deviceId: 'device-id',
        deviceName: 'Device',
        platform: 'platform',
        appVersion: '1.0.0',
        customDbPath: snapshotDbPath,
      );
    });
    await tempSnapshotDb.close();

    await tester.runAsync(() async {
      final manifestMeta = await mockProvider.readManifest();
      if (manifestMeta != null) {
        final manifest = CloudSyncManifest.fromJson(manifestMeta.content);
        if (manifest.snapshots.isNotEmpty) {
          final snapshotPath = manifest.snapshots.first.path;
          final encryptedBytes = await mockProvider.readFile(snapshotPath);
          if (encryptedBytes != null) {
            final key = await encryptionService.deriveKey(passphrase: passphrase, salt: base64Decode(manifest.encryption.saltBase64));
            final decryptedBytes = await encryptionService.decrypt(encryptedData: encryptedBytes, secretKey: key);
            final testRestoreFile = File(p.join(tempDir.path, 'test_restored.sqlite'));
            await testRestoreFile.writeAsBytes(decryptedBytes);
            final checkDb = AppDatabase(userId: 'check-db', executor: NativeDatabase(testRestoreFile));
            final checkRows = await checkDb.customSelect("SELECT * FROM transactions").get();
            expect(checkRows.isNotEmpty, isTrue);
            await checkDb.close();
            await testRestoreFile.delete();
          }
        }
      }
    });

    fakeGoogleSignIn.isMockSignedIn = true;

    await tester.pumpWidget(buildTestWidget(controller: controller));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    // Type passphrase
    await tester.enterText(find.byType(TextFormField), passphrase);
    await tester.pumpAndSettle();

    // Find and tap Restore
    final restoreBtn = find.widgetWithText(ElevatedButton, 'Restore');
    expect(restoreBtn, findsOneWidget);
    await tester.ensureVisible(restoreBtn);
    await tester.tap(restoreBtn);
    await tester.pumpAndSettle();

    // Confirm dialog 1
    expect(find.text('Restore Cloud Backup?'), findsOneWidget);
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();

    // Confirm dialog 2
    expect(find.text('WARNING: Destructive Operation'), findsOneWidget);
    await tester.tap(find.text('Yes, Force Restore'));
    await tester.pumpAndSettle();
    
    // We wait for the async restore operation using runAsync
    await tester.runAsync(() async {
      for (int i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        if (find.text('Status: Restore completed').evaluate().isNotEmpty) {
          break;
        }
      }
    });



    expect(controller.state.transactions.length, equals(1));
    expect(controller.state.transactions.first.id, equals('tx-snapshot-1'));

    await activeDb.close();
  });

  testWidgets('Restore is blocked when the cloud backup requires a newer database schema', (WidgetTester tester) async {
    final activeDb = AppDatabase(userId: 'test-user', executor: NativeDatabase.memory());
    final controller = AppStateController(
      repository: repository,
      database: activeDb,
      ownsDatabase: false,
      useSqliteLocalStoreProvider: _Gate(true),
      marketDataApiService: FakeMarketDataApiService(),
      enableBackgroundSync: false,
      enableMarketAutoRefresh: false,
    );
    await controller.load();
    await controller.loadAuthenticated('test-user');

    final manifest = CloudSyncManifest(
      schemaVersion: 1,
      databaseSchemaVersion: activeDb.schemaVersion,
      currentSnapshotSequence: 1,
      snapshots: [
        SnapshotEntry(
          id: 'schema-blocked',
          sequence: 1,
          checksum: 'checksum-schema-blocked',
          createdAt: DateTime.now(),
          path: 'snapshots/snapshot_00000001.sqlite.enc',
          globalSequence: 1,
          deviceId: 'device-ios',
          deviceName: 'iPhone 16',
          databaseSchemaVersion: activeDb.schemaVersion + 1,
          appVersion: '1.0.0',
        ),
      ],
      latestGlobalSequence: 1,
      lastMergedAt: DateTime.now(),
      encryption: const EncryptionConfig(
        keyDerivation: 'PBKDF2',
        iterations: 100000,
        saltBase64: 'salt',
      ),
      knownDevices: {
        'device-ios': DeviceMetadata(
          deviceId: 'device-ios',
          deviceName: 'iPhone 16',
          platform: 'ios',
          appVersion: '1.0.0',
          registeredAt: DateTime.now(),
          lastSeenAt: DateTime.now(),
          lastActive: DateTime.now(),
          latestProcessedSequence: 1,
        ),
      },
    );
    await mockProvider.writeManifest(manifest.toJson());

    fakeGoogleSignIn.isMockSignedIn = true;

    await tester.pumpWidget(buildTestWidget(controller: controller));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextFormField), 'test-passphrase-key');
    await tester.pump();

    final restoreBtn = find.widgetWithText(ElevatedButton, 'Restore');
    expect(restoreBtn, findsOneWidget);
    await tester.ensureVisible(restoreBtn);
    await tester.tap(restoreBtn);
    await tester.pumpAndSettle();

    expect(find.text('Restore Blocked'), findsOneWidget);
    expect(find.textContaining('schema version'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await activeDb.close();
  });

  testWidgets('Restore is blocked when the cloud backup app version is newer than the local app', (WidgetTester tester) async {
    final activeDb = AppDatabase(userId: 'test-user', executor: NativeDatabase.memory());
    final controller = AppStateController(
      repository: repository,
      database: activeDb,
      ownsDatabase: false,
      useSqliteLocalStoreProvider: _Gate(true),
      marketDataApiService: FakeMarketDataApiService(),
      enableBackgroundSync: false,
      enableMarketAutoRefresh: false,
    );
    await controller.load();
    await controller.loadAuthenticated('test-user');

    final manifest = CloudSyncManifest(
      schemaVersion: 1,
      databaseSchemaVersion: activeDb.schemaVersion,
      currentSnapshotSequence: 1,
      snapshots: [
        SnapshotEntry(
          id: 'app-blocked',
          sequence: 1,
          checksum: 'checksum-app-blocked',
          createdAt: DateTime.now(),
          path: 'snapshots/snapshot_00000001.sqlite.enc',
          globalSequence: 1,
          deviceId: 'device-ios',
          deviceName: 'iPhone 16',
          databaseSchemaVersion: activeDb.schemaVersion,
          appVersion: '9.9.9',
        ),
      ],
      latestGlobalSequence: 1,
      lastMergedAt: DateTime.now(),
      encryption: const EncryptionConfig(
        keyDerivation: 'PBKDF2',
        iterations: 100000,
        saltBase64: 'salt',
      ),
      knownDevices: {
        'device-ios': DeviceMetadata(
          deviceId: 'device-ios',
          deviceName: 'iPhone 16',
          platform: 'ios',
          appVersion: '9.9.9',
          registeredAt: DateTime.now(),
          lastSeenAt: DateTime.now(),
          lastActive: DateTime.now(),
          latestProcessedSequence: 1,
        ),
      },
    );
    await mockProvider.writeManifest(manifest.toJson());

    fakeGoogleSignIn.isMockSignedIn = true;

    await tester.pumpWidget(buildTestWidget(controller: controller));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextFormField), 'test-passphrase-key');
    await tester.pump();

    final restoreBtn = find.widgetWithText(ElevatedButton, 'Restore');
    expect(restoreBtn, findsOneWidget);
    await tester.ensureVisible(restoreBtn);
    await tester.tap(restoreBtn);
    await tester.pumpAndSettle();

    expect(find.text('Restore Blocked'), findsOneWidget);
    expect(find.textContaining('Please update the app'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await activeDb.close();
  });

  testWidgets('Restoring an older backup shows the stale backup warning', (WidgetTester tester) async {
    final activeDb = AppDatabase(userId: 'test-user', executor: NativeDatabase.memory());
    final controller = AppStateController(
      repository: repository,
      database: activeDb,
      ownsDatabase: false,
      useSqliteLocalStoreProvider: _Gate(true),
      marketDataApiService: FakeMarketDataApiService(),
      enableBackgroundSync: false,
      enableMarketAutoRefresh: false,
    );
    await controller.load();
    await controller.loadAuthenticated('test-user');

    final manifest = CloudSyncManifest(
      schemaVersion: 1,
      databaseSchemaVersion: activeDb.schemaVersion,
      currentSnapshotSequence: 2,
      snapshots: [
        SnapshotEntry(
          id: 'older-backup',
          sequence: 1,
          checksum: 'checksum-older',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          path: 'snapshots/snapshot_00000001.sqlite.enc',
          globalSequence: 1,
          deviceId: 'device-ios',
          deviceName: 'iPhone 16',
          databaseSchemaVersion: activeDb.schemaVersion,
          appVersion: '1.0.0',
        ),
        SnapshotEntry(
          id: 'current-backup',
          sequence: 2,
          checksum: 'mock-local-checksum',
          createdAt: DateTime.now(),
          path: 'snapshots/snapshot_00000002.sqlite.enc',
          globalSequence: 2,
          deviceId: 'device-ios',
          deviceName: 'iPhone 16',
          databaseSchemaVersion: activeDb.schemaVersion,
          appVersion: '1.0.0',
        ),
      ],
      latestGlobalSequence: 2,
      lastMergedAt: DateTime.now(),
      encryption: const EncryptionConfig(
        keyDerivation: 'PBKDF2',
        iterations: 100000,
        saltBase64: 'salt',
      ),
      knownDevices: {
        'device-ios': DeviceMetadata(
          deviceId: 'device-ios',
          deviceName: 'iPhone 16',
          platform: 'ios',
          appVersion: '1.0.0',
          registeredAt: DateTime.now(),
          lastSeenAt: DateTime.now(),
          lastActive: DateTime.now(),
          latestProcessedSequence: 2,
        ),
      },
    );
    await mockProvider.writeManifest(manifest.toJson());

    fakeGoogleSignIn.isMockSignedIn = true;

    await tester.pumpWidget(buildTestWidget(controller: controller));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextFormField), 'test-passphrase-key');
    await tester.pump();

    final restoreBtn = find.widgetWithText(OutlinedButton, 'Restore');
    expect(restoreBtn, findsOneWidget);
    await tester.ensureVisible(restoreBtn);
    await tester.tap(restoreBtn);
    await tester.pumpAndSettle();

    expect(find.text('Older Backup Warning'), findsOneWidget);
    expect(find.textContaining('older than your current database'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await activeDb.close();
  });

  testWidgets('Disconnect clears connection and provider state but leaves SQLite untouched', (WidgetTester tester) async {
    final activeDb = AppDatabase(userId: 'test-user', executor: NativeDatabase.memory());
    final controller = AppStateController(
      repository: repository,
      database: activeDb,
      ownsDatabase: false,
      useSqliteLocalStoreProvider: _Gate(true),
      marketDataApiService: FakeMarketDataApiService(),
      enableBackgroundSync: false,
      enableMarketAutoRefresh: false,
    );
    await controller.load();
    await controller.loadAuthenticated('test-user');

    // Populate active database with a row to verify it is untouched
    await controller.database!.customStatement(
      "INSERT INTO transactions (id, type, date, amount_text, currency, category, description, created_at, updated_at, rolled_over) "
      "VALUES ('tx-safe-1', 'expense', '2026-06-23', '10.0', 'USD', 'Food', 'Lunch', '2026-06-23T08:00:00Z', '2026-06-23T08:00:00Z', 0)",
    );

    fakeGoogleSignIn.isMockSignedIn = true;

    await tester.pumpWidget(buildTestWidget(controller: controller));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Status: Connected'), findsOneWidget);

    // Tap disconnect
    final disconnectBtn = find.widgetWithText(AppPrimaryButton, 'Disconnect Google Drive');
    expect(disconnectBtn, findsOneWidget);
    await tester.tap(disconnectBtn);
    await tester.pumpAndSettle();

    // Verification: Renders disconnected state
    expect(find.text('Status: Not connected'), findsOneWidget);
    expect(find.text('Connect Google Drive'), findsOneWidget);

    // Verify SQLite database remains untouched
    final check = await controller.database!.customSelect("SELECT * FROM transactions").get();
    expect(check.length, equals(1));
    expect(check.first.read<String>('id'), equals('tx-safe-1'));

    await activeDb.close();
  });
}
