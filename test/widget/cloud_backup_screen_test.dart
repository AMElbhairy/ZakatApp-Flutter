import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/core/widgets/app_ui.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/screens/account/cloud_backup_screen.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/auth_controller.dart';
import 'package:zakatapp_flutter/features/auth/auth_service.dart' as app_auth;
import 'package:zakatapp_flutter/services/backup_key_manager.dart';
import 'package:zakatapp_flutter/services/cloud_backup_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/market_data_api_service.dart';
import 'package:zakatapp_flutter/services/sync/cloud_sync_manager.dart';
import 'package:zakatapp_flutter/services/sync/cloud_sync_manifest.dart';
import 'package:zakatapp_flutter/services/sync/snapshot_manager.dart';
import 'package:zakatapp_flutter/services/sync/sync_encryption_service.dart';
import 'package:zakatapp_flutter/services/sync/user_cloud_storage_provider.dart';
import 'package:zakatapp_flutter/models/user_profile.dart';
import '../support/mock_cloud_storage_provider.dart';

class FakeGoogleSignInAccount extends Fake implements GoogleSignInAccount {
  @override
  String get email => 'user@example.com';

  @override
  String get displayName => 'Test User';

  @override
  Future<Map<String, String>> get authHeaders async => {
    'Authorization': 'Bearer token',
  };
}

class FakeGoogleSignIn extends Fake implements GoogleSignIn {
  bool isMockSignedIn = false;
  bool driveScopeGranted = true;
  bool requestScopesAllowed = true;
  bool allowInteractiveSignIn = true;
  Completer<void>? signInSilentlyGate;
  int signInCalls = 0;
  int signInSilentlyCalls = 0;
  int requestScopesCalls = 0;
  int signOutCalls = 0;
  final mockAccount = FakeGoogleSignInAccount();

  @override
  Future<bool> isSignedIn() async => isMockSignedIn;

  @override
  Future<GoogleSignInAccount?> signInSilently({
    bool suppressErrors = true,
    bool reAuthenticate = false,
  }) async {
    signInSilentlyCalls += 1;
    final gate = signInSilentlyGate;
    if (gate != null && !gate.isCompleted) {
      await gate.future;
    }
    return isMockSignedIn ? mockAccount : null;
  }

  @override
  Future<GoogleSignInAccount?> signIn() async {
    signInCalls += 1;
    if (!allowInteractiveSignIn) {
      return null;
    }
    isMockSignedIn = true;
    return mockAccount;
  }

  @override
  Future<GoogleSignInAccount?> signOut() async {
    signOutCalls += 1;
    isMockSignedIn = false;
    driveScopeGranted = false;
    return null;
  }

  @override
  GoogleSignInAccount? get currentUser => isMockSignedIn ? mockAccount : null;

  @override
  Future<bool> canAccessScopes(
    List<String> scopes, {
    String? accessToken,
  }) async => isMockSignedIn && driveScopeGranted;

  @override
  Future<bool> requestScopes(List<String> scopes) async {
    requestScopesCalls += 1;
    if (!requestScopesAllowed) {
      return false;
    }
    driveScopeGranted = true;
    isMockSignedIn = true;
    return true;
  }
}

class TrackingMockFirebaseAuth extends MockFirebaseAuth {
  TrackingMockFirebaseAuth({
    required super.mockUser,
    super.signedIn = false,
  });

  int signInWithCredentialCalls = 0;

  @override
  Future<UserCredential> signInWithCredential(AuthCredential? credential) {
    signInWithCredentialCalls += 1;
    return super.signInWithCredential(credential);
  }
}

class TrackingAuthController extends AuthController {
  TrackingAuthController({
    required super.authService,
    required super.localStorage,
  });

  int loadCalls = 0;
  int ensureSessionCalls = 0;

  @override
  Future<void> load() async {
    loadCalls += 1;
    await super.load();
  }

  @override
  Future<bool> ensureSession() async {
    ensureSessionCalls += 1;
    return super.ensureSession();
  }
}

class _FakeAuthService implements app_auth.AuthService {
  _FakeAuthService();

  final UserProfile? user = null;

  @override
  Future<bool> ensureSession() async => true;

  @override
  Future<UserProfile?> restoreSession() async => user;

  @override
  Future<UserProfile?> signIn({
    app_auth.AuthProvider provider = app_auth.AuthProvider.google,
  }) async => user;

  @override
  Future<UserProfile?> signInWithEmail({
    required String email,
    required String password,
  }) async => user;

  @override
  Future<UserProfile?> createAccountWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async => user;

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<UserProfile?> reloadCurrentUser() async => user;

  @override
  Future<bool> isCurrentUserEmailVerified() async =>
      user?.emailVerified ?? false;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMarketDataApiService implements MarketDataApiService {
  @override
  Future<Map<String, double>?> fetchFxRatesToEgp() async => <String, double>{};

  @override
  Future<double?> fetchGold24kPerGramEgp({required double usdToEgp}) async =>
      null;

  @override
  Future<double?> fetchSilverPerGramEgp({required double usdToEgp}) async =>
      null;
}

class _Gate implements UseSqliteLocalStoreProvider {
  _Gate(this.value);
  final bool value;
  @override
  Future<bool> prepareForRead({String? userId}) async => value;
}

class PermissionRevokedMockCloudStorageProvider
    extends MockCloudStorageProvider {
  PermissionRevokedMockCloudStorageProvider() : super(connected: true);

  @override
  Future<CloudManifest?> readManifest() async {
    throw StateError('403 insufficientPermissions permission revoked');
  }
}

class _FakeBackupKeyManager extends BackupKeyManager {
  _FakeBackupKeyManager({required this.key, this.throwOnRecovery = false})
    : super(
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'test-user', email: 'test@example.com'),
        ),
        firestore: FakeFirebaseFirestore(),
      );

  final Uint8List key;
  final bool throwOnRecovery;

  @override
  Future<Uint8List> getOrCreateKey() async {
    if (throwOnRecovery) {
      throw const BackupKeyRecoveryException(
        BackupKeyRecoveryException.recoveryUnavailableMessage,
      );
    }
    return key;
  }

  @override
  Future<Uint8List?> getExistingKey() async {
    if (throwOnRecovery) {
      return null;
    }
    return key;
  }

  @override
  Future<void> recoverKeyFromFirestore() async {
    if (throwOnRecovery) {
      throw const BackupKeyRecoveryException(
        BackupKeyRecoveryException.recoveryUnavailableMessage,
      );
    }
  }

  @override
  Future<void> rotateKey() async {}

  @override
  Future<void> uploadRecoveryKey() async {}
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

  final MethodChannel pathProviderChannel = const MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'zakatapp_backup_screen_test_',
    );
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

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'getApplicationDocumentsDirectory' ||
              methodCall.method == 'getTemporaryDirectory') {
            return tempDir.path;
          }
          return null;
        });

    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = AppStateRepository(localStorage: const LocalStorageService());
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget buildTestWidget({
    required AppStateController controller,
    AuthController? authController,
    BackupKeyManager? backupKeyManager,
    CloudBackupController? cloudBackupController,
  }) {
    final http.Client driveHttpClient = MockClient((request) async {
      if (!fakeGoogleSignIn.driveScopeGranted &&
          request.method == 'GET' &&
          request.url.path.endsWith('/files')) {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 403,
              'message': 'insufficientPermissions',
            },
          }),
          403,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.method == 'GET' && request.url.path.endsWith('/files')) {
        return http.Response(
          jsonEncode({'files': <Map<String, dynamic>>[]}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('OK', 200);
    });
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppStateController>.value(value: controller),
        ChangeNotifierProvider<AuthController>.value(
          value:
              authController ??
              AuthController(
                authService: _FakeAuthService(),
                localStorage: const LocalStorageService(),
              ),
        ),
        if (cloudBackupController != null)
          ChangeNotifierProvider<CloudBackupController>.value(
            value: cloudBackupController,
          ),
      ],
      child: MaterialApp(
        home: CloudBackupScreen(
          googleSignIn: fakeGoogleSignIn,
          syncManager: syncManager,
          backupKeyManager:
              backupKeyManager ??
              _FakeBackupKeyManager(
                key: Uint8List.fromList(
                  List<int>.generate(32, (int i) => i + 1),
                ),
              ),
          driveHttpClient: driveHttpClient,
        ),
      ),
    );
  }

  Future<void> scrollToAndTap(WidgetTester tester, Finder finder) async {
    try {
      await tester.ensureVisible(finder);
    } catch (_) {
      final Finder scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.scrollUntilVisible(
          finder,
          200,
          scrollable: scrollable.first,
        );
      }
    }
    await tester.pumpAndSettle();
    await tester.tap(finder, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  Future<void> grantDrivePermission() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      'cloud_backup_drive_permission_granted_test-user',
      true,
    );
  }

  testWidgets(
    'Backup screen shows checking state before Drive connection resolves',
    (WidgetTester tester) async {
      final activeDb = AppDatabase(
        userId: 'test-user',
        executor: NativeDatabase.memory(),
      );
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

      fakeGoogleSignIn
        ..isMockSignedIn = false
        ..signInSilentlyGate = Completer<void>()
        ..driveScopeGranted = false
        ..requestScopesAllowed = true
        ..allowInteractiveSignIn = true;

      await tester.pumpWidget(buildTestWidget(controller: controller));
      await tester.pump();

      expect(find.text('Not connected'), findsNothing);

      fakeGoogleSignIn.signInSilentlyGate!.complete();
      await tester.pumpAndSettle();

      expect(find.text('Connect Google Drive'), findsOneWidget);
      await activeDb.close();
    },
  );

  testWidgets(
    'Backup screen exposes advanced interval settings in production',
    (WidgetTester tester) async {
      final activeDb = AppDatabase(
        userId: 'test-user',
        executor: NativeDatabase.memory(),
      );
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
      await grantDrivePermission();

      final cloudController = CloudBackupController(
        appStateController: controller,
        authController: AuthController(
          authService: _FakeAuthService(),
          localStorage: const LocalStorageService(),
        ),
        backupKeyManager: _FakeBackupKeyManager(
          key: Uint8List.fromList(
            List<int>.generate(32, (int i) => i + 1),
          ),
        ),
      );
      addTearDown(cloudController.dispose);

      await tester.pumpWidget(
        buildTestWidget(
          controller: controller,
          cloudBackupController: cloudController,
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('advancedBackupSettingsTile')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('advancedBackupSettingsTile')));
      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('advancedBackupSettingsTile')), findsOneWidget);
      expect(find.text('Minimum interval'), findsOneWidget);
      expect(find.text('3 hours'), findsOneWidget);

      await activeDb.close();
    },
  );

  testWidgets(
    'Backup screen keeps cloud deletion hidden until Advanced is expanded',
    (WidgetTester tester) async {
      final activeDb = AppDatabase(
        userId: 'test-user',
        executor: NativeDatabase.memory(),
      );
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
      await grantDrivePermission();

      final cloudController = CloudBackupController(
        appStateController: controller,
        authController: AuthController(
          authService: _FakeAuthService(),
          localStorage: const LocalStorageService(),
        ),
        backupKeyManager: _FakeBackupKeyManager(
          key: Uint8List.fromList(
            List<int>.generate(32, (int i) => i + 1),
          ),
        ),
      );
      addTearDown(cloudController.dispose);

      await tester.pumpWidget(
        buildTestWidget(
          controller: controller,
          cloudBackupController: cloudController,
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('advancedBackupSettingsTile')));
      await tester.tap(find.byKey(const Key('advancedBackupSettingsTile')));
      await tester.pumpAndSettle();

      expect(find.text('Delete All Cloud Backups'), findsOneWidget);

      await activeDb.close();
    },
  );

  testWidgets('Backup screen renders disconnected state', skip: true, (
    WidgetTester tester,
  ) async {
    final activeDb = AppDatabase(
      userId: 'test-user',
      executor: NativeDatabase.memory(),
    );
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

    expect(find.text('Connect Google Drive'), findsOneWidget);
    expect(
      find.text('Connect Google Drive to enable cloud backups'),
      findsOneWidget,
    );
    expect(find.textContaining('appDataFolder is app-private'), findsOneWidget);
    expect(
      find.textContaining('encrypted on this device before upload'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Firebase app login is separate'),
      findsOneWidget,
    );
    expect(find.text('Skip'), findsOneWidget);

    await scrollToAndTap(tester, find.text('Skip'));

    expect(find.text('Connect Google Drive'), findsOneWidget);
    expect(find.text('Disconnect Google Drive'), findsNothing);
    expect(find.text('Backup Now'), findsNothing);
    expect(find.text('Manual Sync Now'), findsNothing);

    await activeDb.close();
  });

  testWidgets('Connected state lists backups from mock provider', skip: true, (
    WidgetTester tester,
  ) async {
    final activeDb = AppDatabase(
      userId: 'test-user',
      executor: NativeDatabase.memory(),
    );
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
    await grantDrivePermission();
    await grantDrivePermission();

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
      encryption: const EncryptionConfig(
        keyDerivation: 'PBKDF2',
        iterations: 100000,
        saltBase64: 'salt',
      ),
      knownDevices: knownDevices,
    );
    await mockProvider.writeManifest(manifest.toJson());

    await tester.pumpWidget(buildTestWidget(controller: controller));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Disconnect Google Drive'), findsOneWidget);
    expect(find.text('Backup Now'), findsOneWidget);
    expect(find.text('Disconnect Google Drive'), findsOneWidget);
    expect(find.text('Latest Backup'), findsOneWidget);
    expect(find.text('Previous Backups'), findsOneWidget);
    expect(find.text('iPhone 16'), findsWidgets);
    expect(find.text('Pixel 9'), findsWidgets);
    expect(find.byIcon(Icons.phone_iphone), findsWidgets);
    expect(find.byIcon(Icons.phone_android), findsWidgets);

    await activeDb.close();
  });

  testWidgets('Backup Now creates a new encrypted backup entry', skip: true, (
    WidgetTester tester,
  ) async {
    final activeDbFile = File(
      p.join(tempDir.path, 'zakatapp_test-user.sqlite'),
    );
    final activeDb = AppDatabase(
      userId: 'test-user',
      executor: NativeDatabase(activeDbFile),
    );
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
    await grantDrivePermission();
    await grantDrivePermission();

    await tester.pumpWidget(buildTestWidget(controller: controller));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    // Tap backup now
    final backupBtn = find.text('Backup Now');
    // We wait for the async pushSnapshot operation using runAsync
    await tester.runAsync(() async {
      await scrollToAndTap(tester, backupBtn);
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

  testWidgets(
    'Automatic key recovery enables backup without passphrase entry',
    skip: true,
    (WidgetTester tester) async {
      final activeDb = AppDatabase(
        userId: 'test-user',
        executor: NativeDatabase.memory(),
      );
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
      await grantDrivePermission();
      await grantDrivePermission();

      await tester.pumpWidget(buildTestWidget(controller: controller));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.textContaining(
          'Backups are encrypted automatically on this device before upload.',
        ),
        findsOneWidget,
      );

      final backupBtn = find.text('Backup Now');
      await tester.runAsync(() async {
        await scrollToAndTap(tester, backupBtn);
        for (int i = 0; i < 50; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          await tester.pump();
          if (find.text('Status: Backup completed').evaluate().isNotEmpty) {
            break;
          }
        }
      });

      final manifestMeta = await mockProvider.readManifest();
      expect(manifestMeta, isNotNull);

      await activeDb.close();
    },
  );

  testWidgets(
    'Google account reuses silent sign-in and requests missing Drive scope only',
    (WidgetTester tester) async {
      final activeDb = AppDatabase(
        userId: 'test-user',
        executor: NativeDatabase.memory(),
      );
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

      fakeGoogleSignIn
        ..isMockSignedIn = true
        ..driveScopeGranted = false
        ..requestScopesAllowed = true
        ..allowInteractiveSignIn = true
        ..signInCalls = 0
        ..signInSilentlyCalls = 0
        ..requestScopesCalls = 0
        ..signOutCalls = 0;

      await tester.pumpWidget(buildTestWidget(controller: controller));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      expect(fakeGoogleSignIn.signInCalls, equals(0));
      expect(fakeGoogleSignIn.signInSilentlyCalls, greaterThan(0));

      final connectBtn = find.widgetWithText(
        FilledButton,
        'Connect Google Drive',
      );
      await tester.ensureVisible(connectBtn);
      await tester.tap(connectBtn);
      await tester.pumpAndSettle();

      expect(fakeGoogleSignIn.signInCalls, equals(0));
      expect(fakeGoogleSignIn.requestScopesCalls, equals(1));
      expect(fakeGoogleSignIn.signOutCalls, equals(0));
      expect(find.textContaining('permission is required'), findsNothing);

      await activeDb.close();
    },
  );

  testWidgets('Email/password user can connect Google Drive separately', (
    WidgetTester tester,
  ) async {
    final activeDb = AppDatabase(
      userId: 'test-user',
      executor: NativeDatabase.memory(),
    );
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

    fakeGoogleSignIn
      ..isMockSignedIn = false
      ..driveScopeGranted = false
      ..requestScopesAllowed = true
      ..allowInteractiveSignIn = true
      ..signInCalls = 0
      ..signInSilentlyCalls = 0
      ..requestScopesCalls = 0
      ..signOutCalls = 0;

    await tester.pumpWidget(buildTestWidget(controller: controller));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    final connectBtn = find.widgetWithText(
      FilledButton,
      'Connect Google Drive',
    );
    await tester.ensureVisible(connectBtn);
    await tester.tap(connectBtn);
    await tester.pumpAndSettle();

    expect(fakeGoogleSignIn.signInCalls, equals(1));
    expect(fakeGoogleSignIn.requestScopesCalls, equals(1));
    expect(fakeGoogleSignIn.signOutCalls, equals(0));

    await activeDb.close();
  });

  testWidgets(
    'Email/password Drive connection leaves Firebase auth unchanged',
    (WidgetTester tester) async {
      final activeDb = AppDatabase(
        userId: 'firebase-user',
        executor: NativeDatabase.memory(),
      );
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

      final TrackingMockFirebaseAuth trackingAuth = TrackingMockFirebaseAuth(
        mockUser: MockUser(uid: 'firebase-user', email: 'user@example.com'),
        signedIn: true,
      );
      final TrackingAuthController authController = TrackingAuthController(
        authService: app_auth.FirebaseAuthService(
          firebaseAuth: trackingAuth,
          googleSignIn: fakeGoogleSignIn,
        ),
        localStorage: const LocalStorageService(),
      );

      await authController.load();
      expect(authController.currentUser, isNotNull);
      expect(authController.currentUser!.id, equals('firebase-user'));
      trackingAuth.signInWithCredentialCalls = 0;
      authController.loadCalls = 0;
      authController.ensureSessionCalls = 0;

      await controller.loadAuthenticated(authController.currentUser!.id);
      await controller.attachCurrentUser(
        userId: authController.currentUser!.id,
        email: authController.currentUser!.email,
        displayName: authController.currentUser!.displayName,
        provider: authController.currentUser!.provider,
      );

      fakeGoogleSignIn
        ..isMockSignedIn = false
        ..driveScopeGranted = false
        ..requestScopesAllowed = true
        ..allowInteractiveSignIn = true
        ..signInCalls = 0
        ..signInSilentlyCalls = 0
        ..requestScopesCalls = 0
        ..signOutCalls = 0;

      await tester.pumpWidget(
        buildTestWidget(controller: controller, authController: authController),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final connectBtn = find.widgetWithText(
        FilledButton,
        'Connect Google Drive',
      );
      await tester.ensureVisible(connectBtn);
      await tester.tap(connectBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(authController.currentUser, isNotNull);
      expect(authController.currentUser!.id, equals('firebase-user'));
      expect(trackingAuth.signInWithCredentialCalls, equals(0));
      expect(authController.ensureSessionCalls, equals(0));
      expect(authController.loadCalls, equals(0));
      expect(fakeGoogleSignIn.signInCalls, equals(1));
      expect(fakeGoogleSignIn.requestScopesCalls, equals(1));
      expect(fakeGoogleSignIn.signOutCalls, equals(0));
      expect(find.textContaining('permission is required'), findsNothing);

      await activeDb.close();
    },
  );

  testWidgets('Cancelled Drive permission does not mark connected', (
    WidgetTester tester,
  ) async {
    final activeDb = AppDatabase(
      userId: 'test-user',
      executor: NativeDatabase.memory(),
    );
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

    fakeGoogleSignIn
      ..isMockSignedIn = true
      ..driveScopeGranted = false
      ..requestScopesAllowed = false
      ..allowInteractiveSignIn = true
      ..signInCalls = 0
      ..signInSilentlyCalls = 0
      ..requestScopesCalls = 0
      ..signOutCalls = 0;

    await tester.pumpWidget(buildTestWidget(controller: controller));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    final connectBtn = find.widgetWithText(
      FilledButton,
      'Connect Google Drive',
    );
    await tester.ensureVisible(connectBtn);
    await tester.tap(connectBtn);
    await tester.pumpAndSettle();

    expect(fakeGoogleSignIn.isMockSignedIn, isTrue);
    expect(fakeGoogleSignIn.signOutCalls, equals(0));
    expect(fakeGoogleSignIn.requestScopesCalls, equals(1));

    await activeDb.close();
  });

  testWidgets(
    'Reopening Backup & Sync keeps the connected state without prompting login again',
    (WidgetTester tester) async {
      final activeDb = AppDatabase(
        userId: 'test-user',
        executor: NativeDatabase.memory(),
      );
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

      fakeGoogleSignIn
        ..isMockSignedIn = true
        ..driveScopeGranted = false
        ..requestScopesAllowed = true
        ..allowInteractiveSignIn = true
        ..signInCalls = 0
        ..signInSilentlyCalls = 0
        ..requestScopesCalls = 0
        ..signOutCalls = 0;

      await tester.pumpWidget(buildTestWidget(controller: controller));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      final connectBtn = find.text('Connect Google Drive');
      await scrollToAndTap(tester, connectBtn);

      expect(fakeGoogleSignIn.signInCalls, equals(0));
      expect(fakeGoogleSignIn.requestScopesCalls, equals(1));

      final callsBeforeReopen = fakeGoogleSignIn.signInCalls;
      await tester.pumpWidget(buildTestWidget(controller: controller));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      expect(fakeGoogleSignIn.signInCalls, equals(callsBeforeReopen));
      expect(fakeGoogleSignIn.signInSilentlyCalls, greaterThanOrEqualTo(2));

      await activeDb.close();
    },
  );

  testWidgets('Key recovery failure shows blocking dialog', skip: true, (
    WidgetTester tester,
  ) async {
    final activeDb = AppDatabase(
      userId: 'test-user',
      executor: NativeDatabase.memory(),
    );
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
    await grantDrivePermission();
    await grantDrivePermission();

    await tester.pumpWidget(
      buildTestWidget(
        controller: controller,
        backupKeyManager: _FakeBackupKeyManager(
          key: Uint8List.fromList(List<int>.generate(32, (int i) => i + 1)),
          throwOnRecovery: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    final backupBtn = find.widgetWithText(FilledButton, 'Backup Now');
    await tester.ensureVisible(backupBtn);
    await tester.tap(backupBtn);
    await tester.pumpAndSettle();

    expect(find.text('Backup Key Recovery Failed'), findsOneWidget);
    expect(find.textContaining('could not be recovered'), findsOneWidget);

    await activeDb.close();
  });

  testWidgets(
    'Restore calls active database replacement only after double confirmation',
    (WidgetTester tester) async {
      final activeDbFile = File(
        p.join(tempDir.path, 'zakatapp_test-user.sqlite'),
      );
      final activeDb = AppDatabase(
        userId: 'test-user',
        executor: NativeDatabase(activeDbFile),
      );
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
      final snapshotDb = AppDatabase(
        userId: 'snapshot-source',
        executor: NativeDatabase(File(snapshotDbPath)),
      );
      await snapshotDb.customStatement(
        "INSERT INTO transactions (id, type, date, amount_text, currency, category, description, created_at, updated_at, rolled_over) "
        "VALUES ('tx-snapshot-1', 'income', '2026-06-23', '500.0', 'USD', 'Salary', 'Pay', '2026-06-23T08:00:00Z', '2026-06-23T08:00:00Z', 0)",
      );
      await snapshotDb.close();

      // Export this snapshot to the mock provider
      final Uint8List recoveryKey = Uint8List.fromList(
        List<int>.generate(32, (int i) => i + 1),
      );
      final String passphrase = base64UrlEncode(recoveryKey);
      final backupKeyManager = _FakeBackupKeyManager(key: recoveryKey);
      final tempSnapshotDb = AppDatabase(
        userId: 'temp-db',
        executor: NativeDatabase(File(snapshotDbPath)),
      );
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
              final key = await encryptionService.deriveKey(
                passphrase: passphrase,
                salt: base64Decode(manifest.encryption.saltBase64),
              );
              final decryptedBytes = await encryptionService.decrypt(
                encryptedData: encryptedBytes,
                secretKey: key,
              );
              final testRestoreFile = File(
                p.join(tempDir.path, 'test_restored.sqlite'),
              );
              await testRestoreFile.writeAsBytes(decryptedBytes);
              final checkDb = AppDatabase(
                userId: 'check-db',
                executor: NativeDatabase(testRestoreFile),
              );
              final checkRows = await checkDb
                  .customSelect("SELECT * FROM transactions")
                  .get();
              expect(checkRows.isNotEmpty, isTrue);
              await checkDb.close();
              await testRestoreFile.delete();
            }
          }
        }
      });

      fakeGoogleSignIn.isMockSignedIn = true;
      await grantDrivePermission();

      await tester.pumpWidget(
        buildTestWidget(
          controller: controller,
          backupKeyManager: backupKeyManager,
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      // Find and tap Restore
      final restoreBtn = find.text('Restore');
      expect(restoreBtn, findsOneWidget);
      await tester.ensureVisible(restoreBtn);
      await scrollToAndTap(tester, restoreBtn);

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
    },
  );

  testWidgets(
    'Restore is blocked when the cloud backup requires a newer database schema',
    (WidgetTester tester) async {
      final activeDb = AppDatabase(
        userId: 'test-user',
        executor: NativeDatabase.memory(),
      );
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
      await mockProvider.writeFile(
        'snapshots/snapshot_00000001.sqlite.enc',
        Uint8List.fromList(<int>[1, 2, 3, 4]),
      );

      fakeGoogleSignIn.isMockSignedIn = true;
      await grantDrivePermission();

      await tester.pumpWidget(buildTestWidget(controller: controller));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      final restoreBtn = find.text('Restore');
      expect(restoreBtn, findsOneWidget);
      await tester.ensureVisible(restoreBtn);
      await scrollToAndTap(tester, restoreBtn);

      expect(find.text('Restore Blocked'), findsOneWidget);
      expect(find.textContaining('schema version'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await activeDb.close();
    },
  );

  testWidgets(
    'Restore is blocked when the cloud backup app version is newer than the local app',
    (WidgetTester tester) async {
      final activeDb = AppDatabase(
        userId: 'test-user',
        executor: NativeDatabase.memory(),
      );
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
      await mockProvider.writeFile(
        'snapshots/snapshot_00000001.sqlite.enc',
        Uint8List.fromList(<int>[1, 2, 3, 4]),
      );

      fakeGoogleSignIn.isMockSignedIn = true;
      await grantDrivePermission();

      await tester.pumpWidget(buildTestWidget(controller: controller));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      final restoreBtn = find.text('Restore');
      expect(restoreBtn, findsOneWidget);
      await tester.ensureVisible(restoreBtn);
      await scrollToAndTap(tester, restoreBtn);

      expect(find.text('Restore Blocked'), findsOneWidget);
      expect(find.textContaining('Please update the app'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await activeDb.close();
    },
  );

  testWidgets('Restoring an older backup shows the stale backup warning', (
    WidgetTester tester,
  ) async {
    final activeDb = AppDatabase(
      userId: 'test-user',
      executor: NativeDatabase.memory(),
    );
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
      await mockProvider.writeFile(
        'snapshots/snapshot_00000001.sqlite.enc',
        Uint8List.fromList(<int>[1, 2, 3, 4]),
      );

    fakeGoogleSignIn.isMockSignedIn = true;
    await grantDrivePermission();

    await tester.pumpWidget(buildTestWidget(controller: controller));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Backup History'));
    await tester.pumpAndSettle();

    final restoreBtn = find.widgetWithText(OutlinedButton, 'Restore');
    expect(restoreBtn, findsOneWidget);
    await tester.ensureVisible(restoreBtn);
    await tester.tap(restoreBtn);
    await tester.pumpAndSettle();

    expect(find.text('Older Backup Warning'), findsOneWidget);
    expect(
      find.textContaining('older than your current database'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await activeDb.close();
  });

  testWidgets(
    'Disconnect clears connection and provider state but leaves SQLite untouched',
    skip: true,
    (WidgetTester tester) async {
      final activeDb = AppDatabase(
        userId: 'test-user',
        executor: NativeDatabase.memory(),
      );
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
      await grantDrivePermission();

      await tester.pumpWidget(buildTestWidget(controller: controller));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Disconnect Google Drive'), findsOneWidget);

      // Tap disconnect
      final disconnectBtn = find.widgetWithText(
        AppPrimaryButton,
        'Disconnect Google Drive',
      );
      expect(disconnectBtn, findsOneWidget);
      await tester.tap(disconnectBtn);
      await tester.pumpAndSettle();

      // Verification: Renders disconnected state
      expect(find.text('Connect Google Drive'), findsOneWidget);
      expect(find.text('Disconnect Google Drive'), findsNothing);

      // Verify SQLite database remains untouched
      final check = await controller.database!
          .customSelect("SELECT * FROM transactions")
          .get();
      expect(check.length, equals(1));
      expect(check.first.read<String>('id'), equals('tx-safe-1'));

      await activeDb.close();
    },
  );

  testWidgets(
    'Permission revoked error shows reconnect message and disconnected state',
    (WidgetTester tester) async {
      final activeDb = AppDatabase(
        userId: 'test-user',
        executor: NativeDatabase.memory(),
      );
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

      final revokedProvider = PermissionRevokedMockCloudStorageProvider();
      final revokedSyncManager = CloudSyncManager(
        provider: revokedProvider,
        snapshotManager: snapshotManager,
        deviceId: 'test-device-id',
        deviceName: 'Test Device',
        platform: 'android',
        appVersion: '1.0.0',
      );

      fakeGoogleSignIn.isMockSignedIn = true;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppStateController>.value(value: controller),
          ],
          child: MaterialApp(
            home: CloudBackupScreen(
              googleSignIn: fakeGoogleSignIn,
              syncManager: revokedSyncManager,
              driveHttpClient: MockClient((request) async {
                if (request.method == 'GET' &&
                    request.url.path.endsWith('/files')) {
                  return http.Response(
                    jsonEncode({'files': <Map<String, dynamic>>[]}),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
                  );
                }
                return http.Response('OK', 200);
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('Google Drive permission was revoked. Please reconnect.'),
        findsOneWidget,
      );
      expect(find.text('Connect Google Drive'), findsOneWidget);

      await activeDb.close();
    },
  );

  testWidgets('Status panel shows backup count and last backup label', (
    WidgetTester tester,
  ) async {
    final activeDb = AppDatabase(
      userId: 'test-user',
      executor: NativeDatabase.memory(),
    );
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
    await grantDrivePermission();

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
      encryption: const EncryptionConfig(
        keyDerivation: 'PBKDF2',
        iterations: 100000,
        saltBase64: 'salt',
      ),
      knownDevices: knownDevices,
    );
    await mockProvider.writeManifest(manifest.toJson());

    await tester.pumpWidget(buildTestWidget(controller: controller));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Last backup:'), findsOneWidget);
    expect(find.text('Latest Backup'), findsOneWidget);
    expect(find.text('Backup History'), findsOneWidget);

    await activeDb.close();
  });

  testWidgets('Missing manifest snapshot file is marked unavailable and cannot be restored', (
    WidgetTester tester,
  ) async {
    final activeDb = AppDatabase(
      userId: 'test-user',
      executor: NativeDatabase.memory(),
    );
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
    final manifest = CloudSyncManifest(
      schemaVersion: 1,
      databaseSchemaVersion: activeDb.schemaVersion,
      currentSnapshotSequence: 2,
      snapshots: entries,
      latestGlobalSequence: 2,
      lastMergedAt: DateTime.now(),
      encryption: const EncryptionConfig(
        keyDerivation: 'PBKDF2',
        iterations: 100000,
        saltBase64: 'salt',
      ),
      knownDevices: const <String, DeviceMetadata>{},
    );
    await mockProvider.writeManifest(manifest.toJson());
    await mockProvider.writeFile(
      entries.first.path,
      Uint8List.fromList(<int>[1, 2, 3, 4]),
    );

    await tester.pumpWidget(buildTestWidget(controller: controller));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Unavailable'), findsWidgets);
    expect(find.widgetWithText(OutlinedButton, 'Unavailable'), findsOneWidget);
    expect(find.text('Backup History'), findsOneWidget);

    await activeDb.close();
  });
}
